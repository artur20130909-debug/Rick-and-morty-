#!/bin/sh
# Проверка типов всего Luau-кода против определений Roblox API (luau-lsp).
#   LUAU_LSP     — путь к luau-lsp (https://github.com/JohnnyMorganz/luau-lsp)
#   ROBLOX_DEFS  — путь к globalTypes.None.d.luau из того же репозитория
cd "$(dirname "$0")/.."
LSP=${LUAU_LSP:-luau-lsp}
DEFS=${ROBLOX_DEFS:-globalTypes.None.d.luau}
rojo sourcemap default.project.json -o sourcemap.json || exit 1
"$LSP" analyze --platform=roblox --sourcemap=sourcemap.json --definitions=@roblox="$DEFS" \
  --flag:LuauSolverV2=false src/ 2>&1
