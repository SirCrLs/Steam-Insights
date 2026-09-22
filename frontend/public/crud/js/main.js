import { GamesAPI, UsersAPI, AchievementsAPI } from '/crud/js/services/api.js';
import { renderDynamicTable } from '/crud/js/services/table-render.js';
import { renderPagination } from '/crud/js/services/page-render.js'; 

const ITEMS_PER_PAGE = 100;
let currentPage = 1;
let currentEntity = 'games';

const API_MAP = {
  games: GamesAPI,
  users: UsersAPI,
  achievements: AchievementsAPI
};

async function loadData(offset) {
  const api = API_MAP[currentEntity];
  
  if (!api) {
    throw new Error(`Entity not found: ${currentEntity}`);
  }

  return await api.getAll(ITEMS_PER_PAGE, offset);
}

async function loadPage(page) {
  currentPage = page;
  const offset = (currentPage - 1) * ITEMS_PER_PAGE;

  try {
    const res = await loadData(offset);
    const items = res.games || res.users || res.achievements || [];
    
    renderDynamicTable(items);
    
    renderPagination(currentPage, res.total, ITEMS_PER_PAGE, (newPage) => {
      loadPage(newPage);
    });
    
  } catch (error) {
    console.error("Failed to load page data:", error);
  }
}

loadPage(1);