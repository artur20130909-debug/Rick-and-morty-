-- Оформление интерфейса: шрифты, цвета и конструкторы элементов
local Theme = {}

Theme.Black = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
Theme.BlackItalic = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
Theme.Bold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
Theme.Medium = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal)

Theme.Panel = Color3.fromRGB(14, 14, 20)
Theme.Panel2 = Color3.fromRGB(26, 26, 36)
Theme.Line = Color3.fromRGB(70, 70, 90)
Theme.Text = Color3.fromRGB(245, 245, 250)
Theme.Dim = Color3.fromRGB(160, 162, 176)
Theme.Good = Color3.fromRGB(90, 230, 130)
Theme.Bad = Color3.fromRGB(255, 80, 80)
Theme.Gold = Color3.fromRGB(255, 214, 92)
Theme.Accent = Color3.fromRGB(255, 92, 51)

local function apply(inst, props)
	for k, v in pairs(props) do
		if k ~= "Parent" and k ~= "Children" then inst[k] = v end
	end
	if props.Children then
		for _, c in ipairs(props.Children) do c.Parent = inst end
	end
	if props.Parent then inst.Parent = props.Parent end
	return inst
end
Theme.apply = apply

function Theme.frame(props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Theme.Panel
	return apply(f, props)
end

function Theme.label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.TextColor3 = Theme.Text
	l.FontFace = Theme.Bold
	l.TextSize = 16
	l.Text = ""
	return apply(l, props)
end

function Theme.button(props)
	local b = Instance.new("TextButton")
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.BackgroundColor3 = Theme.Panel2
	b.TextColor3 = Theme.Text
	b.FontFace = Theme.Black
	b.TextSize = 18
	b.Text = ""
	return apply(b, props)
end

function Theme.corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = parent
	return c
end

function Theme.stroke(parent, color, thick, transp)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Line
	s.Thickness = thick or 1.5
	s.Transparency = transp or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Theme.textStroke(parent, thick)
	local s = Instance.new("UIStroke")
	s.Color = Color3.new(0, 0, 0)
	s.Thickness = thick or 1.5
	s.Transparency = 0.25
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
	return s
end

function Theme.gradient(parent, c0, c1, rot, t0, t1)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c0, c1 or c0)
	g.Rotation = rot or 0
	if t0 or t1 then
		g.Transparency = NumberSequence.new(t0 or 0, t1 or 0)
	end
	g.Parent = parent
	return g
end

function Theme.padding(parent, px)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = parent
	return p
end

function Theme.list(parent, dir, pad, halign, valign)
	local l = Instance.new("UIListLayout")
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, pad or 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if halign then l.HorizontalAlignment = halign end
	if valign then l.VerticalAlignment = valign end
	l.Parent = parent
	return l
end

-- тёмнее/светлее
function Theme.shade(c, k)
	if k >= 0 then return c:Lerp(Color3.new(1, 1, 1), k) end
	return c:Lerp(Color3.new(0, 0, 0), -k)
end

return Theme
