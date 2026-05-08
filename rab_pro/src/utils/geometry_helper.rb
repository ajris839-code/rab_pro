# ==============================================================================
# RAB Pro - Geometry Helper
# Wraps SketchUp geometry APIs for volume, area, and length calculations.
# All internal calculations use SketchUp's native inches; output is converted
# to SI units (m, m², m³) via UnitConverter.
# ==============================================================================

module RABPro
  module GeometryHelper

    INCH   = 1.0
    METER  = 39.3701   # inches per metre
    SQ_M   = METER ** 2
    CU_M   = METER ** 3

    # --------------------------------------------------------------------------
    # Bounding box volume (m³) — fast approximation for non-solid groups
    # --------------------------------------------------------------------------
    def self.bounding_box_volume_m3(entity)
      bb = entity.bounds
      vol_in3 = bb.width * bb.height * bb.depth
      vol_in3 / CU_M
    end

    # --------------------------------------------------------------------------
    # Solid volume (m³) using SketchUp's solid inspector
    # Returns nil if entity is not a manifold solid
    # --------------------------------------------------------------------------
    def self.solid_volume_m3(entity)
      return nil unless entity.respond_to?(:volume)
      vol = entity.volume   # returns in³ (negative if faces reversed)
      return nil if vol.nil?
      vol.abs / CU_M
    end

    # --------------------------------------------------------------------------
    # Face area (m²)
    # --------------------------------------------------------------------------
    def self.face_area_m2(face)
      face.area / SQ_M
    end

    # --------------------------------------------------------------------------
    # Total surface area of all faces in an entity (m²)
    # --------------------------------------------------------------------------
    def self.total_surface_area_m2(entity)
      faces = collect_faces(entity)
      total = faces.sum(&:area)
      total / SQ_M
    end

    # --------------------------------------------------------------------------
    # Edge / linear length (m)
    # --------------------------------------------------------------------------
    def self.edge_length_m(edge)
      edge.length / METER
    end

    # --------------------------------------------------------------------------
    # Perimeter of a face (m)
    # --------------------------------------------------------------------------
    def self.face_perimeter_m(face)
      face.edges.sum(&:length) / METER
    end

    # --------------------------------------------------------------------------
    # Bounding box dimensions hash (m)
    # --------------------------------------------------------------------------
    def self.dimensions_m(entity)
      bb = entity.bounds
      {
        width:  (bb.width  / METER).round(4),
        height: (bb.height / METER).round(4),
        depth:  (bb.depth  / METER).round(4)
      }
    end

    # --------------------------------------------------------------------------
    # Floor area — largest horizontal face projected onto XY plane (m²)
    # Useful for slabs, floors, site areas
    # --------------------------------------------------------------------------
    def self.floor_area_m2(entity)
      faces = collect_faces(entity)
      horiz = faces.select { |f| _face_is_horizontal?(f) }
      return 0.0 if horiz.empty?
      horiz.max_by(&:area).area / SQ_M
    end

    # --------------------------------------------------------------------------
    # Wall area — sum of vertical faces (m²)
    # --------------------------------------------------------------------------
    def self.wall_area_m2(entity)
      faces = collect_faces(entity)
      vert  = faces.select { |f| _face_is_vertical?(f) }
      vert.sum(&:area) / SQ_M
    end

    # --------------------------------------------------------------------------
    # Centroid of entity (world coordinates)
    # --------------------------------------------------------------------------
    def self.centroid(entity)
      bb = entity.bounds
      bb.center
    end

    # --------------------------------------------------------------------------
    # Collect all faces recursively from an entity
    # --------------------------------------------------------------------------
    def self.collect_faces(entity, transform = nil)
      faces = []
      _traverse(entity, transform) { |e, _t| faces << e if e.is_a?(Sketchup::Face) }
      faces
    end

    # --------------------------------------------------------------------------
    # Collect all edges recursively
    # --------------------------------------------------------------------------
    def self.collect_edges(entity)
      edges = []
      _traverse(entity, nil) { |e, _t| edges << e if e.is_a?(Sketchup::Edge) }
      edges
    end

    private

    def self._traverse(entity, transform, &block)
      entities = case entity
                 when Sketchup::Group, Sketchup::ComponentInstance
                   entity.definition.entities
                 when Sketchup::Entities
                   entity
                 else
                   return
                 end

      t = transform || (entity.respond_to?(:transformation) ? entity.transformation : nil)

      entities.each do |e|
        block.call(e, t)
        if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          child_t = t ? t * e.transformation : e.transformation
          _traverse(e, child_t, &block)
        end
      end
    end

    def self._face_is_horizontal?(face)
      normal = face.normal
      normal.dot(Geom::Vector3d.new(0, 0, 1)).abs > 0.95
    end

    def self._face_is_vertical?(face)
      normal = face.normal
      normal.dot(Geom::Vector3d.new(0, 0, 1)).abs < 0.05
    end

  end
end
