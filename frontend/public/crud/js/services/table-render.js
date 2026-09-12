export function renderDynamicTable(data) {
  const theadRow = document.getElementById('table-headers');
  const tbody = document.getElementById('table-body');

  tbody.innerHTML = '';

  if (!data || data.length === 0) {
    theadRow.innerHTML = `<th>Información</th><th>Acciones</th>`;
    tbody.innerHTML = `<tr class="empty-row"><td colspan="2">No hay datos disponibles.</td></tr>`;
    return;
  }

  const columns = Object.keys(data[0]);

  theadRow.innerHTML = columns.map(col => `<th>${escapeHTML(col.toUpperCase())}</th>`).join('') 
    + `<th style="text-align: center;">Acciones</th>`;

  data.forEach((row, index) => {
    const tr = document.createElement('tr');
    const dataCells = columns.map(col => `<td>${escapeHTML(row[col])}</td>`).join('');
    
    const actionCell = `
      <td style="text-align: center;">
        <details class="dropdown-details">
          <summary class="btn-icon">
            <i data-lucide="more-vertical"></i>
          </summary>
          <div class="dropdown-menu dropdown-menu-right">
            <button class="dropdown-item btn-edit" data-index="${index}">
              <i data-lucide="edit-2"></i> Editar
            </button>
            <button class="dropdown-item btn-delete text-danger" data-index="${index}">
              <i data-lucide="trash-2"></i> Eliminar
            </button>
          </div>
        </details>
      </td>
    `;

    tr.innerHTML = dataCells + actionCell;
    tbody.appendChild(tr);
  });

  if (window.lucide) window.lucide.createIcons();
}

function escapeHTML(val) {
  if (val === null || val === undefined) return '-';
  if (typeof val === 'object') return escapeHTML(JSON.stringify(val));
  return String(val).replace(/[&<>"']/g, m => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[m]));
}