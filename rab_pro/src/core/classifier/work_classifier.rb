# ==============================================================================
# RAB Pro - Work Classifier
# Maps tagged entities to formal SNI pekerjaan items.
# Produces structured work items ready for the RAB engine (Fase 2).
# Also handles sub-item decomposition (e.g. dinding → pasang + plester + aci)
# ==============================================================================

module RABPro
  module Core
    module Classifier

      WorkItem = Struct.new(
        :work_id,         # unique identifier for this work item
        :category_id,     # maps to CategoryLibrary category
        :category_code,   # e.g. "E.1"
        :category_name,   # display name
        :entity_id,       # source SketchUp entity
        :entity_name,
        :quantity,        # computed quantity (already in correct unit)
        :unit,            # unit string e.g. "m²"
        :quantity_type,   # :volume | :area | :length | :count
        :sub_items,       # array of WorkItem (decomposed sub-pekerjaan)
        :notes,
        keyword_init: true
      )

      class WorkClassifier

        # Sub-item decomposition rules
        # Each entry: { category: :parent_cat, sub_items: [{ category_id:, factor: }] }
        # factor = multiplier applied to parent quantity
        SUB_ITEM_RULES = {
          dinding_bata: [
            { category_id: :plester, factor: 2.0, note: 'Plesteran kedua sisi' },
            { category_id: :cat_dinding, factor: 2.0, note: 'Cat kedua sisi' }
          ],
          dinding_batako: [
            { category_id: :plester, factor: 2.0, note: 'Plesteran kedua sisi' },
            { category_id: :cat_dinding, factor: 2.0, note: 'Cat kedua sisi' }
          ],
          dinding_hebel: [
            { category_id: :plester, factor: 2.0, note: 'Plesteran kedua sisi (tipis)' },
            { category_id: :cat_dinding, factor: 2.0, note: 'Cat kedua sisi' }
          ],
          lantai_keramik: [
            { category_id: :rabat_beton, factor: 1.0, note: 'Rabat beton di bawah keramik' }
          ],
          lantai_granit: [
            { category_id: :rabat_beton, factor: 1.0, note: 'Rabat beton di bawah granit' }
          ]
        }.freeze

        def initialize(model)
          @model    = model
          @analyzer = Inspector::GeometryAnalyzer.new
        end

        # ----------------------------------------------------------------------
        # Classify all tagged entities → array of WorkItem
        # ----------------------------------------------------------------------
        def classify_all
          tagged_items = Tagger::TagEngine.group_by_category(@model)
          work_items   = []

          tagged_items.each do |cat_id, entities|
            cat = Data::CategoryLibrary.find(cat_id.to_sym)
            next unless cat

            entities.each do |item|
              entity  = item[:entity]
              tag     = item[:tag]
              geo     = @analyzer.analyze_entity(entity)

              qty = _compute_quantity(entity, cat, geo, tag)
              next if qty.nil? || qty <= 0

              wi = WorkItem.new(
                work_id:       "#{cat.id}_#{entity.entityID}",
                category_id:   cat.id,
                category_code: cat.code,
                category_name: cat.name,
                entity_id:     entity.entityID,
                entity_name:   _entity_name(entity),
                quantity:      qty.round(4),
                unit:          cat.unit,
                quantity_type: cat.quantity_type,
                sub_items:     _decompose(cat, qty),
                notes:         tag[:note]
              )
              work_items << wi
            end
          end

          work_items
        end

        # ----------------------------------------------------------------------
        # Group and aggregate work items by category for RAB table
        # Returns: { category_id => { cat_info, total_quantity, items: [] } }
        # ----------------------------------------------------------------------
        def aggregate
          items   = classify_all
          grouped = items.group_by(&:category_id)

          grouped.transform_values do |group_items|
            first = group_items.first
            cat   = Data::CategoryLibrary.find(first.category_id)
            {
              category_id:   first.category_id,
              category_code: first.category_code,
              category_name: first.category_name,
              group:         cat&.group,
              group_label:   Data::CategoryLibrary.groups[cat&.group],
              unit:          first.unit,
              quantity_type: first.quantity_type,
              total_quantity: group_items.sum(&:quantity).round(4),
              item_count:    group_items.size,
              items:         group_items
            }
          end
        end

        # ----------------------------------------------------------------------
        # Summary suitable for AI context (compact)
        # ----------------------------------------------------------------------
        def ai_summary
          agg = aggregate
          agg.values.map do |g|
            "#{g[:category_code]} #{g[:category_name]}: #{g[:total_quantity]} #{g[:unit]} (#{g[:item_count]} entitas)"
          end.join("\n")
        end

        private

        # Pick the right quantity measure based on category's quantity_type
        def _compute_quantity(entity, cat, geo, tag)
          # Use manual override if set
          override = tag[:quantity_override]
          return override.to_f if override

          return nil unless geo

          case cat.quantity_type
          when :volume  then geo.volume_m3
          when :area    then _pick_area(cat, geo)
          when :length  then geo.length_m
          when :count   then 1.0
          else geo.volume_m3
          end
        end

        def _pick_area(cat, geo)
          # For wall-type categories use wall area, for floor use floor area
          wall_cats = %i[dinding_bata dinding_batako dinding_hebel plester cat_dinding]
          floor_cats = %i[lantai_keramik lantai_granit rabat_beton plat_lantai]

          if wall_cats.include?(cat.id)
            geo.wall_area_m2 > 0 ? geo.wall_area_m2 : geo.surface_area_m2
          elsif floor_cats.include?(cat.id)
            geo.floor_area_m2 > 0 ? geo.floor_area_m2 : geo.surface_area_m2
          else
            geo.surface_area_m2
          end
        end

        # Decompose a work item into sub-items per rules table
        def _decompose(cat, qty)
          rules = SUB_ITEM_RULES[cat.id]
          return [] unless rules

          rules.map do |rule|
            sub_cat = Data::CategoryLibrary.find(rule[:category_id])
            next unless sub_cat

            WorkItem.new(
              work_id:       "sub_#{cat.id}_#{sub_cat.id}",
              category_id:   sub_cat.id,
              category_code: sub_cat.code,
              category_name: sub_cat.name,
              entity_id:     nil,
              entity_name:   nil,
              quantity:      (qty * rule[:factor]).round(4),
              unit:          sub_cat.unit,
              quantity_type: sub_cat.quantity_type,
              sub_items:     [],
              notes:         rule[:note]
            )
          end.compact
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
end
