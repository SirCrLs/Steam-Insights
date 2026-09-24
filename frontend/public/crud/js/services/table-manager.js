import { GamesAPI, UsersAPI, AchievementsAPI, UserGamesAPI, UserAchievementsAPI, QueryAPI } from './api.js';
import { renderDynamicTable } from './table-render.js';
import { renderPagination } from './page-render.js'; 
import { handleViewAction, handleEditAction, handleDeleteAction } from './actions-manager.js';

const ITEMS_PER_PAGE = 100;
export let currentPage = 1;
export let currentEntity = 'games';
export let currentTableData = [];

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

    currentTableData = items;
    
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

// Free query on Terminal
export function initQueryForm() {
  const queryForm = document.getElementById('query-form');
  const queryInput = document.getElementById('query-input');

  if (queryForm) {
    queryForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const sqlQuery = queryInput.value.trim();
      if (!sqlQuery) return;

      try {
        const result = await QueryAPI.execute(sqlQuery);
        renderDynamicTable(result);
      } catch (error) {
        console.error("Error on execute of SQL:", error);
        alert("Error: " + (error.message || "Verify is a valid SELECT"));
      }
    });
  }
}

export function initTableActions() {
  const tableContainer = document.querySelector('#table-container') || document.body;

  tableContainer.addEventListener('click', async (e) => {
    const viewBtn = e.target.closest('.btn-view');
    if (viewBtn) {
      await handleViewAction(viewBtn);
      return;
    }

    const editBtn = e.target.closest('.btn-edit');
    if (editBtn) {
      handleEditAction(editBtn);
      return;
    }

    const deleteBtn = e.target.closest('.btn-delete');
    if (deleteBtn) {
      await handleDeleteAction(deleteBtn);
      return;
    }
  });
}