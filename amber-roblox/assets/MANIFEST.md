# Ассеты Amber Alert — звуки и текстуры

Все файлы сгенерированы процедурно скриптом `tools/gen_assets.py` (синтез, шум, свёртка с синтетическими импульсными откликами комнат; рисование узоров с периодическим шумом). Никаких чужих записей, шрифтовых логотипов и реальных эмблем: эмблемы EAS и Black Ridge нарисованы с нуля.

Перегенерировать: `python3 tools/gen_assets.py` (нужны numpy, scipy, Pillow и ffmpeg с libvorbis). Только часть: `--only sounds|images`, `--keys EasTone,Carpet`. Результат детерминирован.

Превью: `preview.png` (картинки, тайлы 2×2) и `preview_audio.png` (спектрограммы всех звуков).

## Как загрузить в Roblox

1. Studio → **View → Asset Manager → Bulk Import** (кнопка импорта), выбрать файлы из `assets/sounds` и `assets/images`. Либо Creator Hub → **Development Items → Audio / Decals → Upload**.
2. После модерации: в Asset Manager ПКМ по ассету → **Copy Asset ID** (для картинок копируйте ID *изображения*; если грузили как Decal через сайт — вставьте Decal в Studio и возьмите число из его свойства `Texture`, оно отличается от ID декали).
3. Вставить ID в `ReplicatedStorage → Shared → Config`: `Config.Sounds.EasTone = "1234567890"`, `Config.Images.Carpet = "1234567890"` (только цифры). Пустая строка = звук/текстура не используется.

**Ограничения аудио** (на момент генерации, проверяйте в Creator Hub): `.ogg/.mp3/.wav/.flac`, до 7 минут и до 20 МБ на файл; квота — около 10 аудио в месяц без подтверждения личности и около 100 в месяц с подтверждённым ID (ID Verification). Каждый звук проходит модерацию. Аудио по умолчанию приватно: загружайте от того же аккаунта/группы, которой принадлежит место, иначе звук не заиграет. Картинки: до 1024×1024, PNG с альфой поддерживается.

**Что грузить в первую очередь** (максимум эффекта при маленькой квоте): `EasTone`, `Jumpscare`, `AmbientNight`, `DoorBash`, `GlassBreak`, `Heartbeat`, `Stinger`, `Static`, `WallpaperLiving`, `WallpaperBedroom`, `WallpaperKids`. Потом — `DoorBreak`, `DoorOpen`, `AmbientHouse`, `TvNews`, `EasNoise`, `Whisper`, `Breath`, `Footstep`, а дальше всё остальное.

Петли (`Looped = true`) собраны бесшовно «по кругу» (шум, фильтры и реверберация замкнуты), формат Ogg Vorbis не добавляет паузы на стыке (в отличие от MP3). Все файлы нормализованы до −1 dBFS по пику, поэтому громкость в игре задаётся свойством `Volume` (рекомендации ниже).

## Звуки (`assets/sounds`, Ogg Vorbis 44.1 кГц)

| Ключ Config | Файл | Длительность / размер | Описание | Рекомендуемые свойства |
|---|---|---|---|---|
| `EasTone` | `sounds/EasTone.ogg` | 19.01 с · моно · 204 КБ | Сигнал EAS: 3 AFSK-заголовка (520.83 бод, 2083.3/1562.5 Гц), 8 с двухтонального сигнала 853+960 Гц, 3 пакета EOM. Полоса 300–3400 Гц, лёгкое шипение. Заголовок нарочно «мусорный» (не декодируется). | Volume 0.70, RollOffMinDistance 10, RollOffMaxDistance 90 |
| `EasNoise` | `sounds/EasNoise.ogg` | 30.00 с · моно · 295 КБ | Фон эфира во время оповещения: помехи, кадровое жужжание, провалы сигнала, треск. Петля 30 с. | Volume 0.35, Looped = true, RollOffMinDistance 10, RollOffMaxDistance 80 |
| `Static` | `sounds/Static.ogg` | 10.00 с · моно · 100 КБ | ТВ-«снег»: белый шум через динамик телевизора с кадровым гулом. Петля 10 с. | Volume 0.35, Looped = true, RollOffMinDistance 8, RollOffMaxDistance 60 |
| `TvNews` | `sounds/TvNews.ogg` | 30.00 с · моно · 302 КБ | Заставка местных новостей 90-х: медь, литавры, «тикер»-арпеджио, бас, гейтованный малый. 128 BPM, 16 тактов = ровно 30 с, бесшовная петля. Окрашено как динамик ТВ. | Volume 0.45, Looped = true, RollOffMinDistance 10, RollOffMaxDistance 70 |
| `DoorOpen` | `sounds/DoorOpen.ogg` | 2.27 с · моно · 24 КБ | Дверь открывается: щелчок защёлки и долгий скрип (синтез трения через резонансы полотна и петли). | Volume 0.70, RollOffMinDistance 8, RollOffMaxDistance 70 |
| `DoorClose` | `sounds/DoorClose.ogg` | 1.22 с · моно · 13 КБ | Дверь закрывается: короткий скрип, глухой удар полотна о коробку и щелчок защёлки. | Volume 0.70, RollOffMinDistance 8, RollOffMaxDistance 70 |
| `DoorLock` | `sounds/DoorLock.ogg` | 0.47 с · моно · 8 КБ | Замок: короткий скрежет ригеля и двойной металлический щелчок. | Volume 0.60, RollOffMinDistance 6, RollOffMaxDistance 40 |
| `DoorBash` | `sounds/DoorBash.ogg` | 1.44 с · моно · 15 КБ | Тяжёлый удар в деревянную дверь: низкий «бум» полотна, дребезг петель и защёлки. | Volume 0.90, RollOffMinDistance 12, RollOffMaxDistance 140 |
| `DoorBreak` | `sounds/DoorBreak.ogg` | 2.39 с · моно · 29 КБ | Дверь выбита: мощный удар, треск древесины с щепками, звон петли, падающие обломки. | Volume 1.00, RollOffMinDistance 15, RollOffMaxDistance 160 |
| `GlassBreak` | `sounds/GlassBreak.ogg` | 1.68 с · моно · 26 КБ | Разбитое окно: хлопок трещины, шумовой всплеск и сотни коротких звонких осколков с падением на пол. | Volume 0.90, RollOffMinDistance 12, RollOffMaxDistance 140 |
| `FlashlightClick` | `sounds/FlashlightClick.ogg` | 0.18 с · моно · 6 КБ | Щелчок кнопки фонарика: пластик + пружинка. | Volume 0.50, RollOffMinDistance 4, RollOffMaxDistance 25 |
| `ApplePick` | `sounds/ApplePick.ogg` | 1.00 с · моно · 13 КБ | Сорвать яблоко: шелест листвы, щелчок черенка, мягкий шлепок в ладонь. | Volume 0.60, RollOffMinDistance 6, RollOffMaxDistance 50 |
| `Coin` | `sounds/Coin.ogg` | 1.71 с · моно · 16 КБ | Монеты: звон двух монет с отскоком и короткий колокольчик кассы — продажа/награда. | Volume 0.60, RollOffMinDistance 6, RollOffMaxDistance 40 |
| `PowerDown` | `sounds/PowerDown.ogg` | 3.33 с · моно · 15 КБ | Отключение света: щелчок реле, гул 60 Гц падает и глохнет, «уходящий» писк электроники. | Volume 0.80, RollOffMinDistance 10, RollOffMaxDistance 90 |
| `PowerUp` | `sounds/PowerUp.ogg` | 3.68 с · моно · 33 КБ | Включение света: щелчок реле, гул растёт до 60 Гц, стартёры ламп щёлкают, ровное жужжание. | Volume 0.80, RollOffMinDistance 10, RollOffMaxDistance 90 |
| `Fuse` | `sounds/Fuse.ogg` | 1.43 с · моно · 12 КБ | Предохранитель/щиток: щелчок, искрящий «дзз» дуги, хлопок и короткий гул. | Volume 0.70, RollOffMinDistance 8, RollOffMaxDistance 60 |
| `Shotgun` | `sounds/Shotgun.ogg` | 1.71 с · моно · 19 КБ | Дробовик: выстрел (хлопок + низкий «бум» + насыщение, отражения коридора) и передёргивание цевья. | Volume 1.00, RollOffMinDistance 20, RollOffMaxDistance 300 |
| `Pepper` | `sounds/Pepper.ogg` | 1.26 с · моно · 17 КБ | Перцовый баллончик: щелчок клапана и резкое шипение струи с турбулентностью. | Volume 0.60, RollOffMinDistance 6, RollOffMaxDistance 40 |
| `Stun` | `sounds/Stun.ogg` | 1.31 с · моно · 24 КБ | Электрошокер: частые щелчки разрядов (≈18 Гц), жужжание дуги и треск. | Volume 0.80, RollOffMinDistance 8, RollOffMaxDistance 60 |
| `TrapSnap` | `sounds/TrapSnap.ogg` | 0.96 с · моно · 15 КБ | Капкан: щелчок спуска, свист пружины, лязг стальных дуг и звяканье цепи. | Volume 0.90, RollOffMinDistance 10, RollOffMaxDistance 90 |
| `Heal` | `sounds/Heal.ogg` | 2.70 с · моно · 24 КБ | Лечение: мягкое колокольное арпеджио (ми мажор) с тёплой подложкой и хвостом. | Volume 0.55 |
| `Defib` | `sounds/Defib.ogg` | 2.57 с · моно · 18 КБ | Дефибриллятор: нарастающий писк зарядки, сигнал готовности, разряд (хлопок + глухой удар). | Volume 0.85, RollOffMinDistance 8, RollOffMaxDistance 60 |
| `Jumpscare` | `sounds/Jumpscare.ogg` | 2.60 с · моно · 35 КБ | Скример: диссонансный кластер расстроенных пил с «криковыми» формантами, шум, металлический FM-визг, падение высоты, суб-удар, жёсткое искажение. | Volume 1.00 |
| `Heartbeat` | `sounds/Heartbeat.ogg` | 6.00 с · моно · 15 КБ | Сердцебиение 80 уд/мин, «тук-тук» глухо и плотно. Бесшовная петля 6 с (8 ударов) — для тревоги повышайте PlaybackSpeed. | Volume 0.70, Looped = true, PlaybackSpeed 1.0–1.6 по опасности |
| `Breath` | `sounds/Breath.ogg` | 10.00 с · моно · 96 КБ | Нервное дыхание (через рот, дрожащие вдохи) — петля 10 с, для прятанья в шкафу. | Volume 0.50, Looped = true |
| `Whisper` | `sounds/Whisper.ogg` | 4.42 с · моно · 47 КБ | Жуткий шёпот без слов: формантный шум «слогами», два голоса, обратный отзвук и хвост коридора. | Volume 0.60, RollOffMinDistance 6, RollOffMaxDistance 40 |
| `AmbientLobby` | `sounds/AmbientLobby.ogg` | 45.00 с · стерео · 826 КБ | Лобби у лечебницы: холодный низкий дрон с биениями, далёкий ветер со свистом, гул прожекторов, редкий далёкий металлический скрип. Стерео, петля 45 с. | Volume 0.35, Looped = true |
| `AmbientDay` | `sounds/AmbientDay.ogg` | 45.00 с · стерео · 854 КБ | Пригород днём: разные птицы (свисты, трели, щебет) на разных дистанциях, лёгкий ветерок с шелестом листвы, далёкий гул улицы и одна проезжающая машина. Стерео, петля 45 с. | Volume 0.35, Looped = true |
| `AmbientNight` | `sounds/AmbientNight.ogg` | 45.00 с · стерео · 1.2 МБ | Ночь во дворе: хор сверчков, далёкий лай собаки с эхом улицы, низкий тревожный дрон, слабый ветер. Стерео, петля 45 с. | Volume 0.35, Looped = true |
| `AmbientHouse` | `sounds/AmbientHouse.ogg` | 40.00 с · стерео · 615 КБ | Дом изнутри: гул холодильника (компрессор ~59 Гц с биениями 118/120 Гц, вентилятор), настенные часы «тик-так» 1 Гц, тихий фон комнаты, редкий скрип дома. Стерео, петля 40 с. | Volume 0.40, Looped = true |
| `Wind` | `sounds/Wind.ogg` | 40.00 с · стерео · 769 КБ | Порывистый ветер: низкий гул, «тело» с плавающим центром и свист щелей. Стерео, петля 40 с. | Volume 0.40, Looped = true |
| `Crickets` | `sounds/Crickets.ogg` | 30.00 с · стерео · 769 КБ | Хор сверчков с трелью древесного сверчка и тихим ночным фоном. Стерео, петля 30 с. | Volume 0.35, Looped = true |
| `Stinger` | `sounds/Stinger.ogg` | 5.01 с · моно · 28 КБ | Хоррор-удар: низкий медный кластер (ре–ми♭–ля♭–ля), суб-бум, «смычковый» металл, большой зал. | Volume 0.80 |
| `Dawn` | `sounds/Dawn.ogg` | 6.40 с · моно · 57 КБ | Рассвет: тёплый мажорный аккорд (ре add9) с плавной атакой, электропиано-арпеджио и пара птиц. | Volume 0.60 |
| `Win` | `sounds/Win.ogg` | 5.56 с · моно · 59 КБ | Победа: медная фанфара вверх по до мажору, литавры, тарелка и финальный аккорд. | Volume 0.70 |
| `Lose` | `sounds/Lose.ogg` | 4.81 с · моно · 31 КБ | Поражение: низкий колокол, хроматический спуск в миноре, «замедление ленты» в конце. | Volume 0.70 |
| `UiHover` | `sounds/UiHover.ogg` | 0.12 с · моно · 4 КБ | Наведение на кнопку: короткий мягкий «тик» 2 кГц. | Volume 0.25 |
| `UiClick` | `sounds/UiClick.ogg` | 0.10 с · моно · 5 КБ | Нажатие кнопки: пластиковый щелчок + короткий восходящий «блип». | Volume 0.40 |
| `Footstep` | `sounds/Footstep.ogg` | 0.49 с · моно · 8 КБ | Шаг ботинка по деревянному полу (пятка + носок, вариант 1). В Config есть только Footstep; остальные варианты — по желанию (случайный выбор). | Volume 0.45, RollOffMinDistance 5, RollOffMaxDistance 45, PlaybackSpeed 0.9–1.1 случайно |
| `Footstep2` | `sounds/Footstep2.ogg` | 0.56 с · моно · 8 КБ | Шаг ботинка по деревянному полу (пятка + носок, вариант 2). В Config есть только Footstep; остальные варианты — по желанию (случайный выбор). | Volume 0.45, RollOffMinDistance 5, RollOffMaxDistance 45, PlaybackSpeed 0.9–1.1 случайно |
| `Footstep3` | `sounds/Footstep3.ogg` | 0.54 с · моно · 8 КБ | Шаг ботинка по деревянному полу (пятка + носок, вариант 3). В Config есть только Footstep; остальные варианты — по желанию (случайный выбор). | Volume 0.45, RollOffMinDistance 5, RollOffMaxDistance 45, PlaybackSpeed 0.9–1.1 случайно |
| `Footstep4` | `sounds/Footstep4.ogg` | 0.51 с · моно · 8 КБ | Шаг ботинка по деревянному полу (пятка + носок, вариант 4). В Config есть только Footstep; остальные варианты — по желанию (случайный выбор). | Volume 0.45, RollOffMinDistance 5, RollOffMaxDistance 45, PlaybackSpeed 0.9–1.1 случайно |

Варианты `Footstep2…4` в `Config` нет — их можно добавить ключами `Footstep2`, `Footstep3`, `Footstep4` и выбирать случайно.

Готовая таблица громкостей (можно вставить в `Config.lua` и применять в `Sound.play`, если `props.Volume` не задан):

```lua
Config.SoundVolume = {
	EasTone = 0.70, EasNoise = 0.35, Static = 0.35, TvNews = 0.45, DoorOpen = 0.70, DoorClose = 0.70,
	DoorLock = 0.60, DoorBash = 0.90, DoorBreak = 1.00, GlassBreak = 0.90, FlashlightClick = 0.50, ApplePick = 0.60,
	Coin = 0.60, PowerDown = 0.80, PowerUp = 0.80, Fuse = 0.70, Shotgun = 1.00, Pepper = 0.60,
	Stun = 0.80, TrapSnap = 0.90, Heal = 0.55, Defib = 0.85, Jumpscare = 1.00, Heartbeat = 0.70,
	Breath = 0.50, Whisper = 0.60, AmbientLobby = 0.35, AmbientDay = 0.35, AmbientNight = 0.35, AmbientHouse = 0.40,
	Wind = 0.40, Crickets = 0.35, Stinger = 0.80, Dawn = 0.60, Win = 0.70, Lose = 0.70,
	UiHover = 0.25, UiClick = 0.40, Footstep = 0.45, Footstep2 = 0.45, Footstep3 = 0.45, Footstep4 = 0.45,
}
```

## Картинки (`assets/images`, PNG)

| Ключ Config | Файл | Размер | Описание | Рекомендуемые свойства |
|---|---|---|---|---|
| `WallpaperLiving` | `images/WallpaperLiving.png` | 1024×1024 RGB · 1.0 МБ | Обои гостиной: приглушённый пыльно-розовый дамаск 90-х, тон-в-тон, с «атласным» мотивом, вертикальной фактурой бумаги и лёгким пожелтением. | Texture, бесшовный: StudsPerTileU = 6, StudsPerTileV = 6 |
| `WallpaperBedroom` | `images/WallpaperBedroom.png` | 512×512 RGB · 336 КБ | Обои спальни: кремовая полоска тон-в-тон с тёмно-синими и бордовыми «пинстрайпами», неровности печати, фактура бумаги. | Texture, бесшовный: StudsPerTileU = 4, StudsPerTileV = 4 |
| `WallpaperKids` | `images/WallpaperKids.png` | 512×512 RGB · 378 КБ | Обои детской: выцветший голубой фон, звёзды, месяцы, кубики с буквами и мячики; лёгкий сдвиг печати, фактура бумаги. | Texture, бесшовный: StudsPerTileU = 5, StudsPerTileV = 5 |
| `KitchenTiles` | `images/KitchenTiles.png` | 512×512 RGB · 342 КБ | Линолеум кухни «шахматка» 4×4: кремовые и почти чёрные плитки с крошкой, грязь в швах, потёртости и чёрные следы каблуков. | Texture, бесшовный: StudsPerTileU = 4, StudsPerTileV = 4 |
| `BathTiles` | `images/BathTiles.png` | 512×512 RGB · 340 КБ | Мелкая квадратная керамическая плитка 8×8 (мятно-голубая глазурь) с затёртыми серыми швами, фасками, бликами и грязью в углах. | Texture, бесшовный: StudsPerTileU = 2, StudsPerTileV = 2 |
| `Carpet` | `images/Carpet.png` | 512×512 RGB · 537 КБ | Ковролин бежевый «builder beige»: плотный ворс, оттенки волокон, лёгкие пятна и примятости. | Texture, бесшовный: StudsPerTileU = 6, StudsPerTileV = 6 |
| `WoodFloor` | `images/WoodFloor.png` | 1024×1024 RGB · 1.1 МБ | Паркетная доска «золотой дуб»: 8 рядов досок со случайными стыками, кольца и волокна, щели, лак с потёртостями и царапинами. | Texture, бесшовный: StudsPerTileU = 8, StudsPerTileV = 8 |
| `Ceiling` | `images/Ceiling.png` | 512×512 RGB · 475 КБ | Потолок «попкорн»: бугристая белёсая штукатурка с тенями и лёгким пожелтением. | Texture, бесшовный: StudsPerTileU = 8, StudsPerTileV = 8 |
| `Siding` | `images/Siding.png` | 512×512 RGB · 296 КБ | Виниловый сайдинг «миндаль»: 8 горизонтальных досок с тенью под нахлёстом, тиснение под дерево, грязевые подтёки. Светлый — можно тонировать Texture.Color3. | Texture, бесшовный: StudsPerTileU = 6, StudsPerTileV = 6; Color3 для оттенка |
| `RoofShingles` | `images/RoofShingles.png` | 512×512 RGB · 520 КБ | Битумная черепица «3 лепестка»: 8 рядов со смещением, гранулы разных цветов, тени под кромкой, прорези, выгоревшие и тёмные лепестки, подтёки. | Texture, бесшовный: StudsPerTileU = 8, StudsPerTileV = 8 |
| `TvStatic` | `images/TvStatic.png` | 512×512 RGB · 615 КБ | ТВ-«снег» (бесшовно): зерно, горизонтальный смаз, строки развёртки, светлые/тёмные полосы. Для анимации сдвигайте OffsetStudsV/U или меняйте Rotation. | Texture, бесшовный: StudsPerTileU = 4, StudsPerTileV = 4; анимировать OffsetStudsU/V каждый кадр |
| `Vignette` | `images/Vignette.png` | 512×512 RGBA · 66 КБ | Виньетка: чёрный, прозрачный центр, тёмные края (альфа). Растянуть ImageLabel на весь экран. | ImageLabel на весь экран, BackgroundTransparency = 1, ScaleType = Stretch, ImageTransparency 0–0.3 |
| `Grain` | `images/Grain.png` | 512×512 RGBA · 328 КБ | Плёночное зерно (бесшовно, альфа): светлые и тёмные крупинки ~8% непрозрачности. ImageLabel с ScaleType = Tile, TileSize ~ 256 px, двигать каждый кадр. | ImageLabel на весь экран, BackgroundTransparency = 1, ScaleType = Tile, TileSize = UDim2.fromOffset(256, 256) |
| `EasLogo` | `images/EasLogo.png` | 1024×1024 RGBA · 296 КБ | Оригинальная эмблема «EAS»: круглый знак, синее кольцо с надписью EMERGENCY ALERT SYSTEM, янтарный диск с вышкой и радиоволнами, плашка EAS. Прозрачный фон. | Decal (или ImageLabel в SurfaceGui), квадратная грань |
| `BlackRidgeLogo` | `images/BlackRidgeLogo.png` | 1024×1024 RGBA · 1.0 МБ | Оригинальный герб лечебницы Black Ridge: щит (костяная глава с чёрным хребтом и месяцем, тёмное поле со скрещёнными ключами), лавры, лента CUSTODIA ET CURA, надписи. Потёртость, прозрачный фон. | Decal (или ImageLabel в SurfaceGui), квадратная грань |
| `Poster1` | `images/Poster1.png` | 512×1024 RGBA · 1.0 МБ | Плакат группы (ксерокс на кислотно-жёлтой бумаге): MOTH CIRCUS, растровая бабочка-моль, машинописные строки, «вырезанные» буквы, скотч и оторванный угол. Пропорция 1:2. | Decal на грань 2×4 (ширина×высота) студа, пропорция 1:2 |
| `Poster2` | `images/Poster2.png` | 512×1024 RGB · 658 КБ | Постер фильма ужасов 1996 г. «THE QUIET CUL-DE-SAC»: луна, силуэты домов с одним горящим окном, фигура под фонарём, слоган, титры. Сгибы, выцветание. Пропорция 1:2. | Decal на грань 2×4 (ширина×высота) студа, пропорция 1:2 |
| `Poster3` | `images/Poster3.png` | 512×1024 RGBA · 1.2 МБ | Листовка «LOST DOG»: ксерокопия с фото пса Бисквита, приметы, телефон 555-0143, награда, красная надпись маркером STILL MISSING, отрывные язычки (двух нет), скотч. Пропорция 1:2. | Decal на грань 2×4 (ширина×высота) студа, пропорция 1:2 |
| `FamilyPhoto` | `images/FamilyPhoto.png` | 512×512 RGB · 488 КБ | Семейное фото (живописное, размытое, без реальных людей): папа, мама и двое детей на заднем дворе у сайдинга, цвета плёнки 90-х, виньетка, засветка и оранжевая дата «96 7 14». | Decal на квадратную грань в рамке (например 2×2 студа) |

Итого: звуки 6.5 МБ, картинки 10.9 МБ.

## Заметки

- `EasTone`: настоящая структура сигнала EAS (заголовок AFSK 520.83 бод, 853+960 Гц ~8 с, три EOM), но байты заголовка случайные — реальные приёмники EAS его не распознают. Не транслируйте в эфир.
- `TvNews` ровно 16 тактов при 128 BPM (30 с): фанфара на «раз», дробь литавр в конце ведёт обратно в начало — можно зацикливать весь день. Тембр «из динамика ТВ», лучше вешать на корпус телевизора (3D).
- Амбиенты стерео: проигрывайте их в 2D (`Sound.loop(key, nil, ...)`, родитель — SoundService). Остальные звуки моно для 3D-позиционирования.
- Постеры 512×1024 (1:2): если грань другой пропорции, картинка растянется.
