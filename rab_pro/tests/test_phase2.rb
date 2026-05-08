# ==============================================================================
# RAB Pro - Test Suite (Fase 2)
# Run from SketchUp Ruby Console:
#   RABPro::Tests::Phase2.run
# ==============================================================================

module RABPro
  module Tests
    class Phase2

      def self.run
        puts "\n=========================================="
        puts "RAB Pro - Fase 2 Test Suite"
        puts "=========================================="

        passed = 0
        failed = 0

        [
          method(:test_harga_satuan_database),
          method(:test_analisa_computation),
          method(:test_qto_engine_with_model),
          method(:test_rab_calculator_with_model),
          method(:test_excel_exporter),
          method(:test_pdf_exporter),
          method(:test_terbilang),
          method(:test_ai_engine_init),
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

      def self.test_harga_satuan_database
        db = RABPro::RAB::HargaSatuanDatabase
        raise 'empty' if db.all.empty?

        hs = db.find(:kolom)
        raise 'kolom not found'  unless hs
        raise 'wrong unit'       unless hs.unit == 'm³'
        raise 'no koefisien'     if hs.koefisien.empty?

        # Verify price keys exist
        hs.koefisien.each do |k|
          price = db.price_for_item(k[:item])
          raise "Missing price for #{k[:item]}" unless price >= 0
        end

        { name: 'HargaSatuanDatabase', pass: true }
      rescue => e
        { name: 'HargaSatuanDatabase', pass: false, error: e.message }
      end

      def self.test_analisa_computation
        db = RABPro::RAB::HargaSatuanDatabase
        analisa = db.compute_analisa(:kolom, overhead_pct: 15.0, profit_pct: 10.0)

        raise 'no grand_total'   unless analisa[:grand_total] > 0
        raise 'no material'      unless analisa[:material_total] > 0
        raise 'no labor'         unless analisa[:labor_total] > 0
        raise 'no line_items'    if analisa[:line_items].empty?
        raise 'subtotal mismatch' unless (analisa[:subtotal] -
          (analisa[:material_total] + analisa[:labor_total] + analisa[:equipment_total])).abs < 0.01

        { name: 'Analisa Computation', pass: true }
      rescue => e
        { name: 'Analisa Computation', pass: false, error: e.message }
      end

      def self.test_qto_engine_with_model
        model = Sketchup.active_model
        raise 'no model' unless model

        engine = RABPro::RAB::QuantityTakeoffEngine.new(model)
        result = engine.run

        raise 'no items key'   unless result.key?(:items)
        raise 'no summary key' unless result.key?(:summary)
        raise 'no stats key'   unless result.key?(:stats)

        { name: 'QTO Engine (model)', pass: true }
      rescue => e
        { name: 'QTO Engine (model)', pass: false, error: e.message }
      end

      def self.test_rab_calculator_with_model
        model = Sketchup.active_model
        raise 'no model' unless model

        calc = RABPro::RAB::RABCalculator.new(model)
        doc  = calc.generate

        raise 'no sections'    if doc.sections.nil?
        raise 'no grand_total' unless doc.grand_total >= 0
        raise 'no terbilang'   if doc.terbilang.to_s.empty?

        hash = RABPro::RAB::RABCalculator.document_to_hash(doc)
        raise 'hash missing sections'    unless hash.key?(:sections)
        raise 'hash missing grand_total' unless hash.key?(:grand_total)

        { name: 'RAB Calculator (model)', pass: true }
      rescue => e
        { name: 'RAB Calculator (model)', pass: false, error: e.message }
      end

      def self.test_excel_exporter
        # Test CSV fallback (doesn't need write_xlsx gem)
        model  = Sketchup.active_model
        raise 'no model' unless model

        calc   = RABPro::RAB::RABCalculator.new(model)
        doc    = calc.generate
        exp    = RABPro::Export::ExcelExporter.new(doc)

        # Test that class initializes correctly
        raise 'wrong currency' unless exp.instance_variable_get(:@currency).is_a?(String)

        { name: 'ExcelExporter init', pass: true }
      rescue => e
        { name: 'ExcelExporter init', pass: false, error: e.message }
      end

      def self.test_pdf_exporter
        model = Sketchup.active_model
        raise 'no model' unless model

        calc = RABPro::RAB::RABCalculator.new(model)
        doc  = calc.generate
        exp  = RABPro::Export::PDFExporter.new(doc)

        raise 'no currency' unless exp.instance_variable_get(:@currency).is_a?(String)

        { name: 'PDFExporter init', pass: true }
      rescue => e
        { name: 'PDFExporter init', pass: false, error: e.message }
      end

      def self.test_terbilang
        calc = RABPro::RAB::RABCalculator.new(Sketchup.active_model)

        cases = {
          0       => 'nol',
          1       => 'satu',
          11      => 'sebelas',
          100     => 'seratus',
          1000    => 'seribu',
          1_500   => 'seribu lima ratus',
          1_000_000 => 'satu juta',
        }

        cases.each do |n, expected|
          result = calc.send(:_terbilang, n)
          raise "#{n}: expected '#{expected}' in result, got '#{result}'" unless result.include?(expected)
        end

        { name: 'Terbilang conversion', pass: true }
      rescue => e
        { name: 'Terbilang conversion', pass: false, error: e.message }
      end

      def self.test_ai_engine_init
        settings = RABPro::SettingsManager.new
        engine   = RABPro::AI::AIEngine.new(settings)

        raise 'no history method' unless engine.respond_to?(:history)
        raise 'no chat method'    unless engine.respond_to?(:chat)
        raise 'history not array' unless engine.history.is_a?(Array)

        # Test that disabled AI returns graceful message
        settings.set('ai_enabled', false)
        result = engine.chat('test')
        raise 'disabled AI should return content' if result[:content].to_s.empty?
        settings.set('ai_enabled', true)

        { name: 'AIEngine init', pass: true }
      rescue => e
        { name: 'AIEngine init', pass: false, error: e.message }
      end

    end
  end
end
