# ==============================================================================
# RAB Pro - Test Suite (Fase 4)
# Run from SketchUp Ruby Console:
#   RABPro::Tests::Phase4.run
# ==============================================================================

module RABPro
  module Tests
    class Phase4

      def self.run
        puts "\n=========================================="
        puts "RAB Pro - Fase 4 Test Suite"
        puts "=========================================="

        passed = 0
        failed = 0

        [
          method(:test_chat_manager_init),
          method(:test_chat_disabled),
          method(:test_chat_no_key),
          method(:test_chat_history_management),
          method(:test_context_summary),
          method(:test_dashboard_init),
          method(:test_dashboard_snapshot),
          method(:test_progress_entry),
          method(:test_milestone_defaults),
          method(:test_template_engine_all),
          method(:test_template_find),
          method(:test_template_categories),
          method(:test_cloud_sync_init),
          method(:test_snapshot_serialization),
          method(:test_comment_system),
          method(:test_share_report_generation),
          method(:test_json_export_import),
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
            puts "     #{e.backtrace.first}"
            failed += 1
          end
        end

        puts "------------------------------------------"
        puts "Results: #{passed} passed, #{failed} failed"
        puts "==========================================\n"
        { passed: passed, failed: failed }
      end

      # ---- ChatManager tests -------------------------------------------------

      def self.test_chat_manager_init
        model    = Sketchup.active_model
        settings = RABPro::SettingsManager.new
        store    = RABPro::ProjectStore.new(settings)
        store.attach(model)

        mgr = RABPro::AI::Chat::ChatManager.new(model, settings: settings, project_store: store)
        raise 'no send method'            unless mgr.respond_to?(:send)
        raise 'no history method'         unless mgr.respond_to?(:history)
        raise 'no clear_history method'   unless mgr.respond_to?(:clear_history)
        raise 'no parse_model_command'    unless mgr.respond_to?(:parse_model_command)
        raise 'history not array'         unless mgr.history.is_a?(Array)

        { name: 'ChatManager init', pass: true }
      rescue => e
        { name: 'ChatManager init', pass: false, error: e.message }
      end

      def self.test_chat_disabled
        model    = Sketchup.active_model
        settings = RABPro::SettingsManager.new
        settings.set('ai_enabled', false)
        store    = RABPro::ProjectStore.new(settings)
        store.attach(model)

        mgr    = RABPro::AI::Chat::ChatManager.new(model, settings: settings, project_store: store)
        result = mgr.send('test')

        raise 'should return content when disabled' if result[:content].to_s.empty?
        raise 'should not be success'              if result[:success]

        settings.set('ai_enabled', true)
        { name: 'ChatManager disabled graceful', pass: true }
      rescue => e
        { name: 'ChatManager disabled graceful', pass: false, error: e.message }
      end

      def self.test_chat_no_key
        model    = Sketchup.active_model
        settings = RABPro::SettingsManager.new
        settings.set('ai_enabled', true)
        # Don't set api key — simulate missing key scenario
        store    = RABPro::ProjectStore.new(settings)
        store.attach(model)

        # Force no key by checking response format
        mgr    = RABPro::AI::Chat::ChatManager.new(model, settings: settings, project_store: store)
        result = mgr.send('test')

        # Result should always be a hash with :content key
        raise 'result missing :content' unless result.key?(:content)
        raise 'result missing :role'    unless result.key?(:role)

        { name: 'ChatManager no-key graceful', pass: true }
      rescue => e
        { name: 'ChatManager no-key graceful', pass: false, error: e.message }
      end

      def self.test_chat_history_management
        model    = Sketchup.active_model
        settings = RABPro::SettingsManager.new
        settings.set('ai_enabled', false)   # prevent real API calls
        store    = RABPro::ProjectStore.new(settings)
        store.attach(model)

        mgr = RABPro::AI::Chat::ChatManager.new(model, settings: settings, project_store: store)

        initial_count = mgr.history_count
        mgr.clear_history
        raise 'clear_history should empty history' unless mgr.history.empty?
        raise 'history_count should be 0'          unless mgr.history_count == 0

        { name: 'ChatManager history management', pass: true }
      rescue => e
        { name: 'ChatManager history management', pass: false, error: e.message }
      end

      def self.test_context_summary
        model    = Sketchup.active_model
        settings = RABPro::SettingsManager.new
        settings.set('ai_enabled', false)
        store    = RABPro::ProjectStore.new(settings)
        store.attach(model)

        mgr     = RABPro::AI::Chat::ChatManager.new(model, settings: settings, project_store: store)
        summary = mgr.build_model_context_summary

        raise 'summary should be a string' unless summary.is_a?(String)

        { name: 'ChatManager context summary', pass: true }
      rescue => e
        { name: 'ChatManager context summary', pass: false, error: e.message }
      end

      # ---- Dashboard tests ---------------------------------------------------

      def self.test_dashboard_init
        model = Sketchup.active_model
        raise 'no model' unless model

        db = RABPro::Dashboard::ProjectDashboard.new(model)
        raise 'no snapshot method'                unless db.respond_to?(:snapshot)
        raise 'no load_progress method'           unless db.respond_to?(:load_progress)
        raise 'no update_progress method'         unless db.respond_to?(:update_progress)
        raise 'no load_milestones method'         unless db.respond_to?(:load_milestones)
        raise 'no initialize_progress_from_rab'   unless db.respond_to?(:initialize_progress_from_rab)

        { name: 'ProjectDashboard init', pass: true }
      rescue => e
        { name: 'ProjectDashboard init', pass: false, error: e.message }
      end

      def self.test_dashboard_snapshot
        model = Sketchup.active_model
        raise 'no model' unless model

        db   = RABPro::Dashboard::ProjectDashboard.new(model)
        snap = db.snapshot

        raise 'snapshot missing :budget_total'  unless snap.key?(:budget_total)
        raise 'snapshot missing :overall_pct'   unless snap.key?(:overall_pct)
        raise 'snapshot missing :milestones'    unless snap.key?(:milestones)
        raise 'snapshot missing :scurve'        unless snap.key?(:scurve)
        raise 'snapshot missing :alerts'        unless snap.key?(:alerts)
        raise 'snapshot missing :bom'           unless snap.key?(:bom)

        { name: 'Dashboard snapshot structure', pass: true }
      rescue => e
        { name: 'Dashboard snapshot structure', pass: false, error: e.message }
      end

      def self.test_progress_entry
        model = Sketchup.active_model
        db    = RABPro::Dashboard::ProjectDashboard.new(model)
        entry = db.update_progress(:kolom, actual_qty: 2.5, actual_cost: 500.0, pct_complete: 50.0)

        raise 'entry should be ProgressEntry'      unless entry.is_a?(RABPro::Dashboard::ProjectDashboard::ProgressEntry)
        raise 'wrong actual_qty'                   unless entry.actual_qty == 2.5
        raise 'wrong actual_cost'                  unless entry.actual_cost == 500.0
        raise 'wrong pct_complete'                 unless entry.pct_complete == 50.0
        raise 'pct_complete not clamped correctly' if entry.pct_complete > 100

        { name: 'Dashboard progress entry', pass: true }
      rescue => e
        { name: 'Dashboard progress entry', pass: false, error: e.message }
      end

      def self.test_milestone_defaults
        model = Sketchup.active_model
        db    = RABPro::Dashboard::ProjectDashboard.new(model)
        ms    = db.load_milestones

        raise 'should have milestones'             if ms.empty?
        raise 'milestones should be array'         unless ms.is_a?(Array)
        raise 'first milestone missing id'         unless ms.first.respond_to?(:id)
        raise 'first milestone missing name'       unless ms.first.respond_to?(:name)
        raise 'first milestone missing status'     unless ms.first.respond_to?(:status)

        { name: 'Dashboard milestone defaults', pass: true }
      rescue => e
        { name: 'Dashboard milestone defaults', pass: false, error: e.message }
      end

      # ---- Template tests ----------------------------------------------------

      def self.test_template_engine_all
        templates = RABPro::Templates::TemplateEngine.all
        raise 'no templates'          if templates.empty?
        raise 'expected >= 5'         if templates.size < 5

        json = RABPro::Templates::TemplateEngine.to_json_array
        raise 'json empty'            if json.empty?
        raise 'json missing :icon'    unless json.first.key?(:icon)
        raise 'json missing :name'    unless json.first.key?(:name)

        { name: 'TemplateEngine all templates', pass: true }
      rescue => e
        { name: 'TemplateEngine all templates', pass: false, error: e.message }
      end

      def self.test_template_find
        tmpl = RABPro::Templates::TemplateEngine.find(:rumah_type_36)
        raise 'rumah_type_36 not found'     unless tmpl
        raise 'wrong building_type'         unless tmpl.building_type == :residential
        raise 'no layers'                   if tmpl.layers.empty?
        raise 'no rab_categories'           if tmpl.rab_categories.empty?
        raise 'no default_scenes'           if tmpl.default_scenes.empty?
        raise 'no milestones'               if tmpl.milestones.empty?

        nil_tmpl = RABPro::Templates::TemplateEngine.find(:nonexistent)
        raise 'should return nil for unknown' unless nil_tmpl.nil?

        { name: 'TemplateEngine find', pass: true }
      rescue => e
        { name: 'TemplateEngine find', pass: false, error: e.message }
      end

      def self.test_template_categories
        tmpl = RABPro::Templates::TemplateEngine.find(:gudang)
        raise 'gudang not found' unless tmpl

        # All category ids in template must exist in CategoryLibrary
        unknown = tmpl.rab_categories.keys.reject do |k|
          RABPro::Data::CategoryLibrary.find(k)
        end

        raise "Unknown categories in gudang template: #{unknown.join(', ')}" unless unknown.empty?
        raise 'gudang wrong building type' unless tmpl.building_type == :industrial

        { name: 'Template categories valid', pass: true }
      rescue => e
        { name: 'Template categories valid', pass: false, error: e.message }
      end

      # ---- CloudSync tests ---------------------------------------------------

      def self.test_cloud_sync_init
        model    = Sketchup.active_model
        settings = RABPro::SettingsManager.new
        store    = RABPro::ProjectStore.new(settings)
        store.attach(model)

        sync = RABPro::Collaboration::CloudSync.new(model, project_store: store, settings: settings)

        raise 'no create_snapshot'           unless sync.respond_to?(:create_snapshot)
        raise 'no export_json'               unless sync.respond_to?(:export_json)
        raise 'no import_json'               unless sync.respond_to?(:import_json)
        raise 'no generate_share_report'     unless sync.respond_to?(:generate_share_report)
        raise 'no add_comment'               unless sync.respond_to?(:add_comment)
        raise 'no load_comments'             unless sync.respond_to?(:load_comments)

        { name: 'CloudSync init', pass: true }
      rescue => e
        { name: 'CloudSync init', pass: false, error: e.message }
      end

      def self.test_snapshot_serialization
        model    = Sketchup.active_model
        settings = RABPro::SettingsManager.new
        store    = RABPro::ProjectStore.new(settings)
        store.attach(model)

        sync = RABPro::Collaboration::CloudSync.new(model, project_store: store, settings: settings)
        snap = sync.create_snapshot(label: 'Test Snapshot')

        raise 'snapshot missing id'         unless snap.id
        raise 'snapshot missing label'      unless snap.label == 'Test Snapshot'
        raise 'snapshot missing created_at' unless snap.created_at

        # Load back
        snaps = sync.load_snapshots
        raise 'loaded snapshots empty' if snaps.empty?
        found = snaps.find { |s| s.label == 'Test Snapshot' }
        raise 'snapshot not persisted' unless found

        { name: 'Snapshot serialization', pass: true }
      rescue => e
        { name: 'Snapshot serialization', pass: false, error: e.message }
      end

      def self.test_comment_system
        model    = Sketchup.active_model
        settings = RABPro::SettingsManager.new
        store    = RABPro::ProjectStore.new(settings)
        store.attach(model)

        sync = RABPro::Collaboration::CloudSync.new(model, project_store: store, settings: settings)

        cmt = sync.add_comment(author: 'Tester', text: 'Test comment dari Phase4 suite')
        raise 'comment missing id'     unless cmt.id
        raise 'comment wrong author'   unless cmt.author == 'Tester'
        raise 'comment already resolved' if cmt.resolved

        # Resolve it
        sync.resolve_comment(cmt.id)
        loaded = sync.load_comments.find { |c| c.id == cmt.id }
        raise 'comment not found after resolve' unless loaded
        raise 'comment should be resolved'      unless loaded.resolved

        { name: 'Comment system', pass: true }
      rescue => e
        { name: 'Comment system', pass: false, error: e.message }
      end

      def self.test_share_report_generation
        model    = Sketchup.active_model
        settings = RABPro::SettingsManager.new
        store    = RABPro::ProjectStore.new(settings)
        store.attach(model)

        sync   = RABPro::Collaboration::CloudSync.new(model, project_store: store, settings: settings)
        tmpdir = Dir.tmpdir
        path   = File.join(tmpdir, 'rab_pro_test_report.html')

        result = sync.generate_share_report(path)
        raise 'report generation failed' unless result[:success]
        raise 'file not created'         unless File.exist?(path)
        raise 'file is empty'            if File.size(path) < 100

        content = File.read(path)
        raise 'missing DOCTYPE'          unless content.include?('DOCTYPE html')
        raise 'missing RAB Pro title'    unless content.include?('RAB Pro')

        File.delete(path) rescue nil
        { name: 'Share report generation', pass: true }
      rescue => e
        { name: 'Share report generation', pass: false, error: e.message }
      end

      def self.test_json_export_import
        model    = Sketchup.active_model
        settings = RABPro::SettingsManager.new
        store    = RABPro::ProjectStore.new(settings)
        store.attach(model)

        sync   = RABPro::Collaboration::CloudSync.new(model, project_store: store, settings: settings)
        tmpdir = Dir.tmpdir
        path   = File.join(tmpdir, 'rab_pro_test_export.json')

        # Export
        exp_result = sync.export_json(path)
        raise 'export failed'        unless exp_result[:success]
        raise 'file not created'     unless File.exist?(path)

        # Validate JSON structure
        data = JSON.parse(File.read(path))
        raise 'missing export_info'  unless data.key?('export_info')
        raise 'wrong format string'  unless data.dig('export_info', 'format') == 'rab_pro_project_v1'
        raise 'missing version'      unless data.dig('export_info', 'version')

        # Import
        imp_result = sync.import_json(path)
        raise 'import failed'        unless imp_result[:success]

        File.delete(path) rescue nil
        { name: 'JSON export/import roundtrip', pass: true }
      rescue => e
        { name: 'JSON export/import roundtrip', pass: false, error: e.message }
      end

    end
  end
end
