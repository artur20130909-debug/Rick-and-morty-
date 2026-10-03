# Amber Alert (Roblox fan remake) — architecture & contracts

This document is the single source of truth for everyone writing code in `amber-roblox/`.
If something you need is not specified here, choose the simplest option, keep it inside the files
you own, and mention it in your final report.

The game is a fan remake of the Roblox horror game **Amber Alert** (TEZ Studios): a night lobby next to the
Black Ridge Asylum → players enter a booth → a 1990s two-storey suburban house. Day: pick apples in the yard,
sell them in the garage shop, buy items. At 21:00 the CRT TV plays an Emergency Alert System (EAS) broadcast
naming the escaped inmate and how to survive. Night: the inmate breaks in through a door or window; players hide
in closets, lock doors, use items. Dawn (7:00) revives the dead. Survive N nights to win.

The previous browser version of this remake lives in `../amber-alert/` (three.js). It already contains the full
design: house layout (`src/10_house.js`, `src/08_world.js`), game loop (`src/11_game.js`), inmates
(`src/12_inmates.js`, `src/12z_*.js`), lobby (`src/13_lobby.js`), UI (`src/15_ui.js`). Research notes from the
Amber Alert wiki: `/tmp/claude-0/-home-user-Rick-and-morty-/5327e945-3630-52ce-862d-2c2c44fd5ac5/scratchpad/`
(`aa_research_dump.txt`, `threat_blocks.txt`, `house_sents.txt`, `items_sents.txt`, `lobby.txt`, `yard.txt`).
Port ideas from there, but write idiomatic Roblox Luau.

## 0. Rules for all code

* **Language:** Luau written in a Lua 5.1-compatible subset so `tools/check.sh` can parse it.
  * No `+=`/`-=`, no `continue`, no type annotations, no backtick string interpolation, no `//` integer division.
  * `goto` and `if`-expressions are also not allowed.
* **Text:** all player-visible text and all code comments are in **Russian**, matching the existing style:
  short comment lines, a header comment at the top of each file explaining what it does.
* **Checks:** run `sh tools/check.sh` after writing. It must print no `FAIL` and no `GLOBALS`, only `checked N files`.
  Build with `python3 build.py` to make sure the place file assembles.
* **Ownership:** only edit files you own (listed in section 9). Need a change in someone else's file?
  Describe it in your final report instead.
* **Robustness:** never let one error kill a loop. Wrap per-frame and per-tick work in `pcall`.
  `warn()` once with a `[AA]` prefix.
* **Dependencies:** no `wait()`, `spawn()` or `delay()`. Use `task.wait`, `task.spawn`, `task.delay`.
* **Shared modules:** use `ReplicatedStorage.Shared.Build` (`B`) for parts and `Shared.Sound` for audio.
  Use `Shared.Config` for data and `Shared.Net` for remotes.
* **Studio state:** the place must work in Roblox Studio Play Solo with an unpublished file.
  * DataStore calls are wrapped in `pcall`.
  * Missing sound or image IDs (empty strings) just mean silence or no texture.

## 1. Project layout (build.py maps folders → instances, like Rojo)

```
src/ReplicatedStorage/Shared/      Build.lua Config.lua Net.lua Sound.lua Rig.lua(inmates agent)
src/ReplicatedStorage/Inmates/     <Key>.lua  — one ModuleScript per inmate (data + model + client anim + server behaviour)
src/ReplicatedStorage/Client/      client ModuleScripts (UI, Controls, World, Hide, Fx, InmatesClient)
src/ServerScriptService/Main.server.lua        bootstrap Script
src/ServerScriptService/Server/    server ModuleScripts (Data, Lobby, Match, HouseLogic, Items, InmateAI, HouseMap, LobbyMap)
src/StarterPlayer/StarterPlayerScripts/Client.client.lua   client bootstrap LocalScript
assets/sounds, assets/images       generated media for the user to upload (see assets/MANIFEST.md)
```
`X.lua` → ModuleScript, `X.server.lua` → Script, `X.client.lua` → LocalScript, folders → Folder.

## 2. World scale and placement

* 1 metre ≈ 3.5 studs. R15 character ≈ 5.2 studs tall, default camera.
* Doors: opening 5 wide × 8.5 tall. Ceilings: 12 studs. Floor-to-floor: 13 (1-stud slab).
* Exterior walls are 1.5 studs thick and interior walls 1 stud — thinner walls leak light under Realistic lighting.
* **Lobby** is built at the world origin `(0, 0, 0)`; ground is at y = 0.
* **Houses** are built per match at `origin = Vector3.new(3000 + 1200 * slot, 0, 0)`.
  * The front of the house faces **−Z**: street on −Z, back yard on +Z.
  * Ground is at `origin.Y`.
  * Everything goes inside the returned house `Model`, and a house plus its lot must fit in a 900 × 900 stud square around the origin.
* Lighting service properties, sky, Atmosphere and post-processing belong to the client (`World.lua`).
  Map builders must **not** create Sky, Atmosphere or post-effects, or touch `Lighting`.
  They only place light objects inside lamps.

## 3. Shared modules

### Build (`Shared/Build.lua`) — read the file, it is short. Key functions:
`B.part(parent,name,size,cf,color,material,props)`, `B.wedge`, `B.cornerWedge`, `B.cyl(parent,name,length,d,cf,...)` (axis = cf X),
`B.vcyl(parent,name,height,d,cf,...)` (vertical), `B.ball`, `B.marker(parent,name,size,cf)` (invisible, no collide/query/touch),
`B.wall(parent,name,a,b,h,th,color,material,openings)` (openings `{at,w,y0,y1}` along the wall from `a`),
`B.light(parent,"PointLight"|"SpotLight"|"SurfaceLight",props)` (Shadows on), `B.prompt(parent,name,action,object,props)`,
`B.sign(part,face,text,labelProps,guiProps)`, `B.texture(part,face,imageKeyId,u,v)`, `B.decal`, `B.weld`, `B.attrs`,
`B.model`, `B.folder`, `B.at(x,y,z,yawDeg)`, `B.color`, `B.asset(id)`, `B.mat(name, fallback)` for new materials.
Colors may be `Color3`, `"#rrggbb"` or `r,g,b`. All parts are Anchored by default.

### Config (`Shared/Config.lua`) — difficulties, items, classes, ranks, timings, `Config.Sounds`, `Config.Images`.
Use `Config.Images.<Key>` through `B.texture/B.decal` (empty → nothing). Do not hardcode asset IDs elsewhere.

### Net (`Shared/Net.lua`) — `Net.event(name)`, `Net.func(name)`; server calls `Net.init()` at start.

### Sound (`Shared/Sound.lua`) — `Sound.play(key, where, props)`, `Sound.loop(key, where, props)`;
`where` = Instance (3D), Vector3 (point) or nil (2D, client only).

## 4. Replicated state

| Where | Attributes / children |
|---|---|
| `Player` | `MatchId` (int, 0 = lobby), `Alive` (bool), `Money`, `Apples` (int), `Static` (0–100), `Class` (string), `Hidden` (bool), `Equipped` (item key or ""), `Sprinting`, `Crouching`, `Flashlight` (bool), `Amber`, `XP`, `Level` (int), `Rank` (string) |
| `Player.Inventory` (Folder) | `IntValue` children: Name = item key, Value = count (`shells` = ammo) |
| `ReplicatedStorage.Matches.Match_<id>` (Folder) | `Id`, `Phase` (`loading`/`day`/`alert`/`night`/`dawn`/`end`), `Clock` (hours, 7…31), `Night`, `Nights`, `Difficulty` (key), `Inmate` (key or ""), `Unknown` (bool), `Power` (bool), `HouseName`, `DirectiveCode`, `DirectiveText`, `PlayerCount`, `Sprinkler` (bool) |
| `workspace.Houses.House_<id>` | the house Model (see §6) |
| `workspace.Inmates` (Folder) | inmate Models with attributes `InmateKey`, `MatchId`, `Anim` (string), `Hp`, `MaxHp`, `Stunned` (bool) |
| `workspace.Lobby` | lobby Model (see §7) |

The client finds its match via `Player:GetAttribute("MatchId")` → `ReplicatedStorage.Matches["Match_"..id]`.

## 5. Remotes (all created by `Net.init()`)

RemoteEvents:

| Name | Direction | Arguments |
|---|---|---|
| `Action` | C→S | `(kind, a, b)`; see the Action kinds below |
| `Toast` | S→C | `(text, color?)` — short message at screen centre-top |
| `Alert` | S→C | `(data)` — EAS broadcast. `data = { lines = {string...}, duration = 34, inmate = key or nil, unknown = bool, num = "102", name = "ГЛАДИС", threat = "class", tip = "how to survive", directive = {code=..., text=...} or nil, night = n, nights = N }` |
| `Scene` | S→C | `(scene, data)`; see the Scene payloads below |
| `Fx` | S→C | `(kind, a, b, c)`; see the Fx kinds below |
| `Hidden` | S→C | `(hideModel or nil)` — you are now hidden in that hide spot / you left it |

`Action` kinds:
* `"flashlight"(on)`
* `"sprint"(on)`, `"crouch"(on)`
* `"equip"(key or "")`
* `"use"(key, camCFrame)`
* `"unhide"()`
* `"qte"(ok)`

`Scene` payloads:
* `"lobby"`, `{}`
* `"loading"`, `{text = "..."}`
* `"house"`, `{matchId = id, house = Model}`
* `"end"`, `{win = bool, nights = n, amber = a, xp = x, text = "..."}`

`Fx` kinds:
* `"sound"`: `a` = sound key, `b` = Vector3/Instance/nil, `c` = props
* `"shake"`: `a` = power 0..2, `b` = seconds
* `"jumpscare"`: `a` = inmate key, `b` = inmate Model
* `"flash"`: `a` = Color3, `b` = start transparency
* `"hurt"`: `a` = damage
* `"killed"`: `a` = inmate key — an inmate was neutralised
* `"revived"`
* `"power"`: `a` = bool
* `"coin"`: `a` = amount
* `"apple"`: `a` = count
* `"spotted"`: `a` = inmate key — the inmate saw you; play a stinger
* `"battery"` — a battery item was consumed; the flashlight is refilled to 100% (Fx → `Controls.refillBattery()`)

RemoteFunctions:

| Name | Call | Returns |
|---|---|---|
| `Shop` | `("buy", key)` / `("sell")` | `{ok = bool, msg = string}` |
| `Profile` | `()` | `{amber, xp, level, rank, class, owned = {classKey = true}}` |
| `Lobby` | `("buyClass", key)` / `("setClass", key)` | `{ok, msg, profile}` |

## 6. House map contract — `Server/HouseMap.lua`

`HouseMap.build(origin: Vector3, parent: Instance, name: string) -> house` and `HouseMap.destroy(house)`.

`house` is a Lua table:
```lua
house = {
  model = Model,            -- named `name`, parented to `parent` (workspace.Houses)
  origin = Vector3,
  spawns = { CFrame, ... }, -- ≥4 day spawn points inside (living room / hall), facing into the room
  alertSpots = { CFrame, ...}, -- ≥4 points in front of the TV, facing the screen
  tv = Model,               -- see TV below
  doors = { Model, ... },   -- every door (interior + exterior)
  windows = { Model, ... },
  entries = { Model, ... }, -- exterior doors + ground-floor windows inmates may break in through (subset of doors/windows)
  hides = { Model, ... },
  trees = { Model, ... },   -- apple tree slots, 3 planted + 3 locked plots
  fuse = Model, shop = Model,
  lights = { BasePart, ... }, -- lamp parts that carry Light objects (powered by the fuse box)
  rooms = { BasePart, ... },  -- room volume markers
  inmateSpawns = { CFrame, ...}, -- ≥3 points outside the lot (street, back fence) where inmates appear at night
  interior = BasePart,      -- invisible box covering the whole indoor volume (indoors test)
  sprinkler = BasePart?,    -- spot in the yard where a bought sprinkler appears
}
```
Model structure inside `house.model` (folders by name): `Doors`, `Windows`, `Hides`, `Trees`, `Lights`, `Rooms`,
`Spawns`, `AlertSpots`, `InmateSpawns`, plus free-form geometry folders (`Structure`, `Furniture`, `Yard`, `Street`, …).

**Door** — `Model` named `Door_<Room>`, attrs:
* `Kind="Door"`, `Exterior=bool`, `Lockable=bool`, `OpenAngle=` degrees (sign = swing direction, ~±100).
* `Open=false`, `Locked=false`, `Broken=false`, `Health=100`.

Children:
* `Model "Leaf"`: every moving part. `Leaf.PrimaryPart` = `Part "Panel"` (≈ 4.8 × 8.4 × 0.35, CanCollide true).
  The knob and any glass are welded or just positioned inside `Leaf`. `HouseLogic` rotates `Leaf` with `PivotTo`.
* `Part "Hinge"` (marker) on the hinge edge, at the door's vertical centre. The leaf rotates around `Hinge`'s Y axis.
* `ProximityPrompt "Prompt"` inside Panel: `ActionText="Открыть"`, E, `HoldDuration 0`.
* If lockable, `ProximityPrompt "LockPrompt"` inside Panel: `ActionText="Запереть"`, `KeyboardKeyCode=R`, `HoldDuration=0.7`.
* Inside Panel, a `PathfindingModifier` with `Label="Door"` and `PassThrough=true`, so pathfinding routes through closed doors.
* Exterior doors also have `Part "In"` and `Part "Out"` markers: floor points about 3 studs inside and 4 studs outside the doorway.
* Frame and casing parts stay outside `Leaf`.

**Window** — `Model` named `Window_<Room>_<n>`, attrs `Kind="Window"`, `Broken=false`. Children:
* `Part "Glass"`: Glass material, Transparency ≈ 0.5, CanCollide true.
* Frame, sill and optional `Curtain` parts.
* Ground-floor windows (entries) also have `Part "In"` and `Part "Out"` floor markers.

**Hide spot** — `Model` named `Hide_<Room>_<n>`, attrs `Kind="Hide"`, `HideType="Closet"|"Wardrobe"|"Cabinet"|"UnderBed"`, `Occupant=0`. Children:
* `Part "Inside"` (marker): the CFrame where the hidden character's root stands. Its LookVector points out through the doors.
* `Part "Exit"` (marker): a floor CFrame in front of the hide spot.
* `ProximityPrompt "Prompt"` on a visible part, `ActionText="Спрятаться"`.
* Slatted doors so a hidden player can see out.

**Apple tree** — `Model` named `Tree_<n>`, attrs:
* `Kind="Tree"`, `Slot=n`, `Planted=bool` (initial: slots 1–3 true, 4–6 false), `Apples=0`.

Children:
* `Model "Plant"`: trunk + canopy. `HouseLogic` hides it when not planted.
* `Folder "Apples"` with Parts `Apple1`…`Apple4` (red balls hanging in the canopy); `HouseLogic` shows the first `Apples` of them.
* `Part "Plot"`: dirt patch.
* `ProximityPrompt "Prompt"` in the trunk or Plot, `ActionText="Сорвать яблоко"`.

**Fuse box** — `Model "FuseBox"`, `Kind="Fuse"`, in the garage. Parts `Box`, `Lever`, `Lamp` (small neon); `ProximityPrompt "Prompt"` ("Щиток").

**TV** — `Model "TV"`, `Kind="TV"`: a 1990s CRT on a stand in the living room facing the sofa.
`Part "Screen"`, where the client mounts a SurfaceGui on the face named by attribute `ScreenFace`
(e.g. `"Front"`), sized ≈ 3.6 × 2.7 studs.

**Shop** — `Model "Shop"`, `Kind="Shop"`, in the garage: a counter with a cash register and a static seller figure
(the "apple vendor"). `ProximityPrompt "Prompt"` with attribute `Opens="Shop"`, `ActionText="Магазин"`.

**Lights** — `Folder "Lights"` of lamp `Part`s with attributes:
* `Room` (string).
* `Glow=true` if the part should switch Material Neon (on) ↔ SmoothPlastic (off).

Each carries one Light object; `HouseLogic` toggles `Light.Enabled`. Use warm colours (255,214,170), Range 14–22, Shadows on.
Budget ≈ 25 lights.

**Rooms** — `Folder "Rooms"` of invisible marker parts covering each room volume. Name is the English id
(`LivingRoom`, `Kitchen`, `Dining`, `Hall`, `Garage`, `Bathroom`, `Bedroom1`, `Bedroom2`, `KidsRoom`, `Upstairs`, `Porch`, `Yard`, `Street`).
Attributes: `Label` (Russian name), `Floor` (1/2/0 outside), `Indoor` (bool).

**Navigation**
* Doorways ≥ 5 studs wide; corridors ≥ 6.
* Stairs: visible steps with CanCollide false, plus one invisible `WedgePart` ramp with CanCollide true, so people and NPCs walk smoothly.
* No furniture blocking doorways. The whole interior must be reachable with PathfindingService (AgentRadius 2, AgentHeight 6).

## 7. Lobby map contract — `Server/LobbyMap.lua`

`LobbyMap.build(parent) -> lobby` builds `Model "Lobby"` at the origin. Returns:
```lua
lobby = {
  model = Model,
  spawn = SpawnLocation,          -- "LobbySpawn", Neutral, Duration 0, facing the booths/billboard
  booths = { Model, ... },        -- 4 booths
  kiosks = { Model, ... },
  billboard = BasePart,           -- big screen; client renders onto face given by attribute ScreenFace
  cells = { Model, ... },         -- asylum cells, one per inmate module
}
```
**Booth** — `Model "Booth_<i>"`, attrs:
* `Kind="Booth"`, `Index=i`, `Difficulty="easy"|"normal"|"hard"|"endless"` (one each).
* `Max=4`, `Count=0`, `Countdown=-1`.

Children:
* `Part "Zone"`: invisible, CanCollide false. The server counts players whose root is inside this box.
* `Part "Sign"` with attribute `ScreenFace`. The client renders difficulty, count and countdown on it.
* Glass front, amber ceiling lamp.

**Kiosk** — `Model "Kiosk_<Name>"` with `ProximityPrompt "Prompt"`; attribute `Opens = "Classes"|"Dossiers"|"Quests"|"Codes"`. The client opens the matching UI.

**Asylum** — a gated 2–3 storey Black Ridge Asylum building behind the plaza, with a row of cells.
* For every ModuleScript in `ReplicatedStorage.Inmates`, there is one `Model "Cell_<Key>"` with a `Part "Tablet"`.
* The Tablet holds a `ProximityPrompt "Prompt"` with attributes `Opens="Dossier"` and `Inmate="<Key>"`, plus a SurfaceGui showing the inmate number.
* Inmate modules are cheap to `require` and expose `num`, `name`, `color`.

## 8. Server modules

`Main.server.lua` creates `ctx = { Config, Build, Net, Sound, Data, Lobby, Match, HouseLogic, Items, InmateAI, HouseMap, LobbyMap }`.
It calls `M.init(ctx)` on each module in this order: Data, HouseMap, LobbyMap, HouseLogic, Items, InmateAI, Match, Lobby.
Every server module returns a table with `init(ctx)`.

### Match object (owned by `Match.lua`; InmateAI and Items rely on these fields/methods)
```lua
match = {
  id = int, folder = Folder (ReplicatedStorage.Matches.Match_<id>), house = <house table>,
  diffKey = "normal", diff = Config.Difficulties[diffKey], night = 1, nights = 7,
  phase = "day", clock = 7.0, players = { Player, ... },  -- everyone in this match (alive or dead)
  inmates = { inm, ... }, power = true, alive = { [Player] = bool },
}
match:isAlive(plr) -> bool
match:alivePlayers() -> {Player}
match:damagePlayer(plr, amount, inm)       -- hurts; kills at 0 (calls killPlayer)
match:killPlayer(plr, inm)                 -- jumpscare Fx to victim, death, spectate
match:toast(text, color)                    -- to everyone in match
match:fx(kind, a, b, c)                     -- Fx to everyone in match
match:fxTo(plr, kind, a, b, c)
match:onInmateKilled(inm, byPlayer)        -- bounty + toast; removes it
match:isIndoors(pos) -> bool ; match:roomAt(pos) -> BasePart|nil
```
### HouseLogic (owned by me) — used by InmateAI:
```lua
HouseLogic.setDoor(door, open, byInmate)   HouseLogic.isOpen(door)  HouseLogic.isLocked(door)
HouseLogic.damageDoor(door, amount) -> broken   -- locked doors only
HouseLogic.breakWindow(window)              HouseLogic.occupant(hide) -> Player|nil
HouseLogic.pullOut(match, plr)              -- inmate drags a hidden player out (then attack)
HouseLogic.setPower(match, on)
```
### InmateAI (owned by the inmates agent) — used by Match/Items:
```lua
InmateAI.choose(match) -> key                         -- which inmate tonight (difficulty tier, night, coop rules)
InmateAI.spawn(match, key) -> inm                     -- builds model from Inmates/<Key>.build, puts it at an inmateSpawn
InmateAI.despawnAll(match)                            -- at dawn / match end
InmateAI.damage(inm, amount, byPlayer)                -- shotgun; at 0 hp → match:onInmateKilled
InmateAI.stun(inm, seconds)                           -- pepper, stun gun, trap
InmateAI.nearest(match, pos, radius) -> inm, dist
InmateAI.info(key) -> module table
```
`inm` fields: `key, def, match, model, hum, root, hp, maxHp, stunUntil, state, target`.

## 9. Ownership

| Owner | Files |
|---|---|
| lead (me) | `Shared/Build,Config,Net,Sound`, `Main.server.lua`, `Server/Data,Lobby,Match,HouseLogic,Items`, `Client.client.lua`, `build.py`, this doc |
| house agent | `Server/HouseMap.lua` |
| lobby agent | `Server/LobbyMap.lua` |
| inmates agent | `Shared/Rig.lua`, `Server/InmateAI.lua`, `Inmates/*.lua`, `Client/InmatesClient.lua` |
| UI agent | `Client/UI.lua` |
| client-systems agent | `Client/Controls.lua`, `Client/World.lua`, `Client/Hide.lua`, `Client/Fx.lua` |
| assets agent | `assets/**`, `tools/gen_assets.py` |

## 10. Client modules

`Client.client.lua` builds:
`ctx = { player, Config, Build, Net, Sound, UI, Controls, World, Hide, Fx, InmatesClient }`.
It requires every module first, then calls `init(ctx)` in the order World, UI, Controls, Hide, Fx, InmatesClient.
Modules talk to each other only through `ctx`.

### UI.lua public API (others call these)
```lua
UI.toast(text, color)                 UI.flash(color, startTransparency, seconds)
UI.setScene(scene, data)              -- lobby/loading/house/end screens; World and Controls also react to Scene themselves
UI.showAlert(data)  UI.hideAlert()    -- full-screen EAS broadcast (see Alert payload)
UI.open(name, arg)  UI.close(name)    -- "Shop", "Classes", "Dossier"(inmateKey), "Quests", "Codes"
UI.isOpen(name) -> bool               UI.anyModal() -> bool
UI.setStamina(frac)  UI.setBattery(frac)  UI.setFlashlight(on)  UI.setSelected(itemKey)  UI.setCrosshair(visible)
UI.qte(onResult) -> handle            -- hide-spot concentration minigame; handle.stop(); onResult(ok) on every hit/miss
UI.showDeath(text)  UI.hideDeath()  UI.setSpectating(nameOrNil)
UI.jumpscareOverlay(color, seconds)   -- red flash + noise used by InmatesClient during jumpscares
```
UI also renders, without being asked:
* the HUD from player/match attributes: clock, night N/N, money, apples, health, static meter, hotbar from `Player.Inventory`;
* booth signs and the lobby billboard text;
* opening UIs from ProximityPrompts that have an `Opens` attribute;
* a custom-styled ProximityPrompt look.

### Controls.lua
* First-person lock in house scenes (`Player.CameraMode = LockFirstPerson`), free camera in the lobby.
* Sprint (Shift) with stamina; crouch (C, Ctrl); flashlight (F) with battery drain; head bob.
* Footsteps by floor material; item hotbar keys 1–9; click to use the equipped item.
* Mobile touch buttons via ContextActionService.
* Spectate camera when dead.

### World.lua
* Lighting, Atmosphere, Sky and post-processing per scene and clock: lobby night, house day/sunset/night with power on or off.
* Ambient sound loops and weather (light rain, wind).
* TV screen content: daytime static and news, EAS during alert.
* Decorative animation.

### Hide.lua
* Camera inside the hide spot, looking out through the slats; breathing.
* Calls `UI.qte` after 10 s and reports through `Action "qte"`; the exit key sends `Action "unhide"`.

### Fx.lua
* Handles `Fx` events: sounds, shakes, flashes, coins and apples feedback.
* Forwards `"jumpscare"` to `InmatesClient.jumpscare(key, model)`.

### InmatesClient.lua
* Animates every model in `workspace.Inmates` via its `Inmates/<Key>.animate`.
* Proximity audio cues and the jumpscare cinematic.

## 11. Inmate module contract — `ReplicatedStorage/Inmates/<Key>.lua`
```lua
return {
  key = "Gladys", num = "102", name = "ГЛАДИС", en = "GLADYS", class = "Класс угрозы: ...",
  color = Color3, hp = 200, speed = 11, chase = 19,   -- studs/s (players walk 12, sprint 20)
  difficulty = 1, minNight = 1,                        -- tier 1..3 from which it can appear
  alert = { "...", "..." },                            -- broadcast lines after Config.AlertHead
  tip = "...",                                         -- one-line survival tip for HUD/dossier
  directive = nil,                                     -- or {code="stay_indoors", text="..."} (later)
  build = function(ctx) -> Model,                      -- Model with Humanoid + HumanoidRootPart (PrimaryPart), Motor6D rig (see Shared/Rig.lua)
  animate = function(model, dt, t, ctx),               -- CLIENT, every frame: procedural animation from model attributes/velocity
  server = { spawn = function(inm) end?, tick = function(inm, dt) end?, onStun = ..., onDamage = ... },
}
```
Default server behaviour (`inm:hunt(dt)` in InmateAI):
1. Approach an entry from outside and open or break it.
2. Roam the rooms.
3. Detect players by sight (line of sight, ~60° cone, lit or close) and by hearing (sprinting, doors).
4. Chase.
5. Check hide spots: it knows if it saw you hide; otherwise it sometimes checks.
6. Attack in melee.
7. At dawn it leaves.

## 12. Visual quality bar

Lighting is Realistic (Future), so geometry and lights matter:
* **Thickness:** walls are thick, and floors and ceilings are separate parts.
* **Interior detail:**
  * baseboards, crown moulding, door and window casings, window sills;
  * curtains, rugs, wall pictures, shelves with books and clutter;
  * kitchen appliances, a sink, a bathtub;
  * beds with pillows and blankets.
* **Exterior detail:**
  * siding planks, roof overhang and gutters, porch with columns, chimney;
  * fence boards, mailbox, driveway, car, street lamps;
  * silhouettes of neighbouring houses.
* **Lights:** warm interior PointLight/SpotLight; cold blue moonlit exterior handled by World. Neon only for small emissive bits (bulbs, LEDs, screens).
* **Variety:**
  * Do not make big single-colour slabs. Vary the colour slightly per plank or tile, mix materials, and add trim.
  * Use the `B.mat` new materials where they exist (`Carpet`, `Plaster`, `RoofShingles`, `CeramicTiles`), with fallbacks.
* **Budget:** house + lot ≤ 6000 parts, lobby ≤ 5000 parts. Build time should stay under ~2 s, so avoid per-part `task.wait`.
* **Animations:** everything that moves is animated client-side (World/InmatesClient), from attributes.
