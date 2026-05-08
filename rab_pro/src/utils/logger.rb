# ==============================================================================
# RAB Pro - Logger
# Thread-safe, levelled logger that writes to SketchUp Ruby Console
# and optionally to a rotating log file on disk.
# ==============================================================================

module RABPro
  class Logger

    LEVELS = { debug: 0, info: 1, warn: 2, error: 3 }.freeze

    class << self
      def debug(msg) = log(:debug, msg)
      def info(msg)  = log(:info,  msg)
      def warn(msg)  = log(:warn,  msg)
      def error(msg) = log(:error, msg)

      def level=(lvl)
        @level = LEVELS.fetch(lvl.to_sym, 1)
      end

      def log(level, msg)
        return if LEVELS[level] < current_level

        timestamp = Time.now.strftime('%H:%M:%S.%L')
        prefix    = "[RABPro][#{level.to_s.upcase}][#{timestamp}]"
        line      = "#{prefix} #{msg}"

        puts line          # SketchUp Ruby Console
        write_to_file(line) if file_logging_enabled?
      end

      private

      def current_level
        @level ||= (Sketchup.version.to_i >= 21 ? LEVELS[:info] : LEVELS[:debug])
      end

      def file_logging_enabled?
        @file_logging ||= false
      end

      def log_file_path
        @log_file_path ||= begin
          base_dir = if ENV['APPDATA']  # Windows
                       File.join(ENV['APPDATA'], 'RABPro', 'logs')
                     else  # macOS/Linux
                       File.join(Dir.home, '.rab_pro', 'logs')
                     end
          
          # Ensure directory exists
          FileUtils.mkdir_p(base_dir) unless Dir.exist?(base_dir)
          File.join(base_dir, "rab_pro_#{Date.today}.log")
        end
      end

      def write_to_file(line)
        begin
          File.open(log_file_path, 'a') { |f| f.puts(line) }
        rescue => e
          puts "[RABPro][WARN] Could not write to log file: #{e.message}"
        end
      end
    end

  end
end
