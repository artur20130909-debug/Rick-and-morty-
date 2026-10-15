--[[
	Sounds — звуки интерфейса и событий.
	По умолчанию стоят встроенные звуки Roblox (rbxasset://), они есть в любой игре.
	Можно заменить на свои: найди звук в Creator Store и впиши "rbxassetid://<ID>".
	Pitch — скорость воспроизведения (выше = тоньше звук).
]]

local Sounds = {
	Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.6, Pitch = 1 },
	Button = { Id = "rbxasset://sounds/button.wav", Volume = 0.45, Pitch = 1 },
	Coin = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 1.5 },
	Sell = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.7, Pitch = 1 },
	EggShake = { Id = "rbxasset://sounds/snap.wav", Volume = 0.5, Pitch = 1.2 },
	Hatch = { Id = "rbxasset://sounds/glassbreak.wav", Volume = 0.35, Pitch = 1.4 },
	Rare = { Id = "rbxasset://sounds/victory.wav", Volume = 0.6, Pitch = 1 },
	Rebirth = { Id = "rbxasset://sounds/victory.wav", Volume = 0.7, Pitch = 0.85 },
	Unlock = { Id = "rbxasset://sounds/victory.wav", Volume = 0.6, Pitch = 1.1 },
	Merge = { Id = "rbxasset://sounds/victory.wav", Volume = 0.6, Pitch = 1.25 },
	Teleport = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.6, Pitch = 1 },
	Error = { Id = "rbxasset://sounds/hit.wav", Volume = 0.4, Pitch = 0.8 },
}

return Sounds
