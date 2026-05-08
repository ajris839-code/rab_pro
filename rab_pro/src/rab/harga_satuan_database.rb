# ==============================================================================
# RAB Pro - Harga Satuan Database (HSPK)
# Complete unit price database based on SNI coefficients.
# Each entry defines: materials + labor + tools per unit of work.
# Base prices in BND (Brunei Dollar) — adjustable per project.
#
# Structure per item:
#   code        : SNI code
#   category_id : matches CategoryLibrary
#   unit        : satuan pekerjaan
#   koefisien   : SNI material/labor coefficients
#   analisa     : computed price breakdown
# ==============================================================================

module RABPro
  module RAB
    class HargaSatuanDatabase

      HargaSatuan = Struct.new(
        :id,
        :category_id,
        :code,
        :name,
        :unit,
        :koefisien,       # Array of { item, satuan, koef, type: :material|:upah|:alat }
        :overhead_factor, # default 0.15 (15%)
        keyword_init: true
      )

      # Price table — all prices in BND per unit
      # Updated for Brunei Darussalam market context
      BASE_PRICES = {
        # ---- UPAH / LABOR (per hari) ----------------------------------------
        mandor:             18.00,
        kepala_tukang:      15.00,
        tukang_batu:        14.00,
        tukang_kayu:        14.00,
        tukang_besi:        14.00,
        tukang_cat:         13.00,
        tukang_keramik:     14.00,
        pekerja:            12.00,

        # ---- MATERIAL -------------------------------------------------------
        # Beton & Struktur
        semen_portland_50kg: 12.50,   # per zak 50kg
        pasir_beton_m3:      45.00,
        kerikil_m3:          55.00,
        besi_d10_kg:          2.80,
        besi_d13_kg:          2.80,
        besi_d16_kg:          2.80,
        kawat_bendrat_kg:     4.50,

        # Pasangan
        bata_merah_buah:      0.35,
        batako_buah:          0.65,
        hebel_aac_m3:       180.00,
        pasir_pasang_m3:     40.00,
        mortar_instant_zak:  12.00,  # 40kg

        # Lantai
        keramik_30x30_m2:    12.00,
        keramik_60x60_m2:    18.00,
        granit_60x60_m2:     45.00,
        semen_warna_zak:      8.00,
        tile_grout_kg:        5.50,

        # Finishing
        cat_interior_liter:   4.50,
        cat_eksterior_liter:  6.00,
        plamir_kg:            3.50,
        amplas_lembar:        0.50,
        gypsum_9mm_lembar:    9.50,
        rangka_hollow_btg:    8.50,  # hollow 4×4

        # Atap
        baja_ringan_c75_btg: 18.00,
        screw_baja_100pcs:    8.00,
        genteng_beton_buah:   1.20,
        spandek_m2:           8.50,
        talang_pvc_m:         4.50,

        # Pondasi & Tanah
        batu_kali_m3:        55.00,
        batu_belah_m3:       50.00,

        # Kusen & Pintu
        pintu_hdf_unit:     250.00,
        pintu_panel_unit:   380.00,
        jendela_aluminium_unit: 180.00,
        engsel_buah:          2.50,
        kunci_pintu:         18.00,
        grendel_buah:         4.50,

        # Alat / tools
        sewa_molen_hari:     35.00,
        sewa_scaffolding_m2:  2.00,
        sewa_compactor_hari: 45.00,
      }.freeze

      # ---- ANALISA HARGA SATUAN (Koefisien SNI) ----------------------------

      HARGA_SATUAN = [

        # ================================================================
        # A. PEKERJAAN PERSIAPAN
        # ================================================================

        HargaSatuan.new(
          id: :pembersihan_lahan, category_id: :pembersihan_lahan,
          code: 'A.1', name: 'Pembersihan Lahan', unit: 'm²',
          overhead_factor: 0.15,
          koefisien: [
            { item: :mandor,    satuan: 'hari', koef: 0.050, type: :upah },
            { item: :pekerja,   satuan: 'hari', koef: 0.100, type: :upah },
          ]
        ),

        # ================================================================
        # B. PEKERJAAN TANAH
        # ================================================================

        HargaSatuan.new(
          id: :galian_tanah, category_id: :galian_tanah,
          code: 'B.1', name: 'Galian Tanah Biasa', unit: 'm³',
          overhead_factor: 0.15,
          koefisien: [
            { item: :mandor,  satuan: 'hari', koef: 0.025, type: :upah },
            { item: :pekerja, satuan: 'hari', koef: 0.750, type: :upah },
          ]
        ),

        HargaSatuan.new(
          id: :urugan_tanah, category_id: :urugan_tanah,
          code: 'B.2', name: 'Urugan Tanah Kembali', unit: 'm³',
          overhead_factor: 0.15,
          koefisien: [
            { item: :mandor,  satuan: 'hari', koef: 0.025, type: :upah },
            { item: :pekerja, satuan: 'hari', koef: 0.500, type: :upah },
          ]
        ),

        HargaSatuan.new(
          id: :pemadatan, category_id: :pemadatan,
          code: 'B.3', name: 'Pemadatan Tanah', unit: 'm²',
          overhead_factor: 0.15,
          koefisien: [
            { item: :mandor,           satuan: 'hari', koef: 0.010, type: :upah },
            { item: :pekerja,          satuan: 'hari', koef: 0.100, type: :upah },
            { item: :sewa_compactor_hari, satuan: 'hari', koef: 0.033, type: :alat },
          ]
        ),

        # ================================================================
        # C. PEKERJAAN PONDASI
        # ================================================================

        HargaSatuan.new(
          id: :pondasi_batu, category_id: :pondasi_batu,
          code: 'C.1', name: 'Pondasi Pasangan Batu Kali (1:4)', unit: 'm³',
          overhead_factor: 0.15,
          koefisien: [
            { item: :batu_kali_m3,       satuan: 'm³',  koef: 1.200, type: :material },
            { item: :semen_portland_50kg, satuan: 'zak', koef: 2.780, type: :material },
            { item: :pasir_pasang_m3,    satuan: 'm³',  koef: 0.520, type: :material },
            { item: :mandor,             satuan: 'hari', koef: 0.075, type: :upah },
            { item: :kepala_tukang,      satuan: 'hari', koef: 0.250, type: :upah },
            { item: :tukang_batu,        satuan: 'hari', koef: 1.500, type: :upah },
            { item: :pekerja,            satuan: 'hari', koef: 0.500, type: :upah },
          ]
        ),

        HargaSatuan.new(
          id: :pondasi_tapak, category_id: :pondasi_tapak,
          code: 'C.2', name: 'Pondasi Tapak Beton Bertulang (K-250)', unit: 'm³',
          overhead_factor: 0.15,
          koefisien: [
            # Beton K-250 per m³
            { item: :semen_portland_50kg, satuan: 'zak', koef: 7.425, type: :material },
            { item: :pasir_beton_m3,      satuan: 'm³',  koef: 0.547, type: :material },
            { item: :kerikil_m3,          satuan: 'm³',  koef: 0.819, type: :material },
            # Pembesian ~150 kg/m³
            { item: :besi_d13_kg,         satuan: 'kg',  koef: 150.0, type: :material },
            { item: :kawat_bendrat_kg,    satuan: 'kg',  koef: 2.250, type: :material },
            # Upah
            { item: :mandor,             satuan: 'hari', koef: 0.083, type: :upah },
            { item: :kepala_tukang,      satuan: 'hari', koef: 0.083, type: :upah },
            { item: :tukang_batu,        satuan: 'hari', koef: 0.833, type: :upah },
            { item: :tukang_besi,        satuan: 'hari', koef: 0.833, type: :upah },
            { item: :pekerja,            satuan: 'hari', koef: 1.667, type: :upah },
            # Alat
            { item: :sewa_molen_hari,    satuan: 'hari', koef: 0.250, type: :alat },
          ]
        ),

        HargaSatuan.new(
          id: :sloof, category_id: :sloof,
          code: 'C.4', name: 'Sloof Beton Bertulang (K-250)', unit: 'm³',
          overhead_factor: 0.15,
          koefisien: [
            { item: :semen_portland_50kg, satuan: 'zak', koef: 7.425, type: :material },
            { item: :pasir_beton_m3,      satuan: 'm³',  koef: 0.547, type: :material },
            { item: :kerikil_m3,          satuan: 'm³',  koef: 0.819, type: :material },
            { item: :besi_d13_kg,         satuan: 'kg',  koef: 120.0, type: :material },
            { item: :kawat_bendrat_kg,    satuan: 'kg',  koef: 1.800, type: :material },
            { item: :mandor,             satuan: 'hari', koef: 0.083, type: :upah },
            { item: :kepala_tukang,      satuan: 'hari', koef: 0.083, type: :upah },
            { item: :tukang_batu,        satuan: 'hari', koef: 0.833, type: :upah },
            { item: :tukang_besi,        satuan: 'hari', koef: 0.667, type: :upah },
            { item: :pekerja,            satuan: 'hari', koef: 1.667, type: :upah },
            { item: :sewa_molen_hari,    satuan: 'hari', koef: 0.200, type: :alat },
          ]
        ),

        # ================================================================
        # D. PEKERJAAN STRUKTUR
        # ================================================================

        HargaSatuan.new(
          id: :kolom, category_id: :kolom,
          code: 'D.1', name: 'Kolom Beton Bertulang (K-300)', unit: 'm³',
          overhead_factor: 0.15,
          koefisien: [
            { item: :semen_portland_50kg, satuan: 'zak', koef: 8.300, type: :material },
            { item: :pasir_beton_m3,      satuan: 'm³',  koef: 0.520, type: :material },
            { item: :kerikil_m3,          satuan: 'm³',  koef: 0.780, type: :material },
            { item: :besi_d16_kg,         satuan: 'kg',  koef: 200.0, type: :material },
            { item: :kawat_bendrat_kg,    satuan: 'kg',  koef: 3.000, type: :material },
            { item: :mandor,             satuan: 'hari', koef: 0.100, type: :upah },
            { item: :kepala_tukang,      satuan: 'hari', koef: 0.100, type: :upah },
            { item: :tukang_batu,        satuan: 'hari', koef: 1.000, type: :upah },
            { item: :tukang_besi,        satuan: 'hari', koef: 1.000, type: :upah },
            { item: :pekerja,            satuan: 'hari', koef: 2.000, type: :upah },
            { item: :sewa_molen_hari,    satuan: 'hari', koef: 0.333, type: :alat },
            { item: :sewa_scaffolding_m2, satuan: 'm²',  koef: 3.000, type: :alat },
          ]
        ),

        HargaSatuan.new(
          id: :balok, category_id: :balok,
          code: 'D.2', name: 'Balok Beton Bertulang (K-300)', unit: 'm³',
          overhead_factor: 0.15,
          koefisien: [
            { item: :semen_portland_50kg, satuan: 'zak', koef: 8.300, type: :material },
            { item: :pasir_beton_m3,      satuan: 'm³',  koef: 0.520, type: :material },
            { item: :kerikil_m3,          satuan: 'm³',  koef: 0.780, type: :material },
            { item: :besi_d16_kg,         satuan: 'kg',  koef: 180.0, type: :material },
            { item: :kawat_bendrat_kg,    satuan: 'kg',  koef: 2.700, type: :material },
            { item: :mandor,             satuan: 'hari', koef: 0.100, type: :upah },
            { item: :kepala_tukang,      satuan: 'hari', koef: 0.100, type: :upah },
            { item: :tukang_batu,        satuan: 'hari', koef: 1.000, type: :upah },
            { item: :tukang_besi,        satuan: 'hari', koef: 1.000, type: :upah },
            { item: :pekerja,            satuan: 'hari', koef: 2.000, type: :upah },
            { item: :sewa_molen_hari,    satuan: 'hari', koef: 0.333, type: :alat },
            { item: :sewa_scaffolding_m2, satuan: 'm²',  koef: 4.000, type: :alat },
          ]
        ),

        HargaSatuan.new(
          id: :plat_lantai, category_id: :plat_lantai,
          code: 'D.3', name: 'Plat Lantai Beton Bertulang t=12cm (K-250)', unit: 'm²',
          overhead_factor: 0.15,
          koefisien: [
            { item: :semen_portland_50kg, satuan: 'zak', koef: 0.891, type: :material },
            { item: :pasir_beton_m3,      satuan: 'm³',  koef: 0.066, type: :material },
            { item: :kerikil_m3,          satuan: 'm³',  koef: 0.098, type: :material },
            { item: :besi_d10_kg,         satuan: 'kg',  koef: 10.0,  type: :material },
            { item: :kawat_bendrat_kg,    satuan: 'kg',  koef: 0.150, type: :material },
            { item: :mandor,             satuan: 'hari', koef: 0.020, type: :upah },
            { item: :kepala_tukang,      satuan: 'hari', koef: 0.020, type: :upah },
            { item: :tukang_batu,        satuan: 'hari', koef: 0.200, type: :upah },
            { item: :tukang_besi,        satuan: 'hari', koef: 0.100, type: :upah },
            { item: :pekerja,            satuan: 'hari', koef: 0.400, type: :upah },
            { item: :sewa_molen_hari,    satuan: 'hari', koef: 0.067, type: :alat },
          ]
        ),

        # ================================================================
        # E. PEKERJAAN DINDING
        # ================================================================

        HargaSatuan.new(
          id: :dinding_bata, category_id: :dinding_bata,
          code: 'E.1', name: 'Pasangan Dinding Bata Merah ½ Bata (1:4)', unit: 'm²',
          overhead_factor: 0.15,
          koefisien: [
            { item: :bata_merah_buah,     satuan: 'buah', koef: 70.0,  type: :material },
            { item: :semen_portland_50kg, satuan: 'zak',  koef: 0.340, type: :material },
            { item: :pasir_pasang_m3,     satuan: 'm³',   koef: 0.048, type: :material },
            { item: :mandor,             satuan: 'hari',  koef: 0.033, type: :upah },
            { item: :kepala_tukang,      satuan: 'hari',  koef: 0.033, type: :upah },
            { item: :tukang_batu,        satuan: 'hari',  koef: 0.333, type: :upah },
            { item: :pekerja,            satuan: 'hari',  koef: 0.700, type: :upah },
          ]
        ),

        HargaSatuan.new(
          id: :dinding_batako, category_id: :dinding_batako,
          code: 'E.2', name: 'Pasangan Dinding Batako Press', unit: 'm²',
          overhead_factor: 0.15,
          koefisien: [
            { item: :batako_buah,         satuan: 'buah', koef: 12.5,  type: :material },
            { item: :semen_portland_50kg, satuan: 'zak',  koef: 0.180, type: :material },
            { item: :pasir_pasang_m3,     satuan: 'm³',   koef: 0.025, type: :material },
            { item: :mandor,             satuan: 'hari',  koef: 0.025, type: :upah },
            { item: :kepala_tukang,      satuan: 'hari',  koef: 0.025, type: :upah },
            { item: :tukang_batu,        satuan: 'hari',  koef: 0.250, type: :upah },
            { item: :pekerja,            satuan: 'hari',  koef: 0.500, type: :upah },
          ]
        ),

        HargaSatuan.new(
          id: :dinding_hebel, category_id: :dinding_hebel,
          code: 'E.3', name: 'Pasangan Dinding Bata Ringan Hebel t=10cm', unit: 'm²',
          overhead_factor: 0.15,
          koefisien: [
            { item: :hebel_aac_m3,        satuan: 'm³',  koef: 0.083, type: :material },
            { item: :mortar_instant_zak,  satuan: 'zak', koef: 0.250, type: :material },
            { item: :mandor,             satuan: 'hari', koef: 0.020, type: :upah },
            { item: :kepala_tukang,      satuan: 'hari', koef: 0.020, type: :upah },
            { item: :tukang_batu,        satuan: 'hari', koef: 0.200, type: :upah },
            { item: :pekerja,            satuan: 'hari', koef: 0.400, type: :upah },
          ]
        ),

        HargaSatuan.new(
          id: :plester, category_id: :plester,
          code: 'E.4', name: 'Plesteran Dinding (1:4) + Acian', unit: 'm²',
          overhead_factor: 0.15,
          koefisien: [
            { item: :semen_portland_50kg, satuan: 'zak',  koef: 0.288, type: :material },
            { item: :pasir_pasang_m3,     satuan: 'm³',   koef: 0.024, type: :material },
            { item: :mandor,             satuan: 'hari',  koef: 0.020, type: :upah },
            { item: :kepala_tukang,      satuan: 'hari',  koef: 0.020, type: :upah },
            { item: :tukang_batu,        satuan: 'hari',  koef: 0.200, type: :upah },
            { item: :pekerja,            satuan: 'hari',  koef: 0.200, type: :upah },
          ]
        ),

        # ================================================================
        # F. PEKERJAAN LANTAI
        # ================================================================

        HargaSatuan.new(
          id: :lantai_keramik, category_id: :lantai_keramik,
          code: 'F.1', name: 'Lantai Keramik 30×30 (termasuk mortar)', unit: 'm²',
          overhead_factor: 0.15,
          koefisien: [
            { item: :keramik_30x30_m2,    satuan: 'm²',  koef: 1.050, type: :material },
            { item: :semen_portland_50kg, satuan: 'zak',  koef: 0.204, type: :material },
            { item: :pasir_pasang_m3,     satuan: 'm³',   koef: 0.045, type: :material },
            { item: :semen_warna_zak,     satuan: 'zak',  koef: 0.025, type: :material },
            { item: :mandor,             satuan: 'hari',  koef: 0.033, type: :upah },
            { item: :kepala_tukang,      satuan: 'hari',  koef: 0.033, type: :upah },
            { item: :tukang_keramik,     satuan: 'hari',  koef: 0.333, type: :upah },
            { item: :pekerja,            satuan: 'hari',  koef: 0.100, type: :upah },
          ]
        ),

        HargaSatuan.new(
          id: :lantai_granit, category_id: :lantai_granit,
          code: 'F.2', name: 'Lantai Granit Polished 60×60', unit: 'm²',
          overhead_factor: 0.15,
          koefisien: [
            { item: :granit_60x60_m2,     satuan: 'm²',  koef: 1.050, type: :material },
            { item: :semen_portland_50kg, satuan: 'zak',  koef: 0.204, type: :material },
            { item: :pasir_pasang_m3,     satuan: 'm³',   koef: 0.045, type: :material },
            { item: :tile_grout_kg,       satuan: 'kg',   koef: 0.300, type: :material },
            { item: :mandor,             satuan: 'hari',  koef: 0.033, type: :upah },
            { item: :kepala_tukang,      satuan: 'hari',  koef: 0.033, type: :upah },
            { item: :tukang_keramik,     satuan: 'hari',  koef: 0.500, type: :upah },
            { item: :pekerja,            satuan: 'hari',  koef: 0.167, type: :upah },
          ]
        ),

        HargaSatuan.new(
          id: :rabat_beton, category_id: :rabat_beton,
          code: 'F.3', name: 'Rabat Beton t=6cm (K-175)', unit: 'm²',
          overhead_factor: 0.15,
          koefisien: [
            { item: :semen_portland_50kg, satuan: 'zak',  koef: 0.336, type: :material },
            { item: :pasir_beton_m3,      satuan: 'm³',   koef: 0.033, type: :material },
            { item: :kerikil_m3,          satuan: 'm³',   koef: 0.049, type: :material },
            { item: :mandor,             satuan: 'hari',  koef: 0.010, type: :upah },
            { item: :tukang_batu,        satuan: 'hari',  koef: 0.100, type: :upah },
            { item: :pekerja,            satuan: 'hari',  koef: 0.200, type: :upah },
          ]
        ),

        # ================================================================
        # G. PEKERJAAN ATAP
        # ================================================================

        HargaSatuan.new(
          id: :rangka_atap_baja, category_id: :rangka_atap_baja,
          code: 'G.1', name: 'Rangka Atap Baja Ringan (per luas atap)', unit: 'm²',
          overhead_factor: 0.15,
          koefisien: [
            { item: :baja_ringan_c75_btg, satuan: 'btg',  koef: 0.800, type: :material },
            { item: :screw_baja_100pcs,   satuan: '100pc', koef: 0.050, type: :material },
            { item: :mandor,             satuan: 'hari',  koef: 0.010, type: :upah },
            { item: :kepala_tukang,      satuan: 'hari',  koef: 0.010, type: :upah },
            { item: :tukang_kayu,        satuan: 'hari',  koef: 0.100, type: :upah },
            { item: :pekerja,            satuan: 'hari',  koef: 0.100, type: :upah },
          ]
        ),

        HargaSatuan.new(
          id: :penutup_atap, category_id: :penutup_atap,
          code: 'G.2', name: 'Penutup Atap Genteng Beton', unit: 'm²',
          overhead_factor: 0.15,
          koefisien: [
            { item: :genteng_beton_buah,  satuan: 'buah', koef: 10.0,  type: :material },
            { item: :mandor,             satuan: 'hari',  koef: 0.010, type: :upah },
            { item: :kepala_tukang,      satuan: 'hari',  koef: 0.010, type: :upah },
            { item: :tukang_kayu,        satuan: 'hari',  koef: 0.100, type: :upah },
            { item: :pekerja,            satuan: 'hari',  koef: 0.100, type: :upah },
          ]
        ),

        HargaSatuan.new(
          id: :talang, category_id: :talang,
          code: 'G.3', name: 'Talang Air PVC D=100mm', unit: 'm',
          overhead_factor: 0.15,
          koefisien: [
            { item: :talang_pvc_m,       satuan: 'm',    koef: 1.100, type: :material },
            { item: :mandor,             satuan: 'hari',  koef: 0.005, type: :upah },
            { item: :tukang_batu,        satuan: 'hari',  koef: 0.050, type: :upah },
            { item: :pekerja,            satuan: 'hari',  koef: 0.050, type: :upah },
          ]
        ),

        # ================================================================
        # H. PEKERJAAN PLAFON
        # ================================================================

        HargaSatuan.new(
          id: :plafon_gypsum, category_id: :plafon_gypsum,
          code: 'H.1', name: 'Plafon Gypsum Board 9mm + Rangka Hollow', unit: 'm²',
          overhead_factor: 0.15,
          koefisien: [
            { item: :gypsum_9mm_lembar,  satuan: 'lbr',  koef: 0.365, type: :material },
            { item: :rangka_hollow_btg,  satuan: 'btg',  koef: 0.800, type: :material },
            { item: :mandor,             satuan: 'hari',  koef: 0.010, type: :upah },
            { item: :kepala_tukang,      satuan: 'hari',  koef: 0.010, type: :upah },
            { item: :tukang_kayu,        satuan: 'hari',  koef: 0.100, type: :upah },
            { item: :pekerja,            satuan: 'hari',  koef: 0.100, type: :upah },
          ]
        ),

        # ================================================================
        # I. KUSEN, PINTU & JENDELA
        # ================================================================

        HargaSatuan.new(
          id: :pintu, category_id: :pintu,
          code: 'I.1', name: 'Pemasangan Daun Pintu HDF + Kusen', unit: 'unit',
          overhead_factor: 0.15,
          koefisien: [
            { item: :pintu_hdf_unit,     satuan: 'unit', koef: 1.000, type: :material },
            { item: :engsel_buah,        satuan: 'buah', koef: 3.000, type: :material },
            { item: :kunci_pintu,        satuan: 'buah', koef: 1.000, type: :material },
            { item: :mandor,             satuan: 'hari',  koef: 0.033, type: :upah },
            { item: :kepala_tukang,      satuan: 'hari',  koef: 0.033, type: :upah },
            { item: :tukang_kayu,        satuan: 'hari',  koef: 0.333, type: :upah },
            { item: :pekerja,            satuan: 'hari',  koef: 0.167, type: :upah },
          ]
        ),

        HargaSatuan.new(
          id: :jendela, category_id: :jendela,
          code: 'I.2', name: 'Pemasangan Jendela Aluminium Lengkap', unit: 'unit',
          overhead_factor: 0.15,
          koefisien: [
            { item: :jendela_aluminium_unit, satuan: 'unit', koef: 1.000, type: :material },
            { item: :grendel_buah,           satuan: 'buah', koef: 2.000, type: :material },
            { item: :mandor,                satuan: 'hari',  koef: 0.025, type: :upah },
            { item: :kepala_tukang,         satuan: 'hari',  koef: 0.025, type: :upah },
            { item: :tukang_kayu,           satuan: 'hari',  koef: 0.250, type: :upah },
            { item: :pekerja,               satuan: 'hari',  koef: 0.125, type: :upah },
          ]
        ),

        # ================================================================
        # J. FINISHING
        # ================================================================

        HargaSatuan.new(
          id: :cat_dinding, category_id: :cat_dinding,
          code: 'J.1', name: 'Pengecatan Dinding Interior (3 lapis)', unit: 'm²',
          overhead_factor: 0.15,
          koefisien: [
            { item: :plamir_kg,          satuan: 'kg',   koef: 0.100, type: :material },
            { item: :cat_interior_liter, satuan: 'liter', koef: 0.200, type: :material },
            { item: :amplas_lembar,      satuan: 'lbr',  koef: 0.300, type: :material },
            { item: :mandor,             satuan: 'hari',  koef: 0.010, type: :upah },
            { item: :kepala_tukang,      satuan: 'hari',  koef: 0.010, type: :upah },
            { item: :tukang_cat,         satuan: 'hari',  koef: 0.100, type: :upah },
            { item: :pekerja,            satuan: 'hari',  koef: 0.050, type: :upah },
          ]
        ),

      ].freeze

      # -----------------------------------------------------------------------
      # Public API
      # -----------------------------------------------------------------------

      class << self

        def all;          HARGA_SATUAN end
        def find(id);     HARGA_SATUAN.find { |h| h.id == id.to_sym } end
        def base_prices;  BASE_PRICES end

        def price_for_item(item_key)
          BASE_PRICES[item_key.to_sym] || 0.0
        end

        # Compute full analisa harga satuan breakdown for one HS entry
        # Returns hash with material_cost, labor_cost, equipment_cost, total, overhead, grand_total
        def compute_analisa(hs_id, custom_prices: {}, overhead_pct: 15.0, profit_pct: 10.0)
          hs = find(hs_id)
          raise ArgumentError, "Harga satuan '#{hs_id}' tidak ditemukan" unless hs

          material_total = 0.0
          labor_total    = 0.0
          equipment_total = 0.0
          line_items     = []

          hs.koefisien.each do |k|
            price = custom_prices[k[:item]] || BASE_PRICES[k[:item]] || 0.0
            amount = k[:koef] * price

            line_items << {
              item:    k[:item],
              satuan:  k[:satuan],
              koef:    k[:koef],
              harga:   price,
              jumlah:  amount.round(4),
              type:    k[:type]
            }

            case k[:type]
            when :material  then material_total  += amount
            when :upah      then labor_total     += amount
            when :alat      then equipment_total += amount
            end
          end

          subtotal      = material_total + labor_total + equipment_total
          overhead      = subtotal * (overhead_pct / 100.0)
          profit        = subtotal * (profit_pct / 100.0)
          grand_total   = subtotal + overhead + profit

          {
            hs_id:            hs.id,
            code:             hs.code,
            name:             hs.name,
            unit:             hs.unit,
            line_items:       line_items,
            material_total:   material_total.round(2),
            labor_total:      labor_total.round(2),
            equipment_total:  equipment_total.round(2),
            subtotal:         subtotal.round(2),
            overhead_pct:     overhead_pct,
            overhead:         overhead.round(2),
            profit_pct:       profit_pct,
            profit:           profit.round(2),
            grand_total:      grand_total.round(2)
          }
        end

        # Compute for all categories at once
        def compute_all(custom_prices: {}, overhead_pct: 15.0, profit_pct: 10.0)
          HARGA_SATUAN.each_with_object({}) do |hs, h|
            h[hs.id] = compute_analisa(
              hs.id,
              custom_prices: custom_prices,
              overhead_pct:  overhead_pct,
              profit_pct:    profit_pct
            )
          rescue => e
            Logger.warn("HargaSatuanDatabase.compute_all: #{hs.id} — #{e.message}")
          end
        end

        def to_json_array
          HARGA_SATUAN.map do |hs|
            {
              id:          hs.id,
              category_id: hs.category_id,
              code:        hs.code,
              name:        hs.name,
              unit:        hs.unit,
              koef_count:  hs.koefisien.size
            }
          end
        end

      end
    end
  end
end
