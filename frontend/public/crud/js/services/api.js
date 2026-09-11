const API_BASE_URL = '/api';

async function request(endpoint, options = {}) {
  const config = {
    ...options,
    credentials: 'include', 
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...options.headers
    }
  };

  try {
    const response = await fetch(`${API_BASE_URL}${endpoint}`, config);

    if (response.status === 204) return null;

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || data.message || `Error ${response.status}`);
    }

    return data;
  } catch (error) {
    console.error(`Error en petición a ${endpoint}:`, error);
    throw error;
  }
}

function buildPaginationQuery(limit, offset) {
  const params = new URLSearchParams();
  if (limit !== undefined && limit !== null) params.append('limit', limit);
  if (offset !== undefined && offset !== null) params.append('offset', offset);
  const queryString = params.toString();
  return queryString ? `?${queryString}` : '';
}

// 1. USERS
export const UsersAPI = {
  getAll: (limit = 100, offset = 0) => 
    request(`/users${buildPaginationQuery(limit, offset)}`),

  getById: (steamId) => 
    request(`/users/${steamId}`),

  create: (userData) => request('/users', {
    method: 'POST',
    body: JSON.stringify(userData)
  }),

  update: (steamId, userData) => request(`/users/${steamId}`, {
    method: 'PUT',
    body: JSON.stringify(userData)
  }),

  delete: (steamId) => request(`/users/${steamId}`, {
    method: 'DELETE'
  })
};

// 2. GAMES
export const GamesAPI = {
  getAll: (limit = 100, offset = 0) => request(`/games${buildPaginationQuery(limit, offset)}`),
  getById: (appId) => request(`/games/${appId}`),

  create: (gameData) => request('/games', {
    method: 'POST',
    body: JSON.stringify(gameData)
  }),

  update: (appId, gameData) => request(`/games/${appId}`, {
    method: 'PUT',
    body: JSON.stringify(gameData)
  }),

  delete: (appId) => request(`/games/${appId}`, {
    method: 'DELETE'
  })
};

// 3. ACHIEVEMENTS
export const AchievementsAPI = {
  getAll: (limit = 100, offset = 0) => 
    request(`/achievements${buildPaginationQuery(limit, offset)}`),

  getByGameId: (appId, limit = 100, offset = 0) => 
    request(`/achievements/${appId}${buildPaginationQuery(limit, offset)}`),

  create: (achievementData) => request('/achievements', {
    method: 'POST',
    body: JSON.stringify(achievementData)
  }),

  update: (key, appId, achievementData) => request(`/achievements/${key}/${appId}`, {
    method: 'PUT',
    body: JSON.stringify(achievementData)
  }),

  delete: (key, appId) => request(`/achievements/${key}/${appId}`, {
    method: 'DELETE'
  })
};

// 4. USERS_GAMES
export const UsersGamesAPI = {

  getUserGames: (steamId, limit = 100, offset = 0) => 
    request(`/users/${steamId}/games${buildPaginationQuery(limit, offset)}`),
  getOneGameFromUser: (steamId, appId) => 
    request(`/users/${steamId}/games/${appId}`),

  upsertGameForUser: (steamId, userGamePayload) => request(`/users/${steamId}/games`, {
    method: 'POST',
    body: JSON.stringify({
      steamId: steamId,
      ...userGamePayload
    })
  }),

  removeGameFromUser: (steamId, appId) => request(`/users/${steamId}/games/${appId}`, {
    method: 'DELETE'
  })
};

// 5. USERS_ACHIEVEMENTS
export const UsersAchievementsAPI = {
  getUserAchievements: (steamId, limit = 100, offset = 0) => 
    request(`/users/${steamId}/achievements${buildPaginationQuery(limit, offset)}`),

  getUserAchievementsByGame: (steamId, appId, limit = 100, offset = 0) => 
    request(`/users/${steamId}/achievements/${appId}${buildPaginationQuery(limit, offset)}`),

  upsertUserAchievement: (steamId, achievementPayload) => request(`/users/${steamId}/achievements`, {
    method: 'PUT',
    body: JSON.stringify({
      steamId: steamId,
      ...achievementPayload
    })
  }),

  removeAllAchievementsFromGame: (steamId, appId) => 
    request(`/users/${steamId}/achievements/${appId}`, {
      method: 'DELETE'
    }),

  removeSpecificAchievement: (steamId, appId, achievementKey) => 
    request(`/users/${steamId}/achievements/${appId}/${achievementKey}`, {
      method: 'DELETE'
    })
};