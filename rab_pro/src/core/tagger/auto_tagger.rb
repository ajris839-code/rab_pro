# ==============================================================================
# RAB Pro - Auto Tagger
# Automatically assigns RAB categories to model entities based on:
#   1. Layer name pattern matching
#   2. Component / group name pattern matching
#   3. Material name hints
#   4. Geometric heuristics (e.g. thin flat horizontal → floor)
# ==============================================================================

module RABPro
  module Core
    module Tagger
      class AutoTagger

        Result = Struct.new(:tagged, :skipped, :errors, :log, keyword_init: true)

        def initialize(model)
          @model   = model
          @lib     = Data::CategoryLibrary
          @tagged  = 0
          @skipped = 0
          @errors  = 0
          @log     = []
        end

        # ----------------------------------------------------------------------
        # Main entry — iterates all entities and applies best-match category
        # ----------------------------------------------------------------------
        def run
          _traverse(@model.entities)
          Result.new(
            tagged:  @tagged,
            skipped: @skipped,
            errors:  @errors,
            log:     @log
          )
        end

        # ----------------------------------------------------------------------
        # Tag a single entity with a specific category (called from UI)
        # ----------------------------------------------------------------------
        def tag_entity(entity, category_id)
          cat = @lib.find(category_id)
          raise ArgumentError, "Unknown category: #{category_id}" unless cat
          _write_tag(entity, cat)
        end

        # ----------------------------------------------------------------------
        # Clear all RAB Pro tags from an entity
        # ----------------------------------------------------------------------
        def clear_tags(entity)
          entity.delete_attribute('RABPro', 'category')
          entity.delete_attribute('RABPro', 'unit')
          entity.delete_attribute('RABPro', 'category_code')
          entity.delete_attribute('RABPro', 'tagged_at')
        end

        private

        def _traverse(entities)
          entities.each do |entity|
            case entity
            when Sketchup::ComponentInstance, Sketchup::Group
              _process_entity(entity)
              child_entities = entity.is_a?(Sketchup::Group) ?
                               entity.entities :
                               entity.definition.entities
              _traverse(child_entities)
            end
          end
        end

        def _process_entity(entity)
          return if _already_tagged?(entity)

          cat = _detect_category(entity)
          if cat
            _write_tag(entity, cat)
            @tagged += 1
            @log << { entity_id: entity.entityID, category: cat.id, method: @_last_method }
          else
            @skipped += 1
          end
        rescue => e
          @errors += 1
          Logger.error("AutoTagger: error on entity #{entity.entityID}: #{e.message}")
        end

        # ----------------------------------------------------------------------
        # Detection pipeline — tries methods in priority order
        # ----------------------------------------------------------------------
        def _detect_category(entity)
          # Priority 1: layer name
          cat = _match_by_layer(entity)
          return (@_last_method = :layer) && cat if cat

          # Priority 2: entity/definition name
          cat = _match_by_name(entity)
          return (@_last_method = :name) && cat if cat

          # Priority 3: material
          cat = _match_by_material(entity)
          return (@_last_method = :material) && cat if cat

          # Priority 4: geometry heuristics
          cat = _match_by_geometry(entity)
          return (@_last_method = :geometry) && cat if cat

          nil
        end

        def _match_by_layer(entity)
          layer_name = entity.layer&.name.to_s
          return nil if layer_name.empty?

          @lib.all.find do |cat|
            StringHelper.matches_any?(layer_name, cat.layer_patterns)
          end
        end

        def _match_by_name(entity)
          name = _entity_display_name(entity)
          return nil if name.nil? || name.strip.empty?

          @lib.all.find do |cat|
            patterns = cat.layer_patterns + [cat.name, cat.name_en]
            StringHelper.matches_any?(name, patterns)
          end
        end

        def _match_by_material(entity)
          mat_name = entity.material&.name.to_s
          return nil if mat_name.empty?

          # Simple keyword approach for materials
          n = StringHelper.normalize(mat_name)

          return @lib.find(:bata_merah)    if n.include?('bata')
          return @lib.find(:dinding_hebel) if n.include?('hebel') || n.include?('aac')
          return @lib.find(:lantai_keramik) if n.include?('keramik') || n.include?('ceramic')
          return @lib.find(:lantai_granit)  if n.include?('granit') || n.include?('marble')
          return @lib.find(:kolom)          if n.include?('beton') || n.include?('concrete')
          nil
        end

        def _match_by_geometry(entity)
          bb = entity.bounds
          return nil if bb.empty?

          w = bb.width   # inches
          h = bb.height
          d = bb.depth

          dims = [w, h, d].sort  # ascending: [thin, medium, large]
          thickness_m = UnitConverter.inches_to_m(dims[0])
          span_m      = UnitConverter.inches_to_m(dims[2])

          # Very thin horizontal entity → likely floor / slab
          if thickness_m < 0.3 && span_m > 0.5
            normal_up = _dominant_normal_is_vertical?(entity)
            return @lib.find(:plat_lantai) if normal_up
          end

          # Tall narrow entity → likely column
          h_m = UnitConverter.inches_to_m(h)
          w_m = UnitConverter.inches_to_m(w)
          d_m = UnitConverter.inches_to_m(d)
          if h_m > 2.0 && w_m < 0.8 && d_m < 0.8
            return @lib.find(:kolom)
          end

          # Wide flat horizontal entity, not too thin → plat lantai or atap
          if d_m < 0.5 && w_m > 1.0
            return @lib.find(:plat_lantai)
          end

          nil
        end

        # ----------------------------------------------------------------------
        # Helpers
        # ----------------------------------------------------------------------

        def _already_tagged?(entity)
          !entity.get_attribute('RABPro', 'category').nil?
        end

        def _write_tag(entity, cat)
          entity.set_attribute('RABPro', 'category',      cat.id.to_s)
          entity.set_attribute('RABPro', 'category_code', cat.code)
          entity.set_attribute('RABPro', 'unit',          cat.unit)
          entity.set_attribute('RABPro', 'tagged_at',     Time.now.iso8601)
        end

        def _entity_display_name(entity)
          if entity.is_a?(Sketchup::ComponentInstance)
            entity.name.empty? ? entity.definition.name : entity.name
          else
            entity.name
          end
        end

        def _dominant_normal_is_vertical?(entity)
          faces = GeometryHelper.collect_faces(entity)
          return false if faces.empty?
          biggest = faces.max_by(&:area)
          n = biggest.normal
          n.dot(Geom::Vector3d.new(0, 0, 1)).abs > 0.9
        rescue
          false
        end

      end
    end
  end
end
