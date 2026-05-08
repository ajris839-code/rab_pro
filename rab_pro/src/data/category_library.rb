# ==============================================================================
# RAB Pro - Category Library
# Defines the full taxonomy of construction work categories.
# Each category maps to: an SNI pekerjaan code, quantity type, IFC class,
# layer name patterns for auto-detection, and display metadata.
# ==============================================================================

module RABPro
  module Data
    class CategoryLibrary

      Category = Struct.new(
        :id,           # unique symbol key
        :code,         # SNI / internal code, e.g. "A.1"
        :name,         # display name in Indonesian
        :name_en,      # English label
        :group,        # parent group symbol
        :quantity_type, # :volume | :area | :length | :count
        :unit,         # 'm³' | 'm²' | 'm' | 'unit' | 'ls'
        :ifc_class,    # IFC entity class string
        :layer_patterns, # array of glob patterns for auto-tag
        :description,
        keyword_init: true
      )

      GROUP_LABELS = {
        persiapan:    'Pekerjaan Persiapan',
        tanah:        'Pekerjaan Tanah',
        pondasi:      'Pekerjaan Pondasi',
        struktur:     'Pekerjaan Struktur',
        dinding:      'Pekerjaan Dinding',
        lantai:       'Pekerjaan Lantai',
        atap:         'Pekerjaan Atap',
        plafon:       'Pekerjaan Plafon',
        kusen:        'Pekerjaan Kusen, Pintu & Jendela',
        finishing:    'Pekerjaan Finishing',
        mep:          'Pekerjaan MEP',
        landscape:    'Pekerjaan Landscape',
        lain:         'Pekerjaan Lain-lain'
      }.freeze

      CATEGORIES = [
        # ---- PERSIAPAN -------------------------------------------------------
        Category.new(id: :pembersihan_lahan, code: 'A.1',
          name: 'Pembersihan Lahan', name_en: 'Site Clearing',
          group: :persiapan, quantity_type: :area, unit: 'm²',
          ifc_class: 'IfcSite',
          layer_patterns: ['*pembersihan*', '*clearing*', '*site*'],
          description: 'Pembersihan lahan dari vegetasi dan debris'),

        Category.new(id: :direksi_keet, code: 'A.2',
          name: 'Direksi Keet & Gudang', name_en: 'Site Office',
          group: :persiapan, quantity_type: :area, unit: 'm²',
          ifc_class: 'IfcBuilding',
          layer_patterns: ['*direksi*', '*gudang*', '*site_office*'],
          description: 'Bangunan sementara untuk direksi dan penyimpanan material'),

        Category.new(id: :pagar_proyek, code: 'A.3',
          name: 'Pagar Proyek', name_en: 'Site Fencing',
          group: :persiapan, quantity_type: :length, unit: 'm',
          ifc_class: 'IfcWall',
          layer_patterns: ['*pagar*', '*fence*', '*boundary*'],
          description: 'Pagar keliling area proyek'),

        # ---- TANAH -----------------------------------------------------------
        Category.new(id: :galian_tanah, code: 'B.1',
          name: 'Galian Tanah', name_en: 'Excavation',
          group: :tanah, quantity_type: :volume, unit: 'm³',
          ifc_class: 'IfcEarthworksCut',
          layer_patterns: ['*galian*', '*excavat*', '*cut*'],
          description: 'Pekerjaan galian tanah untuk pondasi dan utilitas'),

        Category.new(id: :urugan_tanah, code: 'B.2',
          name: 'Urugan Tanah', name_en: 'Backfill',
          group: :tanah, quantity_type: :volume, unit: 'm³',
          ifc_class: 'IfcEarthworksFill',
          layer_patterns: ['*urugan*', '*backfill*', '*fill*'],
          description: 'Pekerjaan urugan kembali dan pemadatan'),

        Category.new(id: :pemadatan, code: 'B.3',
          name: 'Pemadatan Tanah', name_en: 'Compaction',
          group: :tanah, quantity_type: :area, unit: 'm²',
          ifc_class: 'IfcEarthworksFill',
          layer_patterns: ['*padatan*', '*compact*'],
          description: 'Pemadatan tanah dasar dengan alat berat'),

        # ---- PONDASI ---------------------------------------------------------
        Category.new(id: :pondasi_batu, code: 'C.1',
          name: 'Pondasi Batu Kali', name_en: 'Stone Foundation',
          group: :pondasi, quantity_type: :volume, unit: 'm³',
          ifc_class: 'IfcFooting',
          layer_patterns: ['*pondasi_batu*', '*batu_kali*', '*stone_found*'],
          description: 'Pondasi pasangan batu kali / batu belah'),

        Category.new(id: :pondasi_tapak, code: 'C.2',
          name: 'Pondasi Tapak Beton', name_en: 'Pad Footing',
          group: :pondasi, quantity_type: :volume, unit: 'm³',
          ifc_class: 'IfcFooting',
          layer_patterns: ['*pondasi_tapak*', '*pad_foot*', '*footing*'],
          description: 'Pondasi tapak beton bertulang'),

        Category.new(id: :pondasi_tiang, code: 'C.3',
          name: 'Pondasi Tiang Pancang', name_en: 'Pile Foundation',
          group: :pondasi, quantity_type: :length, unit: 'm',
          ifc_class: 'IfcPile',
          layer_patterns: ['*tiang_pancang*', '*pile*', '*bored_pile*'],
          description: 'Pondasi tiang pancang beton / baja'),

        Category.new(id: :sloof, code: 'C.4',
          name: 'Sloof Beton', name_en: 'Grade Beam',
          group: :pondasi, quantity_type: :volume, unit: 'm³',
          ifc_class: 'IfcBeam',
          layer_patterns: ['*sloof*', '*grade_beam*', '*tie_beam*'],
          description: 'Balok sloof / tie beam di atas pondasi'),

        # ---- STRUKTUR --------------------------------------------------------
        Category.new(id: :kolom, code: 'D.1',
          name: 'Kolom Beton Bertulang', name_en: 'Reinforced Concrete Column',
          group: :struktur, quantity_type: :volume, unit: 'm³',
          ifc_class: 'IfcColumn',
          layer_patterns: ['*kolom*', '*column*', '*col_*'],
          description: 'Kolom struktur beton bertulang'),

        Category.new(id: :balok, code: 'D.2',
          name: 'Balok Beton Bertulang', name_en: 'Reinforced Concrete Beam',
          group: :struktur, quantity_type: :volume, unit: 'm³',
          ifc_class: 'IfcBeam',
          layer_patterns: ['*balok*', '*beam*', '*blk_*'],
          description: 'Balok struktur beton bertulang'),

        Category.new(id: :plat_lantai, code: 'D.3',
          name: 'Plat Lantai Beton', name_en: 'Concrete Slab',
          group: :struktur, quantity_type: :area, unit: 'm²',
          ifc_class: 'IfcSlab',
          layer_patterns: ['*plat_lantai*', '*slab*', '*floor_slab*'],
          description: 'Plat lantai beton bertulang'),

        Category.new(id: :ringbalk, code: 'D.4',
          name: 'Ringbalk / Balok Ring', name_en: 'Ring Beam',
          group: :struktur, quantity_type: :volume, unit: 'm³',
          ifc_class: 'IfcBeam',
          layer_patterns: ['*ringbalk*', '*ring_beam*', '*rb_*'],
          description: 'Balok ring di atas pasangan dinding'),

        Category.new(id: :tangga, code: 'D.5',
          name: 'Tangga Beton', name_en: 'Concrete Stair',
          group: :struktur, quantity_type: :count, unit: 'unit',
          ifc_class: 'IfcStair',
          layer_patterns: ['*tangga*', '*stair*', '*staircase*'],
          description: 'Konstruksi tangga beton bertulang'),

        # ---- DINDING ---------------------------------------------------------
        Category.new(id: :dinding_bata, code: 'E.1',
          name: 'Pasangan Dinding Bata Merah', name_en: 'Brick Wall',
          group: :dinding, quantity_type: :area, unit: 'm²',
          ifc_class: 'IfcWall',
          layer_patterns: ['*dinding_bata*', '*brick_wall*', '*bata_merah*'],
          description: 'Dinding pasangan bata merah 1/2 bata'),

        Category.new(id: :dinding_batako, code: 'E.2',
          name: 'Pasangan Dinding Batako', name_en: 'Concrete Block Wall',
          group: :dinding, quantity_type: :area, unit: 'm²',
          ifc_class: 'IfcWall',
          layer_patterns: ['*batako*', '*block_wall*', '*concrete_block*'],
          description: 'Dinding pasangan batako / concrete block'),

        Category.new(id: :dinding_hebel, code: 'E.3',
          name: 'Pasangan Dinding Hebel / AAC', name_en: 'AAC Block Wall',
          group: :dinding, quantity_type: :area, unit: 'm²',
          ifc_class: 'IfcWall',
          layer_patterns: ['*hebel*', '*aac*', '*autoclaved*'],
          description: 'Dinding pasangan bata ringan Hebel / Celcon'),

        Category.new(id: :plester, code: 'E.4',
          name: 'Plesteran Dinding', name_en: 'Wall Plaster',
          group: :dinding, quantity_type: :area, unit: 'm²',
          ifc_class: 'IfcCovering',
          layer_patterns: ['*plester*', '*plaster*', '*render*'],
          description: 'Plesteran dan acian permukaan dinding'),

        # ---- LANTAI ----------------------------------------------------------
        Category.new(id: :lantai_keramik, code: 'F.1',
          name: 'Lantai Keramik', name_en: 'Ceramic Floor Tile',
          group: :lantai, quantity_type: :area, unit: 'm²',
          ifc_class: 'IfcCovering',
          layer_patterns: ['*keramik*', '*ceramic*', '*tile_floor*'],
          description: 'Pemasangan keramik lantai'),

        Category.new(id: :lantai_granit, code: 'F.2',
          name: 'Lantai Granit / Marmer', name_en: 'Granite / Marble Floor',
          group: :lantai, quantity_type: :area, unit: 'm²',
          ifc_class: 'IfcCovering',
          layer_patterns: ['*granit*', '*granite*', '*marble*', '*marmer*'],
          description: 'Pemasangan granit atau marmer lantai'),

        Category.new(id: :rabat_beton, code: 'F.3',
          name: 'Rabat Beton', name_en: 'Concrete Screed',
          group: :lantai, quantity_type: :area, unit: 'm²',
          ifc_class: 'IfcSlab',
          layer_patterns: ['*rabat*', '*screed*', '*concrete_floor*'],
          description: 'Rabat beton / lantai kerja'),

        # ---- ATAP ------------------------------------------------------------
        Category.new(id: :rangka_atap_baja, code: 'G.1',
          name: 'Rangka Atap Baja Ringan', name_en: 'Light Steel Roof Frame',
          group: :atap, quantity_type: :area, unit: 'm²',
          ifc_class: 'IfcRoof',
          layer_patterns: ['*rangka_atap*', '*roof_frame*', '*steel_roof*'],
          description: 'Rangka atap baja ringan / light steel truss'),

        Category.new(id: :penutup_atap, code: 'G.2',
          name: 'Penutup Atap Genteng', name_en: 'Roof Tile',
          group: :atap, quantity_type: :area, unit: 'm²',
          ifc_class: 'IfcRoof',
          layer_patterns: ['*genteng*', '*roof_tile*', '*roofing*'],
          description: 'Penutup atap genteng beton / keramik / metal'),

        Category.new(id: :talang, code: 'G.3',
          name: 'Talang Air', name_en: 'Rain Gutter',
          group: :atap, quantity_type: :length, unit: 'm',
          ifc_class: 'IfcPipeSegment',
          layer_patterns: ['*talang*', '*gutter*', '*rainwater*'],
          description: 'Pemasangan talang air hujan'),

        # ---- PLAFON ----------------------------------------------------------
        Category.new(id: :plafon_gypsum, code: 'H.1',
          name: 'Plafon Gypsum', name_en: 'Gypsum Ceiling',
          group: :plafon, quantity_type: :area, unit: 'm²',
          ifc_class: 'IfcCovering',
          layer_patterns: ['*plafon*', '*ceiling*', '*gypsum_ceil*'],
          description: 'Pemasangan plafon gypsum board'),

        # ---- KUSEN -----------------------------------------------------------
        Category.new(id: :pintu, code: 'I.1',
          name: 'Pintu', name_en: 'Door',
          group: :kusen, quantity_type: :count, unit: 'unit',
          ifc_class: 'IfcDoor',
          layer_patterns: ['*pintu*', '*door*', '*dr_*'],
          description: 'Pemasangan daun pintu dan kusen'),

        Category.new(id: :jendela, code: 'I.2',
          name: 'Jendela', name_en: 'Window',
          group: :kusen, quantity_type: :count, unit: 'unit',
          ifc_class: 'IfcWindow',
          layer_patterns: ['*jendela*', '*window*', '*win_*'],
          description: 'Pemasangan daun jendela dan kusen'),

        # ---- FINISHING -------------------------------------------------------
        Category.new(id: :cat_dinding, code: 'J.1',
          name: 'Pengecatan Dinding', name_en: 'Wall Paint',
          group: :finishing, quantity_type: :area, unit: 'm²',
          ifc_class: 'IfcCovering',
          layer_patterns: ['*cat_dinding*', '*wall_paint*', '*paint*'],
          description: 'Pengecatan permukaan dinding interior/eksterior'),

        # ---- MEP -------------------------------------------------------------
        Category.new(id: :instalasi_listrik, code: 'K.1',
          name: 'Instalasi Listrik', name_en: 'Electrical Installation',
          group: :mep, quantity_type: :count, unit: 'ls',
          ifc_class: 'IfcElectricDistributionBoard',
          layer_patterns: ['*listrik*', '*electrical*', '*mep_e*'],
          description: 'Pekerjaan instalasi listrik daya dan penerangan'),

        Category.new(id: :instalasi_air, code: 'K.2',
          name: 'Instalasi Air Bersih & Kotor', name_en: 'Plumbing',
          group: :mep, quantity_type: :count, unit: 'ls',
          ifc_class: 'IfcPipeSegment',
          layer_patterns: ['*plumbing*', '*pipa*', '*mep_p*', '*sanitasi*'],
          description: 'Pekerjaan instalasi pipa air bersih dan sanitasi'),

        Category.new(id: :ac, code: 'K.3',
          name: 'AC & Mekanikal', name_en: 'HVAC',
          group: :mep, quantity_type: :count, unit: 'unit',
          ifc_class: 'IfcUnitaryControlElement',
          layer_patterns: ['*ac*', '*hvac*', '*mep_m*', '*ac_unit*'],
          description: 'Pekerjaan instalasi AC dan mekanikal'),

      ].freeze

      # ---- Public interface --------------------------------------------------

      def self.all
        CATEGORIES
      end

      def self.find(id)
        CATEGORIES.find { |c| c.id == id.to_sym }
      end

      def self.find_by_code(code)
        CATEGORIES.find { |c| c.code == code }
      end

      def self.for_group(group)
        CATEGORIES.select { |c| c.group == group.to_sym }
      end

      def self.groups
        GROUP_LABELS
      end

      def self.layer_pattern_map
        @_lpm ||= CATEGORIES.each_with_object({}) do |cat, h|
          cat.layer_patterns.each { |pat| (h[pat] ||= []) << cat.id }
        end
      end

      def self.to_json_array
        CATEGORIES.map do |c|
          {
            id:              c.id,
            code:            c.code,
            name:            c.name,
            name_en:         c.name_en,
            group:           c.group,
            group_label:     GROUP_LABELS[c.group],
            quantity_type:   c.quantity_type,
            unit:            c.unit,
            ifc_class:       c.ifc_class,
            layer_patterns:  c.layer_patterns,
            description:     c.description
          }
        end
      end
    end
  end
end
