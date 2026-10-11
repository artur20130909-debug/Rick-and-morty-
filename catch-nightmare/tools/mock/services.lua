-- tools/mock/services.lua — часть 5 мока Roblox (продолжение ../amber-roblox/tools/mock/roblox.lua).
-- Службы (Players, RunService, TweenService, DataStoreService, MarketplaceService ...), игроки и персонажи,
-- удалённые события, запуск скриптов и require, шаг времени и помощники харнесса (mock.*).
-- Файл не самостоятельный: run_mock.py склеивает roblox.lua + этот файл в один чанк,
-- поэтому здесь доступны локальные имена roblox.lua (G, I, v3, E, throw, curCtx ...).
local function part5()
local DATA, defclass, N, newInstance = mock.DATA, I.defclass, I.N, I.newInstance
local isInst, fullName, getEvent, fireEvent = I.isInst, I.fullName, I.getEvent, I.fireEvent
local fireSignal, newSignal, classes = I.fireSignal, I.newSignal, mock.classes
local setParentRaw, findChild, isKnownProp = I.setParentRaw, I.findChild, I.isKnownProp
local V0 = v3(0, 0, 0)
local IDENT = cfnew(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)

---------------------------------------------------------------- копирование аргументов
local function copyVal(v, remote, seen)
	local t = rawtype(v)
	if t == "table" then
		if isInst(v) or isMockObj(v) then return v end
		if seen[v] then
			if remote then suspicious("REMOTE", "циклическая таблица в аргументах") end
			return nil
		end
		seen[v] = true
		local o, nNum, nStr, maxN = {}, 0, 0, 0
		for k, x in pairs(v) do
			local kt = rawtype(k)
			if kt == "number" then
				nNum = nNum + 1
				if k > maxN then maxN = k end
			elseif kt == "string" then
				nStr = nStr + 1
			elseif remote then
				suspicious("REMOTE", "ключ типа " .. kt .. " не передаётся")
			end
			o[k] = copyVal(x, remote, seen)
		end
		if remote and nNum > 0 and nStr > 0 then suspicious("REMOTE", "смешанная таблица (числовые и строковые ключи) теряет данные") end
		if remote and nNum > 0 and nStr == 0 and maxN ~= nNum then suspicious("REMOTE", "массив с дырами теряет элементы") end
		seen[v] = nil
		return o
	elseif t == "function" or t == "thread" or t == "userdata" then
		if remote then suspicious("REMOTE", t .. " нельзя передать через Remote") end
		return nil
	end
	return v
end
function I.copyArgs(remote, ...)
	local n = select("#", ...)
	local out = {}
	for i = 1, n do out[i] = copyVal((select(i, ...)), remote, {}) end
	return tunpack(out, 1, n)
end

---------------------------------------------------------------- службы
local services = {}
local SERVICE = {}
local function defservice(name, super, spec)
	spec = spec or {}
	spec.service = true
	spec.noCreate = true
	defclass(name, super or "Instance", spec)
	SERVICE[name] = true
end

local game
local playerList = {}
mock.players = playerList
local function getService(name)
	local s = services[name]
	if s then return s end
	if not SERVICE[name] then throw("'" .. tostring(name) .. "' is not a valid Service name") end
	s = newInstance(classes[name])
	local d = s[DATA]
	d.p.Name = name
	if name == "Workspace" then I.setWorkspace(s) end
	if name == "ServerScriptService" or name == "ServerStorage" then d.serverOnly = true end
	services[name] = s
	setParentRaw(s, d, game)
	if classes[name].onCreate then classes[name].onCreate(s, d) end
	return s
end
mock.service = getService

defclass("ServiceProvider", "Instance", { noCreate = true })
defclass("DataModel", "ServiceProvider", {
	props = { PlaceId = 0, GameId = 0, CreatorId = 0, CreatorType = E("CreatorType", "User"), JobId = "mock-job", PlaceVersion = 0, PrivateServerId = "", PrivateServerOwnerId = 0 },
	methods = {
		GetService = function(self, name) return getService(name) end,
		FindService = function(self, name) return services[name] end,
		BindToClose = function(self, fn)
			if rawtype(fn) ~= "function" then throw("BindToClose: function expected") end
			mock.closeHandlers = mock.closeHandlers or {}
			table.insert(mock.closeHandlers, { fn = fn, ctx = curCtx() })
		end,
		IsLoaded = function() return true end,
	},
	events = { "Loaded", "Close" },
	noCreate = true,
})

---------------------------------------------------------------- Workspace
defservice("Workspace", "WorldRoot", {
	props = { Gravity = 196.2, FallenPartsDestroyHeight = -500, StreamingEnabled = false, CurrentCamera = N "Instance:Camera",
		DistributedGameTime = 0, AllowThirdPartySales = false, AirDensity = 0.0012, GlobalWind = V0, TouchesUseCollisionGroups = false },
	methods = {
		GetServerTimeNow = function() return mock.epoch + mock.now end,
		Raycast = function(self, o, d, p) return I.raycast(o, d, p) end,
		GetPartBoundsInBox = function() return {} end,
		GetPartBoundsInRadius = function() return {} end,
		GetPartsInPart = function() return {} end,
		GetRealPhysicsFPS = function() return 60 end,
		Blockcast = function() return nil end,
		Spherecast = function() return nil end,
	},
})

---------------------------------------------------------------- игроки
defclass("PlayerGui", "Instance", { props = { SelectionImageObject = N "Instance", ScreenOrientation = E("ScreenOrientation", "LandscapeSensor") },
	methods = { GetTopbarTransparency = function() return 0 end, SetTopbarTransparency = function() end }, noCreate = true })
defclass("Backpack", "Instance", { noCreate = true })
defclass("PlayerScripts", "Instance", { noCreate = true })
defclass("StarterPlayerScripts", "Instance", { noCreate = true })
defclass("StarterCharacterScripts", "Instance", { noCreate = true })
defclass("StarterGear", "Instance", { noCreate = true })

local loadCharacter, removePlayer

defclass("Player", "Instance", {
	props = { UserId = 0, DisplayName = "", AccountAge = 30, MembershipType = E("MembershipType", "None"), Character = N "Instance:Model",
		Team = N "Instance:Team", Neutral = true, RespawnLocation = N "Instance:SpawnLocation", CameraMaxZoomDistance = 128,
		CameraMinZoomDistance = 0.5, CameraMode = E("CameraMode", "Classic"), HealthDisplayDistance = 100, NameDisplayDistance = 100,
		AutoJumpEnabled = true, CharacterAppearanceId = 0, CanLoadCharacterAppearance = true, LocaleId = "ru-ru", ReplicationFocus = N "Instance",
		DevEnableMouseLock = true },
	methods = {
		LoadCharacter = function(self)
			if curCtx().side ~= "server" then throw("LoadCharacter can only be called by the backend server") end
			loadCharacter(self)
		end,
		Kick = function(self, msg)
			mock.emit("kick", tostring(self[DATA].p.Name) .. ": " .. tostring(msg or ""))
			mock.kicked = mock.kicked or {}
			table.insert(mock.kicked, { name = self[DATA].p.Name, msg = msg })
			mock.timer(0, function() removePlayer(self) end)
		end,
		GetMouse = function() suspicious("UNIMPLEMENTED", "Player:GetMouse в моке нет") return nil end,
		GetNetworkPing = function() return 0.06 end,
		IsInGroup = function() return false end,
		GetRankInGroup = function() return 0 end,
		GetRoleInGroup = function() return "Guest" end,
		HasAppearanceLoaded = function() return true end,
		ClearCharacterAppearance = function() end,
		GetFriendsOnline = function() return {} end,
		IsFriendsWith = function() return false end,
		DistanceFromCharacter = function(self, p)
			local c = self[DATA].p.Character
			local h = c and findChild(c[DATA], "Head")
			if not h then return 0 end
			return (h.Position - p).Magnitude
		end,
	},
	events = { "CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded", "Chatted", "Idled", "OnTeleport" },
	noCreate = true,
})

defservice("Players", nil, {
	props = { MaxPlayers = 8, RespawnTime = 5, CharacterAutoLoads = true, PreferredPlayers = 8, BubbleChat = true, ClassicChat = false },
	get = {
		LocalPlayer = function() return curCtx().player end,
		NumPlayers = function() return #playerList end,
	},
	methods = {
		GetPlayers = function()
			local o = {}
			for i, p in ipairs(playerList) do o[i] = p end
			return o
		end,
		GetPlayerByUserId = function(self, id)
			for _, p in ipairs(playerList) do if p[DATA].p.UserId == id then return p end end
			return nil
		end,
		GetPlayerFromCharacter = function(self, m)
			if m == nil then return nil end
			for _, p in ipairs(playerList) do if p[DATA].p.Character == m then return p end end
			return nil
		end,
		GetNameFromUserIdAsync = function(self, id) return "Player" .. tostring(id) end,
		GetUserIdFromNameAsync = function() return 1 end,
		GetUserThumbnailAsync = function() return "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150", true end,
	},
	events = { "PlayerAdded", "PlayerRemoving", "PlayerMembershipChanged" },
})

defservice("StarterPlayer", nil, {
	props = { CameraMaxZoomDistance = 128, CameraMinZoomDistance = 0.5, CharacterWalkSpeed = 16, CharacterJumpHeight = 7.2, CharacterJumpPower = 50,
		CharacterUseJumpPower = false, CameraMode = E("CameraMode", "Classic"), HealthDisplayDistance = 100, NameDisplayDistance = 100,
		AutoJumpEnabled = true, EnableMouseLockOption = true, LoadCharacterAppearance = true, UserEmotesEnabled = true, CharacterMaxSlopeAngle = 89 },
})

---------------------------------------------------------------- RunService
local renderBinds = {}
local function clientOnly(what)
	return function(s)
		s.onConnect = function(sig, ctx)
			if ctx.side ~= "client" then throw(what .. " event can only be used from local scripts") end
		end
	end
end
defservice("RunService", nil, {
	methods = {
		IsServer = function() return curCtx().side == "server" end,
		IsClient = function() return curCtx().side == "client" end,
		IsStudio = function() return mock.isStudio ~= false end,
		IsRunning = function() return true end,
		IsRunMode = function() return false end,
		IsEdit = function() return false end,
		BindToRenderStep = function(self, name, prio, fn)
			local c = curCtx()
			if c.side ~= "client" then throw("BindToRenderStep can only be called from the client") end
			renderBinds[tostring(name) .. "\0" .. c.key] = { fn = fn, ctx = c, prio = prio }
		end,
		UnbindFromRenderStep = function(self, name)
			renderBinds[tostring(name) .. "\0" .. curCtx().key] = nil
		end,
	},
	events = { "Heartbeat", "RenderStepped", "Stepped", "PreSimulation", "PostSimulation", "PreRender", "PreAnimation" },
	eventInit = { RenderStepped = clientOnly("RenderStepped"), PreRender = clientOnly("PreRender") },
})

---------------------------------------------------------------- удалённые события
local pending = setmt({}, { __mode = "k" }) -- remote -> { [player] = { args... } }
local function hasClientConn(sig, player)
	if not sig then return false end
	for _, c in ipairs(sig.conns) do
		if c.Connected and c.ctx.side == "client" and c.ctx.player == player then return true end
	end
	return false
end

local function deliverClient(remote, d, player, args)
	if not player[DATA].parent then return end
	local sig = d.sig and d.sig.OnClientEvent
	if hasClientConn(sig, player) then
		fireSignal(sig, function(ctx) return ctx.side == "client" and ctx.player == player end, tunpack(args, 1, args.n))
	else
		-- как в Roblox: событие ждёт, пока клиент подпишется
		local q = pending[remote] or {}
		pending[remote] = q
		q[player] = q[player] or {}
		table.insert(q[player], args)
	end
end

local function onClientConnect(s, self, d)
	s.onConnect = function(sig, ctx)
		if ctx.side ~= "client" then throw("OnClientEvent can only be used on the client") end
		local q = pending[self]
		local list = q and q[ctx.player]
		if list then
			q[ctx.player] = nil
			mock.timer(0, function()
				for _, args in ipairs(list) do deliverClient(self, d, ctx.player, args) end
			end)
		end
	end
end
classes.RemoteEvent.eventInit.OnClientEvent = onClientConnect
classes.UnreliableRemoteEvent.eventInit.OnClientEvent = onClientConnect

local function needPlayer(p, what)
	if not isInst(p) or p[DATA].cls.name ~= "Player" then throw(what .. ": Player argument must be a Player object") end
end

-- вызвать функцию в другом контексте и дождаться результата
local function invokeIn(ctx, fn, ...)
	local caller, ismain = co_running()
	if ismain then throw("Invoke из главного потока") end
	local args = tpack(...)
	local res, waiting = nil, false
	local co = newThread(function()
		res = tpack(xpcall(fn, function(e) return { e = e, tb = debug.traceback(luauToString(e), 2) } end, tunpack(args, 1, args.n)))
		if waiting then resume(caller) end
	end, ctx)
	resume(co)
	if not res then
		waiting = true
		co_yield()
	end
	if not res[1] then
		mock.recordError(res[2].e, res[2].tb, ctx)
		throw("ошибка в обработчике RemoteFunction: " .. luauToString(res[2].e))
	end
	return I.copyArgs(true, tunpack(res, 2, res.n))
end

I.remote = {
	FireServer = function(self, ...)
		local c = curCtx()
		if c.side ~= "client" then throw("FireServer can only be called from the client") end
		local player = c.player
		local args = tpack(I.copyArgs(true, ...))
		local d = self[DATA]
		mock.timer(mock.netDelay or 0.03, function()
			if not player[DATA].parent then return end
			local s = d.sig and d.sig.OnServerEvent
			if s then fireSignal(s, nil, player, tunpack(args, 1, args.n)) end
		end)
	end,
	FireClient = function(self, player, ...)
		if curCtx().side ~= "server" then throw("FireClient can only be called from the server") end
		needPlayer(player, "FireClient")
		local args = tpack(I.copyArgs(true, ...))
		local d = self[DATA]
		mock.timer(mock.netDelay or 0.03, function() deliverClient(self, d, player, args) end)
	end,
	FireAllClients = function(self, ...)
		if curCtx().side ~= "server" then throw("FireAllClients can only be called from the server") end
		local args = tpack(I.copyArgs(true, ...))
		local d = self[DATA]
		local list = {}
		for i, p in ipairs(playerList) do list[i] = p end
		mock.timer(mock.netDelay or 0.03, function()
			for _, p in ipairs(list) do deliverClient(self, d, p, args) end
		end)
	end,
	InvokeServer = function(self, ...)
		local c = curCtx()
		if c.side ~= "client" then throw("InvokeServer can only be called from the client") end
		local d = self[DATA]
		local cb = d.cb and d.cb.OnServerInvoke
		if not cb then
			suspicious("REMOTE", "InvokeServer: OnServerInvoke не задан у " .. fullName(self))
			return nil
		end
		task.wait(mock.netDelay or 0.03)
		return invokeIn(SERVER, cb, c.player, I.copyArgs(true, ...))
	end,
	InvokeClient = function(self, player, ...)
		if curCtx().side ~= "server" then throw("InvokeClient can only be called from the server") end
		needPlayer(player, "InvokeClient")
		local d = self[DATA]
		local cb = d.cbClient and d.cbClient[player]
		if not cb then throw("InvokeClient: OnClientInvoke не задан") end
		return invokeIn(clientCtx(player), cb, I.copyArgs(true, ...))
	end,
	setCallback = function(self, d, name, f)
		if f ~= nil and rawtype(f) ~= "function" then throw(name .. " must be a function") end
		if name == "OnClientInvoke" then
			d.cbClient = d.cbClient or {}
			d.cbClient[curCtx().player or false] = f
		else
			if curCtx().side ~= "server" then throw("OnServerInvoke can only be set on the server") end
			d.cb = d.cb or {}
			d.cb[name] = f
		end
	end,
}

---------------------------------------------------------------- твины
local tweens = {}
local function lerpVal(a, b, t)
	local ta = rawtype(a)
	if ta == "number" then return a + (b - a) * t end
	local tn = typeof(a)
	if tn == "UDim" then return udim(a.Scale + (b.Scale - a.Scale) * t, a.Offset + (b.Offset - a.Offset) * t) end
	if tn == "Color3" or tn == "Vector3" or tn == "Vector2" or tn == "CFrame" or tn == "UDim2" then return a:Lerp(b, t) end
	if t >= 1 then return b end
	return a
end

defclass("TweenBase", "Instance", {
	props = { PlaybackState = E("PlaybackState", "Begin") },
	methods = {
		Play = function(self)
			local d = self[DATA]
			local tw = d.tw
			tw.start = {}
			for k in pairs(tw.props) do tw.start[k] = tw.inst[k] end
			tw.elapsed = 0
			tw.playing = true
			d.p.PlaybackState = E("PlaybackState", "Playing")
			tweens[self] = true
		end,
		Pause = function(self)
			self[DATA].tw.playing = false
			tweens[self] = nil
			self[DATA].p.PlaybackState = E("PlaybackState", "Paused")
		end,
		Cancel = function(self)
			self[DATA].tw.playing = false
			tweens[self] = nil
			self[DATA].p.PlaybackState = E("PlaybackState", "Cancelled")
		end,
	},
	events = { "Completed" },
	noCreate = true,
})
defclass("Tween", "TweenBase", { props = { Instance = N "Instance" }, noCreate = true })

local function createTween(inst, info, props)
	if not isInst(inst) then throw("TweenService:Create: Instance expected, got " .. typeof(inst)) end
	if typeof(info) ~= "TweenInfo" then throw("TweenService:Create: TweenInfo expected, got " .. typeof(info)) end
	if rawtype(props) ~= "table" then throw("TweenService:Create: table expected for property table") end
	local cls = inst[DATA].cls
	for k, v in pairs(props) do
		if not isKnownProp(cls, k) then throw("TweenService:Create no property named '" .. tostring(k) .. "' for object '" .. inst[DATA].p.Name .. "'") end
		local cur = inst[k]
		if typeof(cur) ~= typeof(v) and not (cur == nil) then
			throw("TweenService:Create property named '" .. k .. "' cannot be tweened due to type mismatch (property is a '" .. typeof(cur) .. "', but given type is '" .. typeof(v) .. "')")
		end
	end
	local t = newInstance(classes.Tween)
	local d = t[DATA]
	d.p.Instance = inst
	d.tw = { inst = inst, info = info, props = props }
	return t
end

local function stepTweens(dt)
	for t in pairs(tweens) do
		local d = t[DATA]
		local tw = d.tw
		if not tw.playing or tw.inst[DATA].destroyed then
			tweens[t] = nil
		else
			tw.elapsed = tw.elapsed + dt
			local time = tw.info.Time
			local a = time <= 0 and 1 or math.min(1, math.max(0, (tw.elapsed - tw.info.DelayTime) / time))
			for k, target in pairs(tw.props) do
				local ok, err = pcall(function() tw.inst[k] = lerpVal(tw.start[k], target, a) end)
				if not ok then mock.recordError(err, err, SERVER) end
			end
			if a >= 1 then
				tweens[t] = nil
				tw.playing = false
				d.p.PlaybackState = E("PlaybackState", "Completed")
				fireEvent(d, "Completed", E("PlaybackState", "Completed"))
				if tw.cb then tw.cb(E("TweenStatus", "Completed")) end
			end
		end
	end
end

defservice("TweenService", nil, {
	methods = {
		Create = function(self, inst, info, props) return createTween(inst, info, props) end,
		GetValue = function(self, a) return a end,
	},
})

I.guiTween = function(self, props, info, override, cb)
	local t = createTween(self, info, props)
	t[DATA].tw.cb = cb
	classes.TweenBase.methods.Play(t)
	return true
end

---------------------------------------------------------------- простые службы
defservice("ReplicatedStorage")
defservice("ReplicatedFirst")
defservice("ServerScriptService", nil, { props = { LoadStringEnabled = false } })
defservice("ServerStorage")
defservice("StarterPack")
defservice("Teams", nil, { methods = { GetTeams = function(self) return self:GetChildren() end } })
defservice("Chat", nil, { props = { BubbleChatEnabled = true, LoadDefaultChat = true } })
defservice("Stats")
defservice("LocalizationService", nil, { props = { RobloxLocaleId = "ru-ru", SystemLocaleId = "ru-ru" } })
defservice("TextChatService", nil, { props = { ChatVersion = E("ChatVersion", "TextChatService"), CreateDefaultCommands = true, CreateDefaultTextChannels = true },
	events = { "MessageReceived", "SendingMessage" } })
defservice("ProximityPromptService", nil, { props = { Enabled = true, MaxPromptsVisible = 16 },
	events = { "PromptTriggered", "PromptShown", "PromptHidden", "PromptButtonHoldBegan", "PromptButtonHoldEnded", "PromptTriggerEnded" } })
defservice("GuiService", nil, { props = { AutoSelectGuiEnabled = true, SelectedObject = N "Instance" },
	methods = { GetGuiInset = function() return v2(0, 58), v2(0, 0) end, IsTenFootInterface = function() return false end }, events = { "MenuOpened", "MenuClosed" } })
defservice("TextService", nil, { methods = { GetTextSize = function(self, text, size) return v2(#tostring(text) * size * 0.5, size) end } })
defservice("BadgeService", nil, { methods = { AwardBadge = function() return true end, UserHasBadgeAsync = function() return false end } })
defservice("PolicyService", nil, { methods = { GetPolicyInfoForPlayerAsync = function() return { ArePaidRandomItemsRestricted = false, AllowedExternalLinkReferences = {}, IsPaidItemTradingAllowed = true, IsSubjectToChinaPolicies = false } end } })
defservice("AnalyticsService", nil, { methods = { LogEconomyEvent = function() end, LogCustomEvent = function() end, LogProgressionEvent = function() end, LogOnboardingFunnelStepEvent = function() end } })
defservice("PhysicsService", nil, { methods = {
	RegisterCollisionGroup = function() end, CollisionGroupSetCollidable = function() end, CollisionGroupsAreCollidable = function() return true end,
	GetRegisteredCollisionGroups = function() return {} end, IsCollisionGroupRegistered = function() return true end } })
defservice("ContextActionService", nil, { methods = {
	BindAction = function() end, BindActionAtPriority = function() end, UnbindAction = function() end, UnbindAllActions = function() end,
	SetTitle = function() end, SetImage = function() end, SetPosition = function() end, SetDescription = function() end, GetButton = function() return nil end } })
defservice("UserInputService", nil, {
	props = { TouchEnabled = false, KeyboardEnabled = true, MouseEnabled = true, GamepadEnabled = false, VREnabled = false,
		MouseBehavior = E("MouseBehavior", "Default"), MouseIconEnabled = true, ModalEnabled = false, MouseDeltaSensitivity = 1 },
	methods = {
		GetLastInputType = function() return E("UserInputType", "Keyboard") end,
		IsKeyDown = function() return false end,
		IsMouseButtonPressed = function() return false end,
		GetMouseLocation = function() return v2(0, 0) end,
		GetKeysPressed = function() return {} end,
		GetFocusedTextBox = function() return nil end,
		GetConnectedGamepads = function() return {} end,
	},
	events = { "InputBegan", "InputEnded", "InputChanged", "TouchStarted", "TouchEnded", "TouchTap", "TouchMoved", "JumpRequest",
		"LastInputTypeChanged", "WindowFocused", "WindowFocusReleased" },
})
defservice("StarterGui", nil, {
	props = { ShowDevelopmentGui = true, ResetPlayerGuiOnSpawn = true, ScreenOrientation = E("ScreenOrientation", "LandscapeSensor") },
	methods = {
		SetCoreGuiEnabled = function(self, t, on)
			if curCtx().side ~= "client" then suspicious("CLIENT_ONLY", "StarterGui:SetCoreGuiEnabled на сервере ничего не делает") end
			if typeof(t) ~= "EnumItem" then throw("SetCoreGuiEnabled: Enum.CoreGuiType expected") end
		end,
		GetCoreGuiEnabled = function() return true end,
		SetCore = function(self, name)
			if curCtx().side ~= "client" then throw("SetCore can only be called from a local script") end
		end,
		GetCore = function() return nil end,
	},
})
defservice("Lighting", nil, {
	props = { Ambient = c3(0.27, 0.27, 0.33), Brightness = 2, ClockTime = 14, ColorShift_Bottom = c3(0, 0, 0), ColorShift_Top = c3(0, 0, 0),
		EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1, ExposureCompensation = 0, FogColor = c3(0.75, 0.75, 0.75), FogEnd = 100000,
		FogStart = 0, GeographicLatitude = 41.7, GlobalShadows = true, OutdoorAmbient = c3(0.5, 0.5, 0.5), ShadowSoftness = 0.2,
		Technology = E("Technology", "Future"), TimeOfDay = "14:00:00", LightingStyle = E("LightingStyle", "Realistic"), PrioritizeLightingQuality = true },
	methods = {
		GetMinutesAfterMidnight = function(self) return self[DATA].p.ClockTime * 60 end,
		SetMinutesAfterMidnight = function(self, m) self.ClockTime = (m / 60) % 24 end,
		GetSunDirection = function() return v3(0, 1, 0) end,
		GetMoonDirection = function() return v3(0, -1, 0) end,
	},
})
defservice("SoundService", nil, {
	props = { AmbientReverb = E("ReverbType", "NoReverb"), DistanceFactor = 3.33, DopplerScale = 1, RolloffScale = 1, RespectFilteringEnabled = true },
	methods = {
		PlayLocalSound = function(self, s)
			if not isInst(s) or not s[DATA].cls.isa.Sound then throw("PlayLocalSound: Sound expected") end
			s:Play()
		end,
		SetListener = function() end,
	},
})
defservice("Debris", nil, { props = { MaxItems = 1000 }, methods = {
	AddItem = function(self, inst, t)
		if not isInst(inst) then throw("Debris:AddItem: Instance expected") end
		mock.timer(tonumber(t) or 10, function() if not inst[DATA].destroyed then inst:Destroy() end end)
	end } })

defservice("CollectionService", nil, {
	methods = {
		GetTagged = function(self, tag)
			local o = {}
			for inst in pairs(I.tagged[tag] or {}) do o[#o + 1] = inst end
			return o
		end,
		AddTag = function(self, inst, tag) inst:AddTag(tag) end,
		RemoveTag = function(self, inst, tag) inst:RemoveTag(tag) end,
		HasTag = function(self, inst, tag) return inst:HasTag(tag) end,
		GetTags = function(self, inst) return inst:GetTags() end,
		GetInstanceAddedSignal = function(self, tag)
			local k = "add:" .. tag
			I.tagSignals[k] = I.tagSignals[k] or newSignal("InstanceAdded:" .. tag, self)
			return I.tagSignals[k]
		end,
		GetInstanceRemovedSignal = function(self, tag)
			local k = "rem:" .. tag
			I.tagSignals[k] = I.tagSignals[k] or newSignal("InstanceRemoved:" .. tag, self)
			return I.tagSignals[k]
		end,
		GetAllTags = function()
			local o = {}
			for tag in pairs(I.tagged) do o[#o + 1] = tag end
			return o
		end,
	},
})

---------------------------------------------------------------- JSON и HttpService
local function jsonEncode(v, path)
	local t = rawtype(v)
	if t == "nil" then return "null" end
	if t == "boolean" then return v and "true" or "false" end
	if t == "number" then
		if v ~= v or v == huge or v == -huge then throw("JSON: число NaN/inf (" .. path .. ")") end
		if v == floor(v) and abs(v) < 1e15 then return sformat("%d", v) end
		return sformat("%.14g", v)
	end
	if t == "string" then
		return '"' .. sgsub(v, '[%c"\\]', function(c)
			local m = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
			return m[c] or sformat("\\u%04x", sbyte(c))
		end) .. '"'
	end
	if t == "table" and not isInst(v) and not isMockObj(v) then
		local n, count, strKeys = #v, 0, false
		for k in pairs(v) do
			count = count + 1
			if rawtype(k) ~= "number" then strKeys = true end
		end
		if count == 0 then return "[]" end
		if not strKeys then
			if count ~= n then throw("JSON: массив с дырами (" .. path .. ") — DataStore/JSON его не сохранит") end
			local parts = {}
			for i = 1, n do parts[i] = jsonEncode(v[i], path .. "[" .. i .. "]") end
			return "[" .. tconcat(parts, ",") .. "]"
		end
		local parts = {}
		for k, x in pairs(v) do
			if rawtype(k) ~= "string" then throw("JSON: смешанные ключи в таблице (" .. path .. ")") end
			parts[#parts + 1] = jsonEncode(k, path) .. ":" .. jsonEncode(x, path .. "." .. k)
		end
		tsort(parts)
		return "{" .. tconcat(parts, ",") .. "}"
	end
	throw("JSON: нельзя сохранить " .. typeof(v) .. " (" .. path .. ")")
end

local function jsonDecode(s)
	local pos = 1
	local function ws() pos = sfind(s, "[^ \t\r\n]", pos) or (#s + 1) end
	local val
	local function str()
		local out = {}
		pos = pos + 1
		while true do
			local c = ssub(s, pos, pos)
			if c == '"' then
				pos = pos + 1
				break
			elseif c == "\\" then
				local e = ssub(s, pos + 1, pos + 1)
				local m = { n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
				if e == "u" then
					out[#out + 1] = utf8.char(tonumber(ssub(s, pos + 2, pos + 5), 16))
					pos = pos + 6
				else
					out[#out + 1] = m[e] or e
					pos = pos + 2
				end
			elseif c == "" then
				throw("JSON: обрыв строки")
			else
				out[#out + 1] = c
				pos = pos + 1
			end
		end
		return tconcat(out)
	end
	function val()
		ws()
		local c = ssub(s, pos, pos)
		if c == "{" then
			local o = {}
			pos = pos + 1
			ws()
			if ssub(s, pos, pos) == "}" then pos = pos + 1 return o end
			while true do
				ws()
				local k = str()
				ws()
				pos = pos + 1 -- :
				o[k] = val()
				ws()
				local d = ssub(s, pos, pos)
				pos = pos + 1
				if d == "}" then return o end
			end
		elseif c == "[" then
			local o = {}
			pos = pos + 1
			ws()
			if ssub(s, pos, pos) == "]" then pos = pos + 1 return o end
			while true do
				o[#o + 1] = val()
				ws()
				local d = ssub(s, pos, pos)
				pos = pos + 1
				if d == "]" then return o end
			end
		elseif c == '"' then
			return str()
		elseif ssub(s, pos, pos + 3) == "true" then pos = pos + 4 return true
		elseif ssub(s, pos, pos + 4) == "false" then pos = pos + 5 return false
		elseif ssub(s, pos, pos + 3) == "null" then pos = pos + 4 return nil
		else
			local num = smatch(s, "^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
			if not num or num == "" then throw("JSON: неожиданный символ на позиции " .. pos) end
			pos = pos + #num
			return tonumber(num)
		end
	end
	return val()
end
mock.jsonEncode, mock.jsonDecode = jsonEncode, jsonDecode

local guidN = 0
defservice("HttpService", nil, { props = { HttpEnabled = false }, methods = {
	JSONEncode = function(self, v) return jsonEncode(v, "value") end,
	JSONDecode = function(self, s) return jsonDecode(s) end,
	GenerateGUID = function(self, braces)
		guidN = guidN + 1
		local g = sformat("00000000-0000-4000-8000-%012d", guidN)
		return braces == false and g or ("{" .. g .. "}")
	end,
	UrlEncode = function(self, s) return s end,
	GetAsync = function() throw("Http requests are not enabled. Enable via game settings") end,
	PostAsync = function() throw("Http requests are not enabled. Enable via game settings") end,
} })

---------------------------------------------------------------- DataStore
mock.dsData = mock.dsData or {}
local stores = {}
local function dsWait()
	local _, ismain = co_running()
	if ismain then throw("DataStore: вызов из главного потока (нужна корутина)") end
	task.wait(mock.dsDelay or 0.05)
end
local function dsKey(key)
	if rawtype(key) ~= "string" and rawtype(key) ~= "number" then throw("DataStore: ключ должен быть строкой") end
	key = tostring(key)
	if #key > 50 then throw("DataStore: ключ длиннее 50 символов") end
	return key
end
defclass("GlobalDataStore", "Instance", {
	methods = {
		GetAsync = function(self, key)
			key = dsKey(key)
			dsWait()
			local raw = self[DATA].data[key]
			if raw == nil then return nil end
			return jsonDecode(raw)
		end,
		SetAsync = function(self, key, value)
			key = dsKey(key)
			local raw = jsonEncode(value, key)
			if #raw > 4000000 then throw("DataStore: значение больше 4 МБ") end
			dsWait()
			self[DATA].data[key] = raw
			mock.dsWrites = (mock.dsWrites or 0) + 1
		end,
		UpdateAsync = function(self, key, fn)
			key = dsKey(key)
			dsWait()
			local raw = self[DATA].data[key]
			local old = raw and jsonDecode(raw) or nil
			local new = fn(old)
			if new ~= nil then self[DATA].data[key] = jsonEncode(new, key) end
			return new
		end,
		RemoveAsync = function(self, key)
			key = dsKey(key)
			dsWait()
			local raw = self[DATA].data[key]
			self[DATA].data[key] = nil
			return raw and jsonDecode(raw) or nil
		end,
		IncrementAsync = function(self, key, delta)
			key = dsKey(key)
			dsWait()
			local raw = self[DATA].data[key]
			local v = (raw and tonumber(raw) or 0) + (delta or 1)
			self[DATA].data[key] = jsonEncode(v, key)
			return v
		end,
	},
	noCreate = true,
})
defclass("DataStore", "GlobalDataStore", { noCreate = true })
defservice("DataStoreService", nil, { methods = {
	GetDataStore = function(self, name, scope)
		if mock.dataStoreError then throw(mock.dataStoreError) end
		local key = tostring(name) .. "/" .. tostring(scope or "global")
		local s = stores[key]
		if not s then
			s = newInstance(classes.DataStore)
			s[DATA].p.Name = tostring(name)
			mock.dsData[key] = mock.dsData[key] or {}
			s[DATA].data = mock.dsData[key]
			stores[key] = s
		end
		return s
	end,
	GetRequestBudgetForRequestType = function() return 100 end,
} })

---------------------------------------------------------------- покупки
defservice("MarketplaceService", nil, {
	get = { ProcessReceipt = function() throw("ProcessReceipt is a callback member of MarketplaceService; you can only set the callback value, get is not available") end },
	set = { ProcessReceipt = function(self, d, f)
		if curCtx().side ~= "server" then throw("ProcessReceipt can only be set on the server") end
		d.processReceipt = f
	end },
	methods = {
		PromptProductPurchase = function(self, player, id)
			needPlayer(player, "PromptProductPurchase")
			mock.prompts = mock.prompts or {}
			table.insert(mock.prompts, { kind = "product", player = player, id = id })
		end,
		PromptGamePassPurchase = function(self, player, id)
			needPlayer(player, "PromptGamePassPurchase")
			mock.prompts = mock.prompts or {}
			table.insert(mock.prompts, { kind = "pass", player = player, id = id })
		end,
		PromptPurchase = function() end,
		UserOwnsGamePassAsync = function(self, uid, id)
			task.wait(0.02)
			return (mock.ownedPasses or {})[tostring(uid) .. ":" .. tostring(id)] == true
		end,
		PlayerOwnsAsset = function() return false end,
		GetProductInfo = function(self, id) return { Name = "Mock " .. tostring(id), PriceInRobux = 0, IsForSale = true } end,
	},
	events = { "PromptGamePassPurchaseFinished", "PromptProductPurchaseFinished", "PromptPurchaseFinished" },
})

---------------------------------------------------------------- Instance.new и глобальные имена
local InstanceG = {
	new = function(cn, parent)
		local cls = classes[cn]
		if rawtype(cn) ~= "string" or not cls or cls.noCreate or cls.service then
			throw("Unable to create an Instance of type \"" .. tostring(cn) .. "\"")
		end
		local o = newInstance(cls)
		if parent ~= nil then o.Parent = parent end
		return o
	end,
	fromExisting = function(o) return o:Clone() end,
}

local mathG = {}
for k, v in pairs(math) do mathG[k] = v end
function mathG.clamp(x, a, b)
	if a > b then throw("invalid argument #3 to 'clamp' (max must be greater than or equal to min)") end
	return x < a and a or (x > b and b or x)
end
function mathG.sign(x) if x > 0 then return 1 elseif x < 0 then return -1 end return 0 end
function mathG.round(x) return floor(x + 0.5) end
function mathG.noise(x, y, z) return (math.sin((x or 0) * 12.9898 + (y or 0) * 78.233 + (z or 0) * 37.719) * 0.5) end
function mathG.pow(a, b) return a ^ b end
mathG.log10 = function(x) return math.log(x, 10) end
local tableG = {}
for k, v in pairs(table) do tableG[k] = v end
function tableG.find(t, v, init)
	for i = init or 1, #t do if t[i] == v then return i end end
	return nil
end
function tableG.clear(t) for k in pairs(t) do t[k] = nil end end
function tableG.create(n, v) local t = {} for i = 1, n do t[i] = v end return t end
function tableG.freeze(t) return t end
function tableG.isfrozen() return false end
function tableG.clone(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end
tableG.getn = function(t) return #t end
local stringG = {}
for k, v in pairs(string) do stringG[k] = v end
function stringG.split(s, sep)
	sep = sep or ","
	local out = {}
	local i = 1
	while true do
		local a, b = sfind(s, sep, i, true)
		if not a then
			out[#out + 1] = ssub(s, i)
			break
		end
		out[#out + 1] = ssub(s, i, a - 1)
		i = b + 1
	end
	return out
end
-- строковые методы ("abc"):split(...) тоже должны работать
local smt = getmetatable("")
smt.__index = stringG

G.Instance = InstanceG
G.math = mathG
G.table = tableG
G.string = stringG
G.os = { time = function(t) if t then return os.time(t) end return floor(mock.epoch + mock.now) end, clock = function() return mock.now end, date = os.date, difftime = os.difftime }
G.Vector3, G.Vector2, G.CFrame, G.Color3 = Vector3, Vector2, CFrame, Color3
G.UDim, G.UDim2, G.BrickColor, G.Enum = UDim, UDim2, BrickColor, Enum
G.typeof = typeof
G.type = rawtype
G.tostring = luauToString
G.tonumber = tonumber
G.print, G.warn = doPrint, doWarn
G.pairs, G.ipairs, G.next, G.select = pairs, ipairs, next, select
G.pcall, G.xpcall, G.error, G.assert = pcall, xpcall, error_, assert
G.rawget, G.rawset, G.rawequal, G.rawlen = rawget, rawset, rawequal, rawlen
G.setmetatable, G.getmetatable = setmt, getmetatable
G.unpack = tunpack
G.coroutine, G.utf8, G.debug = coroutine, utf8, { traceback = debug.traceback, profilebegin = function() end, profileend = function() end, info = function() return nil end }
G.task = task
G.wait = function(t) suspicious("DEPRECATED", "wait() устарел — task.wait") return task.wait(t) end
G.spawn = function(f) suspicious("DEPRECATED", "spawn() устарел — task.spawn") return task.defer(f) end
G.delay = function(t, f) suspicious("DEPRECATED", "delay() устарел — task.delay") return task.delay(t, f) end
G.tick = function() return mock.epoch + mock.now end
G.time = function() return mock.now end
G.elapsedTime = function() return mock.now end
G.shared = {}
G.gcinfo = function() return 1000 end
G.version = function() return "0.700.0" end
G.bit32 = { band = function(a, b) return a & b end, bor = function(a, b) return a | b end, bxor = function(a, b) return a ~ b end,
	lshift = function(a, n) return (a << n) & 0xFFFFFFFF end, rshift = function(a, n) return (a & 0xFFFFFFFF) >> n end, bnot = function(a) return (~a) & 0xFFFFFFFF end }

---------------------------------------------------------------- скрипты и require
local moduleCache = {}

local function compile(inst)
	local d = inst[DATA]
	local src = d.p.Source
	local chunk = "@" .. (d.srcPath or fullName(inst))
	local env = setmt({ script = inst }, {
		__index = G,
		__newindex = function(t, k, v)
			suspicious("GLOBAL", "запись глобальной переменной '" .. tostring(k) .. "'")
			rawset(t, k, v)
		end,
	})
	local fn, err = load(src, chunk, "t", env)
	if not fn then throw("синтаксическая ошибка: " .. tostring(err)) end
	return fn
end

G.require = function(m)
	if not isInst(m) or m[DATA].cls.name ~= "ModuleScript" then throw("Attempted to call require with invalid argument(s).") end
	local ctx = curCtx()
	local cache = moduleCache[ctx.key]
	if not cache then
		cache = {}
		moduleCache[ctx.key] = cache
	end
	local e = cache[m]
	if e then
		if e.state == "loading" then throw("Requested module was required recursively: " .. fullName(m)) end
		if e.state == "error" then throw("Requested module experienced an error while loading: " .. fullName(m)) end
		return e.value
	end
	e = { state = "loading" }
	cache[m] = e
	local fn = compile(m)
	local r = tpack(xpcall(fn, function(err) return { e = err, tb = debug.traceback(luauToString(err), 2) } end))
	if not r[1] then
		e.state = "error"
		local info = r[2]
		if rawtype(info) == "table" and info.e then
			if not (rawtype(info.e) == "string" and sfind(info.e, "Requested module", 1, true)) then mock.recordError(info.e, info.tb, ctx) end
		end
		throw("Requested module experienced an error while loading: " .. fullName(m))
	end
	if r.n ~= 2 then
		e.state = "error"
		throw("Module code did not return exactly one value: " .. fullName(m))
	end
	e.state = "done"
	e.value = r[2]
	return r[2]
end

local function runScript(inst, ctx)
	local ok, fn = pcall(compile, inst)
	if not ok then
		mock.recordError(fn, fn, ctx)
		return
	end
	local co = newThread(fn, ctx)
	resume(co)
end

local function runIn(root, className, ctx)
	local list = {}
	if root[DATA].cls.name == className then list[1] = root end
	for _, d in ipairs(root:GetDescendants()) do
		if d[DATA].cls.name == className then list[#list + 1] = d end
	end
	for _, s in ipairs(list) do
		if s[DATA].p.Enabled ~= false and s[DATA].p.Disabled ~= true then runScript(s, ctx) end
	end
end

---------------------------------------------------------------- персонажи
local function charPart(m, name, size, cf)
	local p = newInstance(classes.Part)
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = false
	p.Parent = m
	return p
end

local function buildCharacter(player)
	local m = newInstance(classes.Model)
	m.Name = player[DATA].p.Name
	local hrp = charPart(m, "HumanoidRootPart", v3(2, 2, 1), IDENT)
	hrp.Transparency = 1
	local parts = {
		charPart(m, "LowerTorso", v3(2, 0.4, 1), cfnew(0, -0.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)),
		charPart(m, "UpperTorso", v3(2, 1.6, 1), cfnew(0, 0.2, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)),
		charPart(m, "Head", v3(1.2, 1.2, 1.2), cfnew(0, 1.6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)),
		charPart(m, "LeftUpperLeg", v3(1, 2, 1), cfnew(-0.5, -2, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)),
		charPart(m, "RightUpperLeg", v3(1, 2, 1), cfnew(0.5, -2, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)),
	}
	for _, p in ipairs(parts) do
		local w = newInstance(classes.WeldConstraint)
		w.Part0 = hrp
		w.Part1 = p
		w.Parent = p
	end
	local hum = newInstance(classes.Humanoid)
	hum.RigType = E("HumanoidRigType", "R15")
	hum.HipHeight = 2
	hum.DisplayName = player[DATA].p.DisplayName
	local sp = services.StarterPlayer
	if sp then hum.WalkSpeed = sp[DATA].p.CharacterWalkSpeed end
	newInstance(classes.Animator).Parent = hum
	hum.Parent = m
	m.PrimaryPart = hrp
	-- точка появления
	local spawnCF = cfnew(0, 5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	for _, d in ipairs(services.Workspace:GetDescendants()) do
		if d[DATA].cls.name == "SpawnLocation" then
			spawnCF = d.CFrame * CFrame.new(0, d.Size.Y / 2 + 3, 0)
			break
		end
	end
	m:PivotTo(spawnCF)
	return m
end

function loadCharacter(player)
	local pd = player[DATA]
	local old = pd.p.Character
	if old then
		fireEvent(pd, "CharacterRemoving", old)
		if not old[DATA].destroyed then old:Destroy() end
	end
	local m = buildCharacter(player)
	player.Character = m
	m.Parent = services.Workspace
	fireEvent(pd, "CharacterAdded", m)
	fireEvent(pd, "CharacterAppearanceLoaded", m)
	return m
end
mock.loadCharacter = loadCharacter

I.onHumanoidDied = function(hum)
	local m = hum[DATA].parent
	if not m then return end
	for _, p in ipairs(playerList) do
		if p[DATA].p.Character == m then
			local players = services.Players
			if players[DATA].p.CharacterAutoLoads then
				mock.timer(players[DATA].p.RespawnTime, function()
					if p[DATA].parent and p[DATA].p.Character == m then loadCharacter(p) end
				end)
			end
		end
	end
end

---------------------------------------------------------------- помощники харнесса
local nextUserId = 1000

function mock.boot(opts)
	opts = opts or {}
	game = newInstance(classes.DataModel)
	game[DATA].p.Name = "Game"
	game[DATA].p.CreatorId = opts.creatorId or 1
	G.game, G.Game = game, game
	for _, n in ipairs({ "Workspace", "Players", "Lighting", "ReplicatedFirst", "ReplicatedStorage", "ServerScriptService", "ServerStorage",
		"StarterGui", "StarterPack", "StarterPlayer", "SoundService", "Teams", "Chat", "TextChatService", "RunService" }) do
		getService(n)
	end
	local ws = services.Workspace
	G.workspace, G.Workspace = ws, ws
	local cam = newInstance(classes.Camera)
	cam.Name = "Camera"
	cam.Parent = ws
	ws.CurrentCamera = cam
	local sp = services.StarterPlayer
	local sps = newInstance(classes.StarterPlayerScripts)
	sps.Name = "StarterPlayerScripts"
	sps.Parent = sp
	local scs = newInstance(classes.StarterCharacterScripts)
	scs.Name = "StarterCharacterScripts"
	scs.Parent = sp
	mock.game = game
	return game
end

-- создать папку/скрипт из харнесса
function mock.folder(parent, name, cls)
	local f = newInstance(classes[cls or "Folder"])
	f.Name = name
	f.Parent = parent
	return f
end

function mock.script(parent, cls, name, path, source)
	local s = newInstance(classes[cls])
	s.Name = name
	s[DATA].p.Source = source
	s[DATA].srcPath = path
	s.Parent = parent
	return s
end

function mock.startServer()
	runIn(services.ServerScriptService, "Script", SERVER)
	runIn(services.Workspace, "Script", SERVER)
end

function mock.addPlayer(name, userId)
	nextUserId = nextUserId + 1
	local p = newInstance(classes.Player)
	-- у каждого входа свой клиентский контекст (свой кэш require), даже при том же имени
	rawset(p, "__name", name .. "#" .. nextUserId)
	local d = p[DATA]
	d.p.Name = name
	d.p.UserId = userId or nextUserId
	d.p.DisplayName = name
	for _, c in ipairs({ { "PlayerGui", "PlayerGui" }, { "Backpack", "Backpack" }, { "PlayerScripts", "PlayerScripts" } }) do
		local x = newInstance(classes[c[1]])
		x.Name = c[2]
		x.Parent = p
	end
	table.insert(playerList, p)
	p.Parent = services.Players
	fireEvent(services.Players[DATA], "PlayerAdded", p)
	-- клиент: скрипты игрока и интерфейс
	local ctx = clientCtx(p)
	for _, c in ipairs(services.StarterGui:GetChildren()) do
		local cl = c:Clone()
		cl.Parent = p.PlayerGui
	end
	for _, c in ipairs(services.StarterPlayer.StarterPlayerScripts:GetChildren()) do
		local cl = c:Clone()
		cl.Parent = p.PlayerScripts
	end
	runIn(p.PlayerScripts, "LocalScript", ctx)
	runIn(p.PlayerGui, "LocalScript", ctx)
	if services.Players[DATA].p.CharacterAutoLoads then loadCharacter(p) end
	return p
end

function removePlayer(p)
	local d = p[DATA]
	if not d.parent then return end
	fireEvent(services.Players[DATA], "PlayerRemoving", p)
	for i, x in ipairs(playerList) do
		if x == p then
			table.remove(playerList, i)
			break
		end
	end
	local c = d.p.Character
	if c and not c[DATA].destroyed then c:Destroy() end
	setParentRaw(p, d, nil)
	clientCtx(p).dead = true
end
mock.removePlayer = removePlayer

-- один кадр
function mock.step(dt)
	dt = dt or 1 / 30
	mock.now = mock.now + dt
	mock.frame = mock.frame + 1
	runTimers()
	runDeferred()
	I.updateHumanoids(dt)
	stepTweens(dt)
	local rs = services.RunService[DATA]
	fireEvent(rs, "Stepped", mock.now, dt)
	fireEvent(rs, "PreSimulation", dt)
	fireEvent(rs, "PostSimulation", dt)
	fireEvent(rs, "Heartbeat", dt)
	fireEvent(rs, "PreRender", dt)
	fireEvent(rs, "RenderStepped", dt)
	for _, b in pairs(renderBinds) do resume(newThread(b.fn, b.ctx), dt) end
	runDeferred()
end

function mock.run(seconds, dt)
	dt = dt or 1 / 30
	local t = 0
	while t < seconds do
		mock.step(dt)
		t = t + dt
	end
end

-- поток в контексте клиента игрока
function mock.asClient(player, fn, ...)
	local co = newThread(fn, clientCtx(player))
	resume(co, ...)
	return co
end
function mock.asServer(fn, ...)
	local co = newThread(fn, SERVER)
	resume(co, ...)
	return co
end

-- нажать подсказку ProximityPrompt
function mock.trigger(player, prompt)
	local pd = prompt[DATA]
	if not pd.p.Enabled then return false, "подсказка выключена" end
	local c = player[DATA].p.Character
	local hrp = c and findChild(c[DATA], "HumanoidRootPart")
	if not hrp then return false, "нет персонажа" end
	local par = pd.parent
	local pos = par and (par[DATA].cls.isa.Attachment and par.WorldPosition or par.Position)
	if not pos then return false, "у подсказки нет позиции" end
	local dist = (pos - hrp.Position).Magnitude
	if dist > math.max(pd.p.MaxActivationDistance, 10) + 2 then return false, sformat("далеко: %.1f", dist) end
	fireEvent(pd, "Triggered", player)
	return true
end

-- переместить персонажа
function mock.teleport(player, pos)
	local c = player[DATA].p.Character
	if c then c:PivotTo(CFrame.new(pos)) end
end

function mock.chat(player, msg)
	fireEvent(player[DATA], "Chatted", msg)
end

-- покупка товара за Robux (вызывает ProcessReceipt)
function mock.buyProduct(player, productId)
	local cb = services.MarketplaceService[DATA].processReceipt
	if not cb then return nil end
	local result
	mock.asServer(function()
		result = cb({ PlayerId = player[DATA].p.UserId, ProductId = productId, PurchaseId = "p" .. mock.frame .. "_" .. productId,
			CurrencySpent = 49, CurrencyType = E("CurrencyType", "Robux"), PlaceIdWherePurchased = 0 })
	end)
	return result
end

function mock.close()
	for _, h in ipairs(mock.closeHandlers or {}) do resume(newThread(h.fn, h.ctx)) end
end

mock.SERVICE = SERVICE
mock.G = G
end -- part5
part5()
