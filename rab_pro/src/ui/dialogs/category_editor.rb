# ==============================================================================
# RAB Pro - Category Editor Dialog
# Allows users to view, search, and customize the work category library.
# Custom categories can be added per project.
# ==============================================================================

module RABPro
  module UI
    module Dialogs
      class CategoryEditorDialog

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
            dialog_title:    'RAB Pro — Library Kategori Pekerjaan',
            preferences_key: 'RABPro_CategoryEditor',
            style:           ::UI::HtmlDialog::STYLE_DIALOG,
            width:           700,
            height:          550,
            min_width:       500,
            min_height:      400
          )

          @dlg.set_html(_html)

          # Send category data when dialog asks for it
          @dlg.add_action_callback('loadCategories') do |_, _|
            payload = {
              categories: Data::CategoryLibrary.to_json_array,
              groups:     Data::CategoryLibrary.groups
            }
            @dlg.execute_script("receiveCategories(#{JSON.generate(payload)})")
          end

          @dlg.add_action_callback('selectCategory') do |_, cat_id|
            Logger.info("CategoryEditor: selected #{cat_id}")
            # Broadcast selection to main panel if open
            AppController.instance.main_panel&.send(:_send_to_js, 'onCategorySelected', { id: cat_id })
          end

          ::UI.start_timer(0.2, false) do
            payload = {
              categories: Data::CategoryLibrary.to_json_array,
              groups:     Data::CategoryLibrary.groups
            }
            @dlg.execute_script("receiveCategories(#{JSON.generate(payload)})")
          end
        end

        def _html
          <<~HTML
            <!DOCTYPE html>
            <html lang="id">
            <head>
              <meta charset="UTF-8">
              <style>
                * { box-sizing:border-box; margin:0; padding:0; }
                body { font-family:-apple-system,sans-serif; font-size:13px; display:flex; flex-direction:column; height:100vh; }
                .toolbar { display:flex; gap:8px; padding:10px 12px; border-bottom:1px solid #e8e8e8; background:#f8f8f8; }
                .search { flex:1; padding:6px 10px; border:1px solid #ddd; border-radius:6px; font-size:12px; }
                .table-wrap { flex:1; overflow-y:auto; }
                table { width:100%; border-collapse:collapse; }
                th { position:sticky; top:0; background:#f8f8f8; font-size:11px; font-weight:600;
                     color:#888; text-transform:uppercase; padding:8px 12px; border-bottom:1px solid #eee; text-align:left; }
                td { padding:7px 12px; border-bottom:1px solid #f0f0f0; font-size:12px; vertical-align:middle; }
                tr:hover td { background:#f5f9ff; cursor:pointer; }
                .code { font-family:monospace; color:#0071e3; }
                .group-row td { background:#fafafa; font-weight:600; font-size:11px; color:#666; padding:5px 12px; }
                .unit-badge { display:inline-block; background:#e8f2ff; color:#0071e3;
                              font-size:10px; padding:2px 6px; border-radius:10px; }
                .ifc { font-size:10px; color:#aaa; font-family:monospace; }
                .count { padding:8px 12px; font-size:11px; color:#888; background:#f8f8f8;
                         border-top:1px solid #eee; }
              </style>
            </head>
            <body>
              <div class="toolbar">
                <input class="search" type="text" placeholder="Cari kode, nama pekerjaan, IFC class..."
                       oninput="filter(this.value)">
              </div>
              <div class="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>Kode</th>
                      <th>Nama Pekerjaan</th>
                      <th>Satuan</th>
                      <th>Tipe Qty</th>
                      <th>IFC Class</th>
                    </tr>
                  </thead>
                  <tbody id="tbody"></tbody>
                </table>
              </div>
              <div class="count" id="count">Memuat...</div>

              <script>
                let _all = [];
                let _groups = {};

                function receiveCategories(data) {
                  _all    = data.categories;
                  _groups = data.groups || {};
                  render(_all);
                }

                function render(cats) {
                  const tbody = document.getElementById('tbody');
                  document.getElementById('count').textContent = cats.length + ' kategori pekerjaan';

                  // Group by group field
                  const grouped = {};
                  cats.forEach(c => { (grouped[c.group] = grouped[c.group] || []).push(c); });

                  let html = '';
                  Object.entries(grouped).forEach(([g, items]) => {
                    const label = items[0].group_label || g;
                    html += '<tr class="group-row"><td colspan="5">' + esc(label) + '</td></tr>';
                    items.forEach(c => {
                      html += '<tr onclick="select(\'' + c.id + '\')">';
                      html += '<td class="code">' + esc(c.code) + '</td>';
                      html += '<td>' + esc(c.name) + '<br><span style="color:#aaa;font-size:11px">' + esc(c.name_en) + '</span></td>';
                      html += '<td><span class="unit-badge">' + esc(c.unit) + '</span></td>';
                      html += '<td style="color:#666">' + esc(c.quantity_type) + '</td>';
                      html += '<td class="ifc">' + esc(c.ifc_class) + '</td>';
                      html += '</tr>';
                    });
                  });
                  tbody.innerHTML = html;
                }

                function filter(q) {
                  if (!q) { render(_all); return; }
                  const ql = q.toLowerCase();
                  render(_all.filter(c =>
                    c.name.toLowerCase().includes(ql) ||
                    c.name_en.toLowerCase().includes(ql) ||
                    c.code.toLowerCase().includes(ql) ||
                    (c.ifc_class || '').toLowerCase().includes(ql)
                  ));
                }

                function select(id) { sketchup.selectCategory(id); }

                function esc(s) {
                  return String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
                }

                sketchup.loadCategories();
              </script>
            </body>
            </html>
          HTML
        end

      end
    end
  end
end
