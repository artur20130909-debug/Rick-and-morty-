#!/bin/sh
# Проверка всех Lua-файлов: синтаксис (luaparse, режим 5.2 — ловит и Luau-синтаксис вроде +=, который
# не понимает песочница) и «случайные» глобальные переменные. Нужен luaparse:  npm i -g luaparse
cd "$(dirname "$0")/.."
FILES=$(find "$PWD/src" -name '*.lua' | sort)
node tools/check.js $FILES | grep -v '^OK' ; node tools/globals.js $FILES | grep -v 'no stray globals'
echo "checked $(echo "$FILES" | wc -l) files"
