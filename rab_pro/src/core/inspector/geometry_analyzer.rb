# ==============================================================================
# RAB Pro - Geometry Analyzer
# Deep geometric analysis of model entities.
# Computes volumes, areas, lengths, and spatial relationships.
# Results feed directly into Quantity Takeoff (Fase 2).
# ==============================================================================

module RABPro
  module Core
    module Inspector
      class GeometryAnalyzer

        AnalysisResult = Struct.new(
          :entity_id,
          :entity_type,
          :name,
          :category,
          :volume_m3,
          :surface_area_m2,
          :floor_area_m2,
          :wall_area_m2,
          :length_m,
          :width_m,
          :height_m,
          :depth_m,
          :perimeter_m,
          :face_count,
          :is_solid,
          :dominant_axis,
          keyword_init: true
        )

        def initialize
          @results = []
        end

        # ----------------------------------------------------------------------
        # Analyze all entities in a model's entities collection
        # Returns array of AnalysisResult
        # ----------------------------------------------------------------------
        def analyze(entities, transform = nil)
          results = []
          _traverse(entities, transform, results)
          results
        end

        # ----------------------------------------------------------------------
        # Analyze a single entity
        # ----------------------------------------------------------------------
        def analyze_entity(entity, transform = nil)
          case entity
          when Sketchup::ComponentInstance
            _analyze_component(entity, transform)
          when Sketchup::Group
            _analyze_group(entity, transform)
          else
            nil
          end
        end

        private

        def _traverse(entities, transform, results)
          entities.each do |e|
            case e
            when Sketchup::ComponentInstance
              result = _analyze_component(e, transform)
              results << result if result
            when Sketchup::Group
              result = _analyze_group(e, transform)
              results << result if result
            end
          end
        end

        # ----------------------------------------------------------------------
        # Component analysis
        # ----------------------------------------------------------------------
        def _analyze_component(instance, parent_transform)
          defn = instance.definition
          t    = parent_transform ? parent_transform * instance.transformation
                                  : instance.transformation

          bb   = instance.bounds
          dims = _sorted_dimensions(bb)

          # Try solid volume first, fall back to bounding box approximation
          solid_vol = GeometryHelper.solid_volume_m3(instance)
          bb_vol    = GeometryHelper.bounding_box_volume_m3(instance)
          volume    = solid_vol || bb_vol

          faces    = GeometryHelper.collect_faces(instance)
          surf_area = faces.sum { |f| GeometryHelper.face_area_m2(f) }
          floor_area = GeometryHelper.floor_area_m2(instance)
          wall_area  = GeometryHelper.wall_area_m2(instance)

          AnalysisResult.new(
            entity_id:       instance.entityID,
            entity_type:     'component',
            name:            instance.name.empty? ? defn.name : instance.name,
            category:        instance.get_attribute('RABPro', 'category'),
            volume_m3:       volume.round(5),
            surface_area_m2: surf_area.round(4),
            floor_area_m2:   floor_area.round(4),
            wall_area_m2:    wall_area.round(4),
            length_m:        dims[:length],
            width_m:         dims[:width],
            height_m:        dims[:height],
            depth_m:         UnitConverter.inches_to_m(bb.depth).round(4),
            perimeter_m:     _floor_perimeter(instance),
            face_count:      faces.count,
            is_solid:        !solid_vol.nil?,
            dominant_axis:   _dominant_axis(bb)
          )
        rescue => e
          Logger.warn("GeometryAnalyzer: skipping component #{instance.entityID}: #{e.message}")
          nil
        end

        # ----------------------------------------------------------------------
        # Group analysis
        # ----------------------------------------------------------------------
        def _analyze_group(group, parent_transform)
          t  = parent_transform ? parent_transform * group.transformation
                                : group.transformation
          bb = group.bounds

          dims    = _sorted_dimensions(bb)
          solid_vol = GeometryHelper.solid_volume_m3(group)
          bb_vol    = GeometryHelper.bounding_box_volume_m3(group)

          faces      = GeometryHelper.collect_faces(group)
          surf_area  = faces.sum { |f| GeometryHelper.face_area_m2(f) }
          floor_area = GeometryHelper.floor_area_m2(group)
          wall_area  = GeometryHelper.wall_area_m2(group)

          AnalysisResult.new(
            entity_id:       group.entityID,
            entity_type:     'group',
            name:            group.name,
            category:        group.get_attribute('RABPro', 'category'),
            volume_m3:       (solid_vol || bb_vol).round(5),
            surface_area_m2: surf_area.round(4),
            floor_area_m2:   floor_area.round(4),
            wall_area_m2:    wall_area.round(4),
            length_m:        dims[:length],
            width_m:         dims[:width],
            height_m:        dims[:height],
            depth_m:         UnitConverter.inches_to_m(bb.depth).round(4),
            perimeter_m:     _floor_perimeter(group),
            face_count:      faces.count,
            is_solid:        !solid_vol.nil?,
            dominant_axis:   _dominant_axis(bb)
          )
        rescue => e
          Logger.warn("GeometryAnalyzer: skipping group #{group.entityID}: #{e.message}")
          nil
        end

        # ----------------------------------------------------------------------
        # Helpers
        # ----------------------------------------------------------------------

        # Returns { length, width, height } sorted so length >= width >= height
        def _sorted_dimensions(bb)
          w = UnitConverter.inches_to_m(bb.width).round(4)
          h = UnitConverter.inches_to_m(bb.height).round(4)
          d = UnitConverter.inches_to_m(bb.depth).round(4)
          sorted = [w, h, d].sort.reverse
          { length: sorted[0], width: sorted[1], height: sorted[2] }
        end

        # Approximate floor perimeter from bounding box footprint
        def _floor_perimeter(entity)
          bb = entity.bounds
          w  = UnitConverter.inches_to_m(bb.width)
          d  = UnitConverter.inches_to_m(bb.depth)
          (2 * (w + d)).round(4)
        end

        # Returns :horizontal | :vertical | :square
        def _dominant_axis(bb)
          w = bb.width
          h = bb.height
          d = bb.depth
          max_horiz = [w, d].max
          if h > max_horiz * 1.5
            :vertical
          elsif [w, d].min > h * 2
            :horizontal
          else
            :square
          end
        end

      end
    end
  end
end
