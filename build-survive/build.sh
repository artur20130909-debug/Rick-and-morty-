#!/bin/sh
# Сборка файла места: sh build.sh  ->  BuildAndSurvive.rbxlx
# Нужен Rojo 7 (https://rojo.space). Перед сборкой генераторы обновляют карту (tools/gen_map.py),
# примеры построек (tools/gen_examples.py) и готовые дома и бункеры магазина (tools/gen_prefabs.py).
cd "$(dirname "$0")"
python3 tools/gen_map.py && python3 tools/gen_examples.py && python3 tools/gen_prefabs.py \
	&& rojo build default.project.json -o BuildAndSurvive.rbxlx
