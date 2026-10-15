--[[
	SoundIds — ID собственных звуков игры (файлы из папки assets/sounds) после загрузки в Roblox.

	Заполняется автоматически:
	  • python3 tools/upload_sounds.py  — загрузит все файлы через Open Cloud и сам перепишет этот файл;
	  • или загрузите файлы вручную и запустите tools/collect_sound_ids.lua в командной строке Studio —
	    он напечатает готовое содержимое этого файла.
	Подробно — README, раздел «Свои звуки».

	Пустая строка — звук ещё не загружен: игра сама найдёт похожий в библиотеке Roblox
	(Config/Sounds → Search), а если не найдёт — возьмёт встроенный звук Roblox.
	Можно писать и просто число: Click = 1234567890.
]]

return {
	Click = "",
	Button = "",
	Coin = "",
	Sell = "",
	EggShake = "",
	Hatch = "",
	Reveal = "",
	Rare = "",
	Rebirth = "",
	Unlock = "",
	Merge = "",
	Teleport = "",
	Error = "",
	Purchase = "",
	Music_Forest = "",
	Music_Desert = "",
	Music_Space = "",
}
