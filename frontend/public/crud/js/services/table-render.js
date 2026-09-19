export function renderDynamicTable(data) {
  const theadRow = document.getElementById('table-headers');
  const tbody = document.getElementById('table-body');

  tbody.innerHTML = '';

  if (!data || data.length === 0) {
    theadRow.innerHTML = `<th>Information</th><th>Acciones</th>`;
    tbody.innerHTML = `<tr class="empty-row"><td colspan="2">No data</td></tr>`;
    return;
  }

  const columns = Object.keys(data[0]);

  theadRow.innerHTML = columns.map(col => `<th>${col.toUpperCase()}</th>`).join('') 
    + `<th style="text-align: center;">Actions</th>`;

  data.forEach((row, index) => {
    const tr = document.createElement('tr');
    const dataCells = columns.map(col => `<td>${row[col]}</td>`).join('');

    const actionCell = `
      <td style="text-align: center; overflow: visible !important;">
        <details class="dropdown-details">
          <summary class="btn-icon">
            <i data-lucide="more-vertical"></i>
          </summary>
          <div class="dropdown-menu dropdown-menu-left">
            <button class="dropdown-item btn-view" data-index="${index}">
              View
            </button>
            <button class="dropdown-item btn-edit" data-index="${index}">
              Edit
            </button>
            <button class="dropdown-item btn-delete text-danger" data-index="${index}">
              Delete
            </button>
          </div>
        </details>
      </td>
    `;

    tr.innerHTML = dataCells + actionCell;
    tbody.appendChild(tr);
  });

  if (window.lucide) window.lucide.createIcons();
  document.addEventListener('click', (event) => {
    const openDetails = document.querySelectorAll('details.dropdown-details[open]');
    
    openDetails.forEach(details => {
      if (!details.contains(event.target)) {
        details.removeAttribute('open');
      }
    });
  });
}