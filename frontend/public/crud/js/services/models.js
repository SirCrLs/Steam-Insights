export function formatGamePayload(originalData, newData) {
  const parseList = (val) => {
    if (!val) return null;
    if (Array.isArray(val)) return val;
    return typeof val === 'string' ? val.split(',').map(s => s.trim()).filter(Boolean) : null;
  };

  const parseIntSafe = (val) => {
    if (val === '' || val === undefined || val === null) return null;
    const parsed = parseInt(val, 10);
    return isNaN(parsed) ? null : parsed;
  };

  const parseFloatSafe = (val) => {
    if (val === '' || val === undefined || val === null) return null;
    const parsed = parseFloat(val);
    return isNaN(parsed) ? null : parsed;
  };

  const parseBool = (val) => {
    if (val === 'true' || val === true) return true;
    if (val === 'false' || val === false) return false;
    return null;
  };

  return {
    ...originalData,
    name: newData.name ?? originalData.name,
    shortDescription: newData.shortDescription || null,
    genres: parseList(newData.genres),
    categories: parseList(newData.categories),
    supportedLanguages: parseList(newData.supportedLanguages),
    headerImage: newData.headerImage || null,
    pcRequirementsMinimum: newData.pcRequirementsMinimum || null,
    pcRequirementsRecommended: newData.pcRequirementsRecommended || null,
    processorMinimum: newData.processorMinimum || null,
    processorRecommended: newData.processorRecommended || null,
    graphicsMinimum: newData.graphicsMinimum || null,
    graphicsRecommended: newData.graphicsRecommended || null,
    ramMinimumGb: parseIntSafe(newData.ramMinimumGb),
    ramRecommendedGb: parseIntSafe(newData.ramRecommendedGb),
    storageMinimumGb: parseIntSafe(newData.storageMinimumGb),
    storageRecommendedGb: parseIntSafe(newData.storageRecommendedGb),
    developers: newData.developers || null,
    isOnWindows: parseBool(newData.isOnWindows),
    isOnMac: parseBool(newData.isOnMac),
    isOnLinux: parseBool(newData.isOnLinux),
    metacriticScore: parseIntSafe(newData.metacriticScore),
    releaseDate: newData.releaseDate || null,
    priceUsd: parseFloatSafe(newData.priceUsd),
    isFree: parseBool(newData.isFree),
    rating: newData.rating || null,
    totalAchievements: parseIntSafe(newData.totalAchievements),
    recommendations: parseIntSafe(newData.recommendations),
    ownersMin: parseIntSafe(newData.ownersMin),
    ownersMax: parseIntSafe(newData.ownersMax),
    positiveReviews: parseIntSafe(newData.positiveReviews),
    negativeReviews: parseIntSafe(newData.negativeReviews),
    totalReviews: parseIntSafe(newData.totalReviews),
    approvalRate: parseFloatSafe(newData.approvalRate),
    fetchedAt: newData.fetchedAt || null
  };
}

export function formatUserPayload(originalData, newData) {
  const parseBool = (val) => {
    if (val === 'true' || val === true) return true;
    if (val === 'false' || val === false) return false;
    return null;
  };

  return {
    ...originalData,
    steamId: originalData.steamId,
    personaName: newData.personaName || null,
    profileUrl: newData.profileUrl || null,
    avatarUrl: newData.avatarUrl || null,
    countryCode: newData.countryCode || null,
    accountCreated: newData.accountCreated || null,
    isPublic: parseBool(newData.isPublic),
    hasPublicGames: parseBool(newData.hasPublicGames),
    hasPublicAchievements: parseBool(newData.hasPublicAchievements),
    gamesFetched: parseBool(newData.gamesFetched),
    fetchedAt: newData.fetchedAt || null
  };
}

export function formatAchievementPayload(originalData, newData) {
  const parseFloatSafe = (val) => {
    if (val === '' || val === undefined || val === null) return null;
    const parsed = parseFloat(val);
    return isNaN(parsed) ? null : parsed;
  };

  return {
    ...originalData, 
    appId: originalData.appId, 
    achievementKey: originalData.achievementKey, 
    displayName: newData.displayName || null,
    achievementDesc: newData.achievementDesc || null,
    globalUnlockPct: parseFloatSafe(newData.globalUnlockPct)
  };
}

export function formatUserGamePayload(originalData, newData) {
  const parseIntSafe = (val) => {
    if (val === '' || val === undefined || val === null) return null;
    const parsed = parseInt(val, 10);
    return isNaN(parsed) ? null : parsed;
  };

  return {
    ...originalData, 
    steamId: originalData.steamId, 
    appId: originalData.appId,
    playtimeForever: parseIntSafe(newData.playtimeForever),
    playtime2weeks: parseIntSafe(newData.playtime2weeks),
    achievementsStatus: newData.achievementsStatus || null
  };
}

export function formatUserAchievementPayload(originalData, newData) {
  return {
    ...originalData, 
    steamId: originalData.steamId,
    appId: originalData.appId,  
    achievementKey: originalData.achievementKey, 
    unlocktime: newData.unlocktime || null  
  };
}