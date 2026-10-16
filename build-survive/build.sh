#!/bin/sh
# Сборка файла места: sh build.sh  ->  BuildAndSurvive.rbxlx
# Нужен Rojo 7 (https://rojo.space). Карта генерируется скриптом tools/gen_map.py.
cd "$(dirname "$0")"
python3 tools/gen_map.py && rojo build default.project.json -o BuildAndSurvive.rbxlx
