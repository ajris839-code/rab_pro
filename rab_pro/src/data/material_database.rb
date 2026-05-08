# ==============================================================================
# RAB Pro - Material Database
# Master data of construction materials with unit weights, specs,
# and base price hints (BND / Brunei context, adjustable per project).
# ==============================================================================

module RABPro
  module Data
    class MaterialDatabase

      Material = Struct.new(
        :id,
        :name,
        :name_en,
        :category,        # :concrete | :masonry | :steel | :wood | :finish | :mep | :other
        :unit,            # purchase unit: kg, m3, m2, lbr, batang, dll
        :density_kg_m3,   # for weight calculations
        :base_price,      # indicative price in BND
        :specs,           # hash of additional specs
        keyword_init: true
      )

      MATERIALS = [
        # ---- CONCRETE MATERIALS ---------------------------------------------
        Material.new(id: :semen_portland, name: 'Semen Portland (50kg)', name_en: 'Portland Cement',
          category: :concrete, unit: 'zak', density_kg_m3: nil, base_price: 12.50,
          specs: { weight_kg: 50, standard: 'SNI 15-2049' }),

        Material.new(id: :pasir_beton, name: 'Pasir Beton', name_en: 'Concrete Sand',
          category: :concrete, unit: 'm³', density_kg_m3: 1600, base_price: 45.00,
          specs: { gradasi: 'Halus–Sedang', kadar_lumpur_max: '5%' }),

        Material.new(id: :kerikil, name: 'Kerikil / Batu Pecah', name_en: 'Coarse Aggregate',
          category: :concrete, unit: 'm³', density_kg_m3: 1550, base_price: 55.00,
          specs: { ukuran: '10–20 mm', standard: 'SNI 03-1750' }),

        Material.new(id: :besi_beton_d10, name: 'Besi Beton D10', name_en: 'Rebar D10',
          category: :steel, unit: 'kg', density_kg_m3: 7850, base_price: 2.80,
          specs: { diameter_mm: 10, panjang_m: 12, berat_per_m: 0.617, grade: 'BJTS 420' }),

        Material.new(id: :besi_beton_d13, name: 'Besi Beton D13', name_en: 'Rebar D13',
          category: :steel, unit: 'kg', density_kg_m3: 7850, base_price: 2.80,
          specs: { diameter_mm: 13, panjang_m: 12, berat_per_m: 1.040, grade: 'BJTS 420' }),

        Material.new(id: :besi_beton_d16, name: 'Besi Beton D16', name_en: 'Rebar D16',
          category: :steel, unit: 'kg', density_kg_m3: 7850, base_price: 2.80,
          specs: { diameter_mm: 16, panjang_m: 12, berat_per_m: 1.578, grade: 'BJTS 420' }),

        Material.new(id: :kawat_bendrat, name: 'Kawat Bendrat', name_en: 'Binding Wire',
          category: :concrete, unit: 'kg', density_kg_m3: 7850, base_price: 4.50,
          specs: { diameter_mm: 1.0 }),

        # ---- MASONRY --------------------------------------------------------
        Material.new(id: :bata_merah, name: 'Bata Merah', name_en: 'Red Brick',
          category: :masonry, unit: 'buah', density_kg_m3: 1800, base_price: 0.35,
          specs: { ukuran: '190×90×50 mm', kuat_tekan: 'K-25', per_m2: 40 }),

        Material.new(id: :batako_press, name: 'Batako Press', name_en: 'Concrete Block',
          category: :masonry, unit: 'buah', density_kg_m3: 1700, base_price: 0.65,
          specs: { ukuran: '400×200×100 mm', per_m2: 12 }),

        Material.new(id: :hebel_aac, name: 'Bata Ringan Hebel / AAC', name_en: 'AAC Block',
          category: :masonry, unit: 'm³', density_kg_m3: 500, base_price: 180.00,
          specs: { ukuran: '600×200×100 mm', kuat_tekan: 'B4', thermal_R: 0.35 }),

        Material.new(id: :mortar_pasangan, name: 'Mortar / Adukan Pasangan (1:4)', name_en: 'Masonry Mortar',
          category: :masonry, unit: 'm³', density_kg_m3: 2000, base_price: 120.00,
          specs: { campuran: '1 semen : 4 pasir' }),

        # ---- FINISHING ------------------------------------------------------
        Material.new(id: :keramik_30x30, name: 'Keramik Lantai 30×30', name_en: 'Floor Tile 30×30',
          category: :finish, unit: 'm²', density_kg_m3: nil, base_price: 12.00,
          specs: { ukuran: '300×300 mm', ketebalan_mm: 7, per_m2: 11.11 }),

        Material.new(id: :keramik_60x60, name: 'Keramik Lantai 60×60', name_en: 'Floor Tile 60×60',
          category: :finish, unit: 'm²', density_kg_m3: nil, base_price: 18.00,
          specs: { ukuran: '600×600 mm', ketebalan_mm: 10, per_m2: 2.78 }),

        Material.new(id: :granit_60x60, name: 'Granit Polished 60×60', name_en: 'Polished Granite 60×60',
          category: :finish, unit: 'm²', density_kg_m3: 2700, base_price: 45.00,
          specs: { ukuran: '600×600 mm', ketebalan_mm: 12 }),

        Material.new(id: :cat_interior, name: 'Cat Tembok Interior', name_en: 'Interior Wall Paint',
          category: :finish, unit: 'liter', density_kg_m3: nil, base_price: 4.50,
          specs: { coverage_m2_per_liter: 10, lapisan: 2 }),

        Material.new(id: :cat_eksterior, name: 'Cat Tembok Eksterior', name_en: 'Exterior Wall Paint',
          category: :finish, unit: 'liter', density_kg_m3: nil, base_price: 6.00,
          specs: { coverage_m2_per_liter: 8, water_resistant: true }),

        Material.new(id: :gypsum_board_9mm, name: 'Gypsum Board 9mm', name_en: 'Gypsum Board 9mm',
          category: :finish, unit: 'lembar', density_kg_m3: nil, base_price: 9.50,
          specs: { ukuran: '1200×2400 mm', tebal_mm: 9, luas_per_lembar: 2.88 }),

        # ---- ROOFING --------------------------------------------------------
        Material.new(id: :baja_ringan_c75, name: 'Baja Ringan C75', name_en: 'Light Steel C75',
          category: :steel, unit: 'batang', density_kg_m3: 7850, base_price: 18.00,
          specs: { profil: 'C 75×45×0.75 mm', panjang_m: 6, berat_kg: 5.4 }),

        Material.new(id: :genteng_beton, name: 'Genteng Beton', name_en: 'Concrete Roof Tile',
          category: :other, unit: 'buah', density_kg_m3: 2000, base_price: 1.20,
          specs: { per_m2: 10, berat_kg: 4.0 }),

        Material.new(id: :spandek, name: 'Atap Spandek 0.35mm', name_en: 'Spandex Roof Sheet',
          category: :other, unit: 'm²', density_kg_m3: nil, base_price: 8.50,
          specs: { tebal_mm: 0.35, lebar_efektif_mm: 800 }),
      ].freeze

      class << self

        def all;          MATERIALS end
        def find(id);     MATERIALS.find { |m| m.id == id.to_sym } end
        def for_category(cat); MATERIALS.select { |m| m.category == cat.to_sym } end

        def to_json_array
          MATERIALS.map do |m|
            {
              id:          m.id,
              name:        m.name,
              name_en:     m.name_en,
              category:    m.category,
              unit:        m.unit,
              base_price:  m.base_price,
              specs:       m.specs
            }
          end
        end

        # Calculate weight of material by volume
        def weight_kg(material_id, volume_m3)
          mat = find(material_id)
          return nil unless mat&.density_kg_m3
          mat.density_kg_m3 * volume_m3
        end

      end
    end
  end
end
