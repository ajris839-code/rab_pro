# ==============================================================================
# RAB Pro - IFC Mapper
# Maps RAB Pro categories to IFC entity classes and property sets.
# Enables interoperability with BIM tools (Revit, ArchiCAD, etc.)
# ==============================================================================

module RABPro
  module Core
    module Classifier
      class IfcMapper

        # IFC 4 class mappings per RAB Pro category
        IFC_MAP = {
          # Site & preparation
          pembersihan_lahan: { ifc_class: 'IfcSite',              pset: 'Pset_SiteCommon' },
          direksi_keet:      { ifc_class: 'IfcBuilding',          pset: 'Pset_BuildingCommon' },
          pagar_proyek:      { ifc_class: 'IfcWall',              pset: 'Pset_WallCommon' },

          # Earthworks
          galian_tanah:      { ifc_class: 'IfcEarthworksCut',     pset: 'Pset_EarthworksCutCommon' },
          urugan_tanah:      { ifc_class: 'IfcEarthworksFill',    pset: 'Pset_EarthworksFillCommon' },
          pemadatan:         { ifc_class: 'IfcEarthworksFill',    pset: 'Pset_EarthworksFillCommon' },

          # Foundation
          pondasi_batu:      { ifc_class: 'IfcFooting',           pset: 'Pset_FootingCommon' },
          pondasi_tapak:     { ifc_class: 'IfcFooting',           pset: 'Pset_FootingCommon' },
          pondasi_tiang:     { ifc_class: 'IfcPile',              pset: 'Pset_PileCommon' },
          sloof:             { ifc_class: 'IfcBeam',              pset: 'Pset_BeamCommon' },

          # Structure
          kolom:             { ifc_class: 'IfcColumn',            pset: 'Pset_ColumnCommon' },
          balok:             { ifc_class: 'IfcBeam',              pset: 'Pset_BeamCommon' },
          plat_lantai:       { ifc_class: 'IfcSlab',              pset: 'Pset_SlabCommon' },
          ringbalk:          { ifc_class: 'IfcBeam',              pset: 'Pset_BeamCommon' },
          tangga:            { ifc_class: 'IfcStair',             pset: 'Pset_StairCommon' },

          # Walls
          dinding_bata:      { ifc_class: 'IfcWall',              pset: 'Pset_WallCommon' },
          dinding_batako:    { ifc_class: 'IfcWall',              pset: 'Pset_WallCommon' },
          dinding_hebel:     { ifc_class: 'IfcWall',              pset: 'Pset_WallCommon' },
          plester:           { ifc_class: 'IfcCovering',          pset: 'Pset_CoveringCommon' },

          # Floors
          lantai_keramik:    { ifc_class: 'IfcCovering',          pset: 'Pset_CoveringCommon' },
          lantai_granit:     { ifc_class: 'IfcCovering',          pset: 'Pset_CoveringCommon' },
          rabat_beton:       { ifc_class: 'IfcSlab',              pset: 'Pset_SlabCommon' },

          # Roof
          rangka_atap_baja:  { ifc_class: 'IfcRoof',              pset: 'Pset_RoofCommon' },
          penutup_atap:      { ifc_class: 'IfcRoof',              pset: 'Pset_RoofCommon' },
          talang:            { ifc_class: 'IfcPipeSegment',       pset: 'Pset_PipeSegmentCommon' },

          # Ceiling
          plafon_gypsum:     { ifc_class: 'IfcCovering',          pset: 'Pset_CoveringCommon' },

          # Openings
          pintu:             { ifc_class: 'IfcDoor',              pset: 'Pset_DoorCommon' },
          jendela:           { ifc_class: 'IfcWindow',            pset: 'Pset_WindowCommon' },

          # Finishing
          cat_dinding:       { ifc_class: 'IfcCovering',          pset: 'Pset_CoveringCommon' },

          # MEP
          instalasi_listrik: { ifc_class: 'IfcElectricDistributionBoard', pset: 'Pset_ElectricDistributionBoardCommon' },
          instalasi_air:     { ifc_class: 'IfcPipeSegment',       pset: 'Pset_PipeSegmentCommon' },
          ac:                { ifc_class: 'IfcUnitaryControlElement', pset: 'Pset_UnitaryControlElementCommon' },
        }.freeze

        class << self

          def ifc_class_for(category_id)
            entry = IFC_MAP[category_id.to_sym]
            entry ? entry[:ifc_class] : 'IfcBuildingElementProxy'
          end

          def pset_for(category_id)
            entry = IFC_MAP[category_id.to_sym]
            entry ? entry[:pset] : nil
          end

          # Write IFC attributes to a SketchUp entity
          def write_ifc_attributes(entity, category_id)
            ifc_cls  = ifc_class_for(category_id)
            pset     = pset_for(category_id)

            entity.set_attribute('IFC 2x3', 'IfcEntity', ifc_cls)
            entity.set_attribute('IFC 2x3', 'Layer',     entity.layer.name)

            # Write property set name
            if pset
              entity.set_attribute('IFC 2x3', 'PropertySetDef', pset)
            end

            Logger.debug("IfcMapper: #{entity.entityID} → #{ifc_cls}")
            ifc_cls
          end

          # Batch-apply IFC attributes to all tagged entities
          def apply_to_model(model)
            count = 0
            Tagger::TagEngine.collect_tagged(model).each do |item|
              write_ifc_attributes(item[:entity], item[:tag][:category])
              count += 1
            rescue => e
              Logger.warn("IfcMapper.apply_to_model: #{e.message}")
            end
            Logger.info("IfcMapper: applied IFC attributes to #{count} entities")
            count
          end

        end
      end
    end
  end
end
