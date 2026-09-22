export function renderPagination(currentPage, totalItems, itemsPerPage = 100, onPageChange) {
  const container = document.getElementById('pagination-container');
  if (!container) return;
  
  container.innerHTML = '';
  const totalPages = Math.ceil(totalItems / itemsPerPage);
  if (totalPages <= 1) return; 

  const wrapper = document.createElement('div');
  wrapper.className = 'pagination-wrapper';

  const navContainer = document.createElement('div');
  navContainer.className = 'pagination-nav';

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

  const createEllipsis = () => {
    const span = document.createElement('span');
    span.className = 'pagination-ellipsis';
    span.innerText = '...';
    return span;
  };

  navContainer.appendChild(createButton('«', currentPage - 1, false, currentPage === 1));

  const maxVisiblePages = 5;
  let startPage = Math.max(1, currentPage - Math.floor(maxVisiblePages / 2));
  let endPage = Math.min(totalPages, startPage + maxVisiblePages - 1);

  if (endPage - startPage + 1 < maxVisiblePages) {
    startPage = Math.max(1, endPage - maxVisiblePages + 1);
  }

  if (startPage > 1) {
    navContainer.appendChild(createButton('1', 1));
    if (startPage > 2) navContainer.appendChild(createEllipsis());
  }

  for (let i = startPage; i <= endPage; i++) {
    navContainer.appendChild(createButton(i, i, i === currentPage));
  }

  if (endPage < totalPages) {
    if (endPage < totalPages - 1) navContainer.appendChild(createEllipsis());
    navContainer.appendChild(createButton(totalPages, totalPages));
  }

  navContainer.appendChild(createButton('»', currentPage + 1, false, currentPage === totalPages));

  const searchContainer = document.createElement('div');
  searchContainer.className = 'pagination-search';

  const input = document.createElement('input');
  input.type = 'number';
  input.min = 1;
  input.max = totalPages;
  input.placeholder = `Go to (1-${totalPages})`;
  input.className = 'pagination-search-input';

  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      const pageNum = parseInt(input.value, 10);
      if (!isNaN(pageNum) && pageNum >= 1 && pageNum <= totalPages) {
        onPageChange(pageNum);
      } else {
        input.value = '';
      }
    }
  });

  searchContainer.appendChild(input);

  wrapper.appendChild(navContainer);
  wrapper.appendChild(searchContainer);
  container.appendChild(wrapper);
}