#!/bin/sh
# Офлайн-проверка игры без Roblox Studio (Linux / macOS / Git Bash).
# Настоящий Luau + мок Roblox API: имена свойств, методов, событий и Enum
# сверяются с официальным API-дампом Roblox. Нужны curl, unzip и python3.
set -e
cd "$(dirname "$0")"
CACHE=.cache
mkdir -p "$CACHE"

case "$(uname -s)" in
	Darwin) LUAU_ZIP=luau-macos.zip ;;
	MINGW* | MSYS* | CYGWIN*) LUAU_ZIP=luau-windows.zip ;;
	*) LUAU_ZIP=luau-ubuntu.zip ;;
esac

if [ ! -f "$CACHE/luau" ] && [ ! -f "$CACHE/luau.exe" ]; then
	echo "Скачиваю Luau CLI..."
	curl -sSL -o "$CACHE/luau.zip" "https://github.com/luau-lang/luau/releases/latest/download/$LUAU_ZIP"
	unzip -o -q "$CACHE/luau.zip" -d "$CACHE"
fi
if [ ! -f "$CACHE/API-Dump.json" ]; then
	echo "Скачиваю API-дамп Roblox..."
	curl -sSL -o "$CACHE/API-Dump.json" "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json"
fi

python3 gen_api.py "$CACHE/API-Dump.json" "$CACHE/api.luau"
"$CACHE/luau-compile" --only-parse $(find ../src -name '*.lua') > /dev/null
echo "Синтаксис всех файлов: OK"
python3 build_bundle.py .. "$CACHE/api.luau" mock.luau test_game.luau "$CACHE/bundle.luau"
"$CACHE/luau" "$CACHE/bundle.luau"
