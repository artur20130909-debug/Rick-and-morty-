-- Состояние клиента: золото, купленные блоки, выбранный инструмент и блок, режимы.
-- Модули подписываются на изменения через State.changed.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Blocks = require(Shared.Blocks)

export type Signal = {
	Connect: (Signal, (...any) -> ()) -> { Disconnect: () -> () },
	Fire: (Signal, ...any) -> (),
}

local function newSignal(): Signal
	local handlers: { (...any) -> () } = {}
	local s = {}
	function s.Connect(_self, fn: (...any) -> ())
		table.insert(handlers, fn)
		return {
			Disconnect = function()
				local i = table.find(handlers, fn)
				if i then
					table.remove(handlers, i)
				end
			end,
		}
	end
	function s.Fire(_self, ...: any)
		for _, fn in table.clone(handlers) do
			task.spawn(fn, ...)
		end
	end
	return (s :: any) :: Signal
end

local State = {
	newSignal = newSignal,
	changed = newSignal(), -- (key, value)

	gold = 0,
	unlocked = {} :: { [string]: boolean },
	bestWave = 0,
	slots = {} :: { any },
	stats = {} :: { [string]: number },
	saveEnabled = false,
	settings = table.clone(Config.DefaultSettings) :: { [string]: any },

	tool = nil :: string?,          -- "build" | "delete" | "paint" | "pick" | "dig" | nil
	digFill = false,                -- инструмент «Копать»: false — копать, true — засыпать
	prefabs = {} :: { [string]: boolean }, -- купленные готовые дома и бункеры (ключи Prefabs)
	isAdmin = false,
	modal = nil :: string?,         -- открытое окно
	siege = nil :: any,             -- последнее состояние осады с сервера
	launched = false,
	rangeTarget = "me",             -- полигон: "me" или "click"
	rangeWeapon = "Bullet",

	sel = {
		kind = "mat",               -- "mat" | "item"
		id = 1,
		shape = 1,
		size = Config.DefaultBlockSize,
		rot = 1,
		color = Blocks.MaterialById[1].color,
		customColor = false,
	},
}

function State.set(key: string, value: any)
	(State :: any)[key] = value
	State.changed:Fire(key, value)
end

function State.isUnlocked(kind: string, id: number): boolean
	local def = (kind == "item") and Blocks.ItemById[id] or Blocks.MaterialById[id]
	if not def then
		return false
	end
	if def.price <= 0 then
		return true
	end
	return State.unlocked[Blocks.unlockKey(kind, id)] == true
end

-- Текущая спецификация блока для строительства
function State.spec()
	local sel = State.sel
	local item = sel.kind == "item" and sel.id or 0
	local mat = sel.kind == "mat" and sel.id or 0
	local shape = sel.kind == "mat" and sel.shape or 1
	local size = Blocks.normalizeSize(shape, item, sel.size, Config.MaxBlockSize)
	if item > 0 then
		-- у особого блока размер только приводится к пределам (дверь не меньше minSize):
		-- запоминаем приведённый, чтобы кнопки «−»/«+» в панели шли от того, что видно
		sel.size = size
	end
	return {
		mat = mat,
		shape = shape,
		item = item,
		size = size,
		rot = sel.rot,
		color = sel.color,
	}
end

-- Размер запоминается для каждого выбора отдельно: один общий для всех материалов ("mat")
-- и свой у каждого особого блока с изменяемым размером (сначала — размер из каталога, у двери 4×7×1).
local sizeMemory: { [string]: Vector3 } = {}

local function sizeKey(kind: string, id: number): string?
	if kind == "mat" then
		return "mat"
	end
	local it = Blocks.ItemById[id]
	if it and it.resizable then
		return "item" .. id
	end
	return nil
end

function State.selectBlock(kind: string, id: number)
	local sel = State.sel
	local oldKey = sizeKey(sel.kind, sel.id)
	if oldKey then
		sizeMemory[oldKey] = sel.size
	end
	sel.kind = kind
	sel.id = id
	local key = sizeKey(kind, id)
	if key then
		sel.size = sizeMemory[key] or (if kind == "item" then Blocks.ItemById[id].size else Config.DefaultBlockSize)
	elseif kind == "item" and Blocks.ItemById[id] then
		sel.size = Blocks.ItemById[id].size -- размер фиксирован
	end
	if not sel.customColor then
		local def = (kind == "item") and Blocks.ItemById[id] or Blocks.MaterialById[id]
		sel.color = def.color
	end
	State.changed:Fire("sel", sel)
end

function State.inSiege(): boolean
	return State.siege ~= nil and State.siege.active == true
end

return State
