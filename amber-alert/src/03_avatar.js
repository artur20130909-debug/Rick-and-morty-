/* ================= АВАТАРЫ: варианты облика игрока (кожа, одежда, шапки, лица) ================= */
const SKINS = ['#f5cd30', '#ffcc99', '#e8b08a', '#c68a5a', '#8d5a3a', '#5a3825', '#f2f2f2'];
const SHIRTS = ['#0d69ac', '#c4281c', '#287f47', '#6b327b', '#1b2a35', '#e8e8e8', '#d9a400', '#ff6fb5', '#55a5ff', '#7a4a2a'];
const PANTS = ['#a4bd47', '#1b2a35', '#3a4a8a', '#5a5a5a', '#7a4a2a', '#c4281c', '#e8e8e8'];
const HATS = ['none', 'cap', 'beanie', 'headphones', 'hair', 'hood'];
const FACES = ['smile', 'grin', 'worried', 'cool'];
const DEFAULT_LOOK = { skin: 0, shirt: 0, pants: 0, hat: 'none', face: 'smile', hatColor: '#c4281c' };
function randomLook() { return { skin: (Math.random() * SKINS.length) | 0, shirt: (Math.random() * SHIRTS.length) | 0, pants: (Math.random() * PANTS.length) | 0, hat: pick(HATS), face: pick(FACES), hatColor: pick(SHIRTS) }; }

// Сам аватар теперь пиксельный спрайт — см. class Avatar в 02c_pxkit.js
