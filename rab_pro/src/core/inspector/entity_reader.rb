# ==============================================================================
# RAB Pro - Entity Reader
# Traverses the full SketchUp model entity tree and extracts structured data
# about every component, group, face, and edge.
# ==============================================================================

module RABPro
  module Core
    module Inspector
      class EntityReader

        MAX_DEPTH = 10  # Guard against runaway recursion in complex models

        def initialize(model)
          @model = model
          @stats = { components: 0, groups: 0, faces: 0, edges: 0, images: 0 }
        end

        # ----------------------------------------------------------------------
        # Top-level summary of the model
        # ----------------------------------------------------------------------
        def summary
          {
            path:           @model.path,
            title:          @model.title,
            description:    @model.description,
            units:          _model_units,
            entity_count:   @model.entities.count,
            component_defs: @model.definitions.count,
            materials:      @model.materials.count,
            layers:         @model.layers.count,
            active_layer:   @model.active_layer&.name,
            bounds:         _bounds_hash(@model.bounds),
            sketchup_version: Sketchup.version
          }
        end

        # ----------------------------------------------------------------------
        # Read ALL entities recursively — returns flat array of entity hashes
        # Each hash is self-contained and can be serialized to JSON
        # ----------------------------------------------------------------------
        def read_all
          results = []
          _traverse(@model.entities, nil, 0, results)
          @stats[:total] = results.size
          results
        end

        # ----------------------------------------------------------------------
        # Read only top-level named components / groups (faster for UI preview)
        # ----------------------------------------------------------------------
        def read_top_level
          @model.entities.flat_map do |e|
            case e
            when Sketchup::ComponentInstance
              [_component_hash(e, nil, 0)]
            when Sketchup::Group
              [_group_hash(e, nil, 0)]
            else
              []
            end
          end
        end

        def stats; @stats end

        private

        def _traverse(entities, parent_transform, depth, results)
          return if depth > MAX_DEPTH

          entities.each do |entity|
            case entity
            when Sketchup::ComponentInstance
              h = _component_hash(entity, parent_transform, depth)
              results << h
              @stats[:components] += 1
              child_t = _combine_transform(parent_transform, entity.transformation)
              _traverse(entity.definition.entities, child_t, depth + 1, results)

            when Sketchup::Group
              h = _group_hash(entity, parent_transform, depth)
              results << h
              @stats[:groups] += 1
              child_t = _combine_transform(parent_transform, entity.transformation)
              _traverse(entity.entities, child_t, depth + 1, results)

            when Sketchup::Face
              results << _face_hash(entity, parent_transform, depth)
              @stats[:faces] += 1

            when Sketchup::Edge
              @stats[:edges] += 1
              # Edges tracked in stats only, not added to results (too verbose)

            when Sketchup::Image
              results << _image_hash(entity, depth)
              @stats[:images] += 1
            end
          end
        end

        def _component_hash(instance, transform, depth)
          defn = instance.definition
          t    = _combine_transform(transform, instance.transformation)
          {
            entity_type:   'component',
            entity_id:     instance.entityID,
            depth:         depth,
            name:          instance.name.empty? ? defn.name : instance.name,
            definition:    defn.name,
            layer:         instance.layer.name,
            hidden:        instance.hidden?,
            locked:        instance.locked?,
            material:      instance.material&.name,
            bounds:        _bounds_hash(instance.bounds),
            transform:     _transform_hash(instance.transformation),
            face_count:    defn.entities.grep(Sketchup::Face).count,
            attributes:    _read_attributes(instance),
            # RAB Pro custom attributes
            rab_category:  instance.get_attribute('RABPro', 'category'),
            rab_unit:      instance.get_attribute('RABPro', 'unit'),
            rab_note:      instance.get_attribute('RABPro', 'note'),
          }
        end

        def _group_hash(group, transform, depth)
          t = _combine_transform(transform, group.transformation)
          {
            entity_type:   'group',
            entity_id:     group.entityID,
            depth:         depth,
            name:          group.name,
            layer:         group.layer.name,
            hidden:        group.hidden?,
            locked:        group.locked?,
            material:      group.material&.name,
            bounds:        _bounds_hash(group.bounds),
            transform:     _transform_hash(group.transformation),
            face_count:    group.entities.grep(Sketchup::Face).count,
            attributes:    _read_attributes(group),
            rab_category:  group.get_attribute('RABPro', 'category'),
            rab_unit:      group.get_attribute('RABPro', 'unit'),
            rab_note:      group.get_attribute('RABPro', 'note'),
          }
        end

        def _face_hash(face, transform, depth)
          area_m2 = GeometryHelper.face_area_m2(face)
          {
            entity_type:   'face',
            entity_id:     face.entityID,
            depth:         depth,
            layer:         face.layer.name,
            hidden:        face.hidden?,
            area_m2:       area_m2.round(4),
            normal:        face.normal.to_a.map { |v| v.round(4) },
            material:      face.material&.name,
            back_material: face.back_material&.name,
          }
        end

        def _image_hash(img, depth)
          {
            entity_type: 'image',
            entity_id:   img.entityID,
            depth:       depth,
            filename:    img.filename,
            layer:       img.layer.name,
          }
        end

        def _bounds_hash(bb)
          {
            min:    bb.min.to_a.map { |v| UnitConverter.inches_to_m(v).round(4) },
            max:    bb.max.to_a.map { |v| UnitConverter.inches_to_m(v).round(4) },
            width:  UnitConverter.inches_to_m(bb.width).round(4),
            height: UnitConverter.inches_to_m(bb.height).round(4),
            depth:  UnitConverter.inches_to_m(bb.depth).round(4),
          }
        end

        def _transform_hash(t)
          {
            origin:  t.origin.to_a.map { |v| UnitConverter.inches_to_m(v).round(4) },
            x_axis:  t.xaxis.to_a.map { |v| v.round(4) },
            y_axis:  t.yaxis.to_a.map { |v| v.round(4) },
            z_axis:  t.zaxis.to_a.map { |v| v.round(4) },
            scale:   t.identity? ? 1.0 : _extract_scale(t)
          }
        end

        def _read_attributes(entity)
          result = {}
          entity.attribute_dictionaries&.each do |dict|
            dict.each { |k, v| result["#{dict.name}.#{k}"] = v }
          end
          result
        end

        def _combine_transform(parent, child)
          return child if parent.nil?
          parent * child
        end

        def _extract_scale(t)
          # Approximate uniform scale from X axis length
          t.xaxis.length.round(4)
        rescue
          1.0
        end

        def _model_units
          dict = @model.options['UnitsOptions']
          return 'unknown' unless dict
          case dict['LengthUnit']
          when 0 then 'inches'
          when 1 then 'feet'
          when 2 then 'mm'
          when 3 then 'cm'
          when 4 then 'm'
          else 'unknown'
          end
        end

      end
    end
  end
end
