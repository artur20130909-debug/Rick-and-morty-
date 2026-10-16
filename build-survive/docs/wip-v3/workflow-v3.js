export const meta = {
  name: 'build-survive-v3',
  description: 'Underground bunkers, prefab house/bunker shop with guards, door fix, path z-fight fix, admin panel — implement, integrate, review, fix, screenshots',
  phases: [
    { title: 'Implement', detail: '7 parallel packages with disjoint file ownership' },
    { title: 'Integrate', detail: 'run all generators/checks/tests/build, fix cross-package mismatches' },
    { title: 'Review', detail: '4 adversarial reviewers by dimension' },
    { title: 'Fix', detail: 'verify each finding, fix confirmed ones, re-run checks' },
    { title: 'Screenshots', detail: 'preview renders of new content + README' },
  ],
}

const ROOT = '/home/user/Rick-and-morty-/build-survive'
const S = '/tmp/claude-0/-home-user-Rick-and-morty-/2a349113-3a50-5418-8ce9-447cba3f51c2/scratchpad'
const SPEC = S + '/SPEC_v3.md'

const PREAMBLE = `You are one of 7 implementers working IN PARALLEL in the same working tree on a Roblox game (Luau + Rojo).
Project root: ${ROOT}. FIRST read the shared spec ${SPEC} completely, then README.md, then the files you own and the files they interact with.
STRICT FILE OWNERSHIP: you may create/edit ONLY the files listed as yours below. Other agents are editing other files right now — never touch them (not even formatting). If you need a change in a file you do not own, describe it precisely in your result under "requests".
Quality bar: this is a game the user will open in Roblox Studio; nothing can be tested in Studio here, so every Roblox API you use must be verified against ${S}/rct/API-Dump.json (class, property, method names; NotScriptable/ReadOnly) and ${S}/creator-docs when unsure. Server must validate every remote argument (type, range, ownership). All comments and player-facing strings in Russian, matching the existing style. Keep code clean and readable like the surrounding code.
Do NOT run sh build.sh / rojo build / git commit. Run the type checker on the project (command in the spec) and make sure YOUR files have no errors (errors caused by other packages' unfinished files are expected while everyone works in parallel; code against the interfaces in the spec).
When done, return a structured result.`

const RESULT_SCHEMA = {
  type: 'object',
  properties: {
    summary: { type: 'string', description: 'what you implemented, key design decisions (concise but complete)' },
    files_changed: { type: 'array', items: { type: 'string' } },
    requests: { type: 'array', items: { type: 'string' }, description: 'precise changes needed in files owned by other packages' },
    checks: { type: 'string', description: 'which checks you ran and their results' },
    open_issues: { type: 'array', items: { type: 'string' } },
  },
  required: ['summary', 'files_changed', 'requests', 'checks', 'open_issues'],
}

const PACKAGES = [
  {
    key: 'UG_SERVER',
    prompt: `${PREAMBLE}

PACKAGE UG_SERVER — underground core (shared math, serializer v2, server state/render, building/damage integration).
Files you own: src/ReplicatedStorage/Shared/Underground.lua (NEW), src/ReplicatedStorage/Shared/Serializer.lua, src/ReplicatedStorage/Shared/Grid.lua, src/ServerScriptService/Server/Underground.lua (NEW), src/ServerScriptService/Server/Building.lua, src/ServerScriptService/Server/Plots.lua, src/ServerScriptService/Server/Damage.lua, src/ServerScriptService/Server/Launch.lua, tools/test_underground.luau (NEW).

Implement exactly the interfaces in the spec sections "UNDERGROUND design", "Shared module", "Serializer v2", "Server module".
Details and requirements:
- Shared/Underground.lua: pure functions only (requires Config via script.Parent.Config). Greedy rectangle meshing per layer must cover exactly the undug cells with no overlap (grow along X first, then along Z).
- Server/Underground.lua: per-plot state plot.dug; rebuild(plot, iy) destroys only parts in plot.ground with attribute Layer == iy and recreates them from UG.layerRects (layer 1 → Slab y[-2,0] + Soil y[-4,-2]; deeper → Soil 4 thick). Parts: Anchored, CanTouch=false, CastShadow=true, Locked=true, TopSurface/BottomSurface Smooth, Material Concrete for Slab, Ground (or Mud/Slate/Rock for deeper layers — verify those Enum.Material values are valid for BasePart) for Soil with colours darkening with depth. Name "Slab" / "Soil". Set plot.model attribute "Dug" to UG.encode(plot.dug) after every change. carveAll() carves terrain per spec (FillBlock with the plot-rotated CFrame). isClear uses UG.cellsInBox. digCell validates: in range, dig → not dug and UG.isExposed; fill → dug, no block overlapping (workspace:GetPartBoundsInBox with Include {plot.blocks}, box shrunk by 0.1), no character part inside the cell (Include all player characters). Return Russian error messages.
- Plots.lua: replace base with ground/foundation/gridPlane (WaitForChild "Ground", "Foundation", "GridPlane" — the MAP agent generates them), plot.dug = {}, isInBuildZone lower bound -(Depth+6). Keep the exported Plot type updated.
- Grid.inBounds: lower Y bound = -Config.Underground.Depth.
- Building.lua: Building.dig(player, ix, iy, iz, fill) remote handler (validate numbers are integers in range, fill is boolean, ownership via Plots.of, Building.canEdit, per-player cooldown Config.Underground.DigCooldown, then Underground.digCell, then pushUndo { type = "dig", index = i, fill = fill }); Building.pushUndo public; undo of dig = reverse digCell (skip silently if it is no longer valid); serialize includes UG hex via Serializer.encode(specs, hex); restore(plot, str, withUndo) applies the mask BEFORE loading blocks; "clear" undo uses restore; place/loadString/undo-of-delete reject blocks under y=0 in undug cells with the Russian message from the spec. Keep everything else working (siege snapshot/restore, slots, examples, starter house).
- Damage.lua: Ground/Foundation parts act as cover in Damage.cover and in the block-occlusion check of Damage.explode (values in spec). Make sure underground blocks/players are properly protected by soil from surface explosions, while explosions that happen inside the pit still work normally. Keep laser behaviour (it already stops at the first hit).
- Launch.lua: read it; blocks below y=0 (underground) must not take part in a launch (they stay where they are, anchored) and must not break the launch logic.
- tools/test_underground.luau: copy the harness from tools/test.luau (do not edit test.luau) and test: index/coords round trip for all cells, cellCenter/cellAt consistency, cellsInBox edge cases (block exactly on cell boundaries, partially above ground, fully above ground → none), isExposed, encode/decode round trip ("" for empty, 384 hex chars, random masks), layerRects exact cover/no overlap for random masks, Serializer v1/v2 round trips incl. empty blocks with mask, Serializer.count, Grid.inBounds for underground positions. Run it with ~/.cargo/bin/lune run tools/test_underground.luau and also run tools/test.luau (must still pass; if an existing test in test.luau breaks because of your intended changes, put the needed test.luau edit into requests).`,
  },
  {
    key: 'UG_CLIENT',
    prompt: `${PREAMBLE}

PACKAGE UG_CLIENT — client side of underground building and the dig tool.
Files you own: src/ReplicatedStorage/Client/BuildController.lua (only this file).
Read also (do not edit): Shared/Underground.lua API in the spec (another agent is writing it right now — code against the spec API), Shared/Grid.lua, Client/State.lua, Client/UI/HUD.lua (hotbar already has tool "dig", hotkey "5"), Client/SoundPlayer.lua, Shared/Sounds.lua ("Dig" sound exists), Client/Fx.lua for effect style.
Implement:
1. Build raycasts include the plot model's "Ground" and "Foundation" folders plus "Blocks" (the old "Base" part no longer exists). Ghost placement works on Slab/Soil/Rim/Bedrock surfaces (you can build on the pit floor and against pit walls).
2. The build grid SurfaceGui is adorned to the plot's "GridPlane" part (Top face) instead of "Base".
3. Ghost validity underground: decode the plot model attribute "Dug" (cache, refresh on GetAttributeChangedSignal("Dug")) and mark the ghost invalid (red) if any cell overlapped below y=0 is not dug (UG.cellsInBox). Bounds check uses Grid.inBounds (lower bound is -Depth after UG_SERVER's change).
4. Delete/paint/pick/hover only ever target blocks (never Ground/Foundation parts).
5. Dig tool (State.tool == "dig", hotkey 5 toggles, also via HUD hotbar button which goes through the existing HUD.onTool wiring):
   - Dig mode (State.digFill == false): ray hits a Slab/Soil part → target cell = UG.cellAt(local(hitPos - normal*0.05)); valid if not dug and exposed (client-side pre-check using the decoded mask). Fill mode (State.digFill == true): ray hits any Ground/Foundation/block surface inside the pit → target cell = cell containing local(hitPos + normal*0.05); valid if dug (the server checks blocks/characters).
   - Visual cursor: a client-only, plot-rotated 4×4×4 box showing the target cell (e.g. a transparent part with a SelectionBox or thin neon edges; colour: dig = warm orange, fill = blue, invalid = red), plus a small label/hint. Must not be hit by raycasts (CanQuery=false) and must not cast shadows.
   - Click → Net.func("Dig"):InvokeServer(ix, iy, iz, fill); success → SoundPlayer.play("Dig") and a short dust burst at the cell (particles using rbxasset://textures/particles/smoke_main.dds, cleaned up); failure → HUD.toast(message, "error") like other actions.
   - Holding the mouse button digs continuously along the layer of the first cell (same pattern/debounce as the existing build hold: Config.HoldDelay then repeat about Config.HoldRepeat*1.5, never the same cell twice per drag, at most one request in flight).
   - F toggles dig/fill (update State.digFill and the hint); holding Shift inverts the mode for that click. Touch: a tap acts like a click (reuse the existing touch handling).
   - Hint text for the tool (Russian), e.g. "ЛКМ — копать землю • F — засыпать • копать можно на 24 стада вниз".
   - Respect canBuildNow() (no digging during siege/launch); the cursor hides when the tool is not "dig".
Keep all existing behaviour (double-click fixes, drag layer, debounce) intact. Make the code readable and consistent.`,
  },
  {
    key: 'MAP',
    prompt: `${PREAMBLE}

PACKAGE MAP — map generator changes and z-fighting fixes.
Files you own: tools/gen_map.py, tools/check_zfight.py (NEW), and the files gen_map.py generates: src/Workspace/Map.model.json, src/Workspace/Plots.model.json, src/ReplicatedStorage/Shared/MapLayout.lua, tools/preview/map.json.
Tasks:
1. Plots: remove parts "Base" and "Skirt". Add per spec: Folder "Ground" with placeholder parts "Slab" (64×2×64, y[-2,0], Concrete (164,166,164), attribute Layer=1) and "Soil" (64×22×64, y[-24,-2], Material Ground, attribute Layer=1? — give it Layer=2 is wrong; the server rebuilds everything anyway, so set attribute Layer=0 for the placeholder soil and document it), Folder "Foundation" with "Bedrock" (76×3×76, y[-27,-24]) and 4 "Rim" walls (6 thick, from ±32 to ±38, y from -27 to -0.1), dark concrete, and Part "GridPlane" (64×0.2×64, top at +0.05, Transparency 1, CanCollide/CanQuery/CanTouch false, CastShadow false). Check how gen_map.py emits attributes and properties so check_props.py stays green.
2. THE USER'S COMPLAINT: "the path was placed right on the floor and they glitch — sometimes the floor shows, sometimes the path" (z-fighting). The plot "Path" part (top at world 4.1) sits on the island terrain grass surface (world 4.0). Raise it clearly above the terrain (top ≈ world 4.5, bottom buried in the terrain), make it look nicer (e.g. curb stones / edging that also do not z-fight), and make sure where it meets the porch and the bridge there is no coplanar overlap. Also the lobby "InnerRing" top is only 0.02 above the "Plaza" top → fix (≥0.1 offset or redesign).
3. Write tools/check_zfight.py: load the generated parts (from tools/preview/map.json "parts" or by re-running the generator data) and detect z-fighting candidates: pairs of parts with parallel same-direction faces that are coplanar within 0.06 studs and whose face polygons overlap with area > 0.05 (handle rotated boxes; approximate cylinders' flat caps as polygons and their sides by their bounding box only for axis-aligned cylinders if simple; skip balls and wedge slopes), plus upward faces within 0.3 studs ABOVE or BELOW a terrain surface they overlap (island grass top is world y=4 inside radius r-1 of each island; also check other terrain ops in MapLayout if relevant). Print a report. Then fix every real z-fight it finds in gen_map.py (lobby, plots, towers, bridges, forts, trees, signs...), re-run until clean (or document intentional exceptions in the script with a reason).
4. Run python3 tools/gen_map.py and python3 tools/check_props.py ${S}/rct/API-Dump.json (must be clean) and python3 tools/check_zfight.py.
Do not change gameplay-relevant coordinates that Lua code depends on (FLOOR, plot centres, tower muzzle positions, spawns) unless required; the server code (owned by UG_SERVER) will WaitForChild "Ground", "Foundation", "GridPlane" in each Plot model.`,
  },
  {
    key: 'PREFABS',
    prompt: `${PREAMBLE}

PACKAGE PREFABS — ready-made houses and bunkers (data generator).
Files you own: tools/gen_prefabs.py (NEW), src/ReplicatedStorage/Shared/Prefabs.lua (GENERATED), tools/preview/prefabs.json (GENERATED), tools/test_prefabs.luau (NEW), build.sh (add running gen_prefabs.py; you may also add gen_examples.py if it is not run there).
Read first: spec section PREFABS (format, keys, prices, zones, limits) and UNDERGROUND (cell indexing and hex mask encoding), tools/gen_examples.py (helpers, rotation table matching Grid.Rotations order, item ids/sizes, colour hex format — reuse by importing it or copying carefully), Shared/Blocks.lua (materials and items; the Guard item id 13 size 2×5×2 is being added right now by another agent — use the spec values), Shared/Serializer.lua (v1 format; v2 = "v2|<blocks>|<384 hex>" per spec), Shared/Grid.lua, Shared/Util.lua (colorToHex), Shared/BlockFactory.lua (how items look: Door 4×7×1 frame+leaf facing ±Z, AATurret 3×2×3, Shield 3×3×3, Medkit, Lamp, Seat), tools/preview/examples.json + how preview.js uses it (produce prefabs.json in the same per-block format so the screenshot agent can render them).
Design 10 buildings — these are premium purchasable buildings, each must look clearly distinct, detailed and attractive, with an obvious progression from rustic to ultra-modern:
 Houses (kind "house", centred on the plot, front door facing -Z toward the spawn porch, footprint inside x,z ∈ [-22,22]):
  1 Cabin "Хижина" 400 — cosy wooden log cabin, porch, window, lamp, table+seat.
  2 BrickHouse "Кирпичный дом" 1500 — brick, glass windows with frames, pitched roof (wedges), chimney, 2 rooms, lamps.
  3 Cottage "Каменный коттедж" 5000 — stone+concrete, 2 floors with interior stairs, balcony, big windows, medkit, 1 AA turret on the roof.
  4 Villa "Современная вилла" 14000 — modern concrete + armour glass, flat cantilevered roofs, neon strip lighting, terrace, pool-like decor (glass/neon), garage, 1 AA turret, 2 guards at the entrance, medkit.
  5 Mansion "Особняк-крепость" 40000 — high-tech fortress mansion: titanium/steel/armour glass, crystal and neon accents, 3 floors, roof helipad-style deck, 2 AA turrets, 1 shield generator, 4 guards (entrance + roof), medkits.
 Bunkers (kind "bunker", data in v2 with the dig mask; entrance kiosk on the surface strictly inside x,z ∈ [24,32]; rooms underground; stairs/ramps (wedges) from the kiosk door down the shaft so a player can walk in; headroom ≥ 7 studs where doors are, ≥ 6 elsewhere; rooms lit with lamps):
  1 Cellar "Погреб" 600 — small wooden cellar, wooden hatch hut, shelves, lamp.
  2 Shelter "Бетонное убежище" 2500 — concrete room, metal door, beds (blocks), lamps, medkit.
  3 MilitaryBunker "Военный бункер" 9000 — steel+concrete, corridor and 2 rooms, armoury decor, medkit, AA turret on the kiosk roof.
  4 CommandBunker "Командный бункер" 20000 — lead+titanium, command room with neon screens, barracks, 2 guards, AA on kiosk, medkits.
  5 DoomsdayBunker "Бункер Судного дня" 50000 — two underground levels down to y = -24, obsidian/lead/titanium, energy crystal core, shield generator (place it on the kiosk roof/surface zone so the dome protects the entrance), 2 AA turrets on the kiosk, 4 guards, medkits, lots of lighting.
Rules your generator MUST validate (assert) before writing: grid alignment (rotated extents' min corner integer on all axes), bounds (zones above), no overlapping blocks (AABB intersection volume > 1e-6), item sizes fixed (Door may be resized but min 2×5×1, Lamp ≥1), every underground block inside dug cells only, every dug cell reachable from the surface layer, block counts ≤ 650, counts guards/aa/shields/medkits written to the module fields, materials/items ids valid, block count ≤ Config.MaxBlocks minus a margin. Also make sure walkways are not blocked (the house door opening leads inside; bunker stairs connect kiosk to rooms).
tools/test_prefabs.luau (copy the harness from tools/test.luau; do not edit test.luau): load Prefabs, Serializer, Blocks, Grid and Underground (Underground.lua is being written now by UG_SERVER; if it is missing when you run, implement the decoding check inline per spec and note it) and re-validate everything from the Luau side (decoding, counts vs fields, alignment, bounds/zones, no overlaps, cells dug, connectivity, Underground.encode(decode(hex)) == hex). Run it.
Run python3 tools/gen_prefabs.py. Keep the generated Prefabs.lua readable (one entry per prefab, data on one line).`,
  },
  {
    key: 'GUARDS',
    prompt: `${PREAMBLE}

PACKAGE GUARDS — guard NPC item and the door size bug.
Files you own: src/ReplicatedStorage/Shared/Blocks.lua, src/ReplicatedStorage/Client/State.lua (only selectBlock/size memory; other fields were pre-added by the lead — keep them), src/ReplicatedStorage/Shared/BlockFactory.lua, src/ServerScriptService/Server/Specials.lua, src/ServerScriptService/Server/Projectiles.lua, src/ReplicatedStorage/Client/Projectiles.lua, src/ReplicatedStorage/Client/World.lua, src/ReplicatedStorage/Client/Fx.lua, tools/gen_examples.py (only add the Guard item to its item tables so ids/sizes stay consistent — do not change the examples), and tools/test.luau (you may add tests for normalizeSize/minSize and selectBlock-independent logic).
1. DOOR BUG (user: "doors for some reason became 1 block, a door is not that small"): State.selectBlock keeps the previous material size (2×2×2) for the resizable Door. Implement per spec: per-selection size memory, Door default 4×7×1; Blocks Door minSize 2×5×1 enforced in Blocks.normalizeSize (server uses it too). Check BuildPanel's size +/- buttons still behave (read BuildPanel.lua; if it needs a change, put it in requests). Check BlockFactory.buildDoor at min and default size: no z-fighting between frame/leaf/panels, leaf fits the opening, handle visible.
2. GUARD item per spec (id 13 …). BlockFactory: build a high-quality soldier figure inside the 2×5×2 box, feet on the box bottom (no levitation), facing local -Z: boots, legs with knee pads, belt, tactical vest with pouches, arms with gloves holding a detailed rifle (stock, body, barrel, magazine, scope, muzzle attachment named "GuardMuzzle"), head with balaclava/face, goggles and a helmet, small backpack/radio with antenna. Root part "Block" is transparent (Transparency 1) and stays the collision/query box; all decor CanCollide=false, CanQuery=false, CanTouch=false, Massless, welded (use the existing decor() helpers / Tint conventions so charring/debris/painting work). Named welds for animation: a waist pivot (yaw of upper body), a neck pivot (head), a shoulder pivot (arms+rifle pitch). Ghost/preview builds stay static.
3. Server interception: in Projectiles.stepOne, after the AA turret check, guards in Specials.guards(plot) within Blocks.GuardRange of the projectile (and not bomblets) roll once per projectile per guard (respect a per-guard cooldown Blocks.GuardCooldown via Specials.guardReady/guardFired), chance = w.aa * Blocks.GuardChance; on success detonate intercepted like AA; every shot fires Net.event("GuardShot"):FireAllClients({ from = muzzle world position (compute from the guard block CFrame; do not rely on client-side animated parts), to = target position, g = guard block }). Bullets (aa = 0) are not intercepted.
4. Client: on GuardShot → bright tracer from muzzle to target, muzzle flash (light + flash part), SoundPlayer 3D "GuardShot" at the muzzle, and the guard turns its upper body/arms toward the target for ~1.2 s, then returns to idle. Idle animation (World.lua or Fx.lua): breathing, slow head scanning, slight weapon sway — only for guards within ~180 studs of the camera, efficient (one RenderStepped/Heartbeat loop, guards tracked via ChildAdded/ChildRemoved on each plot's Blocks folder). Use Weld C0 changes on the client only.
5. Make sure Guard shows up correctly in BuildPanel/ShopUI (they iterate Blocks.Items — verify; if a change is needed in files you do not own, add to requests), and that the damage/debris path handles the guard (read Damage.makeDebris; if it needs a change, add to requests — Damage.lua is owned by UG_SERVER).
Run the type checker and lune tests.`,
  },
  {
    key: 'SHOP',
    prompt: `${PREAMBLE}

PACKAGE SHOP — prefab shop: server purchase/placement, profile data, shop UI.
Files you own: src/ServerScriptService/Server/PrefabShop.lua (NEW), src/ServerScriptService/Server/Data.lua, src/ReplicatedStorage/Client/UI/ShopUI.lua.
Read: spec sections PREFABS and UNDERGROUND (APIs you call: Building.create/overlaps/serialize/pushUndo/canEdit/count, Underground.setMask, Shared Underground.decode, Serializer.decode/dig — other agents are implementing those right now exactly as specified), Shared/Prefabs.lua format (being generated now by the PREFABS agent — may not exist yet; code against the spec format; do not create it), current ShopUI.lua (rarity, filters, detail panel with rotating preview), Lib.lua, Theme.lua, HUD.lua (modals, toasts), Server/Shop.lua and Building.lua for patterns.
1. Data.lua: profile field Prefabs = {} (reconcile handles old profiles), Data.sync sends prefabs = p.Prefabs.
2. PrefabShop.buy(player, key): validate key, not owned, enough gold → deduct, mark owned, Data.sync, async save, return true + Russian message.
3. PrefabShop.place(player, key, free: boolean?): free is ONLY for internal admin use (the remote passes client args, so the bound remote must never let a client pass free=true — expose a separate internal function, e.g. PrefabShop.placeInternal(player, key, true), and make the remote handler ignore extra args). Placement per spec (house: remove blocks intersecting the prefab AABB grown by 1 on X/Z; bunker: remove all blocks below y=0 plus blocks in the kiosk zone, set mask, create). Undo snapshot first via Building.pushUndo({ type = "clear", data = Building.serialize(plot) }). Refuse with a clear message if siege/launch, not owned, would exceed Config.MaxBlocks (compute before changing anything). After placing a bunker, if the owner character is standing inside newly filled soil, nudge them up (PivotTo the spawn or above ground).
4. ShopUI: add two new categories to the shop: "🏠 Дома" and "🛡 Бункеры" (keep all existing material/item shop features working). Cards: tier badge/stars with tier colours (reuse Theme rarity colours), icon, name, price or "Куплено", key stats (blocks, 🛡 guards, 🎯 AA, 🔵 shield, ✚ medkits). Detail panel: rotating 3D preview of the prefab built from Serializer.decode(data) with BlockFactory.build(spec, cf, { preview = true }) for each block (centre and scale the camera to the bounding box; for bunkers show the underground part with a translucent ground plane at y=0 so it reads as underground), description, features list, buttons: "Купить — N" (disabled + red if not enough gold) / "Поставить на участок" (if owned) with an in-UI confirmation explaining what will be replaced and that Ctrl+Z undoes it. Build the 3D preview lazily only for the selected prefab and destroy the previous one (performance). Handle State.changed("prefabs") and gold changes. Toast results, play the existing purchase sound.
Type-check your files.`,
  },
  {
    key: 'ADMIN',
    prompt: `${PREAMBLE}

PACKAGE ADMIN — admin panel for testing everything.
Files you own: src/ServerScriptService/Server/Admin.lua (NEW), src/ReplicatedStorage/Client/UI/AdminUI.lua (NEW), src/ReplicatedStorage/Client/AdminTools.lua (NEW, optional: client fly etc.), src/ServerScriptService/Server/Siege.lua (admin hooks only).
Read: spec section ADMIN and what is pre-wired (HUD admin button, Client.client.lua calls AdminUI.init(), Main binds remote "Admin" → Admin.handle and calls Admin.init()), Server: Data.lua, Building.lua, Siege.lua, Attacks.lua, Projectiles.lua, Plots.lua, Underground spec API, PrefabShop spec (SHOP agent exposes an internal free placement function — call it as PrefabShop.placeInternal(player, key, true); if the name differs the integrator will align it), Shared/Prefabs.lua format (being generated now), Examples.lua, Weapons.lua; Client: HUD.lua, Lib.lua, Theme.lua, SettingsUI.lua/SavesUI.lua/SiegeUI.lua (modal patterns), State.lua.
Server Admin.lua: isAdmin per spec; on PlayerAdded set attribute IsAdmin; handle(player, cmd, arg) re-checks admin every call, whitelists commands, validates args. Commands (all must work):
 Economy: add gold (1000 / 10000 / 100000), set gold to 0, unlock all materials+items, unlock all prefabs, reset purchases.
 Player: god mode toggle (invisible ForceField that persists on respawn; attribute "God" on the player), heal, walk speed presets (16/32/64/120), jump presets, teleport (my plot spawn / lobby / bottom of my pit / to a client-sent point validated to be finite and within the map), fly toggle (client-side, see below; the server only records the attribute).
 Siege: start survival at wave N (1..30) with difficulty 1..4; skip the current wave (end it as cleared); end siege; fire ANY of the 12 weapons at me / at a client-sent aim point on my island / at a random block of mine — without cooldowns (auto-start range mode if there is no siege); restore the build after range shots.
 Build: place any prefab for free; clear the plot (undoable); dig the whole underground; fill the whole underground (first remove underground blocks with an undo snapshot); load any example.
 World: time of day presets (утро 7, день 13, закат 18.2, ночь 0) via Lighting.ClockTime.
 Info: "stats" returns a short Russian text: server heartbeat FPS, physics FPS, projectiles active, blocks on my plot, dug cells, players, memory MB (Stats:GetTotalMemoryUsageMb()).
Siege.lua: add admin hooks WITHOUT changing what the public StartSiege/FireRange remotes accept (bound remotes pass client args — a 4th client arg must not reach any admin-only parameter): e.g. Siege.adminStart(player, difficulty, wave), Siege.skipWave(player), Siege.adminFire(player, key, aim). Make wave skipping clean (no double rewards exploit beyond the admin's own test).
Client AdminUI.lua: modal "admin" registered with HUD.registerModal, F2 toggles it (only when player attribute IsAdmin is true), styled like the other modals (Lib/Theme), tabs: Экономика, Игрок, Осада, Оружие, Постройка, Мир, Инфо. Buttons send Net.func("Admin"):InvokeServer(cmd, arg) and toast the result; toggles reflect state (God/Fly). Weapon tab: grid of the 12 weapons (Weapons.List icons/names) + target selector (на меня / курсор / случайный блок); "курсор" mode: next click in the world picks the aim point (raycast) and fires. Info tab refreshes stats every second while open.
Client fly (AdminTools.lua): toggle via the panel; uses LinearVelocity + AlignOrientation (or similar non-deprecated constraints) on HumanoidRootPart, WASD + Space/Ctrl (or Q/E) for up/down, Shift faster; cleans up on toggle off/death/respawn. Disabled automatically when the panel says off.
Type-check your files.`,
  },
]

phase('Implement')
const impl = await parallel(PACKAGES.map(p => () =>
  agent(p.prompt, { label: 'impl:' + p.key, phase: 'Implement', schema: RESULT_SCHEMA })
    .then(r => ({ key: p.key, ...(r || { summary: 'AGENT FAILED', files_changed: [], requests: [], checks: '', open_issues: ['agent returned null'] }) }))
))
const implReport = impl.filter(Boolean).map(r =>
  `## ${r.key}\nSummary: ${r.summary}\nFiles: ${r.files_changed.join(', ')}\nRequests for other files:\n- ${r.requests.join('\n- ') || '(none)'}\nChecks: ${r.checks}\nOpen issues:\n- ${r.open_issues.join('\n- ') || '(none)'}`
).join('\n\n')
log('Implementation done: ' + impl.filter(Boolean).map(r => r.key).join(', '))

phase('Integrate')
const integration = await agent(`You are the INTEGRATOR for a Roblox game update (Luau + Rojo). Project root: ${ROOT}. Read the spec ${SPEC} and README.md.
Seven agents just implemented packages in parallel with strict file ownership. Their reports (including "requests" — changes they needed in files they did not own) are below. You may now edit ANY file.
Your job:
1. Apply every legitimate cross-package request (or an equivalent fix).
2. Align interfaces: function names/signatures between callers and callees (e.g. PrefabShop.placeInternal vs what Admin calls, Building.pushUndo, Underground API, Plots fields ground/foundation/gridPlane), remote argument orders between client and server (Dig, BuyPrefab, PlacePrefab, Admin), event payloads (GuardShot, Data.prefabs), attribute names ("Dug", "IsAdmin", "God", "Layer"), part/folder names (Ground, Foundation, GridPlane, Slab, Soil, Rim, Bedrock).
3. Run everything and make it all green:
   - python3 tools/gen_map.py && python3 tools/gen_examples.py && python3 tools/gen_prefabs.py
   - python3 tools/check_props.py ${S}/rct/API-Dump.json
   - python3 tools/check_zfight.py (if present)
   - LUAU_LSP=${S}/luau-lsp/build/luau-lsp ROBLOX_DEFS=${S}/luau-lsp/scripts/globalTypes.None.d.luau sh tools/check.sh   (must report no errors)
   - ~/.cargo/bin/lune run tools/test.luau ; ~/.cargo/bin/lune run tools/test_underground.luau ; ~/.cargo/bin/lune run tools/test_prefabs.luau
   - sh build.sh   (produces BuildAndSurvive.rbxlx)
4. Inspect the built place: use Lune's roblox library (see ${S}/verify_place.luau for an earlier example) to load BuildAndSurvive.rbxlx and verify each Plot model has Ground/Foundation/GridPlane and no Base/Skirt, the new ModuleScripts exist (Shared.Underground, Shared.Prefabs, Server.Underground, Server.PrefabShop, Server.Admin, Client.UI.AdminUI ...), Remotes are created at runtime (Net.lua) — and that every require() path used by the new modules resolves to an existing module in the place tree.
5. Read through the new/changed Luau code once end-to-end for obvious runtime errors (nil indexing on server start, WaitForChild on names that do not exist, wrong method names, client code that runs before data arrives).
Do not commit. Return a concise report of what you changed, the final status of every check (paste the key output lines), and any remaining known problems.

IMPLEMENTER REPORTS:
${implReport}`, { label: 'integrate', phase: 'Integrate' })

phase('Review')
const FINDINGS = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          severity: { type: 'string', enum: ['blocker', 'major', 'minor'] },
          file: { type: 'string' },
          line: { type: 'number' },
          title: { type: 'string' },
          detail: { type: 'string', description: 'concrete failure scenario: inputs/state → wrong behaviour, with the code path you traced' },
          fix: { type: 'string' },
        },
        required: ['severity', 'file', 'line', 'title', 'detail', 'fix'],
      },
    },
  },
  required: ['findings'],
}
const REVIEW_PREAMBLE = `You are an adversarial code reviewer for a Roblox game update (Luau + Rojo) at ${ROOT}. Read the spec ${SPEC}. Use git diff (the update is uncommitted; compare against HEAD) plus the full current files. Nothing can be run in Roblox Studio, so reason carefully and verify Roblox API facts against ${S}/rct/API-Dump.json and ${S}/creator-docs. Report ONLY real problems you have traced to a concrete failure scenario (no style nits, no speculation). For each finding give the exact file and line, the failure scenario, and a concrete fix. Do not edit files.`
const REVIEWS = [
  { key: 'underground', prompt: `${REVIEW_PREAMBLE}
FOCUS: underground digging & building end to end — Shared/Underground.lua math (indexing, cellsInBox boundaries, exposure, greedy rects, hex encoding), Serializer v2 compatibility with old v1 saves, server Underground (rebuild correctness, part counts, attribute replication, terrain carve), Building (dig validation & exploits: digging non-exposed cells, filling cells with blocks/players inside, undo/redo of dig and clear, restore applying the mask before blocks, siege snapshot/restore, save slots, player leave/rejoin, examples/starter), Plots fields, Damage cover through soil (can players/blocks underground still be damaged unfairly? can explosions inside the pit work?), Launch with underground blocks, client BuildController (ghost validity underground, dig cursor targeting, hold-drag, fill mode, raycast filters, delete/paint ignoring soil), consistency between Python (gen_prefabs.py) and Luau encodings.` },
  { key: 'prefabs-shop', prompt: `${REVIEW_PREAMBLE}
FOCUS: prefab houses/bunkers and the shop — tools/gen_prefabs.py output validity (alignment, overlaps, zones, dug cells, connectivity, walkability: can a player actually walk in through the door and down the bunker stairs? headroom? are doors oriented correctly and not blocked?), Prefabs.lua format vs consumers, PrefabShop (buy/place validation, free placement not reachable by clients, block-limit precheck, house/bunker replacement rules, undo snapshot, player trapped in soil, siege/launch guard), Data (Prefabs persistence/reconcile/sync), ShopUI (new categories, card/detail logic, 3D preview build/cleanup performance, confirm flow, state updates, existing shop features still intact).` },
  { key: 'admin-security', prompt: `${REVIEW_PREAMBLE}
FOCUS: admin panel security and correctness — Admin.isAdmin (Studio, creator, group owner, Config.Admins), every command re-checks admin, argument validation (types, NaN/inf, ranges), teleport point validation, ability of a non-admin client to reach admin-only parameters through ANY remote (StartSiege, FireRange, PlacePrefab, Admin…), Siege admin hooks (adminStart wave N, skipWave, adminFire without cooldown, interplay with normal siege flow, rewards, finish/restore), god mode persistence, fly client implementation (constraints, cleanup, respawn), AdminUI (F2 only for admins, tabs, cursor aim mode, stats refresh loop stops when closed), and anything that could crash the server or leave a plot in a broken state.` },
  { key: 'runtime-api', prompt: `${REVIEW_PREAMBLE}
FOCUS: runtime errors and Roblox API misuse across ALL changed Luau files, plus the guard item and the door fix: wrong property/method/enum names, NotScriptable/ReadOnly writes, invalid Material for parts, yields in RenderStepped/Heartbeat, nil indexing at startup or before data arrives, WaitForChild on names that never exist, event payload mismatches client↔server (GuardShot, Dig, Data.prefabs, Admin), memory leaks (connections, parts never destroyed), performance (per-frame loops over all blocks, rebuilds per dig), guard model (no z-fighting, feet on ground, welds correct, client animation only touches client-side C0, interception logic and cooldowns in Projectiles), door size memory in State.selectBlock and Blocks.normalizeSize minSize (does the server accept/keep sizes correctly? does BuildPanel still work?), map generator changes (Ground/Foundation/GridPlane properties, path/z-fight fixes).` },
]
const reviews = await parallel(REVIEWS.map(r => () =>
  agent(r.prompt, { label: 'review:' + r.key, phase: 'Review', schema: FINDINGS })
    .then(res => ({ key: r.key, findings: (res && res.findings) || [] }))
))
const allFindings = reviews.filter(Boolean).flatMap(r => r.findings.map(f => ({ ...f, dim: r.key })))
log(`Review: ${allFindings.length} findings (${allFindings.filter(f => f.severity === 'blocker').length} blocker, ${allFindings.filter(f => f.severity === 'major').length} major)`)

phase('Fix')
const fixReport = await agent(`You are the FIXER for a Roblox game update (Luau + Rojo) at ${ROOT}. Read the spec ${SPEC}.
Below are review findings from 4 reviewers. Reviewers can be wrong. For EACH finding: open the code, verify it is real by tracing the concrete scenario (and verify Roblox API claims against ${S}/rct/API-Dump.json / ${S}/creator-docs). If real, fix it properly (minimal, clean, consistent with the code style; Russian comments/strings). If not real, say why. Deduplicate overlapping findings.
After fixing, re-run ALL checks and make them green:
 python3 tools/gen_map.py && python3 tools/gen_examples.py && python3 tools/gen_prefabs.py
 python3 tools/check_props.py ${S}/rct/API-Dump.json ; python3 tools/check_zfight.py
 LUAU_LSP=${S}/luau-lsp/build/luau-lsp ROBLOX_DEFS=${S}/luau-lsp/scripts/globalTypes.None.d.luau sh tools/check.sh
 ~/.cargo/bin/lune run tools/test.luau ; ~/.cargo/bin/lune run tools/test_underground.luau ; ~/.cargo/bin/lune run tools/test_prefabs.luau
 sh build.sh
Do not commit. Return a report: per finding → REAL/NOT REAL + what you did; then the final status of every check (key output lines).

Integrator report (context):
${integration}

FINDINGS (JSON):
${JSON.stringify(allFindings, null, 1)}`, { label: 'fix', phase: 'Fix' })

phase('Screenshots')
const shots = await agent(`You produce preview screenshots and documentation for a Roblox game update at ${ROOT} (read ${SPEC} and README.md).
There is no Roblox Studio here; previews are rendered with a three.js approximation in tools/preview (index.html, preview.js, ui.css; data: map.json from gen_map.py, examples.json from gen_examples.py, prefabs.json from gen_prefabs.py). Earlier screenshots are in assets/screenshots (01..10 jpg) — keep the same visual style and honesty (they are previews, not Studio captures).
How it was run before: copy tools/preview/* (index.html, preview.js, ui.css, *.json) into ${S}/prevrun (it has a "three" symlink), serve it (e.g. cd ${S}/prevrun && python3 -m http.server 8765 in the background if not already serving), then from ${S}/prevdeps run: node shoot.mjs http://localhost:8765 <outdir> <scene1,scene2,...> (Chromium SwiftShader via Playwright, already installed; each scene can take a while). Convert PNGs to high-quality JPG (python PIL or ImageMagick, whichever exists) into assets/screenshots.
Tasks:
1. Extend preview.js with what the update added so the screenshots are faithful: plot Ground (concrete slab + soil layers built from a dig mask like the server's greedy rects), Foundation rim/bedrock, a GridPlane is invisible; the Guard item model (approximate the BlockFactory soldier: helmet, vest, rifle…), and any other new item visuals used by prefabs.
2. New scenes + screenshots (each 1600×900):
   - 11_houses: the five houses side by side (or a collage of five plots) with labels/tiers.
   - 12_bunker_cutaway: the DoomsdayBunker (and/or CommandBunker) as a cutaway: the plot with the soil cut open (front soil removed or translucent) showing rooms, stairs, guards, lights; the entrance kiosk with AA turrets above.
   - 13_dig_tool: a plot where the player is digging a pit (some cells dug, orange dig cursor box, HUD hotbar with the ⛏ Копать tool highlighted, hint text).
   - 14_prefab_shop: the shop UI mock (HTML/CSS overlay in the style of the existing 08_shop) showing the "🏠 Дома / 🛡 Бункеры" category with cards and the detail panel of the Mansion (price 40 000, guards 4, AA 2, shield 1).
   - 15_admin_panel: the admin panel UI mock over the game view (tabs Экономика/Игрок/Осада/Оружие/Постройка/Мир/Инфо, weapons grid etc.) — match the actual AdminUI.lua layout/texts.
   - 16_guards: close-up of guards at the Mansion entrance (one firing a tracer at an incoming missile).
   - Re-shoot 02_building (or the overview) only if the plot floor/path change made the old one inaccurate; check the path fix visually (no z-fighting) and include a close-up 17_path_fixed.
   Look at every produced image yourself (Read the image file) and iterate until it looks good and matches the game's actual content.
3. Update README.md (Russian): new sections — Подземные бункеры (инструмент «Копать», клавиша 5, F — засыпать, глубина 24, защита землёй), Готовые дома и бункеры (таблица 10 построек с ценами и что внутри: ПВО, щит, охранники), Охранники (что делают), Админ-панель (как открыть: кнопка «Админ»/F2; кто админ: в Studio все, в опубликованной игре владелец и Config.Admins; список команд), исправления (двери 4×7, тропинка). Add the new screenshots to the screenshots list. Keep it accurate to the code.
Do not commit. Return the list of produced screenshot files (with a one-line description each) and a summary of README changes.`, { label: 'screenshots', phase: 'Screenshots' })

return { implReport, integration, findingsCount: allFindings.length, fixReport, shots }
