-- tools/mock/gui.lua — выгрузка интерфейса игрока (ScreenGui, BillboardGui, экраны SurfaceGui на камере
-- и в мире)
-- в JSON для рендера поверх 3D-превью (tools/render/render.html, параметр g=...).
local mock = ...
local DATA = mock.DATA
local fmt = string.format

local function num(x) return fmt("%.4g", x) end
local function str(s) return '"' .. tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('[%c]', ' ') .. '"' end
local function col(c) return fmt("[%s,%s,%s]", num(c.R), num(c.G), num(c.B)) end
local function u2(u) return fmt("[%s,%s,%s,%s]", num(u.X.Scale), num(u.X.Offset), num(u.Y.Scale), num(u.Y.Offset)) end

local function fontOf(p)
	local f = p.FontFace
	if not f then return '{"f":"Montserrat","w":600,"i":false}' end
	local fam = tostring(f.Family):match("families/([%w]+)%.json") or "Montserrat"
	local W = { Thin = 100, ExtraLight = 200, Light = 300, Regular = 400, Medium = 500, SemiBold = 600, Bold = 700, ExtraBold = 800, Heavy = 900 }
	local w = W[f.Weight and f.Weight.Name or "Regular"] or 400
	return fmt('{"f":%s,"w":%d,"i":%s}', str(fam), w, (f.Style and f.Style.Name == "Italic") and "true" or "false")
end

local function seqColor(cs)
	local o = {}
	for _, k in ipairs(cs.Keypoints) do o[#o + 1] = fmt("[%s,%s,%s,%s]", num(k.Time), num(k.Value.R), num(k.Value.G), num(k.Value.B)) end
	return "[" .. table.concat(o, ",") .. "]"
end
local function seqNum(ns)
	local o = {}
	for _, k in ipairs(ns.Keypoints) do o[#o + 1] = fmt("[%s,%s]", num(k.Time), num(k.Value)) end
	return "[" .. table.concat(o, ",") .. "]"
end

local node
local function comps(inst)
	local o = {}
	for _, c in ipairs(inst:GetChildren()) do
		local cn = c.ClassName
		if cn == "UICorner" then o[#o + 1] = fmt('"corner":[%s,%s]', num(c.CornerRadius.Scale), num(c.CornerRadius.Offset))
		elseif cn == "UIStroke" and c.Enabled then
			o[#o + 1] = fmt('"stroke":{"c":%s,"t":%s,"tr":%s,"m":%s}', col(c.Color), num(c.Thickness), num(c.Transparency), str(c.ApplyStrokeMode.Name))
		elseif cn == "UIGradient" and c.Enabled then
			o[#o + 1] = fmt('"grad":{"c":%s,"t":%s,"r":%s}', seqColor(c.Color), seqNum(c.Transparency), num(c.Rotation))
		elseif cn == "UIPadding" then
			o[#o + 1] = fmt('"pad":[%s,%s,%s,%s]', num(c.PaddingLeft.Offset), num(c.PaddingTop.Offset), num(c.PaddingRight.Offset), num(c.PaddingBottom.Offset))
		elseif cn == "UIListLayout" then
			o[#o + 1] = fmt('"list":{"d":%s,"p":%s,"h":%s,"v":%s}', str(c.FillDirection.Name), num(c.Padding.Offset), str(c.HorizontalAlignment.Name), str(c.VerticalAlignment.Name))
		elseif cn == "UIScale" then o[#o + 1] = fmt('"scale":%s', num(c.Scale))
		end
	end
	return table.concat(o, ",")
end

function node(inst)
	local d = inst[DATA]
	local c = d.cls
	if not c.isa.GuiObject then return nil end
	local p = d.p
	if not p.Visible then return nil end
	local o = {
		fmt('"cls":%s', str(c.name)), fmt('"n":%s', str(p.Name)), fmt('"pos":%s', u2(p.Position)), fmt('"size":%s', u2(p.Size)),
		fmt('"ap":[%s,%s]', num(p.AnchorPoint.X), num(p.AnchorPoint.Y)), fmt('"rot":%s', num(p.Rotation)), fmt('"z":%d', p.ZIndex),
		fmt('"lo":%d', p.LayoutOrder), fmt('"bg":%s', col(p.BackgroundColor3)), fmt('"bgT":%s', num(p.BackgroundTransparency)),
		fmt('"clip":%s', p.ClipsDescendants and "true" or "false"), fmt('"auto":%s', str(p.AutomaticSize.Name)),
	}
	if c.isa.TextLabel or c.isa.TextButton or c.isa.TextBox then
		local text = p.Text
		local mvg = p.MaxVisibleGraphemes
		if mvg and mvg >= 0 then
			local out, i = {}, 0
			for _, cp in utf8.codes(text) do
				i = i + 1
				if i > mvg then break end
				out[#out + 1] = utf8.char(cp)
			end
			text = table.concat(out)
		end
		o[#o + 1] = fmt('"text":%s,"tc":%s,"tt":%s,"ts":%s,"sc":%s,"font":%s,"xa":%s,"ya":%s,"wrap":%s,"lh":%s', str(text), col(p.TextColor3),
			num(p.TextTransparency), num(p.TextSize), p.TextScaled and "true" or "false", fontOf(p), str(p.TextXAlignment.Name),
			str(p.TextYAlignment.Name), p.TextWrapped and "true" or "false", num(p.LineHeight or 1))
	end
	local cc = comps(inst)
	if cc ~= "" then o[#o + 1] = cc end
	local kids = {}
	for _, ch in ipairs(inst:GetChildren()) do
		local n = node(ch)
		if n then kids[#kids + 1] = n end
	end
	o[#o + 1] = '"kids":[' .. table.concat(kids, ",") .. ']'
	return "{" .. table.concat(o, ",") .. "}"
end

local plr = mock.services.Players:GetPlayers()[1]
local screens, bills, surfaces = {}, {}, {}
if plr then
	local pg = plr:FindFirstChild("PlayerGui")
	for _, g in ipairs(pg and pg:GetChildren() or {}) do
		if g.ClassName == "ScreenGui" and g.Enabled then
			local kids = {}
			for _, ch in ipairs(g:GetChildren()) do
				local n = node(ch)
				if n then kids[#kids + 1] = n end
			end
			screens[#screens + 1] = fmt('{"n":%s,"order":%d,"inset":%s,"kids":[%s]}', str(g.Name), g.DisplayOrder,
				g.IgnoreGuiInset and "false" or "true", table.concat(kids, ","))
		elseif g.ClassName == "BillboardGui" and g.Enabled then
			local ad = g.Adornee
			local pos
			if ad and ad:IsA("BasePart") then pos = ad.Position elseif ad and ad:IsA("Model") then pos = ad:GetPivot().Position end
			if pos then
				local kids = {}
				for _, ch in ipairs(g:GetChildren()) do
					local n = node(ch)
					if n then kids[#kids + 1] = n end
				end
				local so, sz = g.StudsOffset, g.Size
				bills[#bills + 1] = fmt('{"n":%s,"p":[%s,%s,%s],"so":[%s,%s,%s],"size":%s,"sizeOff":[%s,%s],"kids":[%s]}', str(g.Name),
					num(pos.X), num(pos.Y), num(pos.Z), num(so.X), num(so.Y), num(so.Z), u2(sz), num(g.SizeOffset.X), num(g.SizeOffset.Y), table.concat(kids, ","))
			end
		end
	end
	-- экраны на камере (телефон)
	local cam = mock.clientCtx(plr).camera
	if cam then
		for _, sg in ipairs(cam:GetDescendants()) do
			if sg.ClassName == "SurfaceGui" then
				local kids = {}
				for _, ch in ipairs(sg:GetChildren()) do
					local n = node(ch)
					if n then kids[#kids + 1] = n end
				end
				surfaces[#surfaces + 1] = fmt('{"n":%s,"w":%s,"h":%s,"kids":[%s]}', str(sg.Parent.Name), num(sg.CanvasSize.X), num(sg.CanvasSize.Y), table.concat(kids, ","))
			end
		end
	end
end
-- экраны SurfaceGui в мире (лаборатория, радар, вывески): полное дерево интерфейса
local worlds = {}
local function cf12(cf)
	local o = { cf:GetComponents() }
	for i, v in ipairs(o) do o[i] = num(v) end
	return "[" .. table.concat(o, ",") .. "]"
end
for _, sg in ipairs(mock.services.Workspace:GetDescendants()) do
	if sg.ClassName == "SurfaceGui" and sg.Enabled then
		local par = sg.Adornee or sg.Parent
		if par and par:IsA("BasePart") then
			local kids = {}
			for _, ch in ipairs(sg:GetChildren()) do
				local n = node(ch)
				if n then kids[#kids + 1] = n end
			end
			if #kids > 0 then
				local face = sg.Face.Name
				local sz = par.Size
				local fw, fh = sz.X, sz.Y
				if face == "Left" or face == "Right" then fw, fh = sz.Z, sz.Y elseif face == "Top" or face == "Bottom" then fw, fh = sz.X, sz.Z end
				local w, h
				if sg.SizingMode.Name == "FixedSize" then w, h = sg.CanvasSize.X, sg.CanvasSize.Y
				else w, h = fw * sg.PixelsPerStud, fh * sg.PixelsPerStud end
				worlds[#worlds + 1] = fmt('{"part":%s,"c":%s,"z":[%s,%s,%s],"face":%s,"w":%s,"h":%s,"li":%s,"kids":[%s]}', str(par.Name), cf12(par.CFrame),
					num(sz.X), num(sz.Y), num(sz.Z), str(face), num(w), num(h), num(sg.LightInfluence), table.concat(kids, ","))
			end
		end
	end
end
return fmt('{"screens":[%s],"bills":[%s],"surfaces":[%s],"worlds":[%s]}', table.concat(screens, ","), table.concat(bills, ","), table.concat(surfaces, ","), table.concat(worlds, ","))
