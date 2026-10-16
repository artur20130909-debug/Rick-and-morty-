# Обновление v3 — где остановились (WIP)

Работа приостановлена по просьбе пользователя. Базовый коммит до начала v3: `ebffd1f`.
Спецификация: `SPEC_v3.md`. Сценарий процесса: `workflow-v3.js`.
Отчёты готовых пакетов: `done-packages.md`.

## Запрос пользователя
1. Двери стали размером в 1 блок, а должны быть 4×7×1.
2. Подземные бункеры: можно копать под участком.
3. Магазин готовых домов и бункеров. Чем дороже, тем современнее; в дорогих — ПВО и охранники.
4. Тропинка мерцает с полом (z-fighting), исправить и проверить всю карту.
5. Админ-панель для тестов.

## Готово
- Общие связи:
  - `Config.Underground` и `Config.Admins`;
  - удалённые вызовы `Dig`, `BuyPrefab`, `PlacePrefab`, `Admin` и событие `GuardShot`;
  - звуки `Dig` и `GuardShot`;
  - инструмент ⛏ «Копать» (клавиша 5) и кнопка «Админ» в HUD;
  - поля `State.digFill`, `State.prefabs`, `State.isAdmin`;
  - подключение модулей в `Main.server.lua` и `Client.client.lua`.
- **UG_SERVER:**
  - `Shared/Underground.lua` и `Server/Underground.lua`;
  - Serializer v2 с маской выкопанной земли;
  - изменения в Grid, Building (`dig`, отмена, restore), Plots, Damage (земля даёт укрытие) и Launch;
  - тесты `tools/test_underground.luau`.
- **UG_CLIENT:** инструмент «Копать» в `BuildController.lua`.

## Остановлено на середине
- **MAP** (`tools/gen_map.py`, `tools/check_zfight.py`):
  - в Plot: Ground, Foundation и GridPlane вместо Base и Skirt;
  - исправить тропинку и InnerRing;
  - проверить z-fighting по всей карте.
  Сгенерированные файлы могут быть в промежуточном состоянии — перезапустить пакет.

## Не начато
- **PREFABS:** `tools/gen_prefabs.py` → `Shared/Prefabs.lua`, `tools/preview/prefabs.json`, `tools/test_prefabs.luau`.
- **GUARDS:** предмет «Охранник» (id 13) и исправление размера двери (`State.selectBlock`, `Door.minSize`).
- **SHOP:** `Server/PrefabShop.lua`, `Data.Prefabs`, вкладки «Дома» и «Бункеры» в `ShopUI`.
- **ADMIN:** `Server/Admin.lua`, `Client/UI/AdminUI.lua`, `Client/AdminTools.lua` (полёт), админ-хуки в Siege.
- Затем: интеграция (все проверки и `sh build.sh`), ревью, исправления, скриншоты и README.

## Важно
- `Main.server.lua` уже требует `Server.PrefabShop` и `Server.Admin`, а `Client.client.lua` — `UI.AdminUI`.
  Этих модулей ещё нет, поэтому текущее состояние ветки не запускается. Последняя рабочая версия — `ebffd1f`.
- Ревьюерам сравнивать изменения с `ebffd1f`, а не с HEAD.
- На машине 4 ядра, поэтому агенты процесса работают по двое.
