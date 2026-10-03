# Стихийные битвы RNG (Roblox)

RNG-битвы с лобби в стиле Slap Battles: в лобби жмёшь **РОЛЛ** — крутятся способности
(огонь, вода, земля, ветер, молния, лёд, тень, гравитация, метеор) с шансами от «1 к 2» до «1 к 1000».
Через фиолетовый портал попадаешь на арену-остров и сбиваешь других игроков (и манекены) в пустоту.

## Как открыть
1. Скачай `RNG_Battles.rbxlx` и открой в Roblox Studio: **File → Open from File**.
2. Нажми **Play** (F5).
3. Чтобы сохранялся прогресс: **File → Publish to Roblox**, затем **Game Settings → Security →
   Enable Studio Access to API Services**.

## Управление
- **РОЛЛ** (или клавиша R), **АВТО** — авто-ролл.
- **F / клик** — удар, **E** — способность. На телефоне — круглые кнопки справа.
- **Инвентарь** — надеть любую выбитую способность. **Удача ×2** — за 50 монет на 5 минут.

## Устройство
- `src/ReplicatedStorage/Abilities.lua` — список способностей, редкости, шансы.
- `src/ServerScriptService/MapBuilder.lua` — строит лобби и арену при запуске.
- `src/ServerScriptService/GameServer.lua` — данные, ролл, портал, бой, способности.
- `src/StarterPlayerScripts/ClientUI.lua` — интерфейс.
- `python3 build.py` собирает `RNG_Battles.rbxlx` из `src/`.
