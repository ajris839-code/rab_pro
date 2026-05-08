# ==============================================================================
# RAB Pro - Auto Dimensioner
# Automatically places linear dimensions, leader annotations, and elevation
# markers on SketchUp scenes.
#
# Strategy:
#   1. Collect significant edges (long external edges aligned to axes)
#   2. Place dimensions along building perimeter
#   3. Add elevation markers at key heights (floor, sill, lintel, ridge)
#   4. Add room/space labels where area ≥ threshold
# ==============================================================================

module RABPro
  module Drawings
    module Annotations
      class AutoDimensioner

        # Minimum edge length to dimension (metres)
        MIN_DIM_LENGTH_M   = 0.3
        # Offset from building face for dimension lines (inches)
        DIM_OFFSET_IN      = 30.0    # ~76 cm
        DIM_OFFSET_TIER2   = 55.0    # second tier for overall dim
        # Minimum face area to label (m²)
        MIN_LABEL_AREA_M2  = 2.0
        # Elevation marker colour
        ELEV_COLOR         = Sketchup::Color.new(0, 71, 227)

        def initialize(model)
          @model  = model
          @view   = model.active_view
        end

        # -----------------------------------------------------------------------
        # Add all dimension types to current scene
        # -----------------------------------------------------------------------
        def auto_dimension_all
          @model.start_operation('RAB Pro: Auto-dimension', true)

          added = 0
          added += add_perimeter_dimensions
          added += add_elevation_markers
          added += add_room_labels

          @model.commit_operation
          Logger.info("AutoDimensioner: #{added} annotations added")
          added
        rescue => e
          @model.abort_operation
          Logger.error("AutoDimensioner: #{e.message}")
          raise
        end

        # -----------------------------------------------------------------------
        # Perimeter / linear dimensions
        # Finds outermost edges parallel to X and Y axes and dimensions them
        # -----------------------------------------------------------------------
        def add_perimeter_dimensions
          bb       = @model.bounds
          entities = @model.entities
          count    = 0

          # Collect all significant horizontal edges
          x_edges = _collect_axis_edges(:x)
          y_edges = _collect_axis_edges(:y)

          # Dimension along front face (min Y) — X-axis dimensions
          if x_edges.any?
            front_y = bb.min.y - DIM_OFFSET_IN
            x_edges.each do |edge|
              pt1, pt2 = _edge_endpoints_sorted(edge, :x)
              next if _length_m(pt1, pt2) < MIN_DIM_LENGTH_M
              next if _dimension_exists_near?(pt1, pt2)

              dim_pt1 = Geom::Point3d.new(pt1.x, front_y, pt1.z)
              dim_pt2 = Geom::Point3d.new(pt2.x, front_y, pt2.z)
              offset  = Geom::Vector3d.new(0, -1, 0)

              dim = entities.add_dimension_linear(pt1, pt2, offset, DIM_OFFSET_IN)
              dim.text = '' if dim.respond_to?(:text=)
              count += 1
            end

            # Overall X dimension (tier 2)
            _add_overall_dim(:x, bb, front_y - DIM_OFFSET_TIER2)
            count += 1
          end

          # Dimension along right face (max X) — Y-axis dimensions
          if y_edges.any?
            right_x = bb.max.x + DIM_OFFSET_IN
            y_edges.each do |edge|
              pt1, pt2 = _edge_endpoints_sorted(edge, :y)
              next if _length_m(pt1, pt2) < MIN_DIM_LENGTH_M
              next if _dimension_exists_near?(pt1, pt2)

              offset  = Geom::Vector3d.new(1, 0, 0)
              dim = entities.add_dimension_linear(pt1, pt2, offset, DIM_OFFSET_IN)
              count += 1
            end

            _add_overall_dim(:y, bb, right_x + DIM_OFFSET_TIER2)
            count += 1
          end

          count
        rescue => e
          Logger.warn("add_perimeter_dimensions: #{e.message}")
          0
        end

        # -----------------------------------------------------------------------
        # Elevation markers — annotate key Z heights
        # -----------------------------------------------------------------------
        def add_elevation_markers
          bb    = @model.bounds
          count = 0

          key_elevations = _detect_key_elevations
          right_x = bb.max.x + DIM_OFFSET_IN * 1.2

          key_elevations.each do |elev_in, label|
            elev_m = UnitConverter.inches_to_m(elev_in)

            # Place a dimension leader pointing to the elevation
            pt      = Geom::Point3d.new(right_x, bb.center.y, elev_in)
            leader  = @model.entities.add_text(
              "▶ #{label} (+#{('%.2f' % elev_m)} m)",
              pt,
              Geom::Vector3d.new(20, 0, 0)
            )
            count += 1
          rescue => e
            Logger.warn("elevation marker #{elev_m}m: #{e.message}")
          end

          count
        end

        # -----------------------------------------------------------------------
        # Room labels — area text centred in horizontal face
        # -----------------------------------------------------------------------
        def add_room_labels
          count  = 0
          faces  = _collect_significant_floors

          faces.each do |face|
            area_m2 = GeometryHelper.face_area_m2(face)
            next if area_m2 < MIN_LABEL_AREA_M2

            centroid = _face_centroid(face)
            label    = "#{'%.1f' % area_m2} m²"

            @model.entities.add_text(label, centroid, Geom::Vector3d.new(0, 0, 5))
            count += 1
          rescue => e
            Logger.warn("room label: #{e.message}")
          end

          count
        end

        # -----------------------------------------------------------------------
        # Clear all RAB-generated dimensions and text
        # -----------------------------------------------------------------------
        def clear_rab_annotations
          to_delete = @model.entities.select do |e|
            (e.is_a?(Sketchup::DimensionLinear) ||
             e.is_a?(Sketchup::DimensionRadial) ||
             e.is_a?(Sketchup::Text)) &&
            e.get_attribute('RABPro', 'auto_dim')
          end
          @model.entities.erase_entities(to_delete)
          to_delete.size
        end

        private

        # -----------------------------------------------------------------------
        # Collect edges aligned to a given axis above a minimum length
        # -----------------------------------------------------------------------
        def _collect_axis_edges(axis)
          threshold_in = MIN_DIM_LENGTH_M * 39.3701
          results = []

          _traverse_edges(@model.entities) do |edge, _transform|
            vec  = edge.line[1]
            len  = edge.length

            aligned = case axis
                      when :x then vec.x.abs > 0.99 && vec.y.abs < 0.01 && vec.z.abs < 0.01
                      when :y then vec.y.abs > 0.99 && vec.x.abs < 0.01 && vec.z.abs < 0.01
                      when :z then vec.z.abs > 0.99 && vec.x.abs < 0.01 && vec.y.abs < 0.01
                      end

            results << edge if aligned && len >= threshold_in
          end

          # Deduplicate by snapping to grid positions, keep unique lengths
          results.uniq { |e| [e.start.position.to_a.map { |v| v.round(1) },
                              e.end.position.to_a.map { |v| v.round(1) }].sort }
        end

        def _traverse_edges(entities, depth = 0, &block)
          return if depth > 6
          entities.each do |e|
            case e
            when Sketchup::Edge
              block.call(e, nil)
            when Sketchup::Group
              _traverse_edges(e.entities, depth + 1, &block)
            when Sketchup::ComponentInstance
              _traverse_edges(e.definition.entities, depth + 1, &block)
            end
          end
        end

        def _edge_endpoints_sorted(edge, axis)
          pts = [edge.start.position, edge.end.position]
          axis == :x ? pts.sort_by(&:x) : pts.sort_by(&:y)
        end

        def _length_m(pt1, pt2)
          UnitConverter.inches_to_m(pt1.distance(pt2))
        end

        def _dimension_exists_near?(pt1, pt2, tol: 5.0)
          @model.entities.any? do |e|
            next false unless e.is_a?(Sketchup::DimensionLinear)
            e.start.position.distance(pt1) < tol && e.end.position.distance(pt2) < tol
          end
        end

        def _add_overall_dim(axis, bb, offset_coord)
          entities = @model.entities
          case axis
          when :x
            pt1 = Geom::Point3d.new(bb.min.x, bb.min.y, bb.min.z)
            pt2 = Geom::Point3d.new(bb.max.x, bb.min.y, bb.min.z)
            entities.add_dimension_linear(pt1, pt2,
              Geom::Vector3d.new(0, -1, 0), DIM_OFFSET_TIER2)
          when :y
            pt1 = Geom::Point3d.new(bb.max.x, bb.min.y, bb.min.z)
            pt2 = Geom::Point3d.new(bb.max.x, bb.max.y, bb.min.z)
            entities.add_dimension_linear(pt1, pt2,
              Geom::Vector3d.new(1, 0, 0), DIM_OFFSET_TIER2)
          end
        rescue => e
          Logger.warn("_add_overall_dim #{axis}: #{e.message}")
        end

        # Detect floor-level, sill, lintel, and ridge heights
        def _detect_key_elevations
          bb   = @model.bounds
          base = bb.min.z
          top  = bb.max.z
          h    = top - base

          elevations = {}
          elevations[base]               = '± 0.00 (Lantai Dasar)'
          elevations[base + h * 0.25]    = 'Ambang Bawah Jendela'
          elevations[base + h * 0.55]    = 'Ambang Atas Jendela / Pintu'
          elevations[base + h * 0.70]    = 'Ringbalk'
          elevations[top]                = 'Puncak / Ridge'

          # Remove duplicates within 10 inches
          elevations.reject do |z, _|
            elevations.any? { |z2, _| z2 != z && (z - z2).abs < 10 }
          end
        end

        def _collect_significant_floors
          faces = []
          _traverse_faces(@model.entities) do |face|
            next unless face.normal.dot(Geom::Vector3d.new(0, 0, 1)) > 0.95
            next if GeometryHelper.face_area_m2(face) < MIN_LABEL_AREA_M2
            faces << face
          end
          faces
        end

        def _traverse_faces(entities, depth = 0, &block)
          return if depth > 6
          entities.each do |e|
            case e
            when Sketchup::Face
              block.call(e)
            when Sketchup::Group
              _traverse_faces(e.entities, depth + 1, &block)
            when Sketchup::ComponentInstance
              _traverse_faces(e.definition.entities, depth + 1, &block)
            end
          end
        end

        def _face_centroid(face)
          pts = face.outer_loop.vertices.map(&:position)
          avg_x = pts.sum(&:x) / pts.size
          avg_y = pts.sum(&:y) / pts.size
          avg_z = pts.sum(&:z) / pts.size
          Geom::Point3d.new(avg_x, avg_y, avg_z + 2)   # slightly above face
        end

      end
    end
  end
end
