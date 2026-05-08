# ==============================================================================
# RAB Pro - Quantity Takeoff Engine
# Reads tagged entities, computes accurate quantities from 3D geometry,
# and produces structured QTO results ready for RAB calculation.
# ==============================================================================

module RABPro
  module RAB
    class QuantityTakeoffEngine

      QTOItem = Struct.new(
        :id,
        :category_id,
        :category_code,
        :category_name,
        :entity_id,
        :entity_name,
        :layer,
        :quantity,
        :unit,
        :quantity_type,
        :geometry_detail,   # { volume_m3, area_m2, length_m, dimensions }
        :is_override,       # true if quantity was manually set
        :notes,
        keyword_init: true
      ) do
        # Custom to_h method to sanitize JSON-unsafe values
        def to_h
          super.each_with_object({}) do |(k, v), memo|
            memo[k] = _sanitize_value(v)
          end
        end

        private

        def _sanitize_value(value)
          case value
          when Float
            value.finite? ? value : 0.0
          when Hash
            value.each_with_object({}) { |(k, v), m| m[k] = _sanitize_value(v) }
          when Array
            value.map { |v| _sanitize_value(v) }
          else
            value
          end
        end
      end

      QTOSummary = Struct.new(
        :category_id,
        :category_code,
        :category_name,
        :group,
        :group_label,
        :unit,
        :quantity_type,
        :total_quantity,
        :item_count,
        :items,
        keyword_init: true
      )

      def initialize(model, settings: nil, project_store: nil)
        @model         = model
        @settings      = settings
        @project_store = project_store
        @analyzer      = Core::Inspector::GeometryAnalyzer.new
      end

      # -----------------------------------------------------------------------
      # Run full QTO on model — returns { items, summary, stats }
      # -----------------------------------------------------------------------
      def run
        Logger.info('QTO Engine: starting takeoff')
        t0 = Time.now

        tagged = Core::Tagger::TagEngine.collect_tagged(@model)
        Logger.info("QTO Engine: #{tagged.size} tagged entities found")

        items = tagged.map { |t| _process_entity(t[:entity], t[:tag]) }.compact

        summary = _aggregate(items)
        stats   = _stats(items, Time.now - t0)

        Logger.info("QTO Engine: complete — #{items.size} items, #{summary.size} categories")

        { items: items, summary: summary, stats: stats }
      end

      # -----------------------------------------------------------------------
      # Run QTO for a single category only
      # -----------------------------------------------------------------------
      def run_for_category(category_id)
        tagged = Core::Tagger::TagEngine.collect_tagged(@model)
                  .select { |t| t[:tag][:category] == category_id.to_s }

        items = tagged.map { |t| _process_entity(t[:entity], t[:tag]) }.compact
        _aggregate(items)[category_id.to_sym]
      end

      # -----------------------------------------------------------------------
      # Build full RAB line items with unit prices applied
      # -----------------------------------------------------------------------
      def build_rab_lines(custom_prices: {}, overhead_pct: 15.0, profit_pct: 10.0)
        qto        = run
        hs_cache   = HargaSatuanDatabase.compute_all(
          custom_prices: custom_prices,
          overhead_pct:  overhead_pct,
          profit_pct:    profit_pct
        )

        rab_lines = []
        groups    = Data::CategoryLibrary.groups

        qto[:summary].each_value do |sum|
          cat_id = sum.category_id
          hs     = hs_cache[cat_id]

          unit_price = hs ? hs[:grand_total] : 0.0

          rab_lines << {
            category_id:    cat_id,
            category_code:  sum.category_code,
            category_name:  sum.category_name,
            group:          sum.group,
            group_label:    sum.group_label || groups[sum.group],
            unit:           sum.unit,
            quantity:       sum.total_quantity,
            unit_price:     unit_price.round(2),
            total_price:    (sum.total_quantity * unit_price).round(2),
            analisa:        hs,
            item_count:     sum.item_count
          }
        end

        # Sort by category code
        rab_lines.sort_by { |l| l[:category_code] || 'ZZ' }
      end

      private

      # -----------------------------------------------------------------------
      # Process a single tagged entity
      # -----------------------------------------------------------------------
      def _process_entity(entity, tag)
        cat_id = tag[:category].to_sym
        cat    = Data::CategoryLibrary.find(cat_id)
        return nil unless cat

        geo = @analyzer.analyze_entity(entity)

        # Use manual override if set
        if tag[:quantity_override]
          qty     = tag[:quantity_override].to_f
          override = true
        else
          qty     = _compute_qty(cat, geo, entity)
          override = false
        end

        return nil if qty.nil? || qty <= 0

        QTOItem.new(
          id:             "qto_#{cat_id}_#{entity.entityID}",
          category_id:    cat_id,
          category_code:  cat.code,
          category_name:  cat.name,
          entity_id:      entity.entityID,
          entity_name:    _entity_name(entity),
          layer:          entity.layer&.name,
          quantity:       qty.round(4),
          unit:           cat.unit,
          quantity_type:  cat.quantity_type,
          geometry_detail: _geo_detail(geo),
          is_override:    override,
          notes:          tag[:note]
        )
      rescue => e
        Logger.warn("QTO: error on entity #{entity.entityID}: #{e.message}")
        nil
      end

      # -----------------------------------------------------------------------
      # Pick correct quantity measure for each category type
      # -----------------------------------------------------------------------
      def _compute_qty(cat, geo, entity)
        return 1.0 if cat.quantity_type == :count

        return nil unless geo

        wall_cats  = %i[dinding_bata dinding_batako dinding_hebel plester cat_dinding]
        floor_cats = %i[lantai_keramik lantai_granit rabat_beton plat_lantai]
        roof_cats  = %i[rangka_atap_baja penutup_atap]

        case cat.quantity_type
        when :volume
          # Prefer solid volume; fall back to bb volume
          vol = geo.volume_m3
          vol > 0 ? vol : GeometryHelper.bounding_box_volume_m3(entity)

        when :area
          if wall_cats.include?(cat.id)
            area = geo.wall_area_m2
            area > 0 ? area : geo.surface_area_m2 / 2.0  # rough estimate
          elsif floor_cats.include?(cat.id) || roof_cats.include?(cat.id)
            area = geo.floor_area_m2
            area > 0 ? area : geo.surface_area_m2 / 2.0
          else
            geo.surface_area_m2
          end

        when :length
          # Use longest bounding box dimension
          [geo.length_m, geo.width_m, geo.height_m].max

        else
          nil
        end
      end

      # -----------------------------------------------------------------------
      # Aggregate QTO items by category
      # -----------------------------------------------------------------------
      def _aggregate(items)
        grouped = items.group_by(&:category_id)
        groups  = Data::CategoryLibrary.groups

        grouped.transform_values do |group_items|
          first = group_items.first
          cat   = Data::CategoryLibrary.find(first.category_id)

          QTOSummary.new(
            category_id:    first.category_id,
            category_code:  first.category_code,
            category_name:  first.category_name,
            group:          cat&.group,
            group_label:    groups[cat&.group],
            unit:           first.unit,
            quantity_type:  first.quantity_type,
            total_quantity: group_items.sum(&:quantity).round(4),
            item_count:     group_items.size,
            items:          group_items
          )
        end
      end

      def _geo_detail(geo)
        return {} unless geo
        {
          volume_m3:  _safe_float(geo.volume_m3),
          area_m2:    _safe_float(geo.surface_area_m2),
          floor_m2:   _safe_float(geo.floor_area_m2),
          wall_m2:    _safe_float(geo.wall_area_m2),
          length_m:   _safe_float(geo.length_m),
          width_m:    _safe_float(geo.width_m),
          height_m:   _safe_float(geo.height_m),
          is_solid:   geo.is_solid
        }
      end

      def _safe_float(value)
        return 0.0 if value.nil?
        return 0.0 unless value.is_a?(Float) || value.is_a?(Integer)
        
        f = value.to_f
        f.finite? ? f : 0.0
      end

      def _stats(items, elapsed)
        {
          total_items:     items.size,
          categories_hit:  items.map(&:category_id).uniq.size,
          overrides:       items.count(&:is_override),
          elapsed_seconds: elapsed.round(3)
        }
      end

      def _entity_name(entity)
        if entity.is_a?(Sketchup::ComponentInstance)
          entity.name.empty? ? entity.definition.name : entity.name
        else
          entity.name
        end
      end

    end
  end
end
