# ==============================================================================
# RAB Pro - Test Suite (Fase 3)
# Run from SketchUp Ruby Console:
#   RABPro::Tests::Phase3.run
# ==============================================================================

module RABPro
  module Tests
    class Phase3

      def self.run
        puts "\n=========================================="
        puts "RAB Pro - Fase 3 Test Suite"
        puts "=========================================="

        passed = 0
        failed = 0

        [
          method(:test_scene_manager_init),
          method(:test_scene_definitions),
          method(:test_scene_list),
          method(:test_auto_dimensioner_init),
          method(:test_layout_automation_init),
          method(:test_layout_sheet_list),
          method(:test_drawing_register),
          method(:test_export_manager_init),
        ].each do |t|
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

      def self.test_scene_manager_init
        model = Sketchup.active_model
        raise 'no model' unless model
        mgr = RABPro::Drawings::Scenes::SceneManager.new(model)
        raise 'no create_standard_scenes' unless mgr.respond_to?(:create_standard_scenes)
        raise 'no existing_rab_scenes'   unless mgr.respond_to?(:existing_rab_scenes)
        { name: 'SceneManager init', pass: true }
      rescue => e
        { name: 'SceneManager init', pass: false, error: e.message }
      end

      def self.test_scene_definitions
        defs = RABPro::Drawings::Scenes::SceneManager::SCENE_DEFINITIONS
        raise 'empty definitions' if defs.empty?
        raise 'missing denah_lt1'    unless defs.key?(:denah_lt1)
        raise 'missing tampak_depan' unless defs.key?(:tampak_depan)
        raise 'missing potongan_aa'  unless defs.key?(:potongan_aa)
        raise 'missing perspektif'   unless defs.key?(:perspektif)
        defs.each do |id, d|
          raise "#{id} missing name" unless d[:name]
          raise "#{id} missing type" unless d[:type]
        end
        { name: 'Scene definitions', pass: true }
      rescue => e
        { name: 'Scene definitions', pass: false, error: e.message }
      end

      def self.test_scene_list
        list = RABPro::Drawings::Scenes::SceneManager.scene_list
        raise 'empty list'        if list.empty?
        raise 'missing :id key'   unless list.first.key?(:id)
        raise 'missing :name key' unless list.first.key?(:name)
        { name: 'SceneManager.scene_list', pass: true }
      rescue => e
        { name: 'SceneManager.scene_list', pass: false, error: e.message }
      end

      def self.test_auto_dimensioner_init
        model = Sketchup.active_model
        raise 'no model' unless model
        dim = RABPro::Drawings::Annotations::AutoDimensioner.new(model)
        raise 'no auto_dimension_all' unless dim.respond_to?(:auto_dimension_all)
        raise 'no add_elevation_markers' unless dim.respond_to?(:add_elevation_markers)
        { name: 'AutoDimensioner init', pass: true }
      rescue => e
        { name: 'AutoDimensioner init', pass: false, error: e.message }
      end

      def self.test_layout_automation_init
        model = Sketchup.active_model
        raise 'no model' unless model
        la = RABPro::Drawings::Layout::LayoutAutomation.new(model)
        raise 'no generate method'        unless la.respond_to?(:generate)
        raise 'no export_scene_png method' unless la.respond_to?(:export_scene_png)
        { name: 'LayoutAutomation init', pass: true }
      rescue => e
        { name: 'LayoutAutomation init', pass: false, error: e.message }
      end

      def self.test_layout_sheet_list
        list = RABPro::Drawings::Layout::LayoutAutomation.sheet_list
        raise 'empty sheet list'      if list.empty?
        raise 'missing :id'           unless list.first.key?(:id)
        raise 'missing :title'        unless list.first.key?(:title)
        raise 'missing :description'  unless list.first.key?(:description)

        # Cover sheet must be first
        raise 'cover not first' unless list.first[:id] == :cover
        { name: 'LayoutAutomation sheet_list', pass: true }
      rescue => e
        { name: 'LayoutAutomation sheet_list', pass: false, error: e.message }
      end

      def self.test_drawing_register
        model = Sketchup.active_model
        raise 'no model' unless model

        reg = RABPro::Drawings::DrawingRegister.new(model)
        raise 'no add method'    unless reg.respond_to?(:add)
        raise 'no all method'    unless reg.respond_to?(:all)
        raise 'no to_table method' unless reg.respond_to?(:to_table)

        # DISCIPLINES must have expected keys
        disc = RABPro::Drawings::DrawingRegister::DISCIPLINES
        raise 'missing architecture' unless disc.key?(:architecture)
        raise 'missing structure'    unless disc.key?(:structure)

        { name: 'DrawingRegister', pass: true }
      rescue => e
        { name: 'DrawingRegister', pass: false, error: e.message }
      end

      def self.test_export_manager_init
        model = Sketchup.active_model
        raise 'no model' unless model

        exp = RABPro::Drawings::DrawingExportManager.new(model)
        raise 'no export_all'         unless exp.respond_to?(:export_all)
        raise 'no batch_export_scenes' unless exp.respond_to?(:batch_export_scenes)
        raise 'SUPPORTED_FORMATS missing pdf' unless RABPro::Drawings::DrawingExportManager::SUPPORTED_FORMATS.include?(:pdf)
        raise 'SUPPORTED_FORMATS missing dwg' unless RABPro::Drawings::DrawingExportManager::SUPPORTED_FORMATS.include?(:dwg)

        { name: 'DrawingExportManager init', pass: true }
      rescue => e
        { name: 'DrawingExportManager init', pass: false, error: e.message }
      end

    end
  end
end
