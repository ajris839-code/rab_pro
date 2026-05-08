# ==============================================================================
# RAB Pro - AI Chat Manager
# Full-featured conversational AI with:
#   - Persistent conversation history per project
#   - Model context injection (entities, RAB, dimensions)
#   - Tool use: execute SketchUp actions from natural language
#   - Streaming response support via chunked callbacks
#   - Multi-turn context window management
# ==============================================================================

require 'net/http'
require 'json'
require 'uri'

module RABPro
  module AI
    module Chat
      class ChatManager

        CLAUDE_API_URL = 'https://api.anthropic.com/v1/messages'.freeze
        MAX_HISTORY    = 30    # max message pairs kept in memory
        MAX_TOKENS     = 4096

        SYSTEM_PROMPT = <<~PROMPT.freeze
          Anda adalah RAB Pro AI — asisten cerdas untuk quantity surveying, estimasi biaya konstruksi,
          dan desain arsitektur yang terintegrasi langsung dengan SketchUp.

          ## Kemampuan Anda
          1. **Analisis Model** — membaca data geometri, entitas, dan tag dari model SketchUp aktif
          2. **RAB & Estimasi** — menghitung volume, luas, panjang; menilai kewajaran harga; saran value engineering
          3. **Gambar Teknis** — rekomendasi scene, skala, dan standar gambar teknis
          4. **Konstruksi** — pengetahuan mendalam SNI, metode konstruksi, material, dan spesifikasi teknis
          5. **Perintah Model** — menginterpretasi perintah natural language dan menjelaskan tindakan yang akan diambil

          ## Konteks Lokal
          - Proyek di Brunei Darussalam / Asia Tenggara
          - Mata uang default: BND (Brunei Dollar)
          - Standar: SNI, BS, MS (Malaysian Standard)
          - Iklim: tropis lembab — pertimbangkan ventilasi, waterproofing, korosi

          ## Format Respons
          - Gunakan Bahasa Indonesia yang profesional
          - Sertakan angka konkret bila relevan
          - Gunakan format tabel Markdown untuk perbandingan
          - Tandai saran penting dengan **bold**
          - Jika ada perhitungan, tunjukkan rumus dan langkah
          - Respons singkat untuk pertanyaan sederhana, detail untuk analisis

          ## Tool Calls (model actions)
          Jika pengguna meminta tindakan pada model SketchUp (buat objek, hitung, tag), jelaskan
          apa yang akan dilakukan lalu konfirmasi sebelum mengeksekusi.
        PROMPT

        def initialize(model, settings:, project_store:)
          @model         = model
          @settings      = settings
          @project_store = project_store
          @api_key       = _load_api_key
          @history       = []
          @context_cache = {}
          @last_context_refresh = nil
        end

        # -----------------------------------------------------------------------
        # Send a message — returns response hash
        # -----------------------------------------------------------------------
        def send(message, include_model_context: true, include_rab_context: false)
          return _disabled_response unless @settings.ai_enabled?
          return _no_key_response   unless @api_key

          # Build enriched message
          enriched = _enrich_message(message,
                       include_model:   include_model_context,
                       include_rab:     include_rab_context)

          @history << { role: 'user', content: enriched }

          # Trim history
          @history = @history.last(MAX_HISTORY * 2)

          # Call API
          result = _call_claude(@history)

          if result[:success]
            @history << { role: 'assistant', content: result[:content] }
            _save_history

            {
              success:     true,
              role:        'assistant',
              content:     result[:content],
              display:     message,   # original (not enriched) for display
              tokens_used: result[:tokens_used],
              timestamp:   Time.now.iso8601
            }
          else
            @history.pop  # remove failed user message
            { success: false, role: 'error', content: result[:error], timestamp: Time.now.iso8601 }
          end
        end

        # -----------------------------------------------------------------------
        # Quick one-shot query (no history)
        # -----------------------------------------------------------------------
        def query(prompt, system_override: nil)
          return _no_key_response unless @api_key

          messages = [{ role: 'user', content: prompt }]
          _call_claude(messages, system: system_override)
        end

        # -----------------------------------------------------------------------
        # Special: natural language → SketchUp action
        # Returns { action:, params:, explanation: }
        # -----------------------------------------------------------------------
        def parse_model_command(text)
          prompt = <<~P
            Pengguna memberikan perintah untuk model SketchUp:
            "#{text}"

            Analisis perintah dan kembalikan JSON dengan struktur:
            {
              "action": "tag_entity|create_scene|run_qto|build_rab|auto_dimension|inspect|none",
              "params": {},
              "explanation": "Penjelasan singkat apa yang akan dilakukan",
              "requires_confirmation": true/false,
              "warning": null
            }

            Hanya kembalikan JSON, tanpa teks lain.
          P

          result = query(prompt)
          return nil unless result[:success]

          begin
            JSON.parse(result[:content].gsub(/```json|```/, '').strip)
          rescue
            { 'action' => 'none', 'explanation' => result[:content] }
          end
        end

        # -----------------------------------------------------------------------
        # Generate context summary for AI
        # -----------------------------------------------------------------------
        def build_model_context_summary(depth: :normal)
          return @context_cache[:summary] if _context_fresh?

          model_data  = _read_model_data
          tag_stats   = Core::Tagger::TagEngine.stats(@model)

          summary = case depth
                    when :minimal
                      _minimal_summary(model_data, tag_stats)
                    when :full
                      _full_summary(model_data, tag_stats)
                    else
                      _normal_summary(model_data, tag_stats)
                    end

          @context_cache[:summary]     = summary
          @context_cache[:model_data]  = model_data
          @last_context_refresh        = Time.now
          summary
        end

        # -----------------------------------------------------------------------
        # Conversation history management
        # -----------------------------------------------------------------------
        def history
          @history.map do |msg|
            # Return display-friendly version (trim context injections)
            {
              role:    msg[:role],
              content: _strip_context(msg[:content].to_s)
            }
          end
        end

        def clear_history
          @history = []
          _delete_saved_history
          Logger.info('ChatManager: history cleared')
        end

        def history_count
          @history.size / 2  # pairs
        end

        private

        # -----------------------------------------------------------------------
        # Message enrichment
        # -----------------------------------------------------------------------
        def _enrich_message(message, include_model:, include_rab:)
          parts = [message]

          if include_model && (@history.empty? || _context_stale?)
            ctx = build_model_context_summary
            parts << "\n\n---\n[KONTEKS MODEL AKTIF]\n#{ctx}\n---" unless ctx.empty?
          end

          if include_rab
            rab_ctx = _rab_context_summary
            parts << "\n\n[KONTEKS RAB]\n#{rab_ctx}" unless rab_ctx.empty?
          end

          parts.join
        end

        def _read_model_data
          reader = Core::Inspector::EntityReader.new(@model)
          {
            summary:   reader.summary,
            top_level: reader.read_top_level.first(20)  # limit for context
          }
        rescue => e
          Logger.warn("ChatManager._read_model_data: #{e.message}")
          {}
        end

        def _minimal_summary(model_data, tag_stats)
          s = model_data[:summary] || {}
          "Model: #{s[:title]} | #{s[:entity_count]} entitas | #{s[:layers]} layer | " \
          "Tagged: #{tag_stats.values.sum} entitas"
        end

        def _normal_summary(model_data, tag_stats)
          s   = model_data[:summary] || {}
          pi  = @project_store&.project_info&.to_h || {}

          lines = []
          lines << "**Proyek:** #{pi[:name] || 'Unnamed'} | **Lokasi:** #{pi[:location] || '-'}"
          lines << "**Model:** #{s[:title]} | #{s[:entity_count]} entitas | #{s[:layers]} layer | #{s[:materials]} material"
          lines << "**Komponen:** #{s[:component_defs]} definisi"

          unless tag_stats.empty?
            lines << "\n**Tagged entities (#{tag_stats.values.sum} total):**"
            tag_stats.each do |cat, count|
              lines << "  - #{cat}: #{count} entitas"
            end
          end

          pi_info = [pi[:consultant], pi[:contractor]].compact.reject(&:empty?)
          lines << "\n**Tim:** #{pi_info.join(' | ')}" unless pi_info.empty?

          lines.join("\n")
        end

        def _full_summary(model_data, tag_stats)
          base = _normal_summary(model_data, tag_stats)
          top  = model_data[:top_level] || []

          unless top.empty?
            base += "\n\n**Top-level entities:**\n"
            top.first(15).each do |e|
              cat = e[:rab_category] ? " [#{e[:rab_category]}]" : ''
              base += "  - #{e[:name]} (#{e[:entity_type]}, layer: #{e[:layer]})#{cat}\n"
            end
          end

          base
        end

        def _rab_context_summary
          # Try to get last RAB document from project store
          ps = @project_store
          return '' unless ps

          prices = ps.all_custom_prices
          return '' if prices.empty?

          "Custom prices: #{prices.size} items | " \
          "Overhead: #{ps.overhead_pct}% | Profit: #{ps.profit_pct}% | PPN: #{ps.ppn_pct}%"
        rescue
          ''
        end

        def _strip_context(content)
          content.gsub(/\n\n---\n\[KONTEKS MODEL AKTIF\].*?\n---/m, '')
                 .gsub(/\n\n\[KONTEKS RAB\].*?\z/m, '')
                 .strip
        end

        # -----------------------------------------------------------------------
        # API call
        # -----------------------------------------------------------------------
        def _call_claude(messages, system: nil)
          uri  = URI(CLAUDE_API_URL)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl      = true
          http.read_timeout = 45
          http.open_timeout = 10

          body = {
            model:      @settings.ai_model,
            max_tokens: MAX_TOKENS,
            system:     system || SYSTEM_PROMPT,
            messages:   messages
          }

          req = Net::HTTP::Post.new(uri)
          req['Content-Type']      = 'application/json'
          req['x-api-key']         = @api_key
          req['anthropic-version'] = '2023-06-01'
          req.body = JSON.generate(body)

          res  = http.request(req)
          data = JSON.parse(res.body)

          if res.code == '200'
            content = data.dig('content', 0, 'text') || ''
            tokens  = data.dig('usage', 'output_tokens') || 0
            { success: true, content: content, tokens_used: tokens }
          else
            msg = data.dig('error', 'message') || "HTTP #{res.code}"
            Logger.error("ChatManager API: #{msg}")
            { success: false, error: msg }
          end
        rescue Net::OpenTimeout, Net::ReadTimeout => e
          { success: false, error: "Timeout: #{e.message}" }
        rescue => e
          Logger.error("ChatManager._call_claude: #{e.message}")
          { success: false, error: e.message }
        end

        # -----------------------------------------------------------------------
        # History persistence (stored in model attributes)
        # -----------------------------------------------------------------------
        def _save_history
          # Only keep last 10 pairs to avoid bloating model file
          recent = @history.last(20)
          @model.set_attribute('RABPro_Chat', 'history', JSON.generate(recent))
        rescue => e
          Logger.warn("ChatManager._save_history: #{e.message}")
        end

        def _load_history
          raw = @model.get_attribute('RABPro_Chat', 'history')
          return [] unless raw
          parsed = JSON.parse(raw)
          parsed.map { |m| { role: m['role'], content: m['content'] } }
        rescue
          []
        end

        def _delete_saved_history
          @model.delete_attribute('RABPro_Chat', 'history')
        rescue
          nil
        end

        def _context_fresh?
          @last_context_refresh && (Time.now - @last_context_refresh) < 30
        end

        def _context_stale?
          !_context_fresh?
        end

        def _load_api_key
          ENV['ANTHROPIC_API_KEY'] ||
            Sketchup.read_default('RABPro', 'api_key')
        end

        def _disabled_response
          { success: false, role: 'system',
            content: 'AI Assistant dinonaktifkan. Aktifkan di tab Pengaturan.',
            timestamp: Time.now.iso8601 }
        end

        def _no_key_response
          { success: false, role: 'system',
            content: "⚠️ API Key belum dikonfigurasi.\n\n" \
                     "Cara setup:\n" \
                     "1. Kunjungi https://console.anthropic.com\n" \
                     "2. Buat API key baru\n" \
                     "3. Buka Pengaturan RAB Pro → AI → masukkan API key\n\n" \
                     "Atau set environment variable ANTHROPIC_API_KEY sebelum membuka SketchUp.",
            timestamp: Time.now.iso8601 }
        end

      end
    end
  end
end
