# BUILD & SURVIVE — update v3 spec (shared by all agents)

Project root: `/home/user/Rick-and-morty-/build-survive` (Roblox game, Luau, Rojo 7 project `default.project.json`).
Read `README.md` first for the overview. Code style: comments and ALL player-facing strings in Russian,
match surrounding code (tabs, naming, comment density, `--` section headers). Luau with type annotations
(`--!strict` is not used; plain typed Luau checked by luau-lsp with LuauSolverV2=false).

## User request (Russian, from the player/owner)
1. Doors became "1 block" — when you select the Door item it keeps the previous material size (2×2×2).
   A door must be a real door (default 4×7×1).
2. Ability to build UNDERGROUND bunkers (dig under the plot).
3. A shop of ready-made HOUSES and BUNKERS: the more expensive, the more modern, with AA turrets and even
   GUARDS (NPC soldiers) in the most expensive ones.
4. The path ("тропинка") was placed right on the floor and z-fights (floor/path flicker) — fix it, and fix any
   other coplanar z-fighting on the map.
5. An ADMIN PANEL to test everything else.

## Tools / commands (run from project root)
S=/tmp/claude-0/-home-user-Rick-and-morty-/2a349113-3a50-5418-8ce9-447cba3f51c2/scratchpad
- Type check (whole project, ~20 s):
  `LUAU_LSP=$S/luau-lsp/build/luau-lsp ROBLOX_DEFS=$S/luau-lsp/scripts/globalTypes.None.d.luau sh tools/check.sh`
  While packages are developed in parallel you may see errors in files owned by OTHER packages — ignore those,
  but your own files must be clean.
- Property names of generated model JSON vs Roblox API: `python3 tools/check_props.py $S/rct/API-Dump.json`
- Roblox API reference: `$S/rct/API-Dump.json` (check class/property/method names, NotScriptable/ReadOnly tags,
  e.g. `Terrain.Decoration` is NotScriptable). Roblox docs clone: `$S/creator-docs` (grep it).
- Pure-logic tests: `~/.cargo/bin/lune run tools/test.luau` (Lune 0.11: no TweenService/RunService/workspace;
  `luau.load` needs a flat env table — see the harness at the top of tools/test.luau). New test files must
  copy that harness (do not edit tools/test.luau unless you own it).
- DO NOT run `sh build.sh` / `rojo build` / `git commit` — the integrator does that. Generator scripts you own
  (gen_map.py for MAP, gen_prefabs.py for PREFABS) you may run.
- There is no Roblox Studio here. Be extremely careful with Roblox API correctness: every property/method you
  use must exist (check API-Dump.json), avoid deprecated APIs, avoid yields in hot loops, server-authoritative
  validation for every remote.

## Already pre-wired by the lead (do not redo)
- `Config.Underground = { Depth = 24, Cell = 4, DigCooldown = 0.08 }`, `Config.Admins = {}` (Shared/Config.lua)
- Net remotes: RemoteFunctions `Dig`, `BuyPrefab`, `PlacePrefab`, `Admin`; RemoteEvent `GuardShot` (Shared/Net.lua)
- Sounds: `Dig`, `GuardShot` entries (Shared/Sounds.lua) — play via client `SoundPlayer`
- HUD: hotbar tool `{ key = "dig", icon = "⛏", name = "Копать", hotkey = "5" }`; right menu button
  `admin` (visible only when `player:GetAttribute("IsAdmin") == true`). `HUD.onMenu` fires "admin" →
  Client.client.lua calls `HUD.openModal("admin")` (AdminUI must `HUD.registerModal("admin", shade, onOpen, onClose)`).
- State fields: `State.digFill` (false = dig, true = fill back), `State.prefabs` (owned prefab keys, set from the
  `Data` event field `prefabs`, fires `State.changed("prefabs")`), `State.isAdmin`.
- Client.client.lua requires and inits `UI.AdminUI` (`AdminUI.init()`).
- Main.server.lua: requires `Server.Underground`, `Server.PrefabShop`, `Server.Admin`; calls
  `Plots.init()`, `Underground.init()`, then in a task: `TerrainGen.build(); Underground.carveAll()`, `Admin.init()`;
  binds remotes: `Dig → Building.dig`, `BuyPrefab → PrefabShop.buy`, `PlacePrefab → PrefabShop.place`,
  `Admin → Admin.handle`. Remote handlers have signature `(player, ...) -> (boolean, string?)` (only two values
  are returned to the client). On player join: `Building.restore(plot, profile.Auto)` (applies dig mask too).
  On leave: `Building.clear(plot); Underground.reset(plot)`.

## Coordinate conventions (existing)
Plot-local space: origin at plot centre on floor level, +Y up. `plot.cf` is the plot CFrame (rotated, NOT
world-axis aligned). Build zone X,Z ∈ [-32, 32] (Config.PlotSize = 64×96×64). Blocks are axis-aligned in plot
space, integer-aligned min corners, 24 rotations (`Grid.Rotations`). Serializer stores pos×2 and sizes.

## UNDERGROUND design (cells)
- Cell size C = 4, depth D = 24 → NX = 16, NY = 6, NZ = 16, COUNT = 1536.
- Cell (ix, iy, iz), all 1-based. ix,iz ∈ 1..16; iy ∈ 1..6 where iy = 1 is the TOP layer.
  Local bounds: x ∈ [-32 + 4(ix-1), -32 + 4ix], z likewise, y ∈ [-4·iy, -4·(iy-1)].
- Linear index (0-based): `i = (iy-1)*256 + (iz-1)*16 + (ix-1)`.
- Mask = set of DUG cells `{ [i]: true }`. Text encoding (hex bitset, exactly 384 lowercase hex chars):
  hex char k (1-based position k) encodes cells 4(k-1) .. 4(k-1)+3; bit value 1 = cell 4(k-1), 2 = next, 4, 8.
  Empty mask encodes to "" (empty string). Decoding "" / nil / invalid → empty mask.
- Undug cell = solid soil. The top layer (iy = 1) also contains the concrete floor slab (y ∈ [-2, 0]).
- Dig rule: a cell may be dug if it is not dug and is EXPOSED: iy == 1, or any of its 6 neighbours (inside the
  grid) is dug. Fill rule: a dug cell may be filled back if no block overlaps it and no character is inside it.
- A block (any part of whose AABB is below y = 0) is valid only if EVERY cell its AABB overlaps (strictly, eps
  0.01) below y = 0 is dug. Blocks may go down to y = -24 (Grid.inBounds lower bound becomes -Depth).
- Rendering (server builds parts; they replicate): plot model children
  - `Ground` (Folder): rebuilt parts. Per layer iy, greedy 2-D rectangles of UNDUG cells. Layer 1 rectangles →
    two parts: `Slab` (concrete, y [-2,0], Material Concrete, Color (164,166,164)) and `Soil` (y [-4,-2]).
    Layers 2..6 → one `Soil` part per rectangle, 4 thick. Every part has attribute `Layer = iy`, Anchored,
    CanTouch = false. Soil: Material Ground, colours darker with depth (e.g. (118,92,64) → (86,70,56)), layers
    5–6 may use Slate/Rock. These parts are solid and queryable (projectiles and build rays hit them).
  - `Foundation` (Folder, static, generated by gen_map.py): `Bedrock` under the pit (y [-27,-24], 76×3×76) and four
    `Rim` walls around the zone (6 studs thick, X or Z from ±32 to ±38, y from -27 to -0.1). Concrete, dark.
  - `GridPlane` (Part, 64×0.2×64, top at y = +0.05, Transparency 1, CanCollide/CanQuery/CanTouch false,
    CastShadow false): the client build-grid SurfaceGui is adorned to its Top face.
  - The old `Base` and `Skirt` parts are REMOVED. gen_map.py emits the undug placeholder state in `Ground`
    (`Slab` 64×2×64 at y [-2,0] with Layer=1 and one `Soil` 64×22×64 at y [-24,-2]) so the place looks right in
    Studio edit mode; the server rebuilds `Ground` at start.
- Replication: server sets plot model attribute `Dug` = hex mask string after every change (client decodes it to
  validate ghosts and dig cursor).
- Terrain: the island terrain under the plot is carved at runtime by `Underground.carveAll()`:
  `workspace.Terrain:FillBlock(plot.cf * CFrame.new(0, -13.25, 0), Vector3.new(72, 26.5, 72), Enum.Material.Air)`
  for each plot (Rim walls hide the voxel jag).
- Cover/damage: Ground and Foundation parts block explosions and lasers (they are not damageable).
  In `Damage.cover` and block occlusion they count as layers: Soil blast 0.8 / nuke 0.62, Slab blast 0.62 /
  nuke 0.5, Rim/Bedrock 0.9 / 0.8 (per 2 studs of thickness, same formula as blocks).

### Shared module `src/ReplicatedStorage/Shared/Underground.lua` (pure, testable, owned by UG_SERVER)
```
UG.CELL, UG.DEPTH, UG.NX, UG.NY, UG.NZ, UG.COUNT
UG.index(ix, iy, iz): number
UG.coords(i): (number, number, number)
UG.inRange(ix, iy, iz): boolean
UG.cellCenter(ix, iy, iz): Vector3                -- plot-local
UG.cellAt(p: Vector3): (number?, number?, number?) -- plot-local point → cell or nil if outside the volume
UG.cellsInBox(center: Vector3, extents: Vector3): { number } -- cells overlapped below y=0 (strict, eps 0.01)
UG.isExposed(dug: { [number]: boolean }, ix, iy, iz): boolean
UG.encode(dug): string     -- "" or 384 hex chars
UG.decode(hex: string?): { [number]: boolean }
UG.count(dug): number
UG.layerRects(dug, iy): { { x0: number, z0: number, w: number, d: number } } -- greedy rects of UNDUG cells (1-based cell coords, w along X, d along Z)
```

### Serializer v2 (Shared/Serializer.lua, owned by UG_SERVER)
- `Serializer.encode(specs, digHex: string?)`: if digHex is non-empty → `"v2|" .. blocks .. "|" .. digHex`,
  otherwise the old `"v1|" .. blocks`. Blocks part identical to v1 (`;`-separated, 11 comma fields).
- `Serializer.decode(str)` accepts v1 and v2 (v2 may have an empty blocks part: `"v2||<hex>"`).
- `Serializer.dig(str): string?` → the hex part of a v2 string, else nil.
- `Serializer.count(str)` counts blocks for v1 and v2.

### Server module `src/ServerScriptService/Server/Underground.lua` (owned by UG_SERVER)
```
Underground.init()                       -- each plot: plot.dug = {}, rebuild all layers, attribute Dug = ""
Underground.carveAll()                   -- terrain carve (see above), safe to call more than once
Underground.rebuild(plot, iy: number?)   -- nil = all layers
Underground.setMask(plot, dug)           -- replace mask, rebuild, update attribute
Underground.reset(plot)                  -- empty mask (all soil)
Underground.isClear(plot, center, extents): boolean
Underground.digCell(plot, i, fill: boolean): (boolean, string?) -- validated toggle (exposure / no blocks /
                                         -- no characters), rebuild that layer, attribute; no undo, no cooldown
Underground.encode(plot): string
```
`Building.dig(player, ix, iy, iz, fill)` (remote handler, in Building.lua) does ownership, `Building.canEdit`,
cooldown (`Config.Underground.DigCooldown`), argument validation, calls `Underground.digCell`, pushes undo
`{ type = "dig", index = i, fill = fill }`. `Building.undo` reverses dig actions. `Building.pushUndo(plot, action)`
becomes PUBLIC (PrefabShop uses it). `Building.serialize` includes the dig hex. `Building.restore(plot, str,
withUndo)` = optional undo snapshot → clear blocks → `Underground.setMask(plot, UG.decode(Serializer.dig(str)))`
→ `loadString`. The "clear" undo branch must use the same restore path. `Building.loadString` and
`Building.place` reject blocks below y = 0 whose cells are not dug ("Сначала выкопай здесь землю — инструмент
«Копать» (5)").
`Plots`: fields `ground: Folder`, `foundation: Folder`, `gridPlane: BasePart`, `dug: { [number]: boolean }`;
`base` removed; `isInBuildZone` lower Y bound → `-(Depth + 6)`.

## GUARD item (owned by GUARDS)
`Blocks.Items` entry id 13: `{ id = 13, key = "Guard", name = "Охранник", size = Vector3.new(2, 5, 2),
material = Fabric, color = (72, 86, 60), hp = 350, price = 9000, density = 1,
desc = "Солдат с автоматом: сбивает ракеты и дроны рядом с собой." }`, plus `Blocks.GuardRange = 55`,
`Blocks.GuardCooldown = 0.55`, `Blocks.GuardChance = 0.5` (multiplied by weapon `aa`).
Not resizable. Faces local -Z (front). Server-authoritative interception in server `Projectiles.lua`; event
`GuardShot` payload `{ from: Vector3 (muzzle), to: Vector3, g: BasePart (guard block) }`.

## Door fix (owned by GUARDS)
`Blocks.Items` Door gets `minSize = Vector3.new(2, 5, 1)`; `Blocks.normalizeSize` clamps resizable items to
`minSize`. `State.selectBlock` remembers the size per selection (`"mat"` shares one size for all materials;
each resizable item has its own, defaulting to the item's `size`) so selecting Door gives 4×7×1.

## PREFABS (houses & bunkers)
Data module `src/ReplicatedStorage/Shared/Prefabs.lua` GENERATED by `tools/gen_prefabs.py` (owned by PREFABS):
```lua
return {
	{
		key = "Cabin", kind = "house", -- "house" | "bunker"
		tier = 1,                       -- 1..5
		name = "Хижина", icon = "🛖", price = 400,
		desc = "…", features = { "…", "…" }, -- short Russian bullet points
		blocks = 87,                    -- block count
		guards = 0, aa = 0, shields = 0, medkits = 0,
		data = "v1|…",                  -- houses: v1; bunkers: v2 with dig mask
	},
	…
}
```
Order: houses tier 1..5 then bunkers tier 1..5. Keys: houses `Cabin`, `BrickHouse`, `Cottage`, `Villa`,
`Mansion`; bunkers `Cellar`, `Shelter`, `MilitaryBunker`, `CommandBunker`, `DoomsdayBunker`.
Prices: houses 400 / 1500 / 5000 / 14000 / 40000; bunkers 600 / 2500 / 9000 / 20000 / 50000.
Zones: house blocks x,z ∈ [-22, 22], y ∈ [0, 60]. Bunker blocks: underground anywhere inside DUG cells
(y ∈ [-24, 0)); a bunker's surface part (entrance kiosk) only inside x,z ∈ [24, 32] (cells ix,iz ∈ {15,16}),
y ≥ 0. Every dug cell must be reachable from the surface through dug cells (6-neighbour BFS from iy = 1).
Limits: tier-5 house ≤ 650 blocks, tier-5 bunker ≤ 650 blocks. Guards only in house tiers 4–5 and bunker tiers
4–5; AA turrets from tier 3; shield generator in tier 5.

Placing (server `PrefabShop.place`, owned by SHOP): house → remove existing blocks overlapping the house
bounding box (all blocks whose AABB intersects the prefab AABB grown by 1 stud on X/Z), then create the prefab
blocks. Bunker → remove ALL blocks below y = 0 and blocks overlapping the kiosk zone box, set the mask to the
prefab mask, create blocks. Before changing anything: snapshot undo `{ type = "clear", data = Building.serialize(plot) }`
via `Building.pushUndo`; refuse (no change) if the result would exceed Config.MaxBlocks; refuse during
siege/launch (`Building.canEdit`). Prefab blocks bypass the unlock check (`Building.create` directly).
`Data` profile gets `Prefabs: { [string]: boolean }` and `Data.sync` sends `prefabs`.
`PrefabShop.buy(player, key)`, `PrefabShop.place(player, key, free: boolean?)` (free/owned bypass for admin).

## ADMIN (owned by ADMIN)
Server `Admin.lua`: `Admin.init()` (sets `player:SetAttribute("IsAdmin", true)` for admins on join),
`Admin.isAdmin(player)` = `RunService:IsStudio()` or `player.UserId == game.CreatorId` (CreatorType User) or
group owner (CreatorType Group and `GetRankInGroup >= 255`, pcall) or listed in `Config.Admins`.
`Admin.handle(player, cmd: string, arg: any) -> (boolean, string?)` — re-check admin EVERY call.
Client `src/ReplicatedStorage/Client/UI/AdminUI.lua` (modal "admin", hotkey F2).
