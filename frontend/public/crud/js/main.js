import { GamesAPI } from '/crud/js/services/api.js';
import { renderDynamicTable } from '/crud/js/services/table-render.js';

const res = await GamesAPI.getAll(100, 0);
renderDynamicTable(res.games);