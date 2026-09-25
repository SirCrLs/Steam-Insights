import { currentPage, currentEntity, currentTableData } from './table-manager.js'
import { GamesAPI, UsersAPI, AchievementsAPI, UserGamesAPI, UserAchievementsAPI } from './api.js';
import { formatGamePayload, formatUserPayload, formatAchievementPayload, formatUserAchievementPayload, formatUserGamePayload } from './models.js'

async function getOneFromAPI(rowData){
  switch (currentEntity) {
    case 'games':
      return await GamesAPI.getById(rowData.appId);
    case 'users':
      return await UsersAPI.getById(rowData.steamId);
    case 'achievements':
      return await AchievementsAPI.getOne(rowData.appId, rowData.achievementKey);
    case 'user_games':
      return await UserGamesAPI.getOneGameFromUser(rowData.steamId, rowData.appId);
    case 'user_achievements':
      return await UserAchievementsAPI.getOne(rowData.steamId, rowData.appId, rowData.achievementKey);
    default:
      throw new Error("Entity not supported for View");
	}
}

function getRowDataFromButton(button) {
  const index = parseInt(button.getAttribute('data-index'), 10);
  return currentTableData[index];
}

export async function handleViewAction(button) {
  const rowData = getRowDataFromButton(button);
  if (!rowData) return;

  try {
    let details;
    details = await getOneFromAPI(rowData);
    openViewModal(details);
  } catch (error) {
    console.error("Error on view", error);
    alert("Could not load details: " + (error.message || "Unknown Error"));
  }
}

export async function handleEditAction(button) {
  const rowData = getRowDataFromButton(button);
  if (!rowData) return;

  try {
    let details;
    details = await getOneFromAPI(rowData);
    openEditModal(details);
  } catch (error) {
    console.error("Error on edit", error);
    alert("Could not load details: " + (error.message || "Unknown Error"));
  }
}

export async function handleDeleteAction(button) {
  const rowData = getRowDataFromButton(button);
  if (!rowData) return;

  const confirmed = window.confirm("Sure you want to delete it?");
  if (!confirmed) return;

  try {
    switch (currentEntity) {
      case 'games':
        await GamesAPI.delete(rowData.appId);
        break;
      case 'users':
        await UsersAPI.delete(rowData.steamId);
        break;
      case 'achievements':
        await AchievementsAPI.delete(rowData.achievementKey, rowData.appId);
        break;
      case 'user_games':
        await UserGamesAPI.removeGameFromUser(rowData.steamId, rowData.appId);
        break;
      case 'user_achievements':
        await UserAchievementsAPI.removeSpecificAchievement(rowData.steamId, rowData.appId, rowData.achievementKey);
        break;
      default:
        throw new Error("Entity not supported for delete");
    }

    loadPage(currentPage);
  } catch (error) {
    console.error("Error on delete", error);
    alert("Data couldn't be deleted: " + (error.message || "Unknown Error"));
  }
}


function openViewModal(details) {
  const modalBody = document.querySelector('#view-modal-body');
  const modal = document.querySelector('#view-modal');

  modalBody.innerHTML = `
    <ul style="list-style: none; padding: 0; max-height: 60vh; overflow-y: auto;">
      ${Object.entries(details)
        .map(([key, value]) => `
          <li style="margin-bottom: 10px; border-bottom: 1px solid #eee; padding-bottom: 6px;">
            <strong style="color: #333; text-transform: capitalize;">${key}:</strong> 
            <span style="color: #555; word-break: break-all;">${value ?? 'N/A'}</span>
          </li>
        `)
        .join('')}
    </ul>
  `;

  modal.showModal();
}

function openEditModal(details) {
  const formBody = document.querySelector('#edit-form-body');
  const modal = document.querySelector('#edit-modal');

  formBody.innerHTML = Object.entries(details)
    .map(([key, value]) => {
      const isReadOnly = key === 'steamId' || key === 'appId' || key === 'achievementKey';
      
      return `
        <div style="margin-bottom: 10px;">
          <label style="display: block; font-size: 12px; font-weight: bold;">${key}</label>
          <input 
            type="text" 
            name="${key}" 
            value="${value ?? ''}" 
            ${isReadOnly ? 'readonly style="background-color: #eee;"' : ''}
            style="width: 100%; padding: 6px;"
          />
        </div>
      `;
    })
    .join('');

  const form = document.querySelector('#edit-form');
  
  form.onsubmit = async (e) => {
    e.preventDefault();
    const formData = new FormData(form);
    const updatedData = Object.fromEntries(formData.entries());

    try {
      await updateEntityAPI(details, updatedData);
      
      modal.close();
    } catch (err) {
      console.error("Error updating:", err);
      alert("Could not update: " + err.message);
    }
  };

  modal.showModal();
}

async function updateEntityAPI(originalData, newData) {
  switch (currentEntity) {
    case 'users':
			const userPayload = formatUserPayload(originalData, newData);
      await UsersAPI.update(originalData.steamId, userPayload);
			break;
      
    case 'games':
      const gamePayload = formatGamePayload(originalData, newData);
      await GamesAPI.update(originalData.appId, gamePayload);      
      break;
      
    case 'achievements':
      const achievementPayload = formatAchievementPayload(originalData, newData);
      await AchievementsAPI.update(originalData.achievementKey, originalData.appId, achievementPayload);
      break;
      
    case 'user_games':
      const userGamePayload = formatUserGamePayload(originalData, newData);
      await UserGamesAPI.upsertGameForUser(originalData.steamId, userGamePayload);
      break;
      
    case 'user_achievements':
			const userAchievementPayload = formatUserAchievementPayload(originalData, newData);
      await UserAchievementsAPI.upsertUserAchievement(originalData.steamId, userAchievementPayload);
      break;
      
    default:
      throw new Error("Update not implemented for this entity");
  }
}