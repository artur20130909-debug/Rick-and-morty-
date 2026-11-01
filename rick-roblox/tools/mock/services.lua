-- tools/mock/services.lua
-- Продолжение мока Roblox (roblox.lua): DataModel и службы, игрок и персонаж, ввод,
-- TweenService, RunService, глобальные имена Luau, require и запуск скриптов, шаг кадра.
-- Загружается после roblox.lua: services(mock) -> mock.

local mock = ...
local I, DATA, E, G = mock.I, mock.DATA, mock.E, mock.G
local defclass, newInstance, classes, N = I.defclass, I.newInstance, mock.classes, I.N
local getEvent, fireEvent, fireSignal, newSignal = I.getEvent, I.fireEvent, I.fireSignal, I.newSignal
local throw, curCtx, newThread, resume = mock.throw, mock.curCtx, mock.newThread, mock.resume
local typeof, suspicious = mock.typeof, mock.suspect
local Vector3, CFrame, Color3, Vector2, UDim2 = G.Vector3, G.CFrame, G.Color3, G.Vector2, G.UDim2
local UDim, NumberRange, Rect, TweenInfo, task = G.UDim, G.NumberRange, G.Rect, G.TweenInfo, mock.task
local v3, v2, c3 = mock.v3, Vector2.new, Color3.new
local sformat, floor, abs, sqrt, sin, cos, pi = string.format, math.floor, math.abs, math.sqrt, math.sin, math.cos, math.pi

local function isClient() return curCtx().side == "client" end

-- копия аргументов для BindableEvent (как в Roblox: таблицы копируются, метатаблицы теряются)
local function deepCopy(v, seen)
	if type(v) ~= "table" or getmetatable(v) ~= nil then return v end
	seen = seen or {}
	if seen[v] then return seen[v] end
	local o = {}
	seen[v] = o
	for k, x in pairs(v) do o[deepCopy(k, seen)] = deepCopy(x, seen) end
	return o
end
function I.copyArgs(remote, ...)
	local n = select("#", ...)
	local a = { ... }
	for i = 1, n do a[i] = deepCopy(a[i]) end
	return table.unpack(a, 1, n)
end

---------------------------------------------------------------------------
-- 1. Instance.new
---------------------------------------------------------------------------
local Instance = {}
function Instance.new(className, parent)
	if type(className) ~= "string" then throw("invalid argument #1 to 'new' (string expected, got " .. typeof(className) .. ")") end
	local cls = classes[className]
	if not cls or cls.noCreate or cls.service then throw('Unable to create an Instance of type "' .. className .. '"') end
	local inst = newInstance(cls)
	if parent ~= nil then inst.Parent = parent end
	return inst
end
function Instance.fromExisting(i) return i:Clone() end
G.Instance = Instance
mock.Instance = Instance

---------------------------------------------------------------------------
-- 2. Службы
---------------------------------------------------------------------------
local services = {}      -- имя класса -> экземпляр
local game

local function service(name, super, spec)
	spec = spec or {}
	spec.service = true
	spec.noCreate = true
	return defclass(name, super or "Instance", spec)
end

-- Player, PlayerGui, Backpack, PlayerScripts
defclass("PlayerGui", "Instance", {
	props = { ScreenOrientation = E("ScreenOrientation", "LandscapeSensor"), SelectionImageObject = N "Instance" },
	get = { CurrentScreenOrientation = function() return E("ScreenOrientation", "LandscapeRight") end },
	methods = { GetTopbarTransparency = function() return 0 end, SetTopbarTransparency = function() end },
	noCreate = true,
})
defclass("Backpack", "Instance", {})
defclass("PlayerScripts", "Instance", { noCreate = true })
defclass("StarterPlayerScripts", "Instance", { noCreate = true })
defclass("StarterCharacterScripts", "Instance", { noCreate = true })

local players = {}
local loadCharacter -- вперёд
defclass("Player", "Instance", {
	props = {
		DisplayName = "", UserId = 1, Character = N "Instance:Model", CameraMode = E("CameraMode", "Classic"),
		CameraMinZoomDistance = 0.5, CameraMaxZoomDistance = 128, DevEnableMouseLock = true, AutoJumpEnabled = true,
		DevComputerMovementMode = E("DevComputerMovementMode", "UserChoice"), DevTouchMovementMode = E("DevTouchMovementMode", "UserChoice"),
		DevCameraOcclusionMode = E("DevCameraOcclusionMode", "Zoom"), DevComputerCameraMode = E("DevComputerCameraMovementMode", "UserChoice"),
		DevTouchCameraMode = E("DevTouchCameraMovementMode", "UserChoice"), HealthDisplayDistance = 100, NameDisplayDistance = 100,
		Neutral = true, Team = N "Instance:Team", RespawnLocation = N "Instance:SpawnLocation", ReplicationFocus = N "Instance",
		CanLoadCharacterAppearance = true, CharacterAppearanceId = 0, AccountAge = 100, MembershipType = E("MembershipType", "None"),
		LocaleId = "ru-ru", GameplayPaused = false,
	},
	methods = {
		LoadCharacter = function(self) loadCharacter(self) end,
		LoadCharacterAsync = function(self) loadCharacter(self) end,
		GetMouse = function(self)
			local d = self[DATA]
			if not d.mouse then
				d.mouse = setmetatable({ Hit = CFrame.new(), Target = nil, X = 640, Y = 360, Icon = "", UnitRay = nil,
					TargetFilter = nil, Button1Down = newSignal("Button1Down"), Button1Up = newSignal("Button1Up"),
					Move = newSignal("Move"), WheelForward = newSignal("WheelForward"), WheelBackward = newSignal("WheelBackward") },
					{ __type = "Instance" })
			end
			return d.mouse
		end,
		Kick = function(self, msg) mock.emit("warn", "Kick: " .. tostring(msg)) end,
		IsInGroup = function() return false end,
		GetRankInGroup = function() return 0 end,
		HasAppearanceLoaded = function() return true end,
		ClearCharacterAppearance = function() end,
		DistanceFromCharacter = function(self, p)
			local ch = self[DATA].p.Character
			local r = ch and ch:FindFirstChild("HumanoidRootPart")
			return r and (r.Position - p).Magnitude or 0
		end,
		GetNetworkPing = function() return 0.05 end,
		RequestStreamAroundAsync = function() end,
	},
	events = { "CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded", "Chatted", "Idled", "OnTeleport" },
	noCreate = true,
})

service("Players", "Instance", {
	props = { MaxPlayers = 8, PreferredPlayers = 8, CharacterAutoLoads = true, RespawnTime = 5, BubbleChat = true, ClassicChat = false },
	get = {
		LocalPlayer = function() local c = curCtx(); return c.side == "client" and c.player or nil end,
		NumPlayers = function() return #players end,
	},
	methods = {
		GetPlayers = function() local o = {}; for i, p in ipairs(players) do o[i] = p end; return o end,
		GetPlayerFromCharacter = function(self, m)
			for _, p in ipairs(players) do if p[DATA].p.Character == m then return p end end
			return nil
		end,
		GetPlayerByUserId = function(self, id) for _, p in ipairs(players) do if p[DATA].p.UserId == id then return p end end end,
		GetHumanoidDescriptionFromUserId = function() return newInstance(classes.HumanoidDescription) end,
		GetUserIdFromNameAsync = function() return 1 end,
		GetNameFromUserIdAsync = function() return "Player" end,
		GetUserThumbnailAsync = function() return "rbxasset://textures/ui/GuiImagePlaceholder.png", true end,
		CreateHumanoidModelFromDescription = function(self, desc, rig) return mock.buildRig("Character") end,
		CreateHumanoidModelFromUserId = function() return mock.buildRig("Character") end,
	},
	events = { "PlayerAdded", "PlayerRemoving", "PlayerMembershipChanged" },
})

-- RunService
local renderBinds = {} -- ctx -> { {name, prio, fn} }
service("RunService", "Instance", {
	methods = {
		IsServer = function() return curCtx().side == "server" end,
		IsClient = function() return curCtx().side == "client" end,
		IsStudio = function() return true end,
		IsRunning = function() return true end,
		IsRunMode = function() return false end,
		IsEdit = function() return false end,
		BindToRenderStep = function(self, name, prio, fn)
			if not isClient() then throw("BindToRenderStep can only be called from the client") end
			if type(fn) ~= "function" then throw("BindToRenderStep: function expected") end
			local ctx = curCtx()
			local list = renderBinds[ctx] or {}
			renderBinds[ctx] = list
			for i = #list, 1, -1 do if list[i].name == name then table.remove(list, i) end end
			list[#list + 1] = { name = name, prio = tonumber(prio) or 0, fn = fn, ctx = ctx }
			table.sort(list, function(a, b) return a.prio < b.prio end)
		end,
		UnbindFromRenderStep = function(self, name)
			local list = renderBinds[curCtx()]
			if list then for i = #list, 1, -1 do if list[i].name == name then table.remove(list, i) end end end
		end,
	},
	events = { "Heartbeat", "Stepped", "RenderStepped", "PreRender", "PreSimulation", "PostSimulation", "PreAnimation" },
	eventInit = {
		RenderStepped = function(s) s.onConnect = function(sig, ctx) if ctx.side ~= "client" then throw("RenderStepped event can only be used from local scripts") end end end,
	},
})

-- TweenService + Tween
local function easeIn(style, t)
	if style == "Linear" then return t
	elseif style == "Sine" then return 1 - cos(t * pi / 2)
	elseif style == "Quad" then return t * t
	elseif style == "Cubic" then return t * t * t
	elseif style == "Quart" then return t ^ 4
	elseif style == "Quint" then return t ^ 5
	elseif style == "Exponential" then return t == 0 and 0 or 2 ^ (10 * t - 10)
	elseif style == "Circular" then return 1 - sqrt(math.max(0, 1 - t * t))
	elseif style == "Back" then local s = 1.70158; return t * t * ((s + 1) * t - s)
	elseif style == "Elastic" then
		if t == 0 or t == 1 then return t end
		return -(2 ^ (10 * t - 10)) * sin((t * 10 - 10.75) * (2 * pi / 3))
	elseif style == "Bounce" then
		local u = 1 - t
		local r
		if u < 1 / 2.75 then r = 7.5625 * u * u
		elseif u < 2 / 2.75 then u = u - 1.5 / 2.75; r = 7.5625 * u * u + 0.75
		elseif u < 2.5 / 2.75 then u = u - 2.25 / 2.75; r = 7.5625 * u * u + 0.9375
		else u = u - 2.625 / 2.75; r = 7.5625 * u * u + 0.984375 end
		return 1 - r
	end
	return t
end
local function ease(alpha, style, dir)
	style = style and style.Name or "Quad"
	dir = dir and dir.Name or "Out"
	alpha = math.min(1, math.max(0, alpha))
	if dir == "In" then return easeIn(style, alpha)
	elseif dir == "Out" then return 1 - easeIn(style, 1 - alpha)
	else
		if alpha < 0.5 then return easeIn(style, alpha * 2) / 2 end
		return 1 - easeIn(style, (1 - alpha) * 2) / 2
	end
end
mock.ease = ease

local function lerpValue(a, b, t)
	local ta = typeof(a)
	if ta == "number" then return a + (b - a) * t end
	if ta == "boolean" then return t >= 1 and b or a end
	if ta == "Vector3" or ta == "Vector2" or ta == "CFrame" or ta == "Color3" or ta == "UDim2" then return a:Lerp(b, t) end
	if ta == "UDim" then return UDim.new(a.Scale + (b.Scale - a.Scale) * t, a.Offset + (b.Offset - a.Offset) * t) end
	if ta == "NumberRange" then return NumberRange.new(a.Min + (b.Min - a.Min) * t, a.Max + (b.Max - a.Max) * t) end
	if ta == "Rect" then return t >= 1 and b or a end
	if ta == "EnumItem" then return t >= 1 and b or a end
	return t >= 1 and b or a
end

local tweens = {}
defclass("TweenBase", "Instance", {
	props = { PlaybackState = E("PlaybackState", "Begin") },
	events = { "Completed" },
	noCreate = true,
})
local function tweenPlay(self)
	local d = self[DATA]
	local tw = d.tw
	if tw.state == "Playing" then return end
	if tw.state ~= "Paused" then
		tw.elapsed = 0
		tw.start = {}
		for k in pairs(tw.goals) do tw.start[k] = tw.inst[k] end
		tw.rep = 0
		tw.back = false
	end
	tw.state = "Playing"
	d.p.PlaybackState = E("PlaybackState", tw.info.DelayTime > 0 and "Delayed" or "Playing")
	tweens[self] = true
end
defclass("Tween", "TweenBase", {
	props = { Instance = N "Instance", TweenInfo = TweenInfo.new() },
	methods = {
		Play = tweenPlay,
		Pause = function(self) local tw = self[DATA].tw; if tw.state == "Playing" then tw.state = "Paused"; tweens[self] = nil; self[DATA].p.PlaybackState = E("PlaybackState", "Paused") end end,
		Cancel = function(self)
			local d = self[DATA]
			local tw = d.tw
			if tw.state == "Playing" or tw.state == "Paused" then
				tw.state = "Cancelled"; tweens[self] = nil
				d.p.PlaybackState = E("PlaybackState", "Cancelled")
				fireEvent(d, "Completed", E("PlaybackState", "Cancelled"))
			end
		end,
	},
	noCreate = true,
})
service("TweenService", "Instance", {
	methods = {
		Create = function(self, inst, info, goals)
			if not I.isInst(inst) then throw("TweenService:Create - instance expected, got " .. typeof(inst)) end
			if typeof(info) ~= "TweenInfo" then throw("TweenService:Create - TweenInfo expected, got " .. typeof(info)) end
			if type(goals) ~= "table" then throw("TweenService:Create - property table expected") end
			for k, v in pairs(goals) do
				local cls = inst[DATA].cls
				if not I.isKnownProp(cls, k) then throw("TweenService:Create no property named '" .. tostring(k) .. "' for object '" .. inst.Name .. "'") end
				local cur = inst[k]
				if cur ~= nil and typeof(cur) ~= typeof(v) and not (typeof(cur) == "number" and type(v) == "number") then
					throw("TweenService:Create property named '" .. k .. "' cannot be tweened due to type mismatch (property is a '" .. typeof(cur) .. "', but given type is '" .. typeof(v) .. "')")
				end
				if typeof(v) == "string" or typeof(v) == "Instance" then throw("TweenService:Create property named '" .. k .. "' cannot be tweened") end
			end
			local t = newInstance(classes.Tween)
			local d = t[DATA]
			d.p.Instance = inst
			d.p.TweenInfo = info
			d.tw = { inst = inst, info = info, goals = goals, state = "Begin", elapsed = 0 }
			return t
		end,
		GetValue = function(self, alpha, style, dir) return ease(alpha, style, dir) end,
	},
})
local function stepTweens(dt)
	for t in pairs(tweens) do
		local d = t[DATA]
		local tw = d.tw
		if tw.inst[DATA].destroyed then
			tweens[t] = nil
		else
			tw.elapsed = tw.elapsed + dt
			local info = tw.info
			local local_t = tw.elapsed - info.DelayTime
			if local_t >= 0 then
				d.p.PlaybackState = E("PlaybackState", "Playing")
				local dur = math.max(info.Time, 1e-6)
				local a = math.min(1, local_t / dur)
				local k = ease(tw.back and (1 - a) or a, info.EasingStyle, info.EasingDirection)
				for prop, goal in pairs(tw.goals) do
					local ok, err = pcall(function() tw.inst[prop] = lerpValue(tw.start[prop], goal, k) end)
					if not ok then mock.recordError(err, err, mock.SERVER) end
				end
				if a >= 1 then
					if info.Reverses and not tw.back then
						tw.back = true
						tw.elapsed = info.DelayTime
					elseif info.RepeatCount < 0 or tw.rep < info.RepeatCount then
						tw.rep = tw.rep + 1
						tw.back = false
						tw.elapsed = info.DelayTime
					else
						tweens[t] = nil
						tw.state = "Completed"
						d.p.PlaybackState = E("PlaybackState", "Completed")
						fireEvent(d, "Completed", E("PlaybackState", "Completed"))
					end
				end
			end
		end
	end
end

-- Ввод
defclass("InputObject", "Instance", {
	props = { KeyCode = E("KeyCode", "Unknown"), UserInputType = E("UserInputType", "None"), UserInputState = E("UserInputState", "None"),
		Position = v3(0, 0, 0), Delta = v3(0, 0, 0) },
	methods = { IsModifierKeyDown = function() return false end },
	noCreate = true,
})
local keysDown = {} -- ctx -> { [KeyCode.Name] = true }
service("UserInputService", "Instance", {
	props = { MouseBehavior = E("MouseBehavior", "Default"), MouseIconEnabled = true, MouseDeltaSensitivity = 1, ModalEnabled = false,
		MouseEnabled = true, KeyboardEnabled = true, TouchEnabled = false, GamepadEnabled = false, VREnabled = false,
		AccelerometerEnabled = false, GyroscopeEnabled = false, OverrideMouseIconBehavior = E("OverrideMouseIconBehavior", "None"),
		MouseIcon = "" },
	get = { OnScreenKeyboardVisible = function() return false end, PreferredInput = function() return E("PreferredInput", "KeyboardAndMouse") end },
	methods = {
		IsKeyDown = function(self, kc) local k = keysDown[curCtx()]; return k ~= nil and kc ~= nil and k[kc.Name] == true end,
		IsMouseButtonPressed = function() return false end,
		GetMouseLocation = function() return v2(640, 360) end,
		GetMouseDelta = function() return v2(0, 0) end,
		GetFocusedTextBox = function() return nil end,
		GetLastInputType = function() return E("UserInputType", "Keyboard") end,
		GetKeysPressed = function() return {} end,
		GetConnectedGamepads = function() return {} end,
		GetGamepadConnected = function() return false end,
		GetStringForKeyCode = function(self, kc) return kc and kc.Name or "" end,
		GetImageForKeyCode = function() return "" end,
		GetNavigationGamepads = function() return {} end,
	},
	events = { "InputBegan", "InputEnded", "InputChanged", "TouchStarted", "TouchMoved", "TouchEnded", "TouchTap", "TouchSwipe",
		"TouchLongPress", "TouchPinch", "JumpRequest", "LastInputTypeChanged", "WindowFocused", "WindowFocusReleased",
		"TextBoxFocused", "TextBoxFocusReleased", "PointerAction", "GamepadConnected", "GamepadDisconnected" },
})

local casBinds = {} -- ctx -> list
service("ContextActionService", "Instance", {
	methods = {
		BindAction = function(self, name, fn, touch, ...)
			if type(fn) ~= "function" then throw("BindAction: function expected") end
			local ctx = curCtx()
			local list = casBinds[ctx] or {}
			casBinds[ctx] = list
			for i = #list, 1, -1 do if list[i].name == name then table.remove(list, i) end end
			table.insert(list, 1, { name = name, fn = fn, inputs = { ... }, ctx = ctx, prio = 2000 })
		end,
		BindActionAtPriority = function(self, name, fn, touch, prio, ...)
			local ctx = curCtx()
			local list = casBinds[ctx] or {}
			casBinds[ctx] = list
			for i = #list, 1, -1 do if list[i].name == name then table.remove(list, i) end end
			table.insert(list, 1, { name = name, fn = fn, inputs = { ... }, ctx = ctx, prio = prio })
			table.sort(list, function(a, b) return a.prio > b.prio end)
		end,
		UnbindAction = function(self, name)
			local list = casBinds[curCtx()]
			if list then for i = #list, 1, -1 do if list[i].name == name then table.remove(list, i) end end end
		end,
		UnbindAllActions = function() casBinds[curCtx()] = {} end,
		SetTitle = function() end, SetImage = function() end, SetPosition = function() end, SetDescription = function() end,
		GetButton = function() return nil end,
		GetBoundActionInfo = function() return {} end,
		GetAllBoundActionInfo = function() return {} end,
	},
	events = { "LocalToolEquipped", "LocalToolUnequipped" },
})

service("SoundService", "Instance", {
	props = { AmbientReverb = E("ReverbType", "NoReverb"), DistanceFactor = 3.33, DopplerScale = 1, RolloffScale = 1,
		RespectFilteringEnabled = true, VolumetricAudio = E("VolumetricAudio", "Automatic") },
	methods = {
		PlayLocalSound = function(self, s) if s then s:Play() end end,
		SetListener = function() end,
		GetListener = function() return E("ListenerType", "Camera"), nil end,
	},
})

local function syncTimeOfDay(d)
	local ct = d.p.ClockTime % 24
	local h = floor(ct)
	local m = floor((ct - h) * 60)
	local s = floor(((ct - h) * 60 - m) * 60)
	d.p.TimeOfDay = sformat("%02d:%02d:%02d", h, m, s)
end
service("Lighting", "Instance", {
	props = { Ambient = c3(0.27, 0.27, 0.27), Brightness = 2, ClockTime = 14, ColorShift_Bottom = c3(0, 0, 0), ColorShift_Top = c3(0, 0, 0),
		EnvironmentDiffuseScale = 0, EnvironmentSpecularScale = 0, ExposureCompensation = 0, FogColor = c3(0.75, 0.75, 0.75),
		FogEnd = 100000, FogStart = 0, GeographicLatitude = 41.73, GlobalShadows = true, OutdoorAmbient = c3(0.5, 0.5, 0.5),
		ShadowSoftness = 0.2, Technology = E("Technology", "ShadowMap"), TimeOfDay = "14:00:00",
		LightingStyle = E("LightingStyle", "Realistic"), PrioritizeLightingQuality = true },
	set = {
		ClockTime = function(self, d, v)
			if type(v) ~= "number" then v = I.coerce("ClockTime", "number", v) end
			d.p.ClockTime = v % 24
			syncTimeOfDay(d)
			if d.sig then I.propChanged(self, d, "ClockTime") end
		end,
	},
	methods = {
		GetSunDirection = function(self)
			local t = (self[DATA].p.ClockTime - 6) / 12 * pi
			return v3(cos(t), sin(t), -0.3).Unit
		end,
		GetMoonDirection = function(self) return -self:GetSunDirection() end,
		GetMinutesAfterMidnight = function(self) return self[DATA].p.ClockTime * 60 end,
		SetMinutesAfterMidnight = function(self, m) self.ClockTime = m / 60 end,
	},
	events = { "LightingChanged" },
})

local coreEnabled = {}
service("StarterGui", "Instance", {
	props = { ShowDevelopmentGui = true, ResetPlayerGuiOnSpawn = true, ScreenOrientation = E("ScreenOrientation", "LandscapeSensor"),
		VirtualCursorMode = E("VirtualCursorMode", "Default") },
	methods = {
		SetCoreGuiEnabled = function(self, t, on) coreEnabled[t and t.Name or "?"] = on end,
		GetCoreGuiEnabled = function(self, t) local v = coreEnabled[t and t.Name or "?"]; if v == nil then return true end; return v end,
		SetCore = function(self, name, value)
			local ok = { ResetButtonCallback = 1, TopbarEnabled = 1, SendNotification = 1, ChatActive = 1, PointsNotificationsActive = 1,
				BadgesNotificationsActive = 1, ChatWindowPosition = 1, ChatWindowSize = 1, ChatBarDisabled = 1, AvatarContextMenuEnabled = 1 }
			if not ok[name] then throw("SetCore: " .. tostring(name) .. " has not been registered by the CoreScripts") end
		end,
		GetCore = function(self, name) return nil end,
		RegisterSetCore = function() end, RegisterGetCore = function() end,
	},
})

service("GuiService", "Instance", {
	props = { AutoSelectGuiEnabled = true, GuiNavigationEnabled = true, SelectedObject = N "Instance:GuiObject", TouchControlsEnabled = true },
	get = {
		MenuIsOpen = function() return false end,
		TopbarInset = function() return Rect.new(0, 0, 1280, 58) end,
		IsModalDialog = function() return false end,
		PreferredTextSize = function() return E("PreferredTextSize", "Medium") end,
		ReducedMotionEnabled = function() return false end,
	},
	methods = {
		GetGuiInset = function() return v2(0, 58), v2(0, 0) end,
		IsTenFootInterface = function() return false end,
		CloseInspectMenu = function() end,
		Select = function() end,
	},
	events = { "MenuOpened", "MenuClosed", "UiMessageChanged" },
})

local function tagSig(kind, tag)
	local key = kind .. ":" .. tag
	local s = I.tagSignals[key]
	if not s then s = newSignal(key); I.tagSignals[key] = s end
	return s
end
service("CollectionService", "Instance", {
	methods = {
		GetTagged = function(self, tag)
			local o = {}
			local set = I.tagged[tag]
			if set then for inst in pairs(set) do if not inst[DATA].destroyed then o[#o + 1] = inst end end end
			table.sort(o, function(a, b) return a[DATA].id < b[DATA].id end)
			return o
		end,
		HasTag = function(self, inst, tag) return inst:HasTag(tag) end,
		AddTag = function(self, inst, tag) inst:AddTag(tag) end,
		RemoveTag = function(self, inst, tag) inst:RemoveTag(tag) end,
		GetTags = function(self, inst) return inst:GetTags() end,
		GetInstanceAddedSignal = function(self, tag) return tagSig("add", tag) end,
		GetInstanceRemovedSignal = function(self, tag) return tagSig("rem", tag) end,
		GetAllTags = function() local o = {}; for t in pairs(I.tagged) do o[#o + 1] = t end; return o end,
	},
	events = { "TagAdded", "TagRemoved" },
})

service("ContentProvider", "Instance", {
	get = { RequestQueueSize = function() return 0 end, BaseUrl = function() return "https://www.roblox.com/" end },
	methods = {
		PreloadAsync = function(self, list, cb)
			if type(list) ~= "table" then throw("PreloadAsync: table expected") end
			task.wait()
			if cb then for _, a in ipairs(list) do cb(type(a) == "string" and a or tostring(a), E("AssetFetchStatus", "Success")) end end
		end,
		GetAssetFetchStatus = function() return E("AssetFetchStatus", "Success") end,
	},
})

service("TextService", "Instance", {
	methods = {
		GetTextSize = function(self, text, size, font, frame)
			local n = utf8.len(text or "") or #(text or "")
			return v2(math.min(n * size * 0.52, frame and frame.X or 1e9), size * 1.2)
		end,
		GetTextBoundsAsync = function(self, params) return v2(100, 20) end,
		FilterStringAsync = function() return nil end,
	},
})

local groups = { Default = true }
local noCollide = {}
service("PhysicsService", "Instance", {
	methods = {
		RegisterCollisionGroup = function(self, name) groups[name] = true end,
		UnregisterCollisionGroup = function(self, name) groups[name] = nil end,
		IsCollisionGroupRegistered = function(self, name) return groups[name] == true end,
		CollisionGroupSetCollidable = function(self, a, b, on)
			if not groups[a] or not groups[b] then throw("CollisionGroupSetCollidable: collision group does not exist") end
			noCollide[a .. "|" .. b] = not on; noCollide[b .. "|" .. a] = not on
		end,
		CollisionGroupsAreCollidable = function(self, a, b) return not noCollide[a .. "|" .. b] end,
		GetRegisteredCollisionGroups = function() local o = {}; for g in pairs(groups) do o[#o + 1] = { name = g } end; return o end,
		GetMaxCollisionGroups = function() return 32 end,
	},
})

service("Debris", "Instance", {
	props = { MaxItems = 1000 },
	methods = { AddItem = function(self, inst, t) mock.timer(tonumber(t) or 10, function() if inst and not inst[DATA].destroyed then inst:Destroy() end end) end },
})

-- JSON для HttpService
local function jsonEncode(v, out)
	local t = type(v)
	if t == "nil" then out[#out + 1] = "null"
	elseif t == "boolean" then out[#out + 1] = tostring(v)
	elseif t == "number" then out[#out + 1] = mock.luauToString(v)
	elseif t == "string" then out[#out + 1] = '"' .. v:gsub('[%c"\\]', function(c) return sformat("\\u%04x", c:byte()) end) .. '"'
	elseif t == "table" then
		if #v > 0 or next(v) == nil then
			out[#out + 1] = "["
			for i, x in ipairs(v) do if i > 1 then out[#out + 1] = "," end; jsonEncode(x, out) end
			out[#out + 1] = "]"
		else
			out[#out + 1] = "{"
			local first = true
			for k, x in pairs(v) do
				if not first then out[#out + 1] = "," end
				first = false
				jsonEncode(tostring(k), out); out[#out + 1] = ":"; jsonEncode(x, out)
			end
			out[#out + 1] = "}"
		end
	else throw("Can't convert to JSON") end
end
local function jsonDecode(s)
	local pos = 1
	local function ws() pos = s:find("[^ \t\r\n]", pos) or #s + 1 end
	local val
	local function str()
		local o = {}
		pos = pos + 1
		while true do
			local c = s:sub(pos, pos)
			if c == '"' then pos = pos + 1; break end
			if c == "\\" then
				local n = s:sub(pos + 1, pos + 1)
				if n == "u" then o[#o + 1] = utf8.char(tonumber(s:sub(pos + 2, pos + 5), 16)); pos = pos + 6
				else o[#o + 1] = ({ n = "\n", t = "\t", r = "\r", b = "\b", f = "\f" })[n] or n; pos = pos + 2 end
			elseif c == "" then throw("Can't parse JSON")
			else o[#o + 1] = c; pos = pos + 1 end
		end
		return table.concat(o)
	end
	function val()
		ws()
		local c = s:sub(pos, pos)
		if c == "{" then
			local o = {}
			pos = pos + 1; ws()
			if s:sub(pos, pos) == "}" then pos = pos + 1; return o end
			while true do
				ws(); local k = str(); ws(); pos = pos + 1
				o[k] = val(); ws()
				local e = s:sub(pos, pos); pos = pos + 1
				if e == "}" then return o end
			end
		elseif c == "[" then
			local o = {}
			pos = pos + 1; ws()
			if s:sub(pos, pos) == "]" then pos = pos + 1; return o end
			while true do
				o[#o + 1] = val(); ws()
				local e = s:sub(pos, pos); pos = pos + 1
				if e == "]" then return o end
			end
		elseif c == '"' then return str()
		elseif s:sub(pos, pos + 3) == "true" then pos = pos + 4; return true
		elseif s:sub(pos, pos + 4) == "false" then pos = pos + 5; return false
		elseif s:sub(pos, pos + 3) == "null" then pos = pos + 4; return nil
		else
			local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
			if not num or num == "" then throw("Can't parse JSON") end
			pos = pos + #num
			return tonumber(num)
		end
	end
	return val()
end
local guidN = 0
service("HttpService", "Instance", {
	props = { HttpEnabled = false },
	methods = {
		JSONEncode = function(self, v) local o = {}; jsonEncode(v, o); return table.concat(o) end,
		JSONDecode = function(self, s) return jsonDecode(s) end,
		GenerateGUID = function(self, braces)
			guidN = guidN + 1
			local g = sformat("%08X-0000-4000-8000-%012X", guidN, guidN * 7919)
			if braces == false then return g end
			return "{" .. g .. "}"
		end,
		UrlEncode = function(self, s) return (s:gsub("[^%w%-_%.~]", function(c) return sformat("%%%02X", c:byte()) end)) end,
		GetAsync = function() throw("Http requests are not enabled") end,
		PostAsync = function() throw("Http requests are not enabled") end,
	},
})

service("ProximityPromptService", "Instance", {
	props = { Enabled = true, MaxPromptsVisible = 16, MaxIndicatorsVisible = 0 },
	events = { "PromptShown", "PromptHidden", "PromptTriggered", "PromptTriggerEnded", "PromptButtonHoldBegan", "PromptButtonHoldEnded" },
})

local stores = {}
service("DataStoreService", "Instance", {
	methods = {
		GetDataStore = function(self, name)
			local st = stores[name]
			if not st then
				local data = {}
				st = setmetatable({}, { __type = "Instance", __index = {
					GetAsync = function(_, k) task.wait(); return data[k] end,
					SetAsync = function(_, k, v) task.wait(); data[k] = v end,
					UpdateAsync = function(_, k, f) task.wait(); data[k] = f(data[k]); return data[k] end,
					RemoveAsync = function(_, k) local v = data[k]; data[k] = nil; return v end,
				} })
				stores[name] = st
			end
			return st
		end,
		GetRequestBudgetForRequestType = function() return 100 end,
	},
})

for _, nm in ipairs({ "ReplicatedStorage", "ReplicatedFirst", "ServerScriptService", "ServerStorage", "StarterPack", "Teams",
	"Chat", "LocalizationService", "MarketplaceService", "BadgeService", "GroupService", "SocialService", "TeleportService",
	"VRService", "HapticService", "PathfindingService", "MessagingService", "TextChatService", "VoiceChatService",
	"AnalyticsService", "PolicyService", "AvatarEditorService", "ExperienceNotificationService", "Selection", "TestService",
	"AssetService", "MaterialService", "InsertService", "PermissionsService", "LogService", "StatsService" }) do
	if not classes[nm] then service(nm, "Instance", { generic = true }) end
end
classes.HapticService.methods.IsVibrationSupported = function() return false end
classes.HapticService.methods.IsMotorSupported = function() return false end
classes.HapticService.methods.SetMotor = function() end
classes.LocalizationService.getters.RobloxLocaleId = function() return "ru-ru" end
classes.LocalizationService.getters.SystemLocaleId = function() return "ru-ru" end
classes.MaterialService.types.Use2022Materials = "boolean"
classes.MaterialService.defaults.Use2022Materials = true

service("StarterPlayer", "Instance", {
	props = { CameraMode = E("CameraMode", "Classic"), CameraMaxZoomDistance = 128, CameraMinZoomDistance = 0.5,
		CharacterWalkSpeed = 16, CharacterJumpHeight = 7.2, CharacterJumpPower = 50, CharacterUseJumpPower = false,
		CharacterMaxSlopeAngle = 89, AutoJumpEnabled = true, EnableMouseLockOption = true, HealthDisplayDistance = 100,
		NameDisplayDistance = 100, LoadCharacterAppearance = true, UserEmotesEnabled = true, AllowCustomAnimations = true,
		DevComputerMovementMode = E("DevComputerMovementMode", "UserChoice"), DevTouchMovementMode = E("DevTouchMovementMode", "UserChoice"),
		CameraOcclusionMode = E("DevCameraOcclusionMode", "Zoom"), HumanoidStateMachineMode = E("HumanoidStateMachineMode", "Default"),
		CharacterBreakJointsOnDeath = true },
})

-- Workspace
local serverCam
service("Workspace", "WorldRoot", {
	props = { Gravity = 196.2, FallenPartsDestroyHeight = -500, StreamingEnabled = false, AllowThirdPartySales = false,
		Retargeting = E("AnimatorRetargetingMode", "Default"), SignalBehavior = E("SignalBehavior", "Default"),
		AirDensity = 0.0012, GlobalWind = v3(0, 0, 0), TouchesUseCollisionGroups = false },
	get = {
		CurrentCamera = function(self, d)
			local ctx = curCtx()
			if ctx.side == "client" then
				local cam = ctx.camera
				if not cam then
					cam = newInstance(classes.Camera)
					cam.Name = "Camera"
					ctx.camera = cam
				end
				return cam
			end
			if not serverCam then serverCam = newInstance(classes.Camera); serverCam.Name = "Camera" end
			return serverCam
		end,
		DistributedGameTime = function() return mock.now end,
		Terrain = function(self, d) return d.terrain end,
	},
	set = { CurrentCamera = function(self, d, v) local ctx = curCtx(); if ctx.side == "client" then ctx.camera = v else serverCam = v end end },
	methods = {
		Raycast = function(self, origin, dir, params)
			if typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" then throw("Raycast: Vector3 expected") end
			return I.raycast(origin, dir, params)
		end,
		GetPartBoundsInBox = function(self, cf, size, params)
			local x0, y0, z0, x1, y1, z1 = I.boxAABB(cf, size)
			return I.queryAABB(x0, y0, z0, x1, y1, z1, params)
		end,
		GetPartBoundsInRadius = function(self, p, r, params)
			return I.queryAABB(p.X - r, p.Y - r, p.Z - r, p.X + r, p.Y + r, p.Z + r, params)
		end,
		GetPartsInPart = function(self, part, params)
			local x0, y0, z0, x1, y1, z1 = I.boxAABB(part.CFrame, part.Size)
			return I.queryAABB(x0, y0, z0, x1, y1, z1, params)
		end,
		GetServerTimeNow = function() return mock.epoch + mock.now end,
		GetRealPhysicsFPS = function() return 60 end,
		Blockcast = function(self, cf, size, dir, params) return I.raycast(cf.Position, dir, params) end,
		Spherecast = function(self, p, r, dir, params) return I.raycast(p, dir, params) end,
		ArePartsTouchingOthers = function() return false end,
		BulkMoveTo = function(self, parts, cfs) for i, p in ipairs(parts) do p.CFrame = cfs[i] end end,
		PivotTo = function() end,
	},
})

service("UserGameSettings", "Instance", {
	props = { MouseSensitivity = 1, SavedQualityLevel = E("SavedQualitySetting", "Automatic"), MasterVolume = 1,
		ComputerMovementMode = E("ComputerMovementMode", "Default"), ComputerCameraMovementMode = E("ComputerCameraMovementMode", "Default"),
		RotationType = E("RotationType", "MovementRelative"), Fullscreen = false, GamepadCameraSensitivity = 1, ControlMode = E("ControlMode", "Classic") },
	methods = { GetCameraYInvertValue = function() return 1 end, InFullScreen = function() return false end, InStudioMode = function() return true end },
	events = { "FullscreenChanged", "StudioModeChanged" },
})

defclass("DataModel", "Instance", {
	props = { PlaceId = 0, GameId = 0, JobId = "", CreatorId = 0, PlaceVersion = 0, CreatorType = E("CreatorType", "User") },
	methods = {
		GetService = function(self, name)
			local s = services[name]
			if s then return s end
			throw("'" .. tostring(name) .. "' is not a valid Service name")
		end,
		FindService = function(self, name) return services[name] end,
		IsLoaded = function() return true end,
		BindToClose = function() end,
		Shutdown = function() end,
	},
	events = { "Loaded", "Close", "GraphicsQualityChangeRequest" },
	noCreate = true,
})

---------------------------------------------------------------------------
-- 3. DataModel
---------------------------------------------------------------------------
game = newInstance(classes.DataModel)
game[DATA].p.Name = "Game"
local function mkService(name, serverOnly)
	local s = newInstance(classes[name])
	s[DATA].p.Name = name
	I.setParentRaw(s, s[DATA], game)
	if serverOnly then s[DATA].serverOnly = true end
	services[name] = s
	return s
end
local wsInst = mkService("Workspace")
I.setWorkspace(wsInst)
wsInst[DATA].inWs = true
for _, nm in ipairs({ "Players", "Lighting", "ReplicatedStorage", "ReplicatedFirst", "StarterGui", "StarterPack", "StarterPlayer",
	"SoundService", "RunService", "TweenService", "UserInputService", "ContextActionService", "GuiService", "CollectionService",
	"ContentProvider", "TextService", "PhysicsService", "Debris", "HttpService", "ProximityPromptService", "DataStoreService",
	"Teams", "Chat", "LocalizationService", "MarketplaceService", "BadgeService", "GroupService", "SocialService",
	"TeleportService", "VRService", "HapticService", "PathfindingService", "MessagingService", "TextChatService",
	"VoiceChatService", "AnalyticsService", "PolicyService", "AvatarEditorService", "ExperienceNotificationService", "Selection",
	"TestService", "AssetService", "MaterialService", "InsertService", "PermissionsService", "LogService", "StatsService" }) do
	mkService(nm)
end
mkService("ServerScriptService", true)
mkService("ServerStorage", true)
services.UserGameSettings = newInstance(classes.UserGameSettings)
do
	local sp = services.StarterPlayer
	local a = newInstance(classes.StarterPlayerScripts); a[DATA].p.Name = "StarterPlayerScripts"; I.setParentRaw(a, a[DATA], sp)
	local b = newInstance(classes.StarterCharacterScripts); b[DATA].p.Name = "StarterCharacterScripts"; I.setParentRaw(b, b[DATA], sp)
end
mock.game = game
mock.services = services

---------------------------------------------------------------------------
-- 4. Персонаж (R15 из блоков)
---------------------------------------------------------------------------
local function part(model, name, size, cf, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color or c3(0.95, 0.8, 0.65)
	p.CanCollide = name == "HumanoidRootPart" or name == "UpperTorso" or name == "LowerTorso" or name == "Head"
	p.Anchored = false
	p.Parent = model
	return p
end
local function motor(name, p0, p1, c0, c1)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0
	m.C1 = c1 or CFrame.new()
	m.Parent = p1
	return m
end
function mock.buildRig(name, at)
	at = at or CFrame.new(0, 3, 0)
	local m = Instance.new("Model")
	m.Name = name
	local root = part(m, "HumanoidRootPart", v3(2, 2, 1), at)
	root.Transparency = 1
	local lower = part(m, "LowerTorso", v3(2, 0.4, 1), at * CFrame.new(0, -0.8, 0))
	local upper = part(m, "UpperTorso", v3(2, 1.6, 1), at * CFrame.new(0, 0.2, 0))
	local head = part(m, "Head", v3(1.2, 1.2, 1.2), at * CFrame.new(0, 1.6, 0))
	local face = Instance.new("Decal"); face.Name = "face"; face.Texture = "rbxasset://textures/face.png"; face.Parent = head
	motor("Root", root, lower, CFrame.new(0, -0.8, 0), CFrame.new())
	motor("Waist", lower, upper, CFrame.new(0, 0.2, 0), CFrame.new(0, -0.8, 0))
	motor("Neck", upper, head, CFrame.new(0, 0.8, 0), CFrame.new(0, -0.6, 0))
	for _, side in ipairs({ "Left", "Right" }) do
		local sx = side == "Left" and -1 or 1
		local ua = part(m, side .. "UpperArm", v3(1, 1.2, 1), at * CFrame.new(1.5 * sx, 0.4, 0))
		local la = part(m, side .. "LowerArm", v3(1, 1.1, 1), at * CFrame.new(1.5 * sx, -0.7, 0))
		local hd = part(m, side .. "Hand", v3(1, 0.3, 1), at * CFrame.new(1.5 * sx, -1.4, 0))
		motor(side .. "Shoulder", upper, ua, CFrame.new(1.5 * sx, 0.6, 0), CFrame.new(0, 0.4, 0))
		motor(side .. "Elbow", ua, la, CFrame.new(0, -0.6, 0), CFrame.new(0, 0.5, 0))
		motor(side .. "Wrist", la, hd, CFrame.new(0, -0.55, 0), CFrame.new(0, 0.15, 0))
		local ul = part(m, side .. "UpperLeg", v3(1, 1.2, 1), at * CFrame.new(0.5 * sx, -1.6, 0))
		local ll = part(m, side .. "LowerLeg", v3(1, 1.1, 1), at * CFrame.new(0.5 * sx, -2.6, 0))
		local ft = part(m, side .. "Foot", v3(1, 0.3, 1), at * CFrame.new(0.5 * sx, -3.0, 0))
		motor(side .. "Hip", lower, ul, CFrame.new(0.5 * sx, -0.2, 0), CFrame.new(0, 0.6, 0))
		motor(side .. "Knee", ul, ll, CFrame.new(0, -0.6, 0), CFrame.new(0, 0.55, 0))
		motor(side .. "Ankle", ll, ft, CFrame.new(0, -0.55, 0), CFrame.new(0, 0.15, 0))
	end
	local hum = Instance.new("Humanoid")
	hum.RigType = E("HumanoidRigType", "R15")
	hum.HipHeight = 2
	local anim = Instance.new("Animator"); anim.Parent = hum
	hum.Parent = m
	m.PrimaryPart = root
	return m
end

local runScriptsIn -- вперёд
function loadCharacter(plr)
	local pd = plr[DATA]
	local old = pd.p.Character
	if old then
		fireEvent(pd, "CharacterRemoving", old)
		old:Destroy()
	end
	local spawnCf = CFrame.new(0, 5, 0)
	for _, d in ipairs(wsInst:GetDescendants()) do
		if d:IsA("SpawnLocation") and d.Enabled ~= false then spawnCf = d.CFrame * CFrame.new(0, d.Size.Y / 2 + 3, 0); break end
	end
	local sp = services.StarterPlayer
	local m = mock.buildRig(pd.p.Name, spawnCf)
	local hum = m:FindFirstChildOfClass("Humanoid")
	hum.WalkSpeed = sp.CharacterWalkSpeed
	hum.JumpHeight = sp.CharacterJumpHeight
	pd.p.Character = m
	m.Parent = wsInst
	if pd.sig then I.propChanged(plr, pd, "Character") end
	-- скрипты персонажа
	for _, s in ipairs(sp.StarterCharacterScripts:GetChildren()) do
		local c = s:Clone()
		c.Parent = m
	end
	runScriptsIn(m, plr)
	fireEvent(pd, "CharacterAdded", m)
	fireEvent(pd, "CharacterAppearanceLoaded", m)
	return m
end

function mock.addPlayer(name)
	local plr = newInstance(classes.Player)
	local pd = plr[DATA]
	pd.p.Name = name
	pd.p.DisplayName = name
	pd.p.UserId = #players + 1
	rawset(plr, "__name", name)
	players[#players + 1] = plr
	local ctx = mock.clientCtx(plr)
	local pg = newInstance(classes.PlayerGui); pg[DATA].p.Name = "PlayerGui"; I.setParentRaw(pg, pg[DATA], plr)
	local bp = newInstance(classes.Backpack); bp[DATA].p.Name = "Backpack"; I.setParentRaw(bp, bp[DATA], plr)
	local ps = newInstance(classes.PlayerScripts); ps[DATA].p.Name = "PlayerScripts"; I.setParentRaw(ps, ps[DATA], plr)
	I.setParentRaw(plr, pd, services.Players)
	fireEvent(services.Players[DATA], "PlayerAdded", plr)
	-- StarterGui -> PlayerGui
	for _, g in ipairs(services.StarterGui:GetChildren()) do g:Clone().Parent = pg end
	-- StarterPlayerScripts -> PlayerScripts
	for _, s in ipairs(services.StarterPlayer.StarterPlayerScripts:GetChildren()) do s:Clone().Parent = ps end
	runScriptsIn(ps, plr)
	runScriptsIn(pg, plr)
	if services.Players.CharacterAutoLoads then loadCharacter(plr) end
	return plr, ctx
end

---------------------------------------------------------------------------
-- 5. Глобальные имена Luau и require
---------------------------------------------------------------------------
-- расширения стандартной библиотеки Luau
function math.clamp(x, a, b)
	if type(x) ~= "number" or type(a) ~= "number" or type(b) ~= "number" then throw("invalid argument to 'clamp' (number expected)") end
	if a > b then throw("max must be greater than or equal to min") end
	return x < a and a or (x > b and b or x)
end
math.atan2 = function(y, x) return math.atan(y, x) end
math.pow = function(a, b) return a ^ b end
math.log10 = function(x) return math.log(x, 10) end
math.cosh = function(x) return (math.exp(x) + math.exp(-x)) / 2 end
math.sinh = function(x) return (math.exp(x) - math.exp(-x)) / 2 end
math.tanh = function(x) local a, b = math.exp(x), math.exp(-x); return (a - b) / (a + b) end
function math.round(x) if x >= 0 then return math.floor(x + 0.5) end; return math.ceil(x - 0.5) end
function math.sign(x) return x > 0 and 1 or (x < 0 and -1 or 0) end
function math.lerp(a, b, t) return a + (b - a) * t end
do
	local perm = {}
	local rnd = 1234567
	for i = 0, 255 do perm[i] = i end
	for i = 255, 1, -1 do rnd = (rnd * 1103515245 + 12345) % 2147483648; local j = rnd % (i + 1); perm[i], perm[j] = perm[j], perm[i] end
	for i = 0, 255 do perm[i + 256] = perm[i] end
	local function fade(t) return t * t * t * (t * (t * 6 - 15) + 10) end
	local function grad(h, x, y, z)
		h = h % 16
		local u = h < 8 and x or y
		local v = h < 4 and y or ((h == 12 or h == 14) and x or z)
		return ((h % 2) == 0 and u or -u) + ((h % 4) < 2 and v or -v)
	end
	function math.noise(x, y, z)
		x, y, z = x or 0, y or 0, z or 0
		local X, Y, Z = math.floor(x) % 256, math.floor(y) % 256, math.floor(z) % 256
		x, y, z = x - math.floor(x), y - math.floor(y), z - math.floor(z)
		local u, v, w = fade(x), fade(y), fade(z)
		local A, B = perm[X] + Y, perm[X + 1] + Y
		local AA, AB, BA, BB = perm[A] + Z, perm[A + 1] + Z, perm[B] + Z, perm[B + 1] + Z
		local function l(t, a, b) return a + t * (b - a) end
		return l(w, l(v, l(u, grad(perm[AA], x, y, z), grad(perm[BA], x - 1, y, z)), l(u, grad(perm[AB], x, y - 1, z), grad(perm[BB], x - 1, y - 1, z))),
			l(v, l(u, grad(perm[AA + 1], x, y, z - 1), grad(perm[BA + 1], x - 1, y, z - 1)), l(u, grad(perm[AB + 1], x, y - 1, z - 1), grad(perm[BB + 1], x - 1, y - 1, z - 1))))
	end
end
function table.find(t, v, init) for i = init or 1, #t do if t[i] == v then return i end end; return nil end
function table.clear(t) for k in pairs(t) do t[k] = nil end end
function table.create(n, v) local t = {}; for i = 1, n do t[i] = v end; return t end
function table.freeze(t) return t end
function table.isfrozen() return false end
function table.clone(t) local o = {}; for k, v in pairs(t) do o[k] = v end; return o end
function string.split(s, sep)
	sep = sep or ","
	local out = {}
	if sep == "" then for i = 1, #s do out[i] = s:sub(i, i) end; return out end
	local start = 1
	while true do
		local a, b = s:find(sep, start, true)
		if not a then out[#out + 1] = s:sub(start); break end
		out[#out + 1] = s:sub(start, a - 1)
		start = b + 1
	end
	return out
end
local bit32 = {
	band = function(...) local r = -1; for _, v in ipairs({ ... }) do r = r & math.floor(v) end; return r & 0xFFFFFFFF end,
	bor = function(...) local r = 0; for _, v in ipairs({ ... }) do r = r | math.floor(v) end; return r & 0xFFFFFFFF end,
	bxor = function(...) local r = 0; for _, v in ipairs({ ... }) do r = r ~ math.floor(v) end; return r & 0xFFFFFFFF end,
	bnot = function(x) return (~math.floor(x)) & 0xFFFFFFFF end,
	lshift = function(x, n) return (math.floor(x) << n) & 0xFFFFFFFF end,
	rshift = function(x, n) return (math.floor(x) & 0xFFFFFFFF) >> n end,
	extract = function(x, f, w) w = w or 1; return (math.floor(x) >> f) & ((1 << w) - 1) end,
	btest = function(...) return bit32 and true end,
}

local sharedG = {} -- ctx.key -> _G
local scriptEnvs = setmetatable({}, { __mode = "k" })
local moduleCache = {} -- ctx.key -> { [module] = {state, value} }

local function ctxLabel() return curCtx().label end
local function fmtArgs(...)
	local n = select("#", ...)
	local o = {}
	for i = 1, n do o[i] = mock.tostring((select(i, ...))) end
	return table.concat(o, " ")
end

local base = {}
for k, v in pairs(G) do base[k] = v end
for _, k in ipairs({ "assert", "error", "getmetatable", "ipairs", "next", "pairs", "pcall", "rawequal", "rawget", "rawlen",
	"rawset", "select", "setmetatable", "tonumber", "type", "xpcall", "coroutine", "string", "table", "math", "utf8" }) do
	base[k] = _G[k]
end
base.tostring = mock.tostring
base.typeof = mock.typeof
base.unpack = table.unpack
base.bit32 = bit32
base.task = mock.task
base.debug = { traceback = debug.traceback, info = function() return "", 0, "" end, profilebegin = function() end, profileend = function() end, setmemorycategory = function() end, resetmemorycategory = function() end }
base.os = { time = function(t) if t then return os.time(t) end; return math.floor(mock.epoch + mock.now) end,
	clock = function() return mock.now end, date = function(f, t) return os.date(f, t or math.floor(mock.epoch + mock.now)) end,
	difftime = os.difftime }
base.tick = function() return mock.epoch + mock.now end
base.time = function() return mock.now end
base.elapsedTime = function() return mock.now end
base.gcinfo = function() return 1000 end
base.version = function() return "0.700.0.7000000" end
base.print = function(...) mock.emit("print", "[" .. ctxLabel() .. "] " .. fmtArgs(...)) end
base.warn = function(...)
	local t = "[" .. ctxLabel() .. "] " .. fmtArgs(...)
	mock.warns[#mock.warns + 1] = t
	mock.emit("warn", t)
end
base.wait = function(t) suspicious("DEPRECATED", "wait() устарел — используйте task.wait"); return mock.task.wait(t) end
base.spawn = function(f) suspicious("DEPRECATED", "spawn() устарел — используйте task.spawn"); return mock.task.defer(f) end
base.delay = function(t, f) suspicious("DEPRECATED", "delay() устарел — используйте task.delay"); return mock.task.delay(t, f) end
base.game = game
base.Game = game
base.workspace = wsInst
base.Workspace = wsInst
base.settings = function() return { Rendering = { QualityLevel = E("QualityLevel", "Automatic"), EagerBulkExecution = false } } end
base.UserSettings = function() return { GetService = function(_, n) return services[n] end } end
base.plugin = nil

local requireModule
local function makeEnv(scriptInst)
	local ctx = curCtx()
	local g = sharedG[ctx.key]
	if not g then g = {}; sharedG[ctx.key] = g end
	local env = setmetatable({ script = scriptInst, _G = g, shared = g }, { __index = base })
	env.require = function(m) return requireModule(m, scriptInst) end
	return env
end

local function compile(inst)
	local src = inst[DATA].p.Source
	local path = inst[DATA].path or I.fullName(inst)
	local env = makeEnv(inst)
	local fn, err = load(src, "@" .. path, "t", env)
	if not fn then throw("Syntax error in " .. path .. ": " .. tostring(err)) end
	return fn
end

function requireModule(m, from)
	if type(m) == "number" then throw("require(assetId) не поддерживается в песочнице") end
	if not I.isInst(m) or not m:IsA("ModuleScript") then throw("Attempted to call require with invalid argument(s).") end
	local ctx = curCtx()
	local cache = moduleCache[ctx.key]
	if not cache then cache = {}; moduleCache[ctx.key] = cache end
	local e = cache[m]
	if e then
		if e.state == "loading" then
			-- ждём завершения (в Roblox — бесконечное ожидание при цикле)
			local guard = 0
			while e.state == "loading" do
				guard = guard + 1
				if guard > 600 then throw("Requested module was required recursively: " .. I.fullName(m)) end
				mock.task.wait()
			end
		end
		if e.state == "error" then throw("Requested module experienced an error while loading: " .. I.fullName(m)) end
		return e.value
	end
	e = { state = "loading" }
	cache[m] = e
	local fn = compile(m)
	local ok, res = xpcall(function() return table.pack(fn()) end, debug.traceback)
	if not ok then
		e.state = "error"
		mock.recordError(res, res, ctx)
		throw("Requested module experienced an error while loading: " .. I.fullName(m))
	end
	if res.n ~= 1 then
		e.state = "error"
		throw("Module code did not return exactly one value: " .. I.fullName(m))
	end
	e.state = "done"
	e.value = res[1]
	return e.value
end
mock.require = requireModule

local function runScript(s, ctx)
	local d = s[DATA]
	if d.started then return end
	d.started = true
	if s.Disabled == true or s.Enabled == false then return end
	local co = newThread(function()
		local fn = compile(s)
		fn()
	end, ctx)
	resume(co)
end

-- запустить скрипты внутри контейнера: Script — на сервере, LocalScript — у игрока
function runScriptsIn(root, plr)
	local list = { root }
	for _, x in ipairs(root:GetDescendants()) do list[#list + 1] = x end
	for _, s in ipairs(list) do
		local cn = s[DATA].cls.name
		if cn == "LocalScript" and plr then
			runScript(s, mock.clientCtx(plr))
		elseif cn == "Script" then
			local rc = s.RunContext
			if rc and rc.Name == "Client" and plr then runScript(s, mock.clientCtx(plr))
			elseif not plr or (rc and rc.Name == "Server") or root == wsInst then runScript(s, mock.SERVER) end
		end
	end
end
mock.runScriptsIn = runScriptsIn

function mock.startServer()
	runScriptsIn(services.ServerScriptService, nil)
	runScriptsIn(wsInst, nil)
end

---------------------------------------------------------------------------
-- 6. Кадр: время, таймеры, события RunService, твины, гуманоиды, подсказки
---------------------------------------------------------------------------
local promptState = {} -- ctx -> { [prompt] = true }
local function updatePrompts()
	local pps = services.ProximityPromptService
	for _, plr in ipairs(players) do
		local ctx = mock.clientCtx(plr)
		local shown = promptState[ctx] or {}
		promptState[ctx] = shown
		local ch = plr[DATA].p.Character
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		local cam = ctx.camera
		local now = {}
		if root then
			local rp = root.Position
			for _, p in ipairs(wsInst:GetDescendants()) do
				if p[DATA].cls.name == "ProximityPrompt" and p.Enabled and pps.Enabled then
					local par = p.Parent
					local pos
					if par and par:IsA("BasePart") then pos = par.Position
					elseif par and par:IsA("Attachment") then pos = par.WorldPosition
					elseif par and par:IsA("Model") then pos = par:GetPivot().Position end
					if pos and (pos - rp).Magnitude <= p.MaxActivationDistance then now[p] = true end
				end
			end
		end
		local filter = function(c) return c == ctx end
		for p in pairs(now) do
			if not shown[p] then
				fireSignal(getEvent(p, p[DATA], "PromptShown"), filter, E("ProximityPromptInputType", "Keyboard"))
				fireSignal(getEvent(pps, pps[DATA], "PromptShown"), filter, p, E("ProximityPromptInputType", "Keyboard"))
			end
		end
		for p in pairs(shown) do
			if not now[p] and not p[DATA].destroyed then
				fireSignal(getEvent(p, p[DATA], "PromptHidden"), filter)
				fireSignal(getEvent(pps, pps[DATA], "PromptHidden"), filter, p)
			end
		end
		promptState[ctx] = now
	end
end

-- сработать подсказке от имени игрока (как нажатие E рядом с ней)
function mock.triggerPrompt(prompt, plr)
	local pps = services.ProximityPromptService
	fireSignal(getEvent(prompt, prompt[DATA], "Triggered"), nil, plr)
	fireSignal(getEvent(pps, pps[DATA], "PromptTriggered"), nil, prompt, plr)
	fireSignal(getEvent(prompt, prompt[DATA], "TriggerEnded"), nil, plr)
end

local promptAcc = 0
function mock.step(dt)
	dt = dt or (1 / 60)
	mock.now = mock.now + dt
	mock.frame = mock.frame + 1
	mock.runTimersNow()
	local rs = services.RunService
	local rd = rs[DATA]
	if I.updateHumanoids then I.updateHumanoids(dt) end
	if I.solveDirtyJoints then I.solveDirtyJoints() end
	if rd.sig then
		if rd.sig.PreSimulation then fireSignal(rd.sig.PreSimulation, nil, dt) end
		if rd.sig.Stepped then fireSignal(rd.sig.Stepped, nil, mock.now, dt) end
	end
	stepTweens(dt)
	if rd.sig then
		if rd.sig.PostSimulation then fireSignal(rd.sig.PostSimulation, nil, dt) end
		if rd.sig.Heartbeat then fireSignal(rd.sig.Heartbeat, nil, dt) end
	end
	for ctx, list in pairs(renderBinds) do
		local copy = {}
		for i, b in ipairs(list) do copy[i] = b end
		for _, b in ipairs(copy) do resume(newThread(b.fn, ctx), dt) end
	end
	if rd.sig then
		if rd.sig.PreRender then fireSignal(rd.sig.PreRender, nil, dt) end
		if rd.sig.RenderStepped then fireSignal(rd.sig.RenderStepped, nil, dt) end
	end
	promptAcc = promptAcc + dt
	if promptAcc >= 0.1 then promptAcc = 0; updatePrompts() end
	mock.runDeferred()
end
function mock.run(seconds, dt)
	dt = dt or (1 / 30)
	local n = math.max(1, math.floor(seconds / dt + 0.5))
	for _ = 1, n do mock.step(dt) end
end

-- ввод от имени игрока: клавиша (KeyCode) или тип ввода
local function inputObj(kc, uit, state)
	local o = newInstance(classes.InputObject)
	local d = o[DATA]
	d.p.KeyCode = kc and E("KeyCode", kc) or E("KeyCode", "Unknown")
	d.p.UserInputType = E("UserInputType", uit or (kc and "Keyboard" or "MouseButton1"))
	d.p.UserInputState = E("UserInputState", state)
	return o
end
local function routeCAS(ctx, obj, state)
	local list = casBinds[ctx]
	if not list then return false end
	for _, b in ipairs({ table.unpack(list) }) do
		for _, inp in ipairs(b.inputs) do
			if inp == obj.KeyCode or inp == obj.UserInputType then
				local res
				local co = newThread(function() res = b.fn(b.name, E("UserInputState", state), obj) end, ctx)
				resume(co)
				if res == nil or res ~= E("ContextActionResult", "Pass") then return true end
			end
		end
	end
	return false
end
function mock.key(plr, kc, uit, hold)
	local ctx = mock.clientCtx(plr)
	local uis = services.UserInputService
	local filter = function(c) return c == ctx end
	keysDown[ctx] = keysDown[ctx] or {}
	local b = inputObj(kc, uit, "Begin")
	if kc then keysDown[ctx][kc] = true end
	local sunk = routeCAS(ctx, b, "Begin")
	fireSignal(getEvent(uis, uis[DATA], "InputBegan"), filter, b, sunk)
	if hold then mock.run(hold) end
	local e = inputObj(kc, uit, "End")
	if kc then keysDown[ctx][kc] = nil end
	sunk = routeCAS(ctx, e, "End")
	fireSignal(getEvent(uis, uis[DATA], "InputEnded"), filter, e, sunk)
end

-- нажать на GuiButton (как клик мышью / тап)
function mock.click(btn)
	if not btn then throw("mock.click: кнопка не найдена") end
	local d = btn[DATA]
	if not d.cls.isa.GuiButton then throw("mock.click: не кнопка: " .. I.fullName(btn)) end
	local io = inputObj(nil, "MouseButton1", "Begin")
	fireEvent(d, "MouseButton1Down", 640, 360)
	fireEvent(d, "InputBegan", io)
	fireEvent(d, "MouseButton1Up", 640, 360)
	fireEvent(d, "MouseButton1Click")
	fireEvent(d, "Activated", io, 1)
	fireEvent(d, "InputEnded", inputObj(nil, "MouseButton1", "End"))
end
function mock.hover(btn)
	local d = btn[DATA]
	fireEvent(d, "MouseEnter", 640, 360)
	fireEvent(d, "InputBegan", inputObj(nil, "MouseMovement", "Change"))
end

-- найти потомка по имени (в глубину)
function mock.find(root, name)
	for _, x in ipairs(root:GetDescendants()) do if x[DATA].p.Name == name then return x end end
	return nil
end
function mock.findAll(root, pred)
	local o = {}
	for _, x in ipairs(root:GetDescendants()) do if pred(x) then o[#o + 1] = x end end
	return o
end

return mock
