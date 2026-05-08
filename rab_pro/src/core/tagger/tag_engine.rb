# ==============================================================================
# RAB Pro - Tag Engine
# Low-level read/write/query engine for RAB Pro attribute tags on entities.
# The AutoTagger uses this as its persistence layer.
# The RAB engine (Fase 2) reads from this to build quantity takeoffs.
# ==============================================================================

module RABPro
  module Core
    module Tagger
      class TagEngine

        DICT      = 'RABPro'.freeze
        KEY_CAT   = 'category'.freeze
        KEY_CODE  = 'category_code'.freeze
        KEY_UNIT  = 'unit'.freeze
        KEY_NOTE  = 'note'.freeze
        KEY_QTY   = 'quantity_override'.freeze  # manual override for qty
        KEY_PRICE = 'price_override'.freeze     # manual unit price override
        KEY_DATE  = 'tagged_at'.freeze
        KEY_VER   = 'rab_pro_version'.freeze

        class << self

          # ------------------------------------------------------------------
          # Write a full tag to an entity
          # ------------------------------------------------------------------
          def write(entity, category_id:, unit: nil, note: nil)
            cat = Data::CategoryLibrary.find(category_id)
            raise ArgumentError, "Unknown category '#{category_id}'" unless cat

            entity.set_attribute(DICT, KEY_CAT,  cat.id.to_s)
            entity.set_attribute(DICT, KEY_CODE, cat.code)
            entity.set_attribute(DICT, KEY_UNIT, unit || cat.unit)
            entity.set_attribute(DICT, KEY_NOTE, note) if note
            entity.set_attribute(DICT, KEY_DATE, Time.now.iso8601)
            entity.set_attribute(DICT, KEY_VER,  RABPro::EXTENSION_VERSION)

            Logger.debug("TagEngine: tagged entity #{entity.entityID} → #{cat.id}")
            cat
          end

          # ------------------------------------------------------------------
          # Read all RAB Pro tags from an entity
          # Returns nil if entity has no RAB Pro tags
          # ------------------------------------------------------------------
          def read(entity)
            cat_id = entity.get_attribute(DICT, KEY_CAT)
            return nil if cat_id.nil?

            {
              category:         cat_id,
              category_code:    entity.get_attribute(DICT, KEY_CODE),
              unit:             entity.get_attribute(DICT, KEY_UNIT),
              note:             entity.get_attribute(DICT, KEY_NOTE),
              quantity_override: entity.get_attribute(DICT, KEY_QTY),
              price_override:   entity.get_attribute(DICT, KEY_PRICE),
              tagged_at:        entity.get_attribute(DICT, KEY_DATE),
              version:          entity.get_attribute(DICT, KEY_VER)
            }
          end

          # ------------------------------------------------------------------
          # Check if entity has any RAB Pro tag
          # ------------------------------------------------------------------
          def tagged?(entity)
            !entity.get_attribute(DICT, KEY_CAT).nil?
          end

          # ------------------------------------------------------------------
          # Clear all RAB Pro attributes from an entity
          # ------------------------------------------------------------------
          def clear(entity)
            dict = entity.attribute_dictionary(DICT)
            entity.delete_attribute(DICT) if dict
          end

          # ------------------------------------------------------------------
          # Set a manual quantity override (used when AI/user corrects calc)
          # ------------------------------------------------------------------
          def set_quantity_override(entity, value)
            entity.set_attribute(DICT, KEY_QTY, value.to_f)
          end

          # ------------------------------------------------------------------
          # Set a manual unit price override
          # ------------------------------------------------------------------
          def set_price_override(entity, value)
            entity.set_attribute(DICT, KEY_PRICE, value.to_f)
          end

          # ------------------------------------------------------------------
          # Collect all tagged entities in a model (flat list)
          # ------------------------------------------------------------------
          def collect_tagged(model)
            results = []
            _traverse_entities(model.entities) do |entity|
              tag = read(entity)
              results << { entity: entity, tag: tag } if tag
            end
            results
          end

          # ------------------------------------------------------------------
          # Group tagged entities by category
          # Returns: { category_id => [{ entity:, tag: }, ...] }
          # ------------------------------------------------------------------
          def group_by_category(model)
            tagged = collect_tagged(model)
            tagged.group_by { |item| item[:tag][:category] }
          end

          # ------------------------------------------------------------------
          # Stats: how many entities are tagged, per category
          # ------------------------------------------------------------------
          def stats(model)
            grouped = group_by_category(model)
            grouped.transform_values(&:count)
          end

          # ------------------------------------------------------------------
          # Export all tags to a plain Ruby hash (for serialization/backup)
          # ------------------------------------------------------------------
          def export_tags(model)
            collect_tagged(model).map do |item|
              e = item[:entity]
              {
                entity_id:   e.entityID,
                entity_type: _entity_type(e),
                name:        _entity_name(e),
                tag:         item[:tag]
              }
            end
          end

          # ------------------------------------------------------------------
          # Import / restore tags from exported hash
          # ------------------------------------------------------------------
          def import_tags(model, tag_data)
            imported = 0
            tag_data.each do |item|
              entity = model.find_entity_by_id(item['entity_id'].to_i)
              next unless entity

              tag = item['tag']
              write(entity,
                    category_id: tag['category'].to_sym,
                    unit:        tag['unit'],
                    note:        tag['note'])
              imported += 1
            rescue => e
              Logger.warn("TagEngine import: skipped entity #{item['entity_id']}: #{e.message}")
            end
            imported
          end

          private

          def _traverse_entities(entities, depth = 0, &block)
            return if depth > 10
            entities.each do |e|
              block.call(e) if e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
              case e
              when Sketchup::ComponentInstance
                _traverse_entities(e.definition.entities, depth + 1, &block)
              when Sketchup::Group
                _traverse_entities(e.entities, depth + 1, &block)
              end
            end
          end

          def _entity_type(e)
            e.is_a?(Sketchup::ComponentInstance) ? 'component' : 'group'
          end

          def _entity_name(e)
            if e.is_a?(Sketchup::ComponentInstance)
              e.name.empty? ? e.definition.name : e.name
            else
              e.name
            end
          end

        end
      end
    end
  end
end
