# ==============================================================================
# RAB Pro - Project Template Engine
# Manages reusable project templates:
#   - Pre-defined templates (rumah tinggal, ruko, gudang, apartemen)
#   - Custom templates saved from existing projects
#   - Template application: auto-setup layers, tags, RAB structure
#   - Component library per template type
# ==============================================================================

module RABPro
  module Templates
    class TemplateEngine

      TEMPLATES_DIR = File.join(RABPro::RESOURCES_PATH, 'project_templates').freeze

      Template = Struct.new(
        :id, :name, :name_en, :description, :icon,
        :building_type, :typical_area_m2,
        :layers,          # recommended layer names
        :default_scenes,  # scene ids to create
        :rab_categories,  # category ids with typical quantities
        :milestones,      # default milestone dates (relative days)
        :notes,
        keyword_init: true
      )

      # ---- Built-in templates -----------------------------------------------
      BUILTIN_TEMPLATES = [

        Template.new(
          id:           :rumah_type_36,
          name:         'Rumah Tipe 36/72',
          name_en:      'Type 36 House',
          description:  'Rumah tinggal 1 lantai, 2 kamar tidur, LB 36 m², LT 72 m²',
          icon:         '🏠',
          building_type: :residential,
          typical_area_m2: 36.0,
          layers: %w[
            Pondasi Sloof Kolom Balok Plat_Lantai
            Dinding_Bata Plester Cat_Dinding
            Lantai_Keramik Rabat_Beton
            Atap_Rangka Atap_Genteng Plafon_Gypsum
            Pintu Jendela Instalasi_Listrik Instalasi_Air
          ],
          default_scenes: %i[denah_lt1 denah_atap tampak_depan tampak_kiri potongan_aa perspektif],
          rab_categories: {
            pembersihan_lahan: { qty: 72,   unit: 'm²' },
            galian_tanah:      { qty: 8.5,  unit: 'm³' },
            pondasi_batu:      { qty: 5.2,  unit: 'm³' },
            sloof:             { qty: 0.8,  unit: 'm³' },
            kolom:             { qty: 1.2,  unit: 'm³' },
            balok:             { qty: 0.9,  unit: 'm³' },
            plat_lantai:       { qty: 36,   unit: 'm²' },
            dinding_bata:      { qty: 120,  unit: 'm²' },
            plester:           { qty: 240,  unit: 'm²' },
            lantai_keramik:    { qty: 36,   unit: 'm²' },
            rabat_beton:       { qty: 36,   unit: 'm²' },
            rangka_atap_baja:  { qty: 55,   unit: 'm²' },
            penutup_atap:      { qty: 55,   unit: 'm²' },
            plafon_gypsum:     { qty: 36,   unit: 'm²' },
            cat_dinding:       { qty: 240,  unit: 'm²' },
            pintu:             { qty: 4,    unit: 'unit' },
            jendela:           { qty: 6,    unit: 'unit' },
            instalasi_listrik: { qty: 1,    unit: 'ls' },
            instalasi_air:     { qty: 1,    unit: 'ls' },
          },
          milestones: [
            { name: 'Kick-off', days: 0 },
            { name: 'Pondasi selesai', days: 30 },
            { name: 'Struktur selesai', days: 75 },
            { name: 'Atap selesai', days: 100 },
            { name: 'Finishing selesai', days: 150 },
            { name: 'Serah Terima', days: 160 },
          ],
          notes: 'Template standar rumah type 36. Sesuaikan harga satuan dengan lokasi.'
        ),

        Template.new(
          id:           :rumah_type_70,
          name:         'Rumah Tipe 70/120',
          name_en:      'Type 70 House',
          description:  'Rumah tinggal 2 lantai, 3 kamar tidur, LB 70 m², LT 120 m²',
          icon:         '🏘️',
          building_type: :residential,
          typical_area_m2: 70.0,
          layers: %w[
            Pondasi_Tapak Sloof Kolom_Lt1 Kolom_Lt2 Balok_Lt1 Balok_Lt2
            Plat_Lt1 Plat_Lt2 Dinding_Lt1 Dinding_Lt2
            Plester Cat Lantai_Keramik_Lt1 Lantai_Keramik_Lt2
            Atap_Rangka Atap_Genteng Plafon_Lt1 Plafon_Lt2
            Pintu Jendela Tangga MEP
          ],
          default_scenes: %i[denah_lt1 denah_lt2 denah_atap tampak_depan tampak_belakang tampak_kiri tampak_kanan potongan_aa potongan_bb perspektif],
          rab_categories: {
            pembersihan_lahan: { qty: 120,  unit: 'm²' },
            galian_tanah:      { qty: 18,   unit: 'm³' },
            pondasi_tapak:     { qty: 3.5,  unit: 'm³' },
            sloof:             { qty: 1.8,  unit: 'm³' },
            kolom:             { qty: 4.2,  unit: 'm³' },
            balok:             { qty: 3.8,  unit: 'm³' },
            plat_lantai:       { qty: 140,  unit: 'm²' },
            ringbalk:          { qty: 1.0,  unit: 'm³' },
            dinding_bata:      { qty: 280,  unit: 'm²' },
            plester:           { qty: 560,  unit: 'm²' },
            lantai_keramik:    { qty: 140,  unit: 'm²' },
            rabat_beton:       { qty: 70,   unit: 'm²' },
            rangka_atap_baja:  { qty: 90,   unit: 'm²' },
            penutup_atap:      { qty: 90,   unit: 'm²' },
            plafon_gypsum:     { qty: 140,  unit: 'm²' },
            cat_dinding:       { qty: 560,  unit: 'm²' },
            pintu:             { qty: 8,    unit: 'unit' },
            jendela:           { qty: 14,   unit: 'unit' },
            tangga:            { qty: 1,    unit: 'unit' },
            instalasi_listrik: { qty: 1,    unit: 'ls' },
            instalasi_air:     { qty: 1,    unit: 'ls' },
          },
          milestones: [
            { name: 'Kick-off', days: 0 },
            { name: 'Pondasi selesai', days: 45 },
            { name: 'Struktur Lt.1 selesai', days: 90 },
            { name: 'Struktur Lt.2 selesai', days: 130 },
            { name: 'Atap selesai', days: 160 },
            { name: 'Finishing selesai', days: 220 },
            { name: 'Serah Terima', days: 240 },
          ],
          notes: 'Rumah 2 lantai. Perlu perhatian khusus pada sambungan kolom dan plat lantai.'
        ),

        Template.new(
          id:           :ruko,
          name:         'Ruko (Rumah Toko)',
          name_en:      'Shophouse',
          description:  'Ruko 3 lantai, LB 60 m², LT 60 m². Lantai 1 toko, Lt 2-3 hunian/kantor',
          icon:         '🏪',
          building_type: :commercial,
          typical_area_m2: 60.0,
          layers: %w[
            Pondasi Sloof Kolom Balok Plat_Lt1 Plat_Lt2 Plat_Lt3
            Dinding_Depan Dinding_Samping Dinding_Belakang
            Plester_Interior Plester_Eksterior Cat_Interior Cat_Eksterior
            Lantai_Granit_Lt1 Lantai_Keramik_Lt2 Lantai_Keramik_Lt3
            Fasad_Kaca Pintu_Kaca Pintu_Kayu Jendela
            Atap Plafon MEP_Listrik MEP_Air
          ],
          default_scenes: %i[denah_lt1 denah_lt2 tampak_depan tampak_kiri potongan_aa perspektif],
          rab_categories: {
            galian_tanah:      { qty: 22,   unit: 'm³' },
            pondasi_tapak:     { qty: 4.8,  unit: 'm³' },
            kolom:             { qty: 7.2,  unit: 'm³' },
            balok:             { qty: 6.5,  unit: 'm³' },
            plat_lantai:       { qty: 180,  unit: 'm²' },
            dinding_bata:      { qty: 350,  unit: 'm²' },
            plester:           { qty: 700,  unit: 'm²' },
            lantai_granit:     { qty: 60,   unit: 'm²' },
            lantai_keramik:    { qty: 120,  unit: 'm²' },
            rangka_atap_baja:  { qty: 75,   unit: 'm²' },
            penutup_atap:      { qty: 75,   unit: 'm²' },
            plafon_gypsum:     { qty: 180,  unit: 'm²' },
            cat_dinding:       { qty: 700,  unit: 'm²' },
            pintu:             { qty: 10,   unit: 'unit' },
            jendela:           { qty: 18,   unit: 'unit' },
            instalasi_listrik: { qty: 1,    unit: 'ls' },
            instalasi_air:     { qty: 1,    unit: 'ls' },
          },
          milestones: [
            { name: 'Kick-off', days: 0 },
            { name: 'Pondasi + Sloof', days: 40 },
            { name: 'Struktur 3 lantai', days: 150 },
            { name: 'Atap + Fasad', days: 200 },
            { name: 'Finishing', days: 270 },
            { name: 'Serah Terima', days: 300 },
          ],
          notes: 'Ruko standar. Perhatikan izin IMB dan GSB sesuai peraturan daerah.'
        ),

        Template.new(
          id:           :gudang,
          name:         'Gudang / Warehouse',
          name_en:      'Warehouse',
          description:  'Gudang industri 1 lantai dengan struktur baja ringan, LB 500 m²',
          icon:         '🏭',
          building_type: :industrial,
          typical_area_m2: 500.0,
          layers: %w[
            Pondasi Sloof Kolom_Beton Balok_Beton
            Lantai_Beton Dinding_Batako Plester
            Rangka_Baja_Ringan Atap_Spandek
            Pintu_Gudang Jendela_Nako
            MEP_Listrik MEP_Drainase
          ],
          default_scenes: %i[denah_lt1 denah_atap tampak_depan tampak_kiri potongan_aa perspektif],
          rab_categories: {
            pembersihan_lahan: { qty: 600,  unit: 'm²' },
            galian_tanah:      { qty: 85,   unit: 'm³' },
            pondasi_batu:      { qty: 45,   unit: 'm³' },
            sloof:             { qty: 6.0,  unit: 'm³' },
            kolom:             { qty: 8.5,  unit: 'm³' },
            balok:             { qty: 5.0,  unit: 'm³' },
            rabat_beton:       { qty: 500,  unit: 'm²' },
            dinding_batako:    { qty: 480,  unit: 'm²' },
            plester:           { qty: 480,  unit: 'm²' },
            rangka_atap_baja:  { qty: 600,  unit: 'm²' },
            penutup_atap:      { qty: 600,  unit: 'm²' },
            pintu:             { qty: 4,    unit: 'unit' },
            jendela:           { qty: 20,   unit: 'unit' },
            instalasi_listrik: { qty: 1,    unit: 'ls' },
            instalasi_air:     { qty: 1,    unit: 'ls' },
          },
          milestones: [
            { name: 'Kick-off', days: 0 },
            { name: 'Pondasi selesai', days: 60 },
            { name: 'Struktur selesai', days: 120 },
            { name: 'Atap selesai', days: 150 },
            { name: 'Finishing + MEP', days: 200 },
            { name: 'Serah Terima', days: 210 },
          ],
          notes: 'Gudang industri. Pastikan tinggi kuda-kuda cukup untuk forklift (min 6m).'
        ),

        Template.new(
          id:           :kantor,
          name:         'Kantor / Office',
          name_en:      'Office Building',
          description:  'Gedung kantor 2 lantai, open plan, LB 200 m² per lantai',
          icon:         '🏢',
          building_type: :office,
          typical_area_m2: 400.0,
          layers: %w[
            Pondasi_Tapak Sloof Kolom Balok Plat_Lt1 Plat_Lt2
            Dinding_Eksterior Dinding_Partisi_Ringan
            Plester_Eksterior Plester_Interior Cat_Eksterior Cat_Interior
            Lantai_Granit_Lobby Lantai_Keramik_Office
            Plafon_Gypsum_Lt1 Plafon_Gypsum_Lt2
            Fasad Jendela_Curtainwall Pintu_Kaca Pintu_Kayu
            MEP_AC MEP_Listrik MEP_Air Tangga
          ],
          default_scenes: %i[denah_lt1 denah_lt2 tampak_depan tampak_belakang tampak_kiri tampak_kanan potongan_aa perspektif],
          rab_categories: {
            galian_tanah:      { qty: 60,   unit: 'm³' },
            pondasi_tapak:     { qty: 12,   unit: 'm³' },
            kolom:             { qty: 18,   unit: 'm³' },
            balok:             { qty: 15,   unit: 'm³' },
            plat_lantai:       { qty: 400,  unit: 'm²' },
            dinding_bata:      { qty: 600,  unit: 'm²' },
            plester:           { qty: 1200, unit: 'm²' },
            lantai_granit:     { qty: 80,   unit: 'm²' },
            lantai_keramik:    { qty: 320,  unit: 'm²' },
            plafon_gypsum:     { qty: 400,  unit: 'm²' },
            cat_dinding:       { qty: 1200, unit: 'm²' },
            pintu:             { qty: 20,   unit: 'unit' },
            jendela:           { qty: 40,   unit: 'unit' },
            tangga:            { qty: 1,    unit: 'unit' },
            ac:                { qty: 20,   unit: 'unit' },
            instalasi_listrik: { qty: 1,    unit: 'ls' },
            instalasi_air:     { qty: 1,    unit: 'ls' },
          },
          milestones: [
            { name: 'Kick-off', days: 0 },
            { name: 'Pondasi + Sloof', days: 60 },
            { name: 'Struktur 2 lantai', days: 150 },
            { name: 'Atap + Fasad', days: 210 },
            { name: 'Finishing + MEP', days: 300 },
            { name: 'Serah Terima', days: 330 },
          ],
          notes: 'Gedung kantor modern. Perhatikan sistem AC central dan fire protection system.'
        ),

        Template.new(
          id:           :villa,
          name:         'Villa / Bungalow',
          name_en:      'Villa / Bungalow',
          description:  'Villa mewah 1 lantai, 3 kamar tidur, kolam renang, LB 180 m²',
          icon:         '🏖️',
          building_type: :residential,
          typical_area_m2: 180.0,
          layers: %w[
            Pondasi Sloof Kolom Balok Plat_Lantai
            Dinding_Bata Plester_Premium
            Lantai_Granit_Interior Lantai_Outdoor
            Atap_Ekspose Plafon_Gypsum Plafon_Ekspose
            Pintu_Solid Jendela_Aluminium Kolam_Renang
            Landscape MEP_Listrik MEP_Air MEP_AC
          ],
          default_scenes: %i[denah_lt1 denah_atap tampak_depan tampak_belakang tampak_kiri tampak_kanan potongan_aa perspektif],
          rab_categories: {
            pembersihan_lahan: { qty: 500,  unit: 'm²' },
            galian_tanah:      { qty: 35,   unit: 'm³' },
            pondasi_tapak:     { qty: 8.0,  unit: 'm³' },
            kolom:             { qty: 6.5,  unit: 'm³' },
            balok:             { qty: 5.5,  unit: 'm³' },
            plat_lantai:       { qty: 180,  unit: 'm²' },
            dinding_bata:      { qty: 380,  unit: 'm²' },
            plester:           { qty: 760,  unit: 'm²' },
            lantai_granit:     { qty: 180,  unit: 'm²' },
            plafon_gypsum:     { qty: 180,  unit: 'm²' },
            cat_dinding:       { qty: 760,  unit: 'm²' },
            pintu:             { qty: 12,   unit: 'unit' },
            jendela:           { qty: 24,   unit: 'unit' },
            ac:                { qty: 6,    unit: 'unit' },
            instalasi_listrik: { qty: 1,    unit: 'ls' },
            instalasi_air:     { qty: 1,    unit: 'ls' },
          },
          milestones: [
            { name: 'Kick-off', days: 0 },
            { name: 'Pondasi selesai', days: 45 },
            { name: 'Struktur selesai', days: 110 },
            { name: 'Atap + Shell selesai', days: 150 },
            { name: 'Finishing premium', days: 240 },
            { name: 'Landscape + Pool', days: 280 },
            { name: 'Serah Terima', days: 300 },
          ],
          notes: 'Villa premium. Gunakan material finishing kelas A. Kolam renang dihitung terpisah.'
        ),

      ].freeze

      # -----------------------------------------------------------------------
      # Public API
      # -----------------------------------------------------------------------

      def self.all
        BUILTIN_TEMPLATES
      end

      def self.find(id)
        BUILTIN_TEMPLATES.find { |t| t.id == id.to_sym }
      end

      def self.for_type(type)
        BUILTIN_TEMPLATES.select { |t| t.building_type == type.to_sym }
      end

      def self.to_json_array
        BUILTIN_TEMPLATES.map do |t|
          {
            id:              t.id,
            name:            t.name,
            name_en:         t.name_en,
            description:     t.description,
            icon:            t.icon,
            building_type:   t.building_type,
            typical_area_m2: t.typical_area_m2,
            notes:           t.notes,
            category_count:  t.rab_categories.size,
            layer_count:     t.layers.size
          }
        end
      end

      # -----------------------------------------------------------------------
      # Apply template to model
      # -----------------------------------------------------------------------
      def self.apply(model, template_id, project_store: nil, settings: nil)
        template = find(template_id)
        raise ArgumentError, "Template '#{template_id}' tidak ditemukan" unless template

        results = { layers: [], scenes: [], milestones: [], categories: [] }

        model.start_operation("RAB Pro: Apply Template #{template.name}", true)

        # 1. Create layers
        template.layers.each do |layer_name|
          unless model.layers[layer_name]
            model.layers.add(layer_name)
            results[:layers] << layer_name
          end
        end

        # 2. Create scenes
        scene_mgr = Drawings::Scenes::SceneManager.new(model)
        created   = scene_mgr.create_standard_scenes(scene_ids: template.default_scenes)
        results[:scenes] = created

        # 3. Set up milestones with dates
        if project_store
          pi         = project_store.project_info&.to_h || {}
          start_date = _parse_date(pi[:start_date]) || Date.today

          milestones = template.milestones.map.with_index(1) do |ms, i|
            planned = (start_date + ms[:days]).strftime('%Y-%m-%d')
            {
              'id'           => "ms#{i}",
              'name'         => ms[:name],
              'planned_date' => planned,
              'actual_date'  => nil,
              'status'       => 'pending'
            }
          end

          dashboard = Dashboard::ProjectDashboard.new(model, project_store: project_store)
          dashboard.save_milestones(milestones)
          results[:milestones] = milestones.map { |m| m['name'] }
        end

        # 4. Pre-tag any entities matching template layer names
        auto_tagger = Core::Tagger::AutoTagger.new(model)
        tag_result  = auto_tagger.run
        results[:categories] = template.rab_categories.keys

        model.commit_operation

        Logger.info("TemplateEngine: applied '#{template.name}' — #{results}")
        { success: true, template: template.name, results: results }

      rescue => e
        model.abort_operation
        Logger.error("TemplateEngine.apply: #{e.message}")
        { success: false, error: e.message }
      end

      def self._parse_date(str)
        return nil if str.nil? || str.to_s.strip.empty?
        Date.parse(str.to_s)
      rescue
        nil
      end

    end
  end
end
