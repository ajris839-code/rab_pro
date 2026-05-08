# ==============================================================================
# RAB Pro - AI Engine
# Integrates Claude API for:
#   - Cost estimation analysis
#   - Value engineering suggestions
#   - Natural language model queries
#   - Anomaly detection in quantities/prices
#   - Design recommendations
# ==============================================================================

require 'net/http'
require 'json'
require 'uri'

module RABPro
  module AI
    class AIEngine

      CLAUDE_API_URL = 'https://api.anthropic.com/v1/messages'.freeze
      MODEL          = 'claude-sonnet-4-20250514'.freeze
      MAX_TOKENS     = 2048

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

      def initialize(settings)
        @settings = settings
        @api_key  = _load_api_key
        @history  = []
      end

      # -----------------------------------------------------------------------
      # Chat — send a message with full model context
      # Returns { role: 'assistant', content: '...', tokens_used: N }
      # -----------------------------------------------------------------------
      def chat(message, model_context: nil, rab_context: nil)
        unless @settings.ai_enabled?
          return { role: 'assistant', content: 'AI Assistant dinonaktifkan. Aktifkan di Pengaturan.', tokens_used: 0 }
        end

        unless @api_key
          return { role: 'assistant', content: _no_api_key_message, tokens_used: 0 }
        end

        # Build enriched user message with context
        enriched = _build_enriched_message(message, model_context, rab_context)

        # Add to history
        @history << { role: 'user', content: enriched }

        # Trim history to last 10 exchanges (memory management)
        @history = @history.last(20)

        response = _call_api(@history)

        if response[:success]
          assistant_msg = response[:content]
          @history << { role: 'assistant', content: assistant_msg }
          {
            role:        'assistant',
            content:     assistant_msg,
            tokens_used: response[:tokens_used]
          }
        else
          { role: 'assistant', content: "Error: #{response[:error]}", tokens_used: 0 }
        end
      end

      # -----------------------------------------------------------------------
      # Analyze RAB document — returns structured insights
      # -----------------------------------------------------------------------
      def analyze_rab(rab_document)
        return nil unless rab_document

        doc_hash  = RAB::RABCalculator.document_to_hash(rab_document)
        summary   = _rab_summary_for_ai(doc_hash)

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
          generated_at: Time.now.iso8601
        }
      end

      # -----------------------------------------------------------------------
      # Generate cost estimate from model summary (before full RAB)
      # -----------------------------------------------------------------------
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

      # -----------------------------------------------------------------------
      # Value engineering suggestions for a specific work item
      # -----------------------------------------------------------------------
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

      # -----------------------------------------------------------------------
      # Detect anomalies in QTO results
      # -----------------------------------------------------------------------
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

      # -----------------------------------------------------------------------
      # Natural language model command — convert text to Ruby action
      # -----------------------------------------------------------------------
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

      # -----------------------------------------------------------------------
      # Reset conversation history
      # -----------------------------------------------------------------------
      def reset_history
        @history = []
        Logger.info('AIEngine: conversation history cleared')
      end

      def history; @history end

      private

      # -----------------------------------------------------------------------
      # Build enriched message with context injected
      # -----------------------------------------------------------------------
      def _build_enriched_message(message, model_ctx, rab_ctx)
        parts = [message]

        if model_ctx && @history.empty?
          # Only inject full model context at start of conversation
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

      # -----------------------------------------------------------------------
      # API call
      # -----------------------------------------------------------------------
      def _call_api(messages)
        uri  = URI(CLAUDE_API_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl     = true
        http.read_timeout = 30
        http.open_timeout = 10

        body = {
          model:      @settings.ai_model || MODEL,
          max_tokens: MAX_TOKENS,
          system:     SYSTEM_PROMPT,
          messages:   messages
        }

        request = Net::HTTP::Post.new(uri)
        request['Content-Type']      = 'application/json'
        request['x-api-key']         = @api_key
        request['anthropic-version'] = '2023-06-01'
        request.body = JSON.generate(body)

        response = http.request(request)

        if response.code == '200'
          data    = JSON.parse(response.body)
          content = data.dig('content', 0, 'text') || ''
          tokens  = data.dig('usage', 'output_tokens') || 0
          { success: true, content: content, tokens_used: tokens }
        else
          error_data = JSON.parse(response.body) rescue {}
          error_msg  = error_data.dig('error', 'message') || "HTTP #{response.code}"
          Logger.error("AIEngine API error: #{error_msg}")
          { success: false, error: error_msg }
        end

      rescue Net::OpenTimeout, Net::ReadTimeout
        { success: false, error: 'Timeout: Server tidak merespons dalam 30 detik' }
      rescue => e
        Logger.error("AIEngine._call_api: #{e.message}")
        { success: false, error: e.message }
      end

      def _load_api_key
        # Try environment variable first
        key = ENV['ANTHROPIC_API_KEY']
        return key if key && !key.empty?

        # Try SketchUp secure storage
        stored = Sketchup.read_default('RABPro', 'api_key')
        return stored if stored && !stored.empty?

        nil
      end

      def _no_api_key_message
        <<~MSG
          ⚠️ API Key Claude belum dikonfigurasi.

          Untuk menggunakan AI Assistant:
          1. Dapatkan API key dari https://console.anthropic.com
          2. Buka Pengaturan RAB Pro → tab AI
          3. Masukkan API key Anda

          Atau set environment variable ANTHROPIC_API_KEY sebelum membuka SketchUp.
        MSG
      end

    end
  end
end
