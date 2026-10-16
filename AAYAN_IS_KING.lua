--[[
	ALPHA EMPIRE AI
	MADE BY AAYAN
	Discord: https://discord.gg/reKZEKjE2

	ONE standalone Luau script for a Roblox executor. The whole GUI is created with
	Instance.new() - nothing needs to exist beforehand.

	SECTIONS
	  1. Services + capability detection
	  2. Theme + helpers
	  3. Settings / storage
	  4. HTTP + ScriptBlox parsing
	  5. GUI (window, tabs, loading screen)
	  6. Search page (results, details, pagination, refresh, thumbnails, copy)
	  7. About page (branding + Discord)
	  8. Settings page (configurable endpoints)
	  9. Layout / window controls / startup

	SAFETY
	  Retrieved scripts are DISPLAY-ONLY text. They can be copied to the clipboard, but
	  this script never executes, loads, or loadstring()s anything returned by an API.
	  No authentication or access control is bypassed.
]]

-- =====================================================================
-- 1. SERVICES + CAPABILITY DETECTION
-- =====================================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local GUI_NAME = "AlphaEmpireAI"
local BRAND = "ALPHA EMPIRE AI"
local MADE_BY = "MADE BY AAYAN"
local DISCORD_URL = "https://discord.gg/reKZEKjE2"
local DISCORD_CODE = "reKZEKjE2"
local VERSION = "1.1"

local function firstFunction(...)
	for i = 1, select("#", ...) do
		local f = select(i, ...)
		if type(f) == "function" then
			return f
		end
	end
	return nil
end

local httpRequest = firstFunction(
	syn and syn.request,
	http_request,
	request,
	http and http.request,
	fluxus and fluxus.request
)
local clipboardFn = firstFunction(setclipboard, toclipboard, Clipboard and Clipboard.set, syn and syn.write_clipboard)
local assetFn = firstFunction(getcustomasset, getsynasset)

local caps = {
	http = httpRequest ~= nil,
	clipboard = clipboardFn ~= nil,
	files = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function",
	hiddenUi = type(gethui) == "function",
}
caps.thumbs = caps.http and caps.files and assetFn ~= nil

local FOLDER = "AlphaEmpireAI"
local SETTINGS_FILE = FOLDER .. "/settings.json"

-- =====================================================================
-- 2. THEME + HELPERS
-- =====================================================================
local C = {
	bg = Color3.fromRGB(9, 9, 13),
	panel = Color3.fromRGB(16, 16, 22),
	card = Color3.fromRGB(23, 23, 31),
	input = Color3.fromRGB(30, 30, 40),
	text = Color3.fromRGB(240, 240, 246),
	muted = Color3.fromRGB(146, 146, 164),
	cyan = Color3.fromRGB(0, 229, 255),
	purple = Color3.fromRGB(145, 80, 255),
	discord = Color3.fromRGB(88, 101, 242),
	red = Color3.fromRGB(255, 80, 98),
	amber = Color3.fromRGB(255, 190, 60),
	green = Color3.fromRGB(70, 235, 140),
	line = Color3.fromRGB(44, 44, 58),
}
local FONT = Enum.Font.Gotham
local FONT_MED = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

local connections = {}
local unloaded = false
local function track(conn)
	connections[#connections + 1] = conn
	return conn
end

local function create(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(parent, r)
	return create("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

local function stroke(parent, color, thickness, transparency)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function padding(parent, l, t, r, b)
	return create("UIPadding", {
		PaddingLeft = UDim.new(0, l),
		PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, b),
	}, parent)
end

local function label(parent, props)
	local p = {
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 14,
		TextColor3 = C.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = false,
	}
	for k, v in pairs(props) do
		p[k] = v
	end
	return create("TextLabel", p, parent)
end

local function tween(inst, time, props, style, dir)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function button(parent, text, bg, fg, props)
	local p = {
		BackgroundColor3 = bg,
		TextColor3 = fg,
		Font = FONT_BOLD,
		TextSize = 13,
		Text = text,
		AutoButtonColor = false,
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	local b = create("TextButton", p, parent)
	corner(b, 10)
	local base = bg
	b.MouseEnter:Connect(function()
		tween(b, 0.15, { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.15) })
	end)
	b.MouseLeave:Connect(function()
		tween(b, 0.15, { BackgroundColor3 = base })
	end)
	b.MouseButton1Down:Connect(function()
		tween(b, 0.08, { BackgroundColor3 = base:Lerp(Color3.new(0, 0, 0), 0.2) })
	end)
	b.MouseButton1Up:Connect(function()
		tween(b, 0.12, { BackgroundColor3 = base })
	end)
	return b
end

local function trim(s)
	return (s:match("^%s*(.-)%s*$")) or ""
end

-- Converts any value to a safe, length-limited string (third-party data is untrusted).
local function clean(value, maxLen, default)
	if type(value) == "number" then
		value = tostring(value)
	end
	if type(value) ~= "string" then
		return default
	end
	value = value:gsub("[%z\1-\8\11\12\14-\31\127]", "")
	if not utf8.len(value) then
		value = value:gsub("[\128-\255]", "?")
	end
	local len = utf8.len(value) or #value
	if len > maxLen then
		local cut = utf8.offset(value, maxLen + 1)
		value = value:sub(1, (cut or (#value + 1)) - 1) .. "..."
	end
	if value:match("^%s*$") then
		return default
	end
	return value
end

local function formatNumber(n)
	n = math.floor(tonumber(n) or 0)
	local formatted = tostring(n)
	while true do
		local replaced, count = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = replaced
		if count == 0 then
			break
		end
	end
	return formatted
end

local function formatDate(iso)
	if type(iso) ~= "string" or iso == "" then
		return "Unknown"
	end
	local ok, result = pcall(function()
		return DateTime.fromIsoDate(iso):FormatUniversalTime("MMM D, YYYY", "en-us")
	end)
	if ok and type(result) == "string" then
		return result
	end
	return iso:sub(1, 10)
end

local function decodeJson(text)
	if type(text) ~= "string" then
		return nil
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(text)
	end)
	if ok then
		return data
	end
	return nil
end

-- =====================================================================
-- 3. SETTINGS / STORAGE
-- =====================================================================
local DEFAULTS = {
	searchUrl = "https://scriptblox.com/api/script/search",
	imageBase = "https://scriptblox.com",
}
local settings = { searchUrl = DEFAULTS.searchUrl, imageBase = DEFAULTS.imageBase }

local function readJson(path)
	if not caps.files then
		return nil
	end
	local ok, raw = pcall(function()
		if isfile(path) then
			return readfile(path)
		end
		return nil
	end)
	if not ok or type(raw) ~= "string" then
		return nil
	end
	local data = decodeJson(raw)
	if type(data) == "table" then
		return data
	end
	return nil
end

local function ensureFolder()
	pcall(function()
		if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(FOLDER) then
			makefolder(FOLDER)
		end
	end)
end

local function saveSettings()
	if not caps.files then
		return false
	end
	local ok = pcall(function()
		ensureFolder()
		writefile(SETTINGS_FILE, HttpService:JSONEncode(settings))
	end)
	return ok
end

local function validUrl(u)
	return type(u) == "string" and u:match("^https://[%w%-%.]+") ~= nil and #u <= 200
end

do
	local saved = readJson(SETTINGS_FILE)
	if saved then
		if validUrl(saved.searchUrl) then
			settings.searchUrl = saved.searchUrl
		end
		if validUrl(saved.imageBase) then
			settings.imageBase = saved.imageBase
		end
	end
end

-- =====================================================================
-- 4. HTTP + SCRIPTBLOX PARSING
-- =====================================================================
local function httpCall(opts)
	if not httpRequest then
		return false, "This executor does not provide an HTTP request function."
	end
	local ok, res = pcall(httpRequest, opts)
	if not ok then
		return false, tostring(res)
	end
	if type(res) ~= "table" then
		return false, "The executor returned an invalid HTTP response."
	end
	local code = tonumber(res.StatusCode or res.status_code or res.Status or res.status) or 0
	local body = res.Body or res.body
	if type(body) ~= "string" then
		body = ""
	end
	return true, { code = code, body = body }
end

local function resolveImage(v)
	if type(v) ~= "string" or v == "" then
		return ""
	end
	v = v:gsub("%s", "")
	if #v > 300 then
		return ""
	end
	if v:match("^https://") then
		return v
	end
	if v:sub(1, 1) == "/" then
		return (settings.imageBase:gsub("/+$", "")) .. v
	end
	return ""
end

local MAX_SCRIPT_TEXT = 400000

local function parseSearch(body, page)
	local decoded = decodeJson(body)
	if type(decoded) ~= "table" then
		return nil, "ScriptBlox returned an unreadable (malformed) response."
	end
	local result = decoded.result
	if type(result) ~= "table" then
		return nil, "The ScriptBlox response had an unexpected format."
	end
	local scripts = result.scripts
	if scripts == nil then
		scripts = {}
	end
	if type(scripts) ~= "table" then
		return nil, "The ScriptBlox response had an unexpected format."
	end
	local items = {}
	for _, s in ipairs(scripts) do
		if type(s) == "table" then
			local g = type(s.game) == "table" and s.game or {}
			local o = type(s.owner) == "table" and s.owner or {}
			local slug = clean(s.slug, 120, "")
			slug = slug:gsub("[^%w%-%._]", "")
			local scriptText = nil
			if type(s.script) == "string" and #s.script > 0 then
				scriptText = s.script:sub(1, MAX_SCRIPT_TEXT)
			end
			local image = resolveImage(s.image)
			if image == "" then
				image = resolveImage(g.imageUrl)
			end
			items[#items + 1] = {
				id = clean(s._id, 64, ""),
				slug = slug,
				title = clean(s.title, 120, "Untitled script"),
				gameName = clean(g.name, 120, s.isUniversal == true and "Universal" or "Unknown game"),
				gameId = clean(g.gameId, 20, "N/A"),
				description = clean(s.description, 600, nil) or clean(s.features, 600, nil) or "No description provided.",
				views = tonumber(s.views) or 0,
				verified = s.verified == true,
				patched = s.isPatched == true,
				universal = s.isUniversal == true,
				hasKey = s.key == true,
				scriptType = clean(s.scriptType, 20, "unknown"),
				updatedAt = clean(s.updatedAt, 40, ""),
				createdAt = clean(s.createdAt, 40, ""),
				creator = clean(o.username, 60, "Unknown"),
				creatorVerified = o.verified == true,
				imageUrl = image,
				scriptText = scriptText,
			}
		end
	end
	local totalPages = tonumber(result.totalPages) or 1
	totalPages = math.clamp(math.floor(totalPages), 1, 200)
	return { items = items, page = page, totalPages = totalPages }
end

-- =====================================================================
-- 5. GUI ROOT, WINDOW, TABS, LOADING SCREEN
-- =====================================================================
local function getGuiParent()
	if caps.hiddenUi then
		local ok, h = pcall(gethui)
		if ok and typeof(h) == "Instance" then
			return h
		end
	end
	local ok, cg = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok and cg then
		local test = Instance.new("ScreenGui")
		local ok2 = pcall(function()
			test.Parent = cg
		end)
		pcall(function()
			test:Destroy()
		end)
		if ok2 then
			return cg
		end
	end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local guiParent = getGuiParent()
for _, p in ipairs({ guiParent, LocalPlayer:FindFirstChild("PlayerGui") }) do
	pcall(function()
		local old = p:FindFirstChild(GUI_NAME)
		if old then
			old:Destroy()
		end
	end)
end

local gui = create("ScreenGui", {
	Name = GUI_NAME,
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 1000,
}, nil)
gui.Parent = guiParent

local function viewport()
	local cam = workspace.CurrentCamera
	if cam then
		return cam.ViewportSize
	end
	return Vector2.new(1280, 720)
end

local TOP_H, TAB_H = 50, 42

local window = create("CanvasGroup", {
	Name = "Window",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(760, 520),
	BackgroundColor3 = C.bg,
	GroupTransparency = 1,
	Visible = false,
}, gui)
corner(window, 18)
local windowStroke = stroke(window, C.purple, 1.5, 0.3)
local windowScale = create("UIScale", { Scale = 0.85 }, window)

-- ---- Top bar ----
local topBar = create("Frame", {
	Name = "TopBar",
	Size = UDim2.new(1, 0, 0, TOP_H),
	BackgroundColor3 = C.panel,
	BorderSizePixel = 0,
}, window)

local logo = create("Frame", {
	Position = UDim2.fromOffset(12, 11),
	Size = UDim2.fromOffset(28, 28),
	BackgroundColor3 = C.cyan,
}, topBar)
corner(logo, 8)
create("UIGradient", { Color = ColorSequence.new(C.cyan, C.purple), Rotation = 45 }, logo)
label(logo, {
	Size = UDim2.fromScale(1, 1),
	Text = "A",
	Font = FONT_BOLD,
	TextSize = 16,
	TextColor3 = Color3.new(0, 0, 0),
	TextXAlignment = Enum.TextXAlignment.Center,
})
local titleLabel = label(topBar, {
	Position = UDim2.fromOffset(50, 5),
	Size = UDim2.new(1, -160, 0, 22),
	Text = BRAND,
	Font = FONT_BOLD,
	TextSize = 17,
	TextTruncate = Enum.TextTruncate.AtEnd,
})
create("UIGradient", { Color = ColorSequence.new(C.cyan, C.purple) }, titleLabel)
label(topBar, {
	Position = UDim2.fromOffset(50, 27),
	Size = UDim2.new(1, -160, 0, 16),
	Text = MADE_BY,
	Font = FONT_BOLD,
	TextSize = 10,
	TextColor3 = C.muted,
	TextTruncate = Enum.TextTruncate.AtEnd,
})

local closeBtn = button(topBar, "X", C.input, C.red, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -10, 0.5, 0),
	Size = UDim2.fromOffset(32, 32),
})
local maxBtn = button(topBar, "", C.input, C.green, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -48, 0.5, 0),
	Size = UDim2.fromOffset(32, 32),
})
-- maximize icon drawn with frames (a hollow square)
local maxIcon = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(12, 12),
	BackgroundTransparency = 1,
}, maxBtn)
stroke(maxIcon, C.green, 2, 0)
local minBtn = button(topBar, "-", C.input, C.amber, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -86, 0.5, 0),
	Size = UDim2.fromOffset(32, 32),
	TextSize = 18,
})

-- ---- Tab bar ----
local tabBar = create("Frame", {
	Name = "TabBar",
	Position = UDim2.fromOffset(0, TOP_H),
	Size = UDim2.new(1, 0, 0, TAB_H),
	BackgroundColor3 = C.bg,
	BorderSizePixel = 0,
}, window)
create("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = C.line,
	BorderSizePixel = 0,
}, tabBar)
local tabIndicator = create("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, 0),
	Size = UDim2.fromOffset(80, 2),
	BackgroundColor3 = C.cyan,
	BorderSizePixel = 0,
	ZIndex = 3,
}, tabBar)
local tabNames = { "search", "about", "settings" }
local tabTitles = { search = "Search", about = "About", settings = "Settings" }
local tabButtons = {}
for _, name in ipairs(tabNames) do
	tabButtons[name] = create("TextButton", {
		Name = name .. "Tab",
		Size = UDim2.fromOffset(80, TAB_H - 4),
		BackgroundTransparency = 1,
		Text = tabTitles[name],
		Font = FONT_BOLD,
		TextSize = 13,
		TextColor3 = C.muted,
		AutoButtonColor = false,
	}, tabBar)
end

-- Discord button (icon drawn in code; label hidden on narrow screens)
local discordBtn = create("TextButton", {
	Name = "DiscordButton",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, -1),
	Size = UDim2.fromOffset(168, 30),
	BackgroundColor3 = C.discord,
	Text = "",
	AutoButtonColor = false,
}, tabBar)
corner(discordBtn, 10)
local function drawDiscordIcon(parent, size)
	local icon = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, parent)
	corner(icon, math.floor(size / 3))
	local eyeSize = math.max(3, math.floor(size / 5))
	for i = 1, 2 do
		local eye = create("Frame", {
			Position = UDim2.fromOffset(
				math.floor(size * 0.26) + (i - 1) * math.floor(size * 0.32),
				math.floor(size * 0.38)
			),
			Size = UDim2.fromOffset(eyeSize, math.floor(eyeSize * 1.5)),
			BackgroundColor3 = C.discord,
		}, icon)
		corner(eye, eyeSize)
	end
	return icon
end
local discordIcon = drawDiscordIcon(discordBtn, 20)
local discordText = label(discordBtn, {
	Position = UDim2.fromOffset(32, 0),
	Size = UDim2.new(1, -36, 1, 0),
	Text = "JOIN ALPHA EMPIRE",
	Font = FONT_BOLD,
	TextSize = 11,
	TextColor3 = Color3.new(1, 1, 1),
	TextTruncate = Enum.TextTruncate.AtEnd,
})
discordBtn.MouseEnter:Connect(function()
	tween(discordBtn, 0.15, { BackgroundColor3 = C.discord:Lerp(Color3.new(1, 1, 1), 0.15) })
end)
discordBtn.MouseLeave:Connect(function()
	tween(discordBtn, 0.15, { BackgroundColor3 = C.discord })
end)

-- ---- Body ----
local area = create("Frame", {
	Name = "Area",
	Position = UDim2.fromOffset(0, TOP_H + TAB_H),
	Size = UDim2.new(1, 0, 1, -(TOP_H + TAB_H)),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
}, window)
local searchPage = create("Frame", { Name = "SearchPage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, area)
local aboutPage = create("Frame", { Name = "AboutPage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, area)
local settingsPage = create("Frame", { Name = "SettingsPage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, area)

-- ---- Toast (branded notifications) ----
local toast = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 40),
	Size = UDim2.new(0.82, 0, 0, 46),
	BackgroundColor3 = C.card,
	BackgroundTransparency = 1,
	ZIndex = 50,
	Visible = false,
}, window)
corner(toast, 12)
local toastStroke = stroke(toast, C.cyan, 1.5, 1)
local toastBrand = label(toast, {
	Position = UDim2.fromOffset(12, 5),
	Size = UDim2.new(1, -24, 0, 12),
	Text = BRAND,
	Font = FONT_BOLD,
	TextSize = 9,
	TextColor3 = C.cyan,
	TextTransparency = 1,
	ZIndex = 51,
})
local toastLabel = label(toast, {
	Position = UDim2.fromOffset(12, 18),
	Size = UDim2.new(1, -24, 0, 22),
	Text = "",
	Font = FONT_MED,
	TextSize = 13,
	TextTransparency = 1,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 51,
})
local toastToken = 0
local function notify(text, kind)
	toastToken = toastToken + 1
	local my = toastToken
	local color = C.cyan
	if kind == "error" then
		color = C.red
	elseif kind == "warn" then
		color = C.amber
	end
	toast.Visible = true
	toastLabel.Text = text
	toastStroke.Color = color
	toastBrand.TextColor3 = color
	toast.Position = UDim2.new(0.5, 0, 0, 34)
	tween(toast, 0.25, { BackgroundTransparency = 0.03, Position = UDim2.new(0.5, 0, 0, 60) })
	tween(toastStroke, 0.25, { Transparency = 0 })
	tween(toastLabel, 0.25, { TextTransparency = 0 })
	tween(toastBrand, 0.25, { TextTransparency = 0 })
	task.delay(3, function()
		if my ~= toastToken or unloaded then
			return
		end
		tween(toast, 0.3, { BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, 44) })
		tween(toastStroke, 0.3, { Transparency = 1 })
		tween(toastLabel, 0.3, { TextTransparency = 1 })
		tween(toastBrand, 0.3, { TextTransparency = 1 })
		task.delay(0.32, function()
			if my == toastToken and not unloaded then
				toast.Visible = false
			end
		end)
	end)
end

-- ---- Launcher (reopen after close) ----
local launcher = button(gui, "A", C.cyan, Color3.new(0, 0, 0), {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -16),
	Size = UDim2.fromOffset(52, 52),
	TextSize = 22,
	Visible = false,
})
corner(launcher, 26)
create("UIGradient", { Color = ColorSequence.new(C.cyan, C.purple), Rotation = 45 }, launcher)
stroke(launcher, C.purple, 2, 0.2)

-- ---- Loading screen ----
local splash = create("CanvasGroup", {
	Name = "Splash",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.bg,
	ZIndex = 100,
}, window)
local splashLogo = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, -80),
	Size = UDim2.fromOffset(72, 72),
	BackgroundColor3 = C.cyan,
	ZIndex = 101,
}, splash)
corner(splashLogo, 22)
create("UIGradient", { Color = ColorSequence.new(C.cyan, C.purple), Rotation = 45 }, splashLogo)
label(splashLogo, {
	Size = UDim2.fromScale(1, 1),
	Text = "A",
	Font = FONT_BOLD,
	TextSize = 38,
	TextColor3 = Color3.new(0, 0, 0),
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 102,
})
local splashTitle = label(splash, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.5, -34),
	Size = UDim2.new(1, -20, 0, 30),
	Text = BRAND,
	Font = FONT_BOLD,
	TextSize = 24,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 101,
})
create("UIGradient", { Color = ColorSequence.new(C.cyan, C.purple) }, splashTitle)
label(splash, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.5, -2),
	Size = UDim2.new(1, -20, 0, 18),
	Text = MADE_BY,
	Font = FONT_BOLD,
	TextSize = 12,
	TextColor3 = C.muted,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 101,
})
local barTrack = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.5, 34),
	Size = UDim2.new(0.6, 0, 0, 6),
	BackgroundColor3 = C.input,
	ZIndex = 101,
}, splash)
corner(barTrack, 3)
create("UISizeConstraint", { MaxSize = Vector2.new(280, 6), MinSize = Vector2.new(140, 6) }, barTrack)
local barFill = create("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = C.cyan,
	ZIndex = 102,
}, barTrack)
corner(barFill, 3)
create("UIGradient", { Color = ColorSequence.new(C.cyan, C.purple) }, barFill)
local splashStatus = label(splash, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.5, 48),
	Size = UDim2.new(1, -20, 0, 18),
	Text = "Starting...",
	TextSize = 11,
	TextColor3 = C.muted,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 101,
})

-- =====================================================================
-- Shared state + forward declarations
-- =====================================================================
local state = {
	tab = "search",
	minimized = false,
	maximized = false,
	open = false,
	wide = true,
}
local applyLayout, switchTab, showDetails

local function copyText(text, btn, okLabel)
	if not clipboardFn then
		notify("Clipboard is not supported by this executor.", "warn")
		return false
	end
	local ok = pcall(clipboardFn, text)
	if ok then
		notify(okLabel or "Copied to clipboard.")
		if btn then
			local old = btn.Text
			btn.Text = "Copied!"
			task.delay(1.3, function()
				if btn.Parent then
					btn.Text = old
				end
			end)
		end
		return true
	end
	notify("Copy failed.", "error")
	return false
end

-- Discord: try the local Discord client (RPC); fall back to clipboard; else show the link.
local discordBusy = false
local function joinDiscord()
	if discordBusy then
		return
	end
	discordBusy = true
	local function fallback()
		if clipboardFn and pcall(clipboardFn, DISCORD_URL) then
			notify("Could not open Discord automatically. Invite link copied!", "warn")
		else
			notify("Opening links is unsupported here. Invite: discord.gg/" .. DISCORD_CODE, "warn")
		end
	end
	task.spawn(function()
		local opened = false
		if httpRequest then
			local ok, res = httpCall({
				Url = "http://127.0.0.1:6463/rpc?v=1",
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json", ["Origin"] = "https://discord.com" },
				Body = HttpService:JSONEncode({
					cmd = "INVITE_BROWSER",
					args = { code = DISCORD_CODE },
					nonce = HttpService:GenerateGUID(false),
				}),
			})
			opened = ok and res.code >= 200 and res.code < 300
		end
		if not unloaded then
			if opened then
				notify("Opening the ALPHA EMPIRE Discord invite...")
			else
				fallback()
			end
		end
		discordBusy = false
	end)
end
track(discordBtn.MouseButton1Click:Connect(joinDiscord))

-- =====================================================================
-- 6. SEARCH PAGE
-- =====================================================================
local PER_PAGE = 10
local sState = { query = "", page = 1, totalPages = 1, items = {}, loading = false, view = "empty", lastRequest = 0, reqId = 0, imgGen = 0 }
local sCache = {}
local sCacheCount = 0

local searchRow = create("Frame", {
	Position = UDim2.fromOffset(10, 8),
	Size = UDim2.new(1, -20, 0, 40),
	BackgroundTransparency = 1,
}, searchPage)
local searchBox = create("TextBox", {
	Name = "SearchBox",
	Size = UDim2.new(1, -(76 + 52 + 12), 1, 0),
	BackgroundColor3 = C.input,
	TextColor3 = C.text,
	PlaceholderText = "Search scripts (e.g. obby)",
	PlaceholderColor3 = C.muted,
	Text = "",
	Font = FONT_MED,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = false,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, searchRow)
corner(searchBox, 10)
local searchStroke = stroke(searchBox, C.line, 1)
padding(searchBox, 12, 0, 12, 0)
local searchBtn = button(searchRow, "Search", C.cyan, Color3.new(0, 0, 0), {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -58, 0, 0),
	Size = UDim2.new(0, 76, 1, 0),
})
local clearSearchBtn = button(searchRow, "Clear", C.input, C.text, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.new(0, 52, 1, 0),
})
stroke(clearSearchBtn, C.line, 1)
track(searchBox.Focused:Connect(function()
	tween(searchStroke, 0.2, { Color = C.purple })
end))
track(searchBox.FocusLost:Connect(function()
	tween(searchStroke, 0.2, { Color = C.line })
end))

local sStatusRow = create("Frame", {
	Position = UDim2.fromOffset(10, 52),
	Size = UDim2.new(1, -20, 0, 22),
	BackgroundTransparency = 1,
}, searchPage)
local counterLabel = label(sStatusRow, {
	Size = UDim2.new(1, -130, 1, 0),
	Text = "Ready",
	TextSize = 12,
	TextColor3 = C.muted,
	TextTruncate = Enum.TextTruncate.AtEnd,
})
local refreshBtn = button(sStatusRow, "Refresh", C.input, C.cyan, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, 0, 0.5, 0),
	Size = UDim2.fromOffset(64, 22),
	TextSize = 11,
})
local dotsHolder = create("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -74, 0.5, 0),
	Size = UDim2.fromOffset(40, 10),
	BackgroundTransparency = 1,
	Visible = false,
}, sStatusRow)
local sDots = {}
for i = 1, 3 do
	local d = create("Frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.fromOffset((i - 1) * 14, 1),
		BackgroundColor3 = i == 2 and C.purple or C.cyan,
	}, dotsHolder)
	corner(d, 4)
	sDots[i] = d
end

local sContent = create("Frame", {
	Position = UDim2.fromOffset(10, 78),
	Size = UDim2.new(1, -20, 1, -78 - 66),
	BackgroundTransparency = 1,
}, searchPage)

local function makeScroll(name, parent)
	local s = create("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.purple,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
	}, parent)
	create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, s)
	padding(s, 0, 0, 6, 8)
	return s
end
local resultsScroll = makeScroll("Results", sContent)
local detailsScroll = makeScroll("Details", sContent)

local sMessage = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, sContent)
local sMessageTitle = label(sMessage, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.new(1, -20, 0, 26),
	Text = "Search Roblox scripts",
	Font = FONT_BOLD,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Center,
})
local sMessageSub = label(sMessage, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.4, 20),
	Size = UDim2.new(1, -30, 0, 56),
	Text = "Type a keyword above and press Search.",
	TextSize = 13,
	TextColor3 = C.muted,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextXAlignment = Enum.TextXAlignment.Center,
})
local retryBtn = button(sMessage, "Retry", C.purple, C.text, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.4, 80),
	Size = UDim2.fromOffset(100, 34),
	Visible = false,
})

local pageRow = create("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 10, 1, -30),
	Size = UDim2.new(1, -20, 0, 34),
	BackgroundTransparency = 1,
	Visible = false,
}, searchPage)
local prevBtn = button(pageRow, "< Prev", C.input, C.text, { Size = UDim2.new(0, 84, 1, 0) })
stroke(prevBtn, C.line, 1)
local nextBtn = button(pageRow, "Next >", C.input, C.text, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.new(0, 84, 1, 0),
})
stroke(nextBtn, C.line, 1)
local pageLabel = label(pageRow, {
	Position = UDim2.new(0, 90, 0, 0),
	Size = UDim2.new(1, -180, 1, 0),
	Text = "Page 1 / 1",
	Font = FONT_MED,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Center,
})

local detailRow = create("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 10, 1, -30),
	Size = UDim2.new(1, -20, 0, 34),
	BackgroundTransparency = 1,
	Visible = false,
}, searchPage)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, detailRow)
local backBtn = button(detailRow, "< Back", C.input, C.cyan, { LayoutOrder = 1, Size = UDim2.new(0.26, -4, 1, 0) })
stroke(backBtn, C.cyan, 1, 0.5)
local detailViewBtn = button(detailRow, "View script", C.input, C.cyan, { LayoutOrder = 2, Size = UDim2.new(0.37, -4, 1, 0) })
stroke(detailViewBtn, C.cyan, 1, 0.5)
local detailCopyBtn = button(detailRow, "Copy script", C.purple, C.text, { LayoutOrder = 3, Size = UDim2.new(0.37, -4, 1, 0) })

-- ---- Script viewer widgets (display only; logic is defined further below) ----
local viewerFrame = create("Frame", {
	Name = "Viewer",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
}, sContent)
local viewerTitle = label(viewerFrame, {
	Position = UDim2.fromOffset(2, 0),
	Size = UDim2.new(1, -72, 0, 18),
	Text = "",
	Font = FONT_BOLD,
	TextSize = 13,
	TextColor3 = C.cyan,
	TextTruncate = Enum.TextTruncate.AtEnd,
})
local viewerInfo = label(viewerFrame, {
	Position = UDim2.fromOffset(2, 18),
	Size = UDim2.new(1, -72, 0, 16),
	Text = "",
	TextSize = 11,
	TextColor3 = C.muted,
	TextTruncate = Enum.TextTruncate.AtEnd,
})
local sizeMinusBtn = button(viewerFrame, "A-", C.input, C.text, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -34, 0, 4),
	Size = UDim2.fromOffset(30, 26),
	TextSize = 11,
})
local sizePlusBtn = button(viewerFrame, "A+", C.input, C.text, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 4),
	Size = UDim2.fromOffset(30, 26),
	TextSize = 11,
})
local codeBox = create("Frame", {
	Position = UDim2.fromOffset(0, 38),
	Size = UDim2.new(1, 0, 1, -38),
	BackgroundColor3 = Color3.fromRGB(7, 7, 10),
}, viewerFrame)
corner(codeBox, 10)
stroke(codeBox, C.line, 1)
local codeScroll = create("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = C.purple,
	AutomaticCanvasSize = Enum.AutomaticSize.XY,
	CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.XY,
}, codeBox)
padding(codeScroll, 8, 8, 8, 8)
local codeRow = create("Frame", {
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.new(0, 0, 0, 0),
	BackgroundTransparency = 1,
}, codeScroll)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, codeRow)
local numLabel = label(codeRow, {
	LayoutOrder = 1,
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.new(0, 0, 0, 0),
	Text = "",
	Font = Enum.Font.Code,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(95, 95, 118),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = false,
})
local codeLabel = label(codeRow, {
	LayoutOrder = 2,
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.new(0, 0, 0, 0),
	Text = "",
	RichText = true,
	Font = Enum.Font.Code,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(230, 230, 236),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = false,
})

local viewerRow = create("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 10, 1, -30),
	Size = UDim2.new(1, -20, 0, 34),
	BackgroundTransparency = 1,
	Visible = false,
}, searchPage)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, viewerRow)
local viewBackBtn = button(viewerRow, "< Back", C.input, C.cyan, { LayoutOrder = 1, Size = UDim2.new(0.25, -5, 1, 0) })
stroke(viewBackBtn, C.cyan, 1, 0.5)
local viewPrevBtn = button(viewerRow, "< Prev", C.input, C.text, { LayoutOrder = 2, Size = UDim2.new(0.25, -5, 1, 0) })
stroke(viewPrevBtn, C.line, 1)
local viewNextBtn = button(viewerRow, "Next >", C.input, C.text, { LayoutOrder = 3, Size = UDim2.new(0.25, -5, 1, 0) })
stroke(viewNextBtn, C.line, 1)
local viewCopyBtn = button(viewerRow, "Copy", C.purple, C.text, { LayoutOrder = 4, Size = UDim2.new(0.25, -5, 1, 0) })

label(searchPage, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 10, 1, -6),
	Size = UDim2.new(1, -20, 0, 20),
	Text = "Powered by ScriptBlox.com  \226\128\162  " .. MADE_BY,
	TextSize = 11,
	TextColor3 = C.muted,
	TextXAlignment = Enum.TextXAlignment.Center,
})

local function setSearchLoading(on)
	sState.loading = on
	dotsHolder.Visible = on
	if on then
		counterLabel.Text = "Searching ScriptBlox..."
		task.spawn(function()
			local t = 0
			while sState.loading and not unloaded do
				t = t + RunService.Heartbeat:Wait()
				for i, d in ipairs(sDots) do
					local wave = 0.5 + 0.5 * math.sin(t * 7 - i * 0.9)
					d.BackgroundTransparency = 1 - wave
				end
			end
		end)
	end
end

local currentDetail = nil
local function setSearchView(view, title, sub, showRetry)
	sState.view = view
	resultsScroll.Visible = view == "results"
	detailsScroll.Visible = view == "details"
	sMessage.Visible = view == "empty" or view == "message"
	pageRow.Visible = view == "results" and sState.totalPages > 1
	detailRow.Visible = view == "details"
	viewerFrame.Visible = view == "viewer"
	viewerRow.Visible = view == "viewer"
	retryBtn.Visible = showRetry == true
	if title then
		sMessageTitle.Text = title
	end
	if sub then
		sMessageSub.Text = sub
	end
end

local function clearList(scroll)
	for _, child in ipairs(scroll:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

-- ---- Thumbnails (only when the executor can turn downloaded files into assets) ----
local imgCache = {}
local imgJobs = {}
local imgActive = 0

local function urlHash(s)
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + s:byte(i)) % 4294967296
	end
	return string.format("%08x", h)
end

local function fetchImageAsset(url)
	if imgCache[url] ~= nil then
		return imgCache[url]
	end
	local ok, res = httpCall({ Url = url, Method = "GET" })
	if not ok or res.code < 200 or res.code >= 300 or #res.body < 100 or #res.body > 2000000 then
		imgCache[url] = false
		return false
	end
	local b = res.body
	local ext
	if b:sub(1, 4) == "\137PNG" then
		ext = "png"
	elseif b:sub(1, 2) == "\255\216" then
		ext = "jpg"
	else
		imgCache[url] = false -- unsupported format (e.g. webp)
		return false
	end
	local path = FOLDER .. "/img_" .. urlHash(url) .. "." .. ext
	local wrote = pcall(function()
		ensureFolder()
		writefile(path, b)
	end)
	if not wrote then
		imgCache[url] = false
		return false
	end
	local okA, asset = pcall(assetFn, path)
	if okA and type(asset) == "string" and asset ~= "" then
		imgCache[url] = asset
		return asset
	end
	imgCache[url] = false
	return false
end

local function pumpImages()
	while imgActive < 2 and #imgJobs > 0 do
		local job = table.remove(imgJobs, 1)
		imgActive = imgActive + 1
		task.spawn(function()
			if not unloaded and job.gen == sState.imgGen and job.img.Parent then
				local asset = fetchImageAsset(job.url)
				if asset and job.img.Parent then
					job.img.Image = asset
					job.img.ImageTransparency = 1
					tween(job.img, 0.3, { ImageTransparency = 0 })
				end
			end
			imgActive = imgActive - 1
			if not unloaded then
				pumpImages()
			end
		end)
	end
end

local function thumbnail(parent, item, size)
	local frame = create("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = C.input }, parent)
	corner(frame, 10)
	create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(42, 42, 58), Color3.fromRGB(28, 22, 50)),
		Rotation = 45,
	}, frame)
	local initial = (item.gameName or "?"):sub(1, 1):upper()
	if initial == "" then
		initial = "?"
	end
	label(frame, {
		Size = UDim2.fromScale(1, 1),
		Text = initial,
		Font = FONT_BOLD,
		TextSize = math.floor(size * 0.4),
		TextColor3 = C.purple,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	if caps.thumbs and item.imageUrl ~= "" then
		local img = create("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = "",
			ScaleType = Enum.ScaleType.Crop,
			ImageTransparency = 0,
		}, frame)
		corner(img, 10)
		imgJobs[#imgJobs + 1] = { url = item.imageUrl, img = img, gen = sState.imgGen }
		pumpImages()
	end
	return frame
end

local function badge(parent, text, color, order)
	local b = create("TextLabel", {
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.82,
		Text = text,
		TextColor3 = color,
		Font = FONT_BOLD,
		TextSize = 11,
		RichText = false,
	}, parent)
	corner(b, 6)
	padding(b, 8, 0, 8, 0)
	return b
end

local function copyScript(item, btn)
	if not item.scriptText then
		notify("ScriptBlox did not include the script text for this result.", "warn")
		return
	end
	copyText(item.scriptText, btn, "Script copied. It is NOT executed by this app.")
end

-- =====================================================================
-- Script viewer (DISPLAY ONLY): clear, colored, line-numbered, scrollable, resizable text.
-- Nothing here ever runs the script.
-- =====================================================================
local VIEW_LINES_PER_PAGE = 120
local VIEW_WRAP = 200 -- very long (e.g. minified) lines are wrapped so they stay readable
local VIEW_COLOR_LIMIT = 120000 -- bigger scripts are shown without colors to stay fast

local function esc(t)
	t = t:gsub("&", "&amp;")
	t = t:gsub("<", "&lt;")
	t = t:gsub(">", "&gt;")
	return t
end

local HL_KEYWORDS = {}
for _, w in ipairs({
	"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in",
	"local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
}) do
	HL_KEYWORDS[w] = true
end
local HL_BUILTINS = {}
for _, w in ipairs({
	"print", "warn", "error", "pcall", "xpcall", "pairs", "ipairs", "next", "select", "tostring",
	"tonumber", "type", "typeof", "require", "game", "workspace", "script", "task", "wait", "spawn",
	"delay", "Instance", "Vector2", "Vector3", "CFrame", "Color3", "UDim", "UDim2", "Enum", "TweenInfo",
	"math", "string", "table", "os", "coroutine", "utf8", "bit32", "setmetatable", "getmetatable",
	"rawget", "rawset", "assert", "unpack", "tick", "time", "Random", "Ray", "Rect", "BrickColor",
}) do
	HL_BUILTINS[w] = true
end
local HLC = {
	keyword = "#c792ff",
	string = "#7ee787",
	number = "#ffb86b",
	comment = "#6b7280",
	builtin = "#7dd3fc",
}

-- Adds a colored token; tokens that span lines are closed/reopened per line.
local function pushToken(out, text, color)
	local start = 1
	while true do
		local nlPos = text:find("\n", start, true)
		local piece = text:sub(start, (nlPos or (#text + 1)) - 1)
		if piece ~= "" then
			piece = esc(piece)
			if color then
				out[#out + 1] = '<font color="' .. color .. '">' .. piece .. "</font>"
			else
				out[#out + 1] = piece
			end
		end
		if not nlPos then
			break
		end
		out[#out + 1] = "\n"
		start = nlPos + 1
	end
end

-- Returns an array of RichText lines (one entry per source line).
local function highlightToLines(src)
	local out = {}
	local i, n = 1, #src
	while i <= n do
		local c = src:sub(i, i)
		if src:sub(i, i + 1) == "--" then
			local eq = src:match("^%-%-%[(=*)%[", i)
			if eq then
				local close = "]" .. eq .. "]"
				local _, e = src:find(close, i + 4 + #eq, true)
				e = e or n
				pushToken(out, src:sub(i, e), HLC.comment)
				i = e + 1
			else
				local e = src:find("\n", i, true) or (n + 1)
				pushToken(out, src:sub(i, e - 1), HLC.comment)
				i = e
			end
		elseif c == '"' or c == "'" or c == "`" then
			local j = i + 1
			while j <= n do
				local ch = src:sub(j, j)
				if ch == "\\" then
					j = j + 2
				elseif ch == c or ch == "\n" then
					break
				else
					j = j + 1
				end
			end
			local e = math.min(j, n)
			pushToken(out, src:sub(i, e), HLC.string)
			i = e + 1
		elseif c == "[" and src:match("^%[(=*)%[", i) then
			local eq = src:match("^%[(=*)%[", i)
			local close = "]" .. eq .. "]"
			local _, e = src:find(close, i + 2 + #eq, true)
			e = e or n
			pushToken(out, src:sub(i, e), HLC.string)
			i = e + 1
		elseif c:match("%d") or (c == "." and src:sub(i + 1, i + 1):match("%d")) then
			local m = src:match("^0[xX]%x+", i)
				or src:match("^%d+%.?%d*[eE][+-]?%d+", i)
				or src:match("^%d+%.?%d*", i)
				or src:match("^%.%d+", i)
				or c
			pushToken(out, m, HLC.number)
			i = i + #m
		elseif c:match("[%a_]") then
			local word = src:match("^[%a_][%w_]*", i)
			if HL_KEYWORDS[word] then
				pushToken(out, word, HLC.keyword)
			elseif HL_BUILTINS[word] then
				pushToken(out, word, HLC.builtin)
			else
				pushToken(out, word, nil)
			end
			i = i + #word
		else
			local run = src:match("^[^%w_\"'`%-%[%.]+", i)
			if run then
				pushToken(out, run, nil)
				i = i + #run
			else
				pushToken(out, c, nil)
				i = i + 1
			end
		end
	end
	local joined = table.concat(out)
	local lines = {}
	for line in (joined .. "\n"):gmatch("(.-)\n") do
		lines[#lines + 1] = line
	end
	return lines
end

-- Splits the script into display lines (wrapping very long ones) + a line-number column.
local function prepareLines(src)
	src = src:gsub("\r\n", "\n")
	src = src:gsub("\r", "\n")
	src = src:gsub("\t", "    ")
	local out, nums = {}, {}
	local k = 0
	for line in (src .. "\n"):gmatch("(.-)\n") do
		k = k + 1
		if #line <= VIEW_WRAP then
			out[#out + 1] = line
			nums[#nums + 1] = tostring(k)
		else
			local pos = 1
			while pos <= #line do
				local e = math.min(#line, pos + VIEW_WRAP - 1)
				while e > pos and (line:byte(e + 1) or 0) >= 128 and (line:byte(e + 1) or 0) < 192 do
					e = e - 1 -- never cut a multi-byte character in half
				end
				out[#out + 1] = line:sub(pos, e)
				nums[#nums + 1] = pos == 1 and tostring(k) or ""
				pos = e + 1
			end
		end
	end
	return out, nums
end

local viewer = { item = nil, lines = {}, nums = {}, page = 1, pages = 1, size = 13, plain = false, returnView = "results" }

local function applyViewerSize()
	viewer.size = math.clamp(viewer.size, 9, 22)
	numLabel.TextSize = viewer.size
	codeLabel.TextSize = viewer.size
end

local function renderViewerPage()
	local total = #viewer.lines
	local a = (viewer.page - 1) * VIEW_LINES_PER_PAGE + 1
	local b = math.min(total, viewer.page * VIEW_LINES_PER_PAGE)
	codeLabel.Text = table.concat(viewer.lines, "\n", a, b)
	numLabel.Text = table.concat(viewer.nums, "\n", a, b)
	viewerInfo.Text = string.format(
		"Lines %s-%s of %s  \226\128\162  Page %d/%d%s",
		formatNumber(a),
		formatNumber(b),
		formatNumber(total),
		viewer.page,
		viewer.pages,
		viewer.plain and "  \226\128\162  colors off (large script)" or ""
	)
	viewPrevBtn.TextTransparency = viewer.page > 1 and 0 or 0.6
	viewNextBtn.TextTransparency = viewer.page < viewer.pages and 0 or 0.6
	codeScroll.CanvasPosition = Vector2.new(0, 0)
end

local function openViewer(item)
	if not item or not item.scriptText then
		notify("ScriptBlox did not include the script text for this result.", "warn")
		return
	end
	if not item.viewLines then
		local src = item.scriptText
		if not utf8.len(src) then
			src = src:gsub("[\128-\255]", "?")
		end
		local prepared, nums = prepareLines(src)
		local plain = #src > VIEW_COLOR_LIMIT
		local lines = nil
		if not plain then
			lines = highlightToLines(table.concat(prepared, "\n"))
			if #lines ~= #prepared then
				lines = nil
				plain = true
			end
		end
		if not lines then
			lines = {}
			for idx, l in ipairs(prepared) do
				lines[idx] = esc(l)
			end
		end
		item.viewLines, item.viewNums, item.viewPlain = lines, nums, plain
	end
	viewer.item = item
	viewer.lines = item.viewLines
	viewer.nums = item.viewNums
	viewer.plain = item.viewPlain
	viewer.page = 1
	viewer.pages = math.max(1, math.ceil(#viewer.lines / VIEW_LINES_PER_PAGE))
	viewer.returnView = (sState.view == "details") and "details" or "results"
	viewerTitle.Text = item.title
	applyViewerSize()
	renderViewerPage()
	setSearchView("viewer")
end

track(sizeMinusBtn.MouseButton1Click:Connect(function()
	viewer.size = viewer.size - 1
	applyViewerSize()
end))
track(sizePlusBtn.MouseButton1Click:Connect(function()
	viewer.size = viewer.size + 1
	applyViewerSize()
end))
track(viewPrevBtn.MouseButton1Click:Connect(function()
	if viewer.page > 1 then
		viewer.page = viewer.page - 1
		renderViewerPage()
	else
		notify("You're at the start of the script.", "warn")
	end
end))
track(viewNextBtn.MouseButton1Click:Connect(function()
	if viewer.page < viewer.pages then
		viewer.page = viewer.page + 1
		renderViewerPage()
	else
		notify("You're at the end of the script.", "warn")
	end
end))
track(viewBackBtn.MouseButton1Click:Connect(function()
	setSearchView(viewer.returnView)
end))
track(viewCopyBtn.MouseButton1Click:Connect(function()
	if viewer.item then
		copyScript(viewer.item, viewCopyBtn)
	end
end))

local function buildCard(item, index)
	local card = create("Frame", {
		Name = "Card" .. index,
		LayoutOrder = index,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = C.card,
		BackgroundTransparency = 1,
	}, resultsScroll)
	corner(card, 14)
	local cs = stroke(card, C.line, 1, 1)
	padding(card, 12, 12, 12, 12)
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, card)
	task.delay(math.min(index, 8) * 0.04, function()
		if card.Parent then
			tween(card, 0.35, { BackgroundTransparency = 0 })
			tween(cs, 0.35, { Transparency = 0 })
		end
	end)

	local top = create("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1 }, card)
	thumbnail(top, item, 56)
	label(top, {
		Position = UDim2.fromOffset(66, 2),
		Size = UDim2.new(1, -66, 0, 22),
		Text = item.title,
		Font = FONT_BOLD,
		TextSize = 15,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	label(top, {
		Position = UDim2.fromOffset(66, 24),
		Size = UDim2.new(1, -66, 0, 16),
		Text = "Game: " .. item.gameName,
		TextSize = 12,
		TextColor3 = C.cyan,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	label(top, {
		Position = UDim2.fromOffset(66, 40),
		Size = UDim2.new(1, -66, 0, 16),
		Text = "By: " .. item.creator .. "   \226\128\162   ID: " .. item.gameId,
		TextSize = 11,
		TextColor3 = C.muted,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local badges = create("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1 }, card)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, badges)
	badge(badges, item.verified and "VERIFIED" or "UNVERIFIED", item.verified and C.cyan or C.muted, 1)
	if item.patched then
		badge(badges, "PATCHED", C.red, 2)
	end
	if item.hasKey then
		badge(badges, "KEY", C.amber, 3)
	end
	if item.universal then
		badge(badges, "UNIVERSAL", C.purple, 4)
	end

	label(card, {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 52),
		Text = item.description,
		TextSize = 12,
		TextColor3 = C.muted,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	label(card, {
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 16),
		Text = string.format("Views: %s   \226\128\162   Updated: %s", formatNumber(item.views), formatDate(item.updatedAt)),
		TextSize = 11,
		TextColor3 = C.muted,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local btnRow = create("Frame", { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 }, card)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, btnRow)
	local detailsBtn = button(btnRow, "Details", C.purple, C.text, { LayoutOrder = 1, Size = UDim2.new(0.34, -4, 1, 0) })
	local viewBtn = button(btnRow, "View", C.input, item.scriptText and C.cyan or C.muted, { LayoutOrder = 2, Size = UDim2.new(0.3, -4, 1, 0) })
	stroke(viewBtn, C.line, 1)
	local copyBtn = button(btnRow, "Copy", C.input, item.scriptText and C.cyan or C.muted, { LayoutOrder = 3, Size = UDim2.new(0.36, -4, 1, 0) })
	stroke(copyBtn, C.line, 1)
	detailsBtn.MouseButton1Click:Connect(function()
		showDetails(item)
	end)
	viewBtn.MouseButton1Click:Connect(function()
		openViewer(item)
	end)
	copyBtn.MouseButton1Click:Connect(function()
		copyScript(item, copyBtn)
	end)
end

local function addDetailRow(order, key, value, valueColor, mono)
	local row = create("Frame", {
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = C.card,
	}, detailsScroll)
	corner(row, 12)
	padding(row, 12, 8, 12, 8)
	create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	label(row, {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 14),
		Text = string.upper(key),
		Font = FONT_BOLD,
		TextSize = 10,
		TextColor3 = C.muted,
	})
	label(row, {
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Text = value,
		Font = mono and Enum.Font.Code or FONT_MED,
		TextSize = mono and 12 or 13,
		TextColor3 = valueColor or C.text,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
end

function showDetails(item)
	currentDetail = item
	clearList(detailsScroll)
	local head = create("Frame", {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 84),
		BackgroundTransparency = 1,
	}, detailsScroll)
	thumbnail(head, item, 80)
	label(head, {
		Position = UDim2.fromOffset(90, 8),
		Size = UDim2.new(1, -90, 0, 64),
		Text = item.title,
		Font = FONT_BOLD,
		TextSize = 16,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	addDetailRow(1, "Game", item.gameName, C.cyan)
	addDetailRow(2, "Game ID", item.gameId)
	addDetailRow(3, "Description", item.description)
	addDetailRow(4, "Views", formatNumber(item.views))
	addDetailRow(5, "Verification", item.verified and "Verified" or "Not verified", item.verified and C.cyan or C.muted)
	addDetailRow(6, "Status", item.patched and "Marked as patched" or "Not marked as patched", item.patched and C.red or C.text)
	addDetailRow(7, "Key system", item.hasKey and "Requires a key" or "No key required")
	addDetailRow(8, "Script type", item.scriptType)
	addDetailRow(9, "Last updated", formatDate(item.updatedAt))
	addDetailRow(10, "Created", formatDate(item.createdAt))
	addDetailRow(11, "Creator", item.creator .. (item.creatorVerified and "  (verified)" or ""))
	addDetailRow(12, "ScriptBlox ID", item.id ~= "" and item.id or "Unavailable", C.muted)
	if item.scriptText then
		local preview = item.scriptText:sub(1, 700)
		if #item.scriptText > 700 then
			preview = preview .. "\n... (" .. formatNumber(#item.scriptText) .. " characters total - use Copy script)"
		end
		addDetailRow(13, "Script preview (display only)", preview, Color3.fromRGB(215, 215, 225), true)
	else
		addDetailRow(13, "Script text", "ScriptBlox did not include the script text for this result.", C.amber)
	end
	addDetailRow(14, "Safety note", "ALPHA EMPIRE AI only displays and copies text. It never runs scripts. Treat all third-party scripts as untrusted.", C.amber)
	detailCopyBtn.TextColor3 = item.scriptText and C.text or C.muted
	detailViewBtn.TextColor3 = item.scriptText and C.cyan or C.muted
	detailsScroll.CanvasPosition = Vector2.new(0, 0)
	setSearchView("details")
end

local function updatePagination()
	pageLabel.Text = string.format("Page %d / %d", sState.page, sState.totalPages)
	prevBtn.TextTransparency = sState.page > 1 and 0 or 0.6
	nextBtn.TextTransparency = sState.page < sState.totalPages and 0 or 0.6
end

-- Network fetch (runs in its own thread; never blocks the UI)
local function fetchSearch(query, page, force)
	local key = settings.searchUrl .. "|" .. query:lower() .. "|" .. page
	local cached = sCache[key]
	if cached and not force and os.clock() - cached.t < 60 then
		return true, cached.data
	end
	local sep = settings.searchUrl:find("?", 1, true) and "&" or "?"
	local url = string.format("%s%sq=%s&page=%d&max=%d", settings.searchUrl, sep, HttpService:UrlEncode(query), page, PER_PAGE)
	local ok, res = httpCall({ Url = url, Method = "GET", Headers = { ["Accept"] = "application/json" } })
	if not ok then
		return false, "Network error: could not reach ScriptBlox."
	end
	if res.code == 429 then
		return false, "ScriptBlox is rate limiting requests. Wait a moment and press Retry."
	end
	if res.code < 200 or res.code >= 300 then
		return false, "ScriptBlox returned an error (HTTP " .. tostring(res.code) .. ")."
	end
	local parsed, err = parseSearch(res.body, page)
	if not parsed then
		return false, err
	end
	if not cached then
		sCacheCount = sCacheCount + 1
	end
	if sCacheCount > 60 then
		sCache = {}
		sCacheCount = 1
	end
	sCache[key] = { t = os.clock(), data = parsed }
	return true, parsed
end

local function doSearch(query, page, force)
	if sState.loading then
		notify("Please wait, search in progress.", "warn")
		return
	end
	query = trim(tostring(query or ""))
	query = query:gsub("%s+", " ")
	if query == "" then
		notify("Type something to search for.", "warn")
		return
	end
	if utf8.len(query) == nil then
		notify("Search contains invalid characters.", "warn")
		return
	end
	if #query > 50 then
		notify("Search is too long (max 50 characters).", "warn")
		return
	end
	if not caps.http then
		setSearchView("message", "No HTTP support", "This executor does not provide an HTTP request function, so ScriptBlox cannot be reached.", false)
		notify("HTTP is not available in this executor.", "error")
		return
	end
	if os.clock() - sState.lastRequest < 1.5 then
		notify("You're searching too fast. Wait a moment.", "warn")
		return
	end
	sState.lastRequest = os.clock()
	sState.query = query
	sState.reqId = sState.reqId + 1
	local myId = sState.reqId
	setSearchLoading(true)

	-- timeout watchdog (executor HTTP functions have no timeout parameter)
	task.delay(25, function()
		if not unloaded and sState.loading and sState.reqId == myId then
			sState.reqId = sState.reqId + 1 -- discard the late response
			setSearchLoading(false)
			counterLabel.Text = "Timed out"
			setSearchView("message", "Request timed out", "ScriptBlox did not answer in time. Press Retry.", true)
			notify("Search timed out.", "error")
		end
	end)

	task.spawn(function()
		local ok, result = fetchSearch(query, page, force)
		if unloaded or sState.reqId ~= myId then
			return
		end
		setSearchLoading(false)
		if not ok then
			counterLabel.Text = "Error"
			notify(tostring(result), "error")
			setSearchView("message", "Something went wrong", tostring(result), true)
			return
		end
		sState.page = result.page
		sState.totalPages = result.totalPages
		sState.items = result.items
		sState.imgGen = sState.imgGen + 1
		imgJobs = {}
		if #sState.items == 0 then
			counterLabel.Text = "0 results"
			setSearchView("message", "No results found", 'Nothing matched "' .. query .. '". Try a different keyword.', false)
			pageRow.Visible = false
			notify("No results found.", "warn")
			return
		end
		counterLabel.Text = string.format("%d results  \226\128\162  Page %d of %d", #sState.items, sState.page, sState.totalPages)
		clearList(resultsScroll)
		for i, item in ipairs(sState.items) do
			buildCard(item, i)
		end
		resultsScroll.CanvasPosition = Vector2.new(0, 0)
		updatePagination()
		setSearchView("results")
		notify("Found " .. #sState.items .. " scripts.")
	end)
end

track(searchBtn.MouseButton1Click:Connect(function()
	doSearch(searchBox.Text, 1, false)
end))
track(searchBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		doSearch(searchBox.Text, 1, false)
	end
end))
track(clearSearchBtn.MouseButton1Click:Connect(function()
	searchBox.Text = ""
	sState.query = ""
	sState.page = 1
	sState.totalPages = 1
	sState.items = {}
	sState.imgGen = sState.imgGen + 1
	imgJobs = {}
	clearList(resultsScroll)
	clearList(detailsScroll)
	counterLabel.Text = "Ready"
	setSearchView("empty", "Search Roblox scripts", "Type a keyword above and press Search.", false)
	notify("Cleared.")
end))
track(refreshBtn.MouseButton1Click:Connect(function()
	if sState.query == "" then
		notify("Nothing to refresh yet. Search first.", "warn")
		return
	end
	doSearch(sState.query, sState.page, true)
end))
track(retryBtn.MouseButton1Click:Connect(function()
	doSearch(sState.query ~= "" and sState.query or searchBox.Text, sState.page, true)
end))
track(prevBtn.MouseButton1Click:Connect(function()
	if sState.page > 1 then
		doSearch(sState.query, sState.page - 1, false)
	else
		notify("You're on the first page.", "warn")
	end
end))
track(nextBtn.MouseButton1Click:Connect(function()
	if sState.page < sState.totalPages then
		doSearch(sState.query, sState.page + 1, false)
	else
		notify("You're on the last page.", "warn")
	end
end))
track(backBtn.MouseButton1Click:Connect(function()
	if #sState.items > 0 then
		setSearchView("results")
	else
		setSearchView("empty", "Search Roblox scripts", "Type a keyword above and press Search.", false)
	end
end))
track(detailCopyBtn.MouseButton1Click:Connect(function()
	if currentDetail then
		copyScript(currentDetail, detailCopyBtn)
	end
end))
track(detailViewBtn.MouseButton1Click:Connect(function()
	if currentDetail then
		openViewer(currentDetail)
	end
end))

-- =====================================================================
-- 7. ABOUT PAGE (branding + Discord)
-- =====================================================================
local aboutScroll = create("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.purple,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
}, aboutPage)
create("UIListLayout", {
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, aboutScroll)
padding(aboutScroll, 14, 18, 16, 16)

local aLogo = create("Frame", { LayoutOrder = 1, Size = UDim2.fromOffset(64, 64), BackgroundColor3 = C.cyan }, aboutScroll)
corner(aLogo, 20)
create("UIGradient", { Color = ColorSequence.new(C.cyan, C.purple), Rotation = 45 }, aLogo)
label(aLogo, {
	Size = UDim2.fromScale(1, 1),
	Text = "A",
	Font = FONT_BOLD,
	TextSize = 34,
	TextColor3 = Color3.new(0, 0, 0),
	TextXAlignment = Enum.TextXAlignment.Center,
})
local aTitle = label(aboutScroll, {
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 30),
	Text = BRAND,
	Font = FONT_BOLD,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Center,
})
create("UIGradient", { Color = ColorSequence.new(C.cyan, C.purple) }, aTitle)
label(aboutScroll, {
	LayoutOrder = 3,
	Size = UDim2.new(1, 0, 0, 16),
	Text = MADE_BY .. "  \226\128\162  v" .. VERSION,
	Font = FONT_BOLD,
	TextSize = 12,
	TextColor3 = C.muted,
	TextXAlignment = Enum.TextXAlignment.Center,
})
label(aboutScroll, {
	LayoutOrder = 4,
	AutomaticSize = Enum.AutomaticSize.Y,
	Size = UDim2.new(1, 0, 0, 0),
	Text = "Search Roblox scripts through ScriptBlox from inside the game. Results show metadata, thumbnails (when your executor supports it), a clear line-numbered script viewer, and a Copy button for script text. Nothing retrieved is ever executed by this app.",
	TextSize = 13,
	TextColor3 = C.muted,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Top,
})
local aboutDiscord = create("TextButton", {
	LayoutOrder = 5,
	Size = UDim2.new(1, 0, 0, 44),
	BackgroundColor3 = C.discord,
	Text = "",
	AutoButtonColor = false,
}, aboutScroll)
corner(aboutDiscord, 12)
drawDiscordIcon(aboutDiscord, 26)
label(aboutDiscord, {
	Position = UDim2.fromOffset(44, 0),
	Size = UDim2.new(1, -52, 1, 0),
	Text = "JOIN ALPHA EMPIRE",
	Font = FONT_BOLD,
	TextSize = 14,
	TextColor3 = Color3.new(1, 1, 1),
})
aboutDiscord.MouseEnter:Connect(function()
	tween(aboutDiscord, 0.15, { BackgroundColor3 = C.discord:Lerp(Color3.new(1, 1, 1), 0.15) })
end)
aboutDiscord.MouseLeave:Connect(function()
	tween(aboutDiscord, 0.15, { BackgroundColor3 = C.discord })
end)
track(aboutDiscord.MouseButton1Click:Connect(joinDiscord))

local inviteBox = create("TextBox", {
	LayoutOrder = 6,
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundColor3 = C.input,
	TextColor3 = C.cyan,
	Text = DISCORD_URL,
	Font = FONT_MED,
	TextSize = 13,
	ClearTextOnFocus = false,
	TextEditable = false,
}, aboutScroll)
corner(inviteBox, 10)
stroke(inviteBox, C.line, 1)
local copyInviteBtn = button(aboutScroll, "Copy invite link", C.input, C.text, {
	LayoutOrder = 7,
	Size = UDim2.new(1, 0, 0, 34),
})
stroke(copyInviteBtn, C.line, 1)
track(copyInviteBtn.MouseButton1Click:Connect(function()
	copyText(DISCORD_URL, copyInviteBtn, "Discord invite copied.")
end))
label(aboutScroll, {
	LayoutOrder = 8,
	Size = UDim2.new(1, 0, 0, 18),
	Text = "Powered by ScriptBlox.com",
	TextSize = 11,
	TextColor3 = C.muted,
	TextXAlignment = Enum.TextXAlignment.Center,
})

-- =====================================================================
-- 8. SETTINGS PAGE (configurable endpoints + capability report)
-- =====================================================================
local setScroll = create("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.purple,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
}, settingsPage)
create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, setScroll)
padding(setScroll, 12, 10, 14, 14)

local function section(order, titleText)
	local f = create("Frame", {
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = C.card,
	}, setScroll)
	corner(f, 14)
	stroke(f, C.line, 1, 0.3)
	padding(f, 14, 12, 14, 14)
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, f)
	label(f, {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 18),
		Text = titleText,
		Font = FONT_BOLD,
		TextSize = 14,
		TextColor3 = C.cyan,
	})
	return f
end
local function note(parent, order, text, color)
	return label(parent, {
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Text = text,
		TextSize = 12,
		TextColor3 = color or C.muted,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
end
local function textField(parent, order, placeholder, initial)
	local tb = create("TextBox", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = C.input,
		TextColor3 = C.text,
		PlaceholderText = placeholder,
		PlaceholderColor3 = C.muted,
		Text = initial or "",
		Font = FONT_MED,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
	corner(tb, 10)
	stroke(tb, C.line, 1)
	padding(tb, 10, 0, 10, 0)
	return tb
end

local apiSec = section(1, "ScriptBlox endpoints (configurable)")
note(apiSec, 1, "Search API URL. The app adds ?q=KEYWORD&page=N&max=10 to it. Must start with https://")
local searchUrlBox = textField(apiSec, 2, DEFAULTS.searchUrl, settings.searchUrl)
note(apiSec, 3, "Image base URL, used when ScriptBlox returns relative image paths.")
local imageBaseBox = textField(apiSec, 4, DEFAULTS.imageBase, settings.imageBase)
local apiBtnRow = create("Frame", { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, apiSec)
local saveBtn = button(apiBtnRow, "Save", C.cyan, Color3.new(0, 0, 0), { Size = UDim2.new(0.5, -4, 1, 0) })
local resetBtn = button(apiBtnRow, "Reset defaults", C.input, C.text, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.new(0.5, -4, 1, 0),
})
stroke(resetBtn, C.line, 1)
note(
	apiSec,
	6,
	caps.files and "Settings are saved to your executor workspace (AlphaEmpireAI/settings.json)."
		or "This executor has no file functions: settings last until you close the game."
)

local capSec = section(2, "Executor capabilities")
local function capRow(order, name, ok, detail)
	note(capSec, order, (ok and "[ OK ]  " or "[ NO ]  ") .. name .. " - " .. detail, ok and C.green or C.amber)
end
capRow(1, "HTTP requests", caps.http, caps.http and "search works" or "search will NOT work")
capRow(2, "Clipboard", caps.clipboard, caps.clipboard and "Copy buttons work" or "Copy buttons disabled")
capRow(3, "File storage", caps.files, caps.files and "settings are saved" or "nothing saved between sessions")
capRow(4, "Thumbnails", caps.thumbs, caps.thumbs and "downloaded images can be shown" or "needs HTTP + files + getcustomasset; letter tiles shown instead")
capRow(5, "Hidden GUI container", caps.hiddenUi, caps.hiddenUi and "GUI hosted in gethui()" or "using fallback GUI parent")

local dataSec = section(3, "App")
local unloadBtn = button(dataSec, "Unload " .. BRAND, C.input, C.amber, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 36) })
stroke(unloadBtn, C.amber, 1, 0.5)
note(dataSec, 2, BRAND .. "  \226\128\162  " .. MADE_BY .. "  \226\128\162  Powered by ScriptBlox.com")

track(saveBtn.MouseButton1Click:Connect(function()
	local a, b = trim(searchUrlBox.Text), trim(imageBaseBox.Text)
	if not validUrl(a) then
		notify("Search API URL must start with https://", "error")
		return
	end
	if not validUrl(b) then
		notify("Image base URL must start with https://", "error")
		return
	end
	settings.searchUrl = a
	settings.imageBase = b
	sCache = {}
	sCacheCount = 0
	local saved = saveSettings()
	if saved then
		notify("Settings saved.")
	else
		notify("Applied for this session (could not write the settings file).", "warn")
	end
end))
track(resetBtn.MouseButton1Click:Connect(function()
	settings.searchUrl = DEFAULTS.searchUrl
	settings.imageBase = DEFAULTS.imageBase
	searchUrlBox.Text = DEFAULTS.searchUrl
	imageBaseBox.Text = DEFAULTS.imageBase
	sCache = {}
	sCacheCount = 0
	saveSettings()
	notify("Defaults restored.")
end))
track(unloadBtn.MouseButton1Click:Connect(function()
	unloaded = true
	for _, c in ipairs(connections) do
		pcall(function()
			c:Disconnect()
		end)
	end
	pcall(function()
		gui:Destroy()
	end)
end))

-- =====================================================================
-- 9. LAYOUT, TABS, WINDOW CONTROLS, STARTUP
-- =====================================================================
local function layoutTabs()
	local tabW = state.wide and 84 or 68
	local step = tabW + 4
	for i, name in ipairs(tabNames) do
		local tb = tabButtons[name]
		tb.Size = UDim2.fromOffset(tabW, TAB_H - 4)
		tb.Position = UDim2.fromOffset(12 + (i - 1) * step, 2)
	end
	local idx = 1
	for i, name in ipairs(tabNames) do
		if name == state.tab then
			idx = i
		end
	end
	tabIndicator.Size = UDim2.fromOffset(tabW, 2)
	tween(tabIndicator, 0.25, { Position = UDim2.new(0, 12 + (idx - 1) * step, 1, 0) })
	if state.wide then
		discordBtn.Size = UDim2.fromOffset(168, 30)
		discordText.Visible = true
		discordIcon.Position = UDim2.new(0, 6, 0.5, 0)
	else
		discordBtn.Size = UDim2.fromOffset(34, 30)
		discordText.Visible = false
		discordIcon.Position = UDim2.new(0.5, -10, 0.5, 0)
	end
end

function applyLayout()
	local vp = viewport()
	local w, h
	if state.maximized then
		w = math.clamp(vp.X * 0.98, 300, 4000)
		h = math.clamp(vp.Y * 0.96, 340, 4000)
	else
		w = math.clamp(vp.X * 0.96, 300, 860)
		h = math.clamp(vp.Y * 0.9, 340, 600)
	end
	state.wide = w >= 600
	if state.minimized then
		window.Size = UDim2.fromOffset(w, TOP_H)
	else
		window.Size = UDim2.fromOffset(w, h)
	end
	layoutTabs()
end

function switchTab(name)
	state.tab = name
	searchPage.Visible = name == "search"
	aboutPage.Visible = name == "about"
	settingsPage.Visible = name == "settings"
	for key, tb in pairs(tabButtons) do
		tb.TextColor3 = key == name and C.text or C.muted
	end
	layoutTabs()
end
for key, tb in pairs(tabButtons) do
	track(tb.MouseButton1Click:Connect(function()
		switchTab(key)
	end))
end

local function openWindow()
	state.open = true
	launcher.Visible = false
	window.Visible = true
	windowScale.Scale = 0.85
	window.GroupTransparency = 1
	tween(windowScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(window, 0.3, { GroupTransparency = 0 })
end

local function closeWindow()
	state.open = false
	tween(windowScale, 0.25, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local t = tween(window, 0.25, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	t.Completed:Connect(function()
		if not state.open and not unloaded then
			window.Visible = false
			launcher.Visible = true
			launcher.Size = UDim2.fromOffset(0, 0)
			tween(launcher, 0.35, { Size = UDim2.fromOffset(52, 52) }, Enum.EasingStyle.Back)
		end
	end)
end

local function setMinimized(min)
	state.minimized = min
	tabBar.Visible = not min
	area.Visible = not min
	minBtn.Text = min and "+" or "-"
	applyLayout()
end

track(closeBtn.MouseButton1Click:Connect(closeWindow))
track(minBtn.MouseButton1Click:Connect(function()
	setMinimized(not state.minimized)
end))
track(maxBtn.MouseButton1Click:Connect(function()
	if state.minimized then
		setMinimized(false)
	end
	state.maximized = not state.maximized
	window.Position = UDim2.fromScale(0.5, 0.5)
	applyLayout()
	notify(state.maximized and "Window maximized." or "Window restored.")
end))
track(launcher.MouseButton1Click:Connect(openWindow))

-- Dragging (mouse + touch) from the top bar
do
	local dragging = false
	local dragStart, startPos, dragInput
	track(topBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = window.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end))
	track(topBar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end))
	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and input == dragInput then
			local delta = input.Position - dragStart
			window.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end))
end

do
	local cam = workspace.CurrentCamera
	if cam then
		track(cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout))
	end
end

-- ---- Startup: loading screen, then reveal the app ----
setSearchView("empty", "Search Roblox scripts", "Type a keyword above and press Search.", false)
switchTab("search")
applyLayout()
openWindow()

task.spawn(function()
	local steps = {
		{ 0.25, "Checking executor features..." },
		{ 0.5, caps.http and "HTTP support found" or "No HTTP support found" },
		{ 0.75, "Loading settings..." },
		{ 1.0, "Ready" },
	}
	for _, s in ipairs(steps) do
		if unloaded then
			return
		end
		splashStatus.Text = s[2]
		tween(barFill, 0.35, { Size = UDim2.fromScale(s[1], 1) })
		task.wait(0.45)
	end
	if unloaded then
		return
	end
	tween(splash, 0.4, { GroupTransparency = 1 }).Completed:Wait()
	if not unloaded then
		splash:Destroy()
		if not caps.http then
			notify("No HTTP function found. Search will not work here.", "error")
		else
			notify("Welcome to " .. BRAND .. " - " .. MADE_BY)
		end
	end
end)
