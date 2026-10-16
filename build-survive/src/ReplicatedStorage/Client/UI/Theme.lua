-- Цвета и шрифты интерфейса.
local Theme = {}

local FAMILY = "rbxasset://fonts/families/BuilderSans.json"
Theme.Font = Font.new(FAMILY, Enum.FontWeight.Bold)
Theme.FontHeavy = Font.new(FAMILY, Enum.FontWeight.Heavy)
Theme.FontMedium = Font.new(FAMILY, Enum.FontWeight.Medium)

Theme.Bg = Color3.fromRGB(12, 15, 24)
Theme.Panel = Color3.fromRGB(22, 27, 40)
Theme.Panel2 = Color3.fromRGB(32, 38, 56)
Theme.Panel3 = Color3.fromRGB(44, 52, 74)
Theme.Stroke = Color3.fromRGB(255, 255, 255)

Theme.Text = Color3.fromRGB(242, 245, 252)
Theme.Sub = Color3.fromRGB(150, 160, 186)
Theme.Muted = Color3.fromRGB(96, 104, 128)

Theme.Accent = Color3.fromRGB(255, 186, 48)
Theme.Accent2 = Color3.fromRGB(255, 122, 40)
Theme.Good = Color3.fromRGB(72, 214, 126)
Theme.Bad = Color3.fromRGB(240, 70, 70)
Theme.Info = Color3.fromRGB(86, 168, 255)
Theme.Purple = Color3.fromRGB(160, 110, 255)
Theme.Gold = Color3.fromRGB(255, 206, 64)

-- редкость блоков в магазине (зависит от цены)
Theme.RarityCommon = Color3.fromRGB(158, 166, 186)
Theme.RarityUncommon = Color3.fromRGB(86, 214, 104)
Theme.RarityRare = Color3.fromRGB(64, 156, 255)
Theme.RarityEpic = Color3.fromRGB(178, 92, 255)
Theme.RarityLegendary = Color3.fromRGB(255, 184, 40)

Theme.PanelTransparency = 0.08
Theme.Radius = UDim.new(0, 14)

return Theme
