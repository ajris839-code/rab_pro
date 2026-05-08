# ==============================================================================
# RAB Pro - Master Test Runner
# Runs all 4 phase test suites and produces a consolidated report.
#
# Usage (SketchUp Ruby Console):
#   RABPro::Tests::All.run
#   RABPro::Tests::All.run(phases: [1, 2])   # run specific phases only
# ==============================================================================

module RABPro
  module Tests
    class All

      def self.run(phases: [1, 2, 3, 4])
        puts "\n" + ('=' * 52)
        puts "  RAB Pro — MASTER TEST RUNNER"
        puts "  #{Time.now.strftime('%d %B %Y %H:%M:%S')}"
        puts ('=' * 52)

        grand_passed = 0
        grand_failed = 0
        timings      = {}

        suite_map = {
          1 => { klass: Phase1, file: 'test_phase1' },
          2 => { klass: Phase2, file: 'test_phase2' },
          3 => { klass: Phase3, file: 'test_phase3' },
          4 => { klass: Phase4, file: 'test_phase4' }
        }

        phases.each do |phase_no|
          entry = suite_map[phase_no]
          next unless entry

          # Require if not already loaded
          begin
            require File.join(RABPro::EXTENSION_ROOT, 'tests', "#{entry[:file]}.rb")
          rescue LoadError => e
            puts "\n  ⚠️ Could not load #{entry[:file]}: #{e.message}"
            next
          end

          t0     = Time.now
          result = entry[:klass].run
          elapsed = Time.now - t0

          grand_passed += result[:passed]
          grand_failed += result[:failed]
          timings[phase_no] = elapsed.round(2)
        end

        # Summary
        puts "\n" + ('=' * 52)
        puts "  GRAND TOTAL"
        puts ('=' * 52)
        timings.each { |p, t| puts "  Fase #{p}: #{t}s" }
        puts ('-' * 52)
        puts "  ✅ Passed : #{grand_passed}"
        puts "  ❌ Failed : #{grand_failed}"
        puts "  📊 Total  : #{grand_passed + grand_failed}"

        success = grand_failed == 0
        puts "\n  #{success ? '🎉 ALL TESTS PASSED!' : '⚠️  SOME TESTS FAILED'}"
        puts ('=' * 52) + "\n"

        { passed: grand_passed, failed: grand_failed, success: success }
      end

    end
  end
end
