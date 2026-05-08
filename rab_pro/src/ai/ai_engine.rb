# ==============================================================================
# RAB Pro - AI Engine
# Integrates Grok API (X.ai) for cost estimation, analysis, and suggestions
# Supports multi-provider pattern for extensibility (Grok, OpenAI, Anthropic)
# ==============================================================================

require 'net/http'
require 'json'
require 'uri'
require 'time'

module RABPro
  module AI
    class AIEngine

      # =========================================================================
      # PROVIDER CONFIGURATION
      # =========================================================================
      
      PROVIDERS = {
        grok: {
          url:         'https://api.x.ai/v1/chat/completions',
          model:       'grok-beta',
          format:      :openai,  # OpenAI-compatible format
          env_key:     'GROK_API_KEY',
          description: 'Grok AI (X.com) - Free for development'
        },
        openai: {
          url:         'https://api.openai.com/v1/chat/completions',
          model:       'gpt-4-mini',
          format:      :openai,
          env_key:     'OPENAI_API_KEY',
          description: 'OpenAI GPT-4 Mini'
        },
        anthropic: {
          url:         'https://api.anthropic.com/v1/messages',
          model:       'claude-sonnet-4-20250514',
          format:      :anthropic,
          env_key:     'ANTHROPIC_API_KEY',
          description: 'Anthropic Claude Sonnet'
        }
      }.freeze

      DEFAULT_PROVIDER = :grok
      MAX_TOKENS = 2048
      RATE_LIMIT_WINDOW = 60  # seconds
      MAX_REQUESTS_PER_MINUTE = 10
      HISTORY_MAX_SIZE = 20

      SYSTEM_PROMPT = <<~PROMPT.freeze
        Anda adalah AI assistant RAB Pro, ahli estimasi biaya konstruksi dan quantity surveying
        untuk proyek di Brunei Darussalam dan Asia Tenggara.

        Kemampuan Anda:
        - Analisis Rencana Anggaran Biaya (RAB) dan quantity takeoff
        - Estimasi biaya konstruksi berdasarkan SNI dan standar lokal
        - Saran value engineering untuk efisiensi biaya
        - Deteksi anomali dalam volume, harga satuan, atau total biaya
        - Rekomendasi material dan metode konstruksi
        - Interpretasi data geometri dari model SketchUp

        Format respons:
        - Gunakan bahasa Indonesia yang profesional namun mudah dipahami
        - Sertakan angka dan perhitungan yang spesifik jika relevan
        - Berikan saran yang actionable dan prioritas
        - Mata uang default: BND (Brunei Dollar)

        Jika ditanya tentang model SketchUp, gunakan data konteks yang disediakan.
      PROMPT

      # =========================================================================
      # INITIALIZATION
      # =========================================================================

      def initialize(settings)
        @settings = settings
        @provider = (settings.ai_provider || DEFAULT_PROVIDER).to_sym
        @api_key = _load_api_key
        @history = []
        @request_times = []  # For rate limiting
        
        Logger.info("AIEngine: initialized with provider=#{@provider}")
      end

      # =========================================================================
      # PUBLIC API
      # =========================================================================

      # Chat — send a message with full model context
      # Returns { role: 'assistant', content: '...', tokens_used: N, provider: :grok }
      def chat(message, model_context: nil, rab_context: nil)
        unless @settings.ai_enabled?
          return { 
            role: 'assistant', 
            content: 'AI Assistant dinonaktifkan. Aktifkan di Pengaturan.', 
            tokens_used: 0,
            provider: @provider
          }
        end

        unless @api_key
          return { 
            role: 'assistant', 
            content: _no_api_key_message, 
            tokens_used: 0,
            provider: @provider
          }
        end

        # Check rate limiting
        unless _check_rate_limit
          return {
            role: 'assistant',
            content: 'Terlalu banyak permintaan. Tunggu beberapa detik sebelum mencoba lagi.',
            tokens_used: 0,
            provider: @provider
          }
        end

        # Build enriched message with context
        enriched = _build_enriched_message(message, model_context, rab_context)

        # Add to history
        @history << { role: 'user', content: enriched }

        # Trim history to maintain memory
        @history = @history.last(HISTORY_MAX_SIZE)

        response = _call_api(@history)

        if response[:success]
          assistant_msg = response[:content]
          @history << { role: 'assistant', content: assistant_msg }
          {
            role:        'assistant',
            content:     assistant_msg,
            tokens_used: response[:tokens_used],
            provider:    @provider
          }
        else
          {
            role:        'assistant',
            content:     "Error: #{response[:error]}",
            tokens_used: 0,
            provider:    @provider
          }
        end
      end

      # Analyze RAB document — returns structured insights
      def analyze_rab(rab_document)
        return nil unless rab_document

        doc_hash = RAB::RABCalculator.document_to_hash(rab_document)
        summary = _rab_summary_for_ai(doc_hash)

        prompt = <<~P
          Analisis RAB berikut dan berikan:
          1. Evaluasi kewajaran biaya per kategori pekerjaan
          2. Identifikasi 3 item dengan biaya tertinggi dan rekomendasi efisiensi
          3. Peringatan jika ada nilai yang tidak wajar
          4. Estimasi total biaya per m² (jika luas bangunan tersedia)
          5. Saran value engineering spesifik

          DATA RAB:
          #{summary}
        P

        result = chat(prompt)
        {
          analysis:    result[:content],
          tokens_used: result[:tokens_used],
          provider:    result[:provider],
          generated_at: Time.now.iso8601
        }
      end

      # Generate cost estimate from model summary (before full RAB)
      def quick_estimate(model_summary, tagged_count)
        prompt = <<~P
          Berikan estimasi biaya kasar berdasarkan data model SketchUp berikut.
          #{tagged_count} entitas telah di-tag dengan kategori pekerjaan.

          Data model:
          #{begin; JSON.pretty_generate(model_summary.is_a?(Hash) ? model_summary.select{|k,_| [:summary,:stats].include?(k)} : model_summary); rescue; model_summary.to_s; end}

          Berikan:
          1. Estimasi biaya konstruksi kasar (range)
          2. Asumsi yang digunakan
          3. Faktor risiko yang perlu diperhatikan
          4. Rekomendasi langkah selanjutnya
        P

        chat(prompt)
      end

      # Value engineering suggestions for a specific work item
      def suggest_alternatives(category_name, unit_price, quantity, unit)
        prompt = <<~P
          Untuk pekerjaan "#{category_name}" dengan:
          - Volume: #{quantity} #{unit}
          - Harga satuan: #{unit_price} BND/#{unit}
          - Total: #{(quantity.to_f * unit_price.to_f).round(2)} BND

          Berikan:
          1. Alternatif material/metode yang bisa mengurangi biaya
          2. Estimasi penghematan potensial (%)
          3. Trade-off kualitas vs biaya
          4. Rekomendasi untuk konteks Brunei Darussalam
        P

        chat(prompt)
      end

      # Detect anomalies in QTO results
      def detect_anomalies(qto_summary)
        prompt = <<~P
          Periksa hasil quantity takeoff berikut untuk anomali.
          Identifikasi item yang volume atau harganya tidak wajar:

          #{qto_summary.values.map { |s|
            "#{s[:category_code]} #{s[:category_name]}: #{s[:total_quantity]} #{s[:unit]}"
          }.join("\n")}

          Tandai:
          1. Volume yang terlalu besar atau terlalu kecil untuk tipe pekerjaan
          2. Satuan yang mungkin salah kategori
          3. Item yang mungkin terhitung ganda
        P

        chat(prompt)
      end

      # Natural language model command
      def parse_model_command(text, model_context)
        prompt = <<~P
          Pengguna mengetik perintah natural language untuk SketchUp model:
          "#{text}"

          Konteks model: #{model_context[:summary][:entity_count]} entitas,
          #{model_context[:summary][:layers]} layer.

          Interpretasikan perintah dan jelaskan dalam 1-2 kalimat apa yang akan dilakukan,
          lalu berikan respons yang membantu pengguna.
          Jika perintah tidak jelas, minta klarifikasi.
        P

        chat(prompt, model_context: model_context)
      end

      # Reset conversation history
      def reset_history
        @history = []
        Logger.info('AIEngine: conversation history cleared')
      end

      # Provider management
      def provider; @provider end
      def history; @history end
      def switch_provider(name)
        new_provider = name.to_sym
        unless PROVIDERS.key?(new_provider)
          raise "Unknown provider: #{new_provider}. Available: #{PROVIDERS.keys.join(', ')}"
        end
        @provider = new_provider
        @api_key = _load_api_key
        Logger.info("AIEngine: switched to provider=#{@provider}")
      end

      def providers_info
        PROVIDERS.map { |k, v| "#{k}: #{v[:description]}" }.join("\n")
      end

      private

      # =========================================================================
      # PRIVATE METHODS - API CALLS
      # =========================================================================

      def _call_api(messages)
        config = PROVIDERS[@provider]
        raise "Unknown provider: #{@provider}" unless config

        case config[:format]
        when :openai
          _call_openai_style_api(messages, config)
        when :anthropic
          _call_anthropic_api(messages, config)
        else
          raise "Unsupported format: #{config[:format]}"
        end
      end

      # OpenAI-compatible API (Grok, OpenAI)
      def _call_openai_style_api(messages, config)
        uri = URI(config[:url])
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 30
        http.open_timeout = 10

        body = {
          model: @settings.ai_model || config[:model],
          messages: messages.map { |m|
            { role: m[:role], content: m[:content] }
          },
          max_tokens: MAX_TOKENS,
          temperature: 0.7
        }

        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request['Authorization'] = "Bearer #{@api_key}"
        request.body = JSON.generate(body)

        response = http.request(request)

        if response.code == '200'
          data = JSON.parse(response.body)
          content = data.dig('choices', 0, 'message', 'content') || ''
          tokens = data.dig('usage', 'completion_tokens') || 0
          { success: true, content: content, tokens_used: tokens }
        else
          begin
            error_data = JSON.parse(response.body)
            error_msg = error_data.dig('error', 'message') || "HTTP #{response.code}"
          rescue
            error_msg = "HTTP #{response.code}: #{response.body[0..200]}"
          end
          Logger.error("AIEngine._call_openai_style_api: #{error_msg}")
          { success: false, error: error_msg }
        end

      rescue Net::OpenTimeout, Net::ReadTimeout
        { success: false, error: 'Timeout: Server tidak merespons dalam 30 detik' }
      rescue => e
        Logger.error("AIEngine._call_openai_style_api: #{e.message}")
        { success: false, error: e.message }
      end

      # Anthropic API (Claude)
      def _call_anthropic_api(messages, config)
        uri = URI(config[:url])
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 30
        http.open_timeout = 10

        body = {
          model: @settings.ai_model || config[:model],
          max_tokens: MAX_TOKENS,
          system: SYSTEM_PROMPT,
          messages: messages
        }

        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request['x-api-key'] = @api_key
        request['anthropic-version'] = '2023-06-01'
        request.body = JSON.generate(body)

        response = http.request(request)

        if response.code == '200'
          data = JSON.parse(response.body)
          content = data.dig('content', 0, 'text') || ''
          tokens = data.dig('usage', 'output_tokens') || 0
          { success: true, content: content, tokens_used: tokens }
        else
          error_data = JSON.parse(response.body) rescue {}
          error_msg = error_data.dig('error', 'message') || "HTTP #{response.code}"
          Logger.error("AIEngine._call_anthropic_api: #{error_msg}")
          { success: false, error: error_msg }
        end

      rescue Net::OpenTimeout, Net::ReadTimeout
        { success: false, error: 'Timeout: Server tidak merespons dalam 30 detik' }
      rescue => e
        Logger.error("AIEngine._call_anthropic_api: #{e.message}")
        { success: false, error: e.message }
      end

      # =========================================================================
      # PRIVATE METHODS - UTILITIES
      # =========================================================================

      def _build_enriched_message(message, model_ctx, rab_ctx)
        parts = [message]

        if model_ctx && @history.empty?
          summary = model_ctx[:summary] rescue {}
          parts << "\n\n[KONTEKS MODEL SKETCHUP]\n" \
                   "Judul: #{summary[:title]}\n" \
                   "Entitas: #{summary[:entity_count]}, Layer: #{summary[:layers]}, " \
                   "Material: #{summary[:materials]}"
        end

        if rab_ctx
          parts << "\n\n[KONTEKS RAB]\n#{_rab_summary_for_ai(rab_ctx)}"
        end

        parts.join
      end

      def _rab_summary_for_ai(doc_hash)
        lines = []
        lines << "Total: #{doc_hash[:grand_total]} BND"
        lines << "Overhead: #{doc_hash[:overhead_pct]}%, Profit: #{doc_hash[:profit_pct]}%, PPN: #{doc_hash[:ppn_pct]}%"
        lines << "\nItem pekerjaan:"
        doc_hash[:sections]&.each do |s|
          lines << "\n#{s[:group_label]}:"
          s[:items]&.each do |i|
            lines << "  #{i[:category_code]} #{i[:category_name]}: #{i[:quantity]} #{i[:unit]} × #{i[:unit_price]} BND = #{i[:total_price]} BND"
          end
        end
        lines.join("\n")
      rescue
        doc_hash.to_s
      end

      # Rate limiting
      def _check_rate_limit
        now = Time.now.to_i
        @request_times.reject! { |t| t < now - RATE_LIMIT_WINDOW }
        
        if @request_times.size >= MAX_REQUESTS_PER_MINUTE
          return false
        end
        
        @request_times << now
        true
      end

      # API Key loading with provider-aware fallback
      def _load_api_key
        config = PROVIDERS[@provider]
        
        # Try environment variable for this provider
        key = ENV[config[:env_key]]
        return key if key && !key.empty?

        # Try SketchUp secure storage
        stored = Sketchup.read_default('RABPro', "api_key_#{@provider}")
        return stored if stored && !stored.empty?

        nil
      end

      def _no_api_key_message
        config = PROVIDERS[@provider]
        <<~MSG
          ⚠️ API Key untuk #{config[:description]} belum dikonfigurasi.

          Untuk menggunakan AI Assistant:
          1. Dapatkan API key dari provider Anda
          2. Set environment variable: #{config[:env_key]}=your_key_here
          3. Atau buka Pengaturan RAB Pro → tab AI dan masukkan API key

          Provider yang tersedia:
          #{providers_info}
        MSG
      end

    end
  end
end
