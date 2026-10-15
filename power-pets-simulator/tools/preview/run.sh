#!/bin/sh
# Визуальная проверка без Roblox Studio: проходит игру на моке и рисует интерфейс и миры в PNG.
#   sh tools/preview/run.sh [ширина высота отступX отступY экранW экранH]
# По умолчанию — монитор 1280×720 (полоса Roblox сверху 58 px). Телефон: sh tools/preview/run.sh 750 354 47 36 844 390
# Нужны python3 с numpy и Pillow; сначала один раз запустите sh tools/run_tests.sh (скачает Luau и API-дамп).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
TOOLS=$(dirname "$HERE")
W=${1:-1280}; H=${2:-662}; OX=${3:-0}; OY=${4:-58}; SW=${5:-1280}; SH=${6:-720}
OUT="$TOOLS/.cache/preview_${SW}x${SH}"
mkdir -p "$OUT"
{ echo "SCREEN_SIZE = { $W, $H }"; cat "$HERE/scenario.luau"; } > "$OUT/scenario.luau"
cd "$TOOLS"
python3 build_bundle.py .. .cache/api.luau mock.luau "$OUT/scenario.luau" "$OUT/bundle.luau" > /dev/null
.cache/luau "$OUT/bundle.luau" > "$OUT/dump.txt" 2>&1
cd "$HERE"
python3 gui.py "$OUT/dump.txt" "$OUT" "$OX" "$OY" "$SW" "$SH"
[ "$SW" = 1280 ] && python3 scene.py "$OUT/dump.txt" && mv scene_*.png "$OUT/" 2>/dev/null || true
echo "Картинки: $OUT"
