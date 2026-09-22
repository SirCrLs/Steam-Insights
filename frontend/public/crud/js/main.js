import { GamesAPI } from '/crud/js/services/api.js';
import { renderDynamicTable } from '/crud/js/services/table-render.js';
import { renderPagination } from '/crud/js/services/page-render.js'; 

const ITEMS_PER_PAGE = 100;
let currentPage = 1;
let currentEntity = 'games';

async function loadPage(page) {
  currentPage = page;
  
  const offset = (currentPage - 1) * ITEMS_PER_PAGE;

  try {
    const res = await GamesAPI.getAll(ITEMS_PER_PAGE, offset);
    
    renderDynamicTable(res.games);
    renderPagination(currentPage, res.total, ITEMS_PER_PAGE, (newPage) => {
      loadPage(newPage);
    });
    
  } catch (error) {
    console.error("Failed to load page data:", error);
  }
}

loadPage(1);
