export function renderPagination(currentPage, totalItems, itemsPerPage = 100, onPageChange) {
  const container = document.getElementById('pagination-container');
  if (!container) return;
  
  container.innerHTML = '';
  const totalPages = Math.ceil(totalItems / itemsPerPage);

  if (totalPages <= 1) return; 

  const createButton = (text, page, isActive = false, isDisabled = false) => {
    const btn = document.createElement('button');
    btn.className = `pagination-btn ${isActive ? 'active' : ''}`;
    btn.innerText = text;
    btn.disabled = isDisabled;
    if (!isDisabled && typeof page === 'number') {
      btn.addEventListener('click', () => onPageChange(page));
    }
    return btn;
  };

  container.appendChild(createButton('« Prev', currentPage - 1, false, currentPage === 1));

  const maxVisiblePages = 5;
  let startPage = Math.max(1, currentPage - Math.floor(maxVisiblePages / 2));
  let endPage = Math.min(totalPages, startPage + maxVisiblePages - 1);

  if (endPage - startPage + 1 < maxVisiblePages) {
    startPage = Math.max(1, endPage - maxVisiblePages + 1);
  }

  if (startPage > 1) {
    container.appendChild(createButton('1', 1));
    if (startPage > 2) {
      const ellipsis = document.createElement('span');
      ellipsis.className = 'pagination-ellipsis';
      ellipsis.innerText = '...';
      container.appendChild(ellipsis);
    }
  }

  for (let i = startPage; i <= endPage; i++) {
    container.appendChild(createButton(i, i, i === currentPage));
  }

  if (endPage < totalPages) {
    if (endPage < totalPages - 1) {
      const ellipsis = document.createElement('span');
      ellipsis.className = 'pagination-ellipsis';
      ellipsis.innerText = '...';
      container.appendChild(ellipsis);
    }
    container.appendChild(createButton(totalPages, totalPages));
  }

  container.appendChild(createButton('Next »', currentPage + 1, false, currentPage === totalPages));
}