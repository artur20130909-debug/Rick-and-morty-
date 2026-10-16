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

	tool = nil :: string?,          -- "build" | "delete" | "paint" | "pick" | nil
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
	return {
		mat = mat,
		shape = shape,
		item = item,
		size = Blocks.normalizeSize(shape, item, sel.size, Config.MaxBlockSize),
		rot = sel.rot,
		color = sel.color,
	}
end

function State.selectBlock(kind: string, id: number)
	local sel = State.sel
	sel.kind = kind
	sel.id = id
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
