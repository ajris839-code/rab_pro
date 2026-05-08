# ==============================================================================
# RAB Pro - Test Suite (Fase 1)
# Run from SketchUp Ruby Console:
#   RABPro::Tests::Phase1.run
# ==============================================================================

module RABPro
  module Tests
    class Phase1

      def self.run
        puts "\n=========================================="
        puts "RAB Pro - Fase 1 Test Suite"
        puts "=========================================="

        passed = 0
        failed = 0

        tests = [
          method(:test_logger),
          method(:test_unit_converter),
          method(:test_string_helper),
          method(:test_category_library),
          method(:test_material_database),
          method(:test_settings_manager),
          method(:test_tag_engine_with_model),
          method(:test_geometry_helper_with_model),
          method(:test_component_tree_with_model),
          method(:test_auto_tagger_with_model)
        ]

        tests.each do |t|
          begin
            result = t.call
            if result[:pass]
              puts "  ✅ #{result[:name]}"
              passed += 1
            else
              puts "  ❌ #{result[:name]}: #{result[:error]}"
              failed += 1
            end
          rescue => e
            puts "  💥 #{t.name}: EXCEPTION — #{e.message}"
            failed += 1
          end
        end

        puts "------------------------------------------"
        puts "Results: #{passed} passed, #{failed} failed"
        puts "==========================================\n"
        { passed: passed, failed: failed }
      end

      # ---- Individual tests -----------------------------------------------

      def self.test_logger
        RABPro::Logger.info('Test log message')
        RABPro::Logger.debug('Debug message')
        { name: 'Logger', pass: true }
      rescue => e
        { name: 'Logger', pass: false, error: e.message }
      end

      def self.test_unit_converter
        c = RABPro::UnitConverter
        assert_close(c.inches_to_m(39.3701), 1.0, 'inch→m')
        assert_close(c.sq_inches_to_m2(1550.0031), 1.0, 'm²', tol: 0.01)
        { name: 'UnitConverter', pass: true }
      rescue => e
        { name: 'UnitConverter', pass: false, error: e.message }
      end

      def self.test_string_helper
        s = RABPro::StringHelper
        raise 'normalize failed' unless s.normalize('Dinding Bata') == 'dinding bata'
        raise 'humanize failed'  unless s.humanize('dinding_bata') == 'Dinding Bata'
        raise 'matches failed'   unless s.matches_any?('dinding_bata_merah', ['*bata*'])
        raise 'no match failed'  if     s.matches_any?('kolom', ['*bata*'])
        { name: 'StringHelper', pass: true }
      rescue => e
        { name: 'StringHelper', pass: false, error: e.message }
      end

      def self.test_category_library
        lib = RABPro::Data::CategoryLibrary
        raise 'empty library' if lib.all.empty?

        cat = lib.find(:kolom)
        raise 'kolom not found'       unless cat
        raise 'kolom wrong unit'      unless cat.unit == 'm³'
        raise 'kolom wrong qty type'  unless cat.quantity_type == :volume

        dinding = lib.find(:dinding_bata)
        raise 'dinding not found'     unless dinding
        raise 'dinding wrong unit'    unless dinding.unit == 'm²'

        groups = lib.groups
        raise 'no groups'             if groups.empty?

        json = lib.to_json_array
        raise 'json empty'            if json.empty?
        raise 'json missing keys'     unless json.first.key?(:ifc_class)

        { name: 'CategoryLibrary', pass: true }
      rescue => e
        { name: 'CategoryLibrary', pass: false, error: e.message }
      end

      def self.test_material_database
        db = RABPro::Data::MaterialDatabase
        raise 'empty DB'     if db.all.empty?

        semen = db.find(:semen_portland)
        raise 'semen not found'    unless semen
        raise 'semen wrong price'  unless semen.base_price > 0

        conc = db.for_category(:concrete)
        raise 'no concrete mats'   if conc.empty?

        json = db.to_json_array
        raise 'json empty'         if json.empty?

        { name: 'MaterialDatabase', pass: true }
      rescue => e
        { name: 'MaterialDatabase', pass: false, error: e.message }
      end

      def self.test_settings_manager
        sm = RABPro::SettingsManager.new
        raise 'currency wrong default' unless sm.currency.is_a?(String)
        raise 'ai_model empty' if sm.ai_model.to_s.empty?

        hash = sm.to_hash
        raise 'to_hash empty' if hash.empty?

        { name: 'SettingsManager', pass: true }
      rescue => e
        { name: 'SettingsManager', pass: false, error: e.message }
      end

      def self.test_tag_engine_with_model
        model = Sketchup.active_model
        raise 'No active model' unless model

        te = RABPro::Core::Tagger::TagEngine
        stats = te.stats(model)
        raise 'stats not a hash' unless stats.is_a?(Hash)

        { name: 'TagEngine (model)', pass: true }
      rescue => e
        { name: 'TagEngine (model)', pass: false, error: e.message }
      end

      def self.test_geometry_helper_with_model
        model = Sketchup.active_model
        raise 'No active model' unless model

        # Test on first component or group found
        entity = model.entities.find { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }
        if entity
          vol  = RABPro::GeometryHelper.bounding_box_volume_m3(entity)
          area = RABPro::GeometryHelper.total_surface_area_m2(entity)
          dims = RABPro::GeometryHelper.dimensions_m(entity)
          raise 'vol < 0'   if vol < 0
          raise 'area < 0'  if area < 0
          raise 'dims empty' unless dims.key?(:width)
        end

        { name: 'GeometryHelper (model)', pass: true }
      rescue => e
        { name: 'GeometryHelper (model)', pass: false, error: e.message }
      end

      def self.test_component_tree_with_model
        model = Sketchup.active_model
        raise 'No active model' unless model

        tree = RABPro::Core::Inspector::ComponentTree.new(model).build
        raise 'tree missing id'       unless tree.key?(:id)
        raise 'tree missing children' unless tree.key?(:children)

        { name: 'ComponentTree (model)', pass: true }
      rescue => e
        { name: 'ComponentTree (model)', pass: false, error: e.message }
      end

      def self.test_auto_tagger_with_model
        model = Sketchup.active_model
        raise 'No active model' unless model

        tagger = RABPro::Core::Tagger::AutoTagger.new(model)
        # Just verify it initializes and class responds correctly
        raise 'no run method' unless tagger.respond_to?(:run)

        { name: 'AutoTagger (model)', pass: true }
      rescue => e
        { name: 'AutoTagger (model)', pass: false, error: e.message }
      end

      # ---- Assertion helpers -----------------------------------------------

      def self.assert_close(actual, expected, label, tol: 0.001)
        raise "#{label}: expected #{expected}, got #{actual}" unless (actual - expected).abs < tol
      end

    end
  end
end
