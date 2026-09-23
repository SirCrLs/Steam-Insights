import { GamesAPI, UsersAPI, AchievementsAPI, UserGamesAPI, UserAchievementsAPI } from './api.js';
import { renderDynamicTable } from './table-render.js';
import { renderPagination } from './page-render.js'; 

const ITEMS_PER_PAGE = 100;
let currentPage = 1;
let currentEntity = 'games';

const API_MAP = {
  games: GamesAPI,
  users: UsersAPI,
  achievements: AchievementsAPI,
  user_games: UserGamesAPI,
  user_achievements: UserAchievementsAPI 
};

async function loadData(offset) {
  const api = API_MAP[currentEntity];
  
  if (!api) {
    throw new Error(`Entity not found: ${currentEntity}`);
  }

  return await api.getAll(ITEMS_PER_PAGE, offset);
}

export async function loadPage(page = 1) {
  currentPage = page;
  const offset = (currentPage - 1) * ITEMS_PER_PAGE;

  try {
    const res = await loadData(offset);
    const items = res.games || res.users || res.achievements || res.user_games || res.user_achievements || [];
    
    renderDynamicTable(items);
    renderPagination(currentPage, res.total, ITEMS_PER_PAGE, (newPage) => {
      loadPage(newPage);
    });
    
  } catch (error) {
    console.error("Error loading data:", error);
  }
}

export function changeEntity(newEntity) {
  if (API_MAP[newEntity]) {
    currentEntity = newEntity;
    loadPage(1); 
  }
}