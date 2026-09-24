import { currentPage, currentEntity, currentTableData } from './table-manager.js'
import { GamesAPI, UsersAPI, AchievementsAPI, UserGamesAPI, UserAchievementsAPI } from './api.js';

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
    details = getOneFromAPI(rowData);
    openViewModal(details);
  } catch (error) {
    console.error("Error on view", error);
    alert("Could not load details: " + (error.message || "Unknown Error"));
  }
}

export function handleEditAction(button) {
  const rowData = getRowDataFromButton(button);
  if (!rowData) return;

  try {
    let details;
    details = getOneFromAPI(rowData);
    openEditModal(details);
  } catch (error) {
    console.error("Error on view", error);
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

export async function handleUserEditSubmit(event, originalSteamId) {
  event.preventDefault();
  
  const formData = new FormData(event.target);
  const updatedData = {
    personaName: formData.get('personaName'),
    profileUrl: formData.get('profileUrl'),
  };

  try {
    await UsersAPI.update(originalSteamId, updatedData);
    
    closeEditModal();
    loadPage(currentPage); 
  } catch (error) {
    console.error("Error updating user:", error);
    alert("Could not update: " + error.message);
  }
}