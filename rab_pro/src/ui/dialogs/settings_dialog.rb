# ==============================================================================
# RAB Pro - Settings Dialog
# Standalone HtmlDialog for extension settings.
# ==============================================================================

module RABPro
  module UI
    module Dialogs
      class SettingsDialog

        def initialize(settings)
          @settings = settings
          @dlg      = nil
        end

        def show
          _build unless @dlg
          @dlg.show
        end

        private

        def _build
          @dlg = ::UI::HtmlDialog.new(
            dialog_title:    'RAB Pro — Pengaturan',
            preferences_key: 'RABPro_Settings',
            style:           ::UI::HtmlDialog::STYLE_DIALOG,
            width:           520,
            height:          480,
            min_width:       400,
            min_height:      350
          )

          @dlg.set_html(_html)

          @dlg.add_action_callback('getSettings') do |_, _|
            @dlg.execute_script("loadSettings(#{JSON.generate(@settings.to_hash)})")
          end

          @dlg.add_action_callback('saveSettings') do |_, payload|
            begin
              data = JSON.parse(payload) rescue payload
              @settings.from_hash(data)
              @dlg.execute_script("showSaved()")
              Logger.info('Settings saved via SettingsDialog')
            rescue => e
              Logger.error("SettingsDialog save: #{e.message}")
            end
          end

          @dlg.add_action_callback('resetSettings') do |_, _|
            @settings.reset_to_defaults!
            @dlg.execute_script("loadSettings(#{JSON.generate(@settings.to_hash)})")
          end

          ::UI.start_timer(0.2, false) do
            @dlg.execute_script("loadSettings(#{JSON.generate(@settings.to_hash)})")
          end
        end

        def _html
          <<~HTML
            <!DOCTYPE html>
            <html lang="id">
            <head>
              <meta charset="UTF-8">
              <title>Pengaturan RAB Pro</title>
              <style>
                * { box-sizing: border-box; margin: 0; padding: 0; }
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
                       font-size:13px; padding:20px; background:#fff; color:#1a1a1a; }
                h2 { font-size:15px; font-weight:600; margin-bottom:16px; }
                .section { margin-bottom:16px; }
                .section-title { font-size:11px; font-weight:700; color:#888;
                                 text-transform:uppercase; letter-spacing:.06em; margin-bottom:8px; }
                .row { display:flex; align-items:center; justify-content:space-between;
                       padding:7px 0; border-bottom:1px solid #eee; }
                label { font-size:12px; }
                select, input[type=text] { font-size:12px; padding:4px 6px;
                                            border:1px solid #ddd; border-radius:4px; }
                .btn-row { display:flex; gap:8px; margin-top:20px; justify-content:flex-end; }
                .btn { padding:7px 14px; border-radius:5px; font-size:12px; font-weight:500;
                       cursor:pointer; border:1px solid #ddd; background:#f5f5f5; }
                .btn-primary { background:#0071e3; color:#fff; border-color:#0071e3; }
                .saved-msg { color:#2e7d32; font-size:12px; display:none; }
              </style>
            </head>
            <body>
              <h2>Pengaturan RAB Pro</h2>

              <div class="section">
                <div class="section-title">Umum</div>
                <div class="row"><label>Bahasa</label>
                  <select id="ui_language"><option value="id">Indonesia</option><option value="en">English</option></select></div>
                <div class="row"><label>Mata Uang</label>
                  <select id="currency"><option value="BND">BND (Brunei Dollar)</option><option value="IDR">IDR</option><option value="SGD">SGD</option><option value="USD">USD</option></select></div>
                <div class="row"><label>Simbol Mata Uang</label>
                  <input type="text" id="currency_symbol" style="width:80px"></div>
              </div>

              <div class="section">
                <div class="section-title">Unit & Satuan</div>
                <div class="row"><label>Satuan Panjang</label>
                  <select id="length_unit"><option value="m">Meter (m)</option><option value="cm">Centimeter</option></select></div>
              </div>

              <div class="section">
                <div class="section-title">AI Assistant</div>
                <div class="row"><label>Model AI</label>
                  <select id="ai_model">
                    <option value="claude-sonnet-4-20250514">Claude Sonnet 4</option>
                    <option value="claude-opus-4-6">Claude Opus 4.6</option>
                  </select></div>
              </div>

              <div class="section">
                <div class="section-title">Export</div>
                <div class="row"><label>Ukuran Kertas PDF</label>
                  <select id="pdf_paper_size"><option value="A4">A4</option><option value="A3">A3</option><option value="A1">A1</option></select></div>
                <div class="row"><label>Level Log</label>
                  <select id="log_level"><option value="info">Info</option><option value="debug">Debug</option><option value="warn">Warning</option></select></div>
              </div>

              <div class="btn-row">
                <span class="saved-msg" id="saved-msg">✓ Disimpan</span>
                <button class="btn" onclick="reset()">Reset Default</button>
                <button class="btn btn-primary" onclick="save()">Simpan</button>
              </div>

              <script>
                const IDS = ['ui_language','currency','currency_symbol','length_unit','ai_model','pdf_paper_size','log_level'];

                function loadSettings(s) {
                  IDS.forEach(id => { const el = document.getElementById(id); if(el && s[id]!==undefined) el.value = s[id]; });
                }

                function save() {
                  const data = {};
                  IDS.forEach(id => { const el = document.getElementById(id); if(el) data[id] = el.value; });
                  sketchup.saveSettings(JSON.stringify(data));
                }

                function showSaved() {
                  const el = document.getElementById('saved-msg');
                  el.style.display = 'inline';
                  setTimeout(() => el.style.display = 'none', 2000);
                }

                function reset() {
                  if(confirm('Reset semua pengaturan ke default?')) sketchup.resetSettings();
                }

                sketchup.getSettings();
              </script>
            </body>
            </html>
          HTML
        end

      end
    end
  end
end
