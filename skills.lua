-- ╔══════════════════════════════════════════════════════╗
-- ║         CRUSTY HUB  v3  —  BOUNTY STEALTH SUITE      ║
-- ╚══════════════════════════════════════════════════════╝
print("executed!")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer

-- ══════════════════════════════════════════
--  CONFIG
-- ══════════════════════════════════════════
local Config = {
    -- keybinds
    AimKey       = Enum.KeyCode.Q,
    GuiKey       = Enum.KeyCode.Nine,
    KillKey      = Enum.KeyCode.F8,
    -- aimbot
    Enabled      = true,
    IsHoldMode   = true,
    AimActive    = false,
    IsAggressive = false,
    Smoothness   = 0.15,
    Prediction   = 0.12,
    FovRadius    = 350,
    -- legit preset
    Smoothness_Legit      = 0.15,
    Prediction_Legit      = 0.12,
    FovRadius_Legit       = 350,
    -- aggressive preset
    Smoothness_Aggressive = 0.90,
    Prediction_Aggressive = 0.20,
    FovRadius_Aggressive  = 500,
    -- esp
    EspEnabled   = true,
    -- targeting
    TargetLowestHP  = false,
    TargetSpecific  = false,
    -- camera fov
    CameraFov    = 70,
    -- refresh
    RefreshRate  = 0.1,
}

local ESP_Table    = {}
local PlayerStatus = {}   -- [name] = "ally" | "target" | nil
local Binding      = false
local BindTarget   = nil  -- which config key we're rebinding
local GuiVisible   = false

-- capture original camera state for clean restore on terminate
local OriginalFov  = Camera.FieldOfView

-- ══════════════════════════════════════════
--  CONFIG DEFAULTS (for Reset tab)
-- ══════════════════════════════════════════
local Defaults = {
    AimKey         = Enum.KeyCode.Q,
    GuiKey         = Enum.KeyCode.Nine,
    KillKey        = Enum.KeyCode.F8,
    Enabled        = true,
    IsHoldMode     = true,
    IsAggressive   = false,
    Smoothness     = 0.15,
    Prediction     = 0.12,
    FovRadius      = 350,
    EspEnabled     = true,
    TargetLowestHP = false,
    TargetSpecific = false,
    CameraFov      = 70,
}

-- ══════════════════════════════════════════
--  CONFIG PERSISTENCE
-- ══════════════════════════════════════════
local CONFIG_FILE = "crustyhub_config.json"

local function EncodeConfig()
    local parts = {}
    local skip = {AimActive=true, RefreshRate=true,
        Smoothness_Legit=true, Prediction_Legit=true, FovRadius_Legit=true,
        Smoothness_Aggressive=true, Prediction_Aggressive=true, FovRadius_Aggressive=true}
    for k, v in pairs(Config) do
        if not skip[k] then
            if typeof(v) == "EnumItem" then
                table.insert(parts, '"'..k..'":"'..v.Name..'"')
            elseif type(v) == "boolean" then
                table.insert(parts, '"'..k..'":'..(v and "true" or "false"))
            elseif type(v) == "number" then
                table.insert(parts, '"'..k..'":'..(v))
            end
        end
    end
    return "{"..table.concat(parts, ",").."}"
end

local function DecodeAndApply(s)
    for k, v in s:gmatch('"([^"]+)":([^,}]+)') do
        v = v:gsub('"',''):match("^%s*(.-)%s*$")
        if Config[k] ~= nil then
            if v == "true" then Config[k] = true
            elseif v == "false" then Config[k] = false
            elseif tonumber(v) then Config[k] = tonumber(v)
            else
                local ok, e = pcall(function() return Enum.KeyCode[v] end)
                if ok and e then Config[k] = e
                else
                    local ok2, e2 = pcall(function() return Enum.UserInputType[v] end)
                    if ok2 and e2 then Config[k] = e2 end
                end
            end
        end
    end
end

local function SaveConfig()
    if writefile then pcall(function() writefile(CONFIG_FILE, EncodeConfig()) end) end
end

-- load saved config on startup
if isfile and isfile(CONFIG_FILE) and readfile then
    pcall(function() DecodeAndApply(readfile(CONFIG_FILE)) end)
end

-- ══════════════════════════════════════════
--  SOUND HELPER
-- ══════════════════════════════════════════
local function PlaySound(file, vol)
    if isfile and isfile(file) and getcustomasset then
        local s = Instance.new("Sound", game:GetService("SoundService"))
        s.SoundId = getcustomasset(file)
        s.Volume  = vol or 0.6
        s:Play()
        game:GetService("Debris"):AddItem(s, 3)
    end
end

-- ══════════════════════════════════════════
--  PALETTE
-- ══════════════════════════════════════════
local P = {
    BG          = Color3.fromRGB(10,  10,  12 ),
    Surface     = Color3.fromRGB(18,  18,  22 ),
    Card        = Color3.fromRGB(24,  24,  30 ),
    Border      = Color3.fromRGB(40,  40,  52 ),
    Accent      = Color3.fromRGB(0,   255, 150),
    AccentDim   = Color3.fromRGB(0,   120, 70 ),
    Purple      = Color3.fromRGB(170, 80,  255),
    PurpleDim   = Color3.fromRGB(70,  0,   120),
    Red         = Color3.fromRGB(255, 60,  60 ),
    White       = Color3.fromRGB(255, 255, 255),
    Grey        = Color3.fromRGB(140, 140, 155),
    DimGrey     = Color3.fromRGB(50,  50,  62 ),
    Black       = Color3.fromRGB(0,   0,   0  ),
}

-- ══════════════════════════════════════════
--  TWEEN SHORTCUTS
-- ══════════════════════════════════════════
local function Tween(obj, t, style, dir, props)
    style = style or Enum.EasingStyle.Quart
    dir   = dir   or Enum.EasingDirection.Out
    TweenService:Create(obj, TweenInfo.new(t, style, dir), props):Play()
end
local function Spring(obj, t, props)
    Tween(obj, t, Enum.EasingStyle.Back, Enum.EasingDirection.Out, props)
end

-- ══════════════════════════════════════════
--  GUI ROOT
-- ══════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
ScreenGui.Name          = "CrustyHub_v3"
ScreenGui.DisplayOrder  = 100
ScreenGui.ResetOnSpawn  = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Main container — horizontal, wider
local Main = Instance.new("Frame", ScreenGui)
Main.Name              = "Main"
Main.Size              = UDim2.new(0, 540, 0, 380)
Main.Position          = UDim2.new(0.5, -270, 1.5, 0)  -- starts off-screen
Main.BackgroundColor3  = P.BG
Main.BorderSizePixel   = 0
Main.Active            = true
Main.Draggable         = true
Main.ClipsDescendants  = true
local MainCorner = Instance.new("UICorner", Main)
MainCorner.CornerRadius = UDim.new(0, 14)

-- Subtle border glow frame
local GlowBorder = Instance.new("Frame", Main)
GlowBorder.Size              = UDim2.new(1, 0, 1, 0)
GlowBorder.BackgroundTransparency = 1
GlowBorder.BorderSizePixel   = 0
GlowBorder.ZIndex             = 0
local GlowStroke = Instance.new("UIStroke", GlowBorder)
GlowStroke.Color     = P.Accent
GlowStroke.Thickness = 1.2
GlowStroke.Transparency = 0.6

-- ── HEADER BAR ──────────────────────────────────────────
local Header = Instance.new("Frame", Main)
Header.Size             = UDim2.new(1, 0, 0, 52)
Header.BackgroundColor3 = P.Surface
Header.BorderSizePixel  = 0
Header.ZIndex           = 4

local HdrStroke = Instance.new("UIStroke", Header)
HdrStroke.Color       = P.Border
HdrStroke.Thickness   = 1
HdrStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Big watermark glyph (background icon)
local WMark = Instance.new("TextLabel", Header)
WMark.Size               = UDim2.new(0, 60, 1, 0)
WMark.Position           = UDim2.new(0, -4, 0, 0)
WMark.BackgroundTransparency = 1
WMark.Text               = "⊕"
WMark.TextColor3         = P.Accent
WMark.TextTransparency   = 0.80
WMark.Font               = Enum.Font.GothamBold
WMark.TextSize           = 46
WMark.ZIndex             = 4

local TitleLbl = Instance.new("TextLabel", Header)
TitleLbl.Size             = UDim2.new(0, 180, 1, 0)
TitleLbl.Position         = UDim2.new(0, 38, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text             = "CRUSTY HUB"
TitleLbl.TextColor3       = P.Accent
TitleLbl.Font             = Enum.Font.GothamBold
TitleLbl.TextSize         = 22
TitleLbl.TextXAlignment   = Enum.TextXAlignment.Left
TitleLbl.ZIndex           = 5

local TeamLbl = Instance.new("TextLabel", Header)
TeamLbl.Size             = UDim2.new(0, 200, 1, 0)
TeamLbl.Position         = UDim2.new(1, -210, 0, 0)
TeamLbl.BackgroundTransparency = 1
TeamLbl.Text             = "FACTION: —"
TeamLbl.TextColor3       = P.Grey
TeamLbl.Font             = Enum.Font.Gotham
TeamLbl.TextSize         = 13
TeamLbl.TextXAlignment   = Enum.TextXAlignment.Right
TeamLbl.ZIndex           = 5

-- ── TAB BAR ────────────────────────────────────────────
local TabBar = Instance.new("Frame", Main)
TabBar.Size             = UDim2.new(1, 0, 0, 38)
TabBar.Position         = UDim2.new(0, 0, 0, 52)
TabBar.BackgroundColor3 = P.Surface
TabBar.BorderSizePixel  = 0
TabBar.ZIndex           = 4

local TabStroke = Instance.new("UIStroke", TabBar)
TabStroke.Color       = P.Border
TabStroke.Thickness   = 1
TabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Sliding pill under active tab
local TabPill = Instance.new("Frame", TabBar)
TabPill.Size             = UDim2.new(0, 90, 0, 3)
TabPill.Position         = UDim2.new(0, 8, 1, -3)
TabPill.BackgroundColor3 = P.Accent
TabPill.BorderSizePixel  = 0
TabPill.ZIndex           = 6
Instance.new("UICorner", TabPill).CornerRadius = UDim.new(1, 0)

-- ── CONTENT AREA ────────────────────────────────────────
local ContentHolder = Instance.new("Frame", Main)
ContentHolder.Name              = "ContentHolder"
ContentHolder.Size              = UDim2.new(1, 0, 1, -90)
ContentHolder.Position          = UDim2.new(0, 0, 0, 90)
ContentHolder.BackgroundTransparency = 1
ContentHolder.ClipsDescendants  = false
ContentHolder.ZIndex            = 2

-- ══════════════════════════════════════════
--  UI COMPONENT HELPERS
-- ══════════════════════════════════════════

-- Standard toggle button with left glow bar
local function MakeToggle(parent, yPos, labelText, iconText)
    local row = Instance.new("Frame", parent)
    row.Size             = UDim2.new(1, -24, 0, 42)
    row.Position         = UDim2.new(0, 12, 0, yPos)
    row.BackgroundColor3 = P.Card
    row.BorderSizePixel  = 0
    row.ZIndex           = 3
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    -- left accent bar (hidden when off)
    local bar = Instance.new("Frame", row)
    bar.Name             = "AccentBar"
    bar.Size             = UDim2.new(0, 3, 0, 26)
    bar.Position         = UDim2.new(0, 0, 0.5, -13)
    bar.BackgroundColor3 = P.Accent
    bar.BorderSizePixel  = 0
    bar.BackgroundTransparency = 1
    bar.ZIndex           = 4
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    -- watermark icon
    local wm = Instance.new("TextLabel", row)
    wm.Size              = UDim2.new(0, 38, 1, 0)
    wm.Position          = UDim2.new(0, 6, 0, 0)
    wm.BackgroundTransparency = 1
    wm.Text              = iconText or "◎"
    wm.TextColor3        = P.Accent
    wm.TextTransparency  = 0.72
    wm.Font              = Enum.Font.GothamBold
    wm.TextSize          = 26
    wm.ZIndex            = 4

    local lbl = Instance.new("TextLabel", row)
    lbl.Size             = UDim2.new(0, 220, 1, 0)
    lbl.Position         = UDim2.new(0, 40, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = labelText
    lbl.TextColor3       = P.White
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextSize         = 15
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 4

    -- status pill on right
    local pill = Instance.new("TextLabel", row)
    pill.Name            = "StatusPill"
    pill.Size            = UDim2.new(0, 52, 0, 22)
    pill.Position        = UDim2.new(1, -62, 0.5, -11)
    pill.BackgroundColor3 = P.DimGrey
    pill.TextColor3      = P.Grey
    pill.Text            = "OFF"
    pill.Font            = Enum.Font.GothamBold
    pill.TextSize        = 12
    pill.ZIndex          = 5
    Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 5)

    local btn = Instance.new("TextButton", row)
    btn.Size             = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text             = ""
    btn.ZIndex           = 6

    -- hover
    btn.MouseEnter:Connect(function()
        PlaySound("hover.mp3", 0.12)
        Tween(row, 0.18, nil, nil, {BackgroundColor3 = P.DimGrey})
        Tween(row, 0.18, nil, nil, {Position = UDim2.new(0, 10, 0, yPos)})
    end)
    btn.MouseLeave:Connect(function()
        Tween(row, 0.18, nil, nil, {BackgroundColor3 = P.Card})
        Tween(row, 0.18, nil, nil, {Position = UDim2.new(0, 12, 0, yPos)})
    end)

    -- returns: row, btn, bar, pill  (so caller can wire state)
    return row, btn, bar, pill
end

-- Sets toggle visual state
local function SetToggleState(bar, pill, state, accentColor)
    accentColor = accentColor or P.Accent
    if state then
        Tween(bar,  0.22, nil, nil, {BackgroundTransparency = 0})
        Tween(pill, 0.22, nil, nil, {BackgroundColor3 = accentColor, TextColor3 = P.Black})
        pill.Text = "ON"
    else
        Tween(bar,  0.22, nil, nil, {BackgroundTransparency = 1})
        Tween(pill, 0.22, nil, nil, {BackgroundColor3 = P.DimGrey, TextColor3 = P.Grey})
        pill.Text = "OFF"
    end
end

-- Pill pair selector (e.g. HOLD / TOGGLE, LEGIT / AGGRESSIVE)
local function MakePillPair(parent, yPos, leftText, rightText, leftIcon, rightIcon)
    local row = Instance.new("Frame", parent)
    row.Size             = UDim2.new(1, -24, 0, 42)
    row.Position         = UDim2.new(0, 12, 0, yPos)
    row.BackgroundColor3 = P.Card
    row.BorderSizePixel  = 0
    row.ZIndex           = 3
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local function MakePill(text, icon, xPos, w)
        local p = Instance.new("TextButton", row)
        p.Size             = UDim2.new(0, w, 0, 28)
        p.Position         = UDim2.new(0, xPos, 0.5, -14)
        p.BackgroundColor3 = P.DimGrey
        p.TextColor3       = P.Grey
        p.Text             = (icon and (icon .. "  ") or "") .. text
        p.Font             = Enum.Font.GothamBold
        p.TextSize         = 13
        p.BorderSizePixel  = 0
        p.ZIndex           = 5
        Instance.new("UICorner", p).CornerRadius = UDim.new(0, 6)
        return p
    end

    local leftBtn  = MakePill(leftText,  leftIcon,  8,   225)
    local rightBtn = MakePill(rightText, rightIcon, 240, 225)

    return row, leftBtn, rightBtn
end

-- Slider row
local function MakeSlider(parent, yPos, labelText, iconText, minVal, maxVal, initVal, displayFmt)
    displayFmt = displayFmt or function(v) return string.format("%.2f", v) end

    local row = Instance.new("Frame", parent)
    row.Size             = UDim2.new(1, -24, 0, 54)
    row.Position         = UDim2.new(0, 12, 0, yPos)
    row.BackgroundColor3 = P.Card
    row.BorderSizePixel  = 0
    row.ZIndex           = 3
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local wm = Instance.new("TextLabel", row)
    wm.Size              = UDim2.new(0, 36, 0, 24)
    wm.Position          = UDim2.new(0, 6, 0, 4)
    wm.BackgroundTransparency = 1
    wm.Text              = iconText or "◈"
    wm.TextColor3        = P.Accent
    wm.TextTransparency  = 0.70
    wm.Font              = Enum.Font.GothamBold
    wm.TextSize          = 22
    wm.ZIndex            = 4

    local lbl = Instance.new("TextLabel", row)
    lbl.Size             = UDim2.new(0, 200, 0, 24)
    lbl.Position         = UDim2.new(0, 38, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text             = labelText
    lbl.TextColor3       = P.White
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextSize         = 14
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 4

    local valLbl = Instance.new("TextLabel", row)
    valLbl.Name          = "ValLbl"
    valLbl.Size          = UDim2.new(0, 80, 0, 24)
    valLbl.Position      = UDim2.new(1, -88, 0, 4)
    valLbl.BackgroundTransparency = 1
    valLbl.Text          = displayFmt(initVal)
    valLbl.TextColor3    = P.Accent
    valLbl.Font          = Enum.Font.GothamBold
    valLbl.TextSize      = 14
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.ZIndex        = 4

    -- track background
    local trackBG = Instance.new("Frame", row)
    trackBG.Size             = UDim2.new(1, -20, 0, 5)
    trackBG.Position         = UDim2.new(0, 10, 0, 38)
    trackBG.BackgroundColor3 = P.DimGrey
    trackBG.BorderSizePixel  = 0
    trackBG.ZIndex           = 4
    Instance.new("UICorner", trackBG).CornerRadius = UDim.new(1, 0)

    -- track fill
    local trackFill = Instance.new("Frame", trackBG)
    trackFill.Name           = "Fill"
    trackFill.Size           = UDim2.new((initVal - minVal) / (maxVal - minVal), 0, 1, 0)
    trackFill.BackgroundColor3 = P.Accent
    trackFill.BorderSizePixel = 0
    trackFill.ZIndex         = 5
    Instance.new("UICorner", trackFill).CornerRadius = UDim.new(1, 0)

    -- thumb
    local thumb = Instance.new("Frame", trackBG)
    thumb.Name              = "Thumb"
    thumb.Size              = UDim2.new(0, 13, 0, 13)
    thumb.AnchorPoint       = Vector2.new(0.5, 0.5)
    thumb.Position          = UDim2.new((initVal - minVal) / (maxVal - minVal), 0, 0.5, 0)
    thumb.BackgroundColor3  = P.White
    thumb.BorderSizePixel   = 0
    thumb.ZIndex            = 6
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)

    -- drag logic
    local dragging = false
    local hitbox = Instance.new("TextButton", trackBG)
    hitbox.Size             = UDim2.new(1, 0, 0, 20)
    hitbox.Position         = UDim2.new(0, 0, 0.5, -10)
    hitbox.BackgroundTransparency = 1
    hitbox.Text             = ""
    hitbox.ZIndex           = 7

    local currentVal = initVal
    local onChanged  = nil  -- callback

    local function UpdateFromX(absX)
        local trackAbsPos  = trackBG.AbsolutePosition.X
        local trackAbsSize = trackBG.AbsoluteSize.X
        local ratio = math.clamp((absX - trackAbsPos) / trackAbsSize, 0, 1)
        local newVal = minVal + (maxVal - minVal) * ratio
        -- snap to integers if range >= 10
        if (maxVal - minVal) >= 10 then newVal = math.round(newVal) end
        currentVal = newVal
        local fillRatio = (newVal - minVal) / (maxVal - minVal)
        trackFill.Size     = UDim2.new(fillRatio, 0, 1, 0)
        thumb.Position     = UDim2.new(fillRatio, 0, 0.5, 0)
        valLbl.Text        = displayFmt(newVal)
        if onChanged then onChanged(newVal) end
    end

    hitbox.MouseButton1Down:Connect(function(x, _)
        dragging = true
        UpdateFromX(x)
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            UpdateFromX(inp.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    -- returns row and setter
    local function SetValue(v)
        currentVal = math.clamp(v, minVal, maxVal)
        local r = (currentVal - minVal) / (maxVal - minVal)
        trackFill.Size = UDim2.new(r, 0, 1, 0)
        thumb.Position = UDim2.new(r, 0, 0.5, 0)
        valLbl.Text    = displayFmt(currentVal)
    end
    local function OnChange(cb) onChanged = cb end

    return row, SetValue, OnChange
end

-- Section header inside panel
local function MakeSectionHeader(parent, yPos, text, icon)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size             = UDim2.new(1, -24, 0, 24)
    lbl.Position         = UDim2.new(0, 12, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Text             = (icon and (icon .. "  ") or "") .. text
    lbl.TextColor3       = P.Accent
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextSize         = 13
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 3
    return lbl
end

-- ══════════════════════════════════════════
--  TAB SYSTEM
-- ══════════════════════════════════════════
local Tabs       = {}
local TabFrames  = {}
local ActiveTab  = nil
local TabBtnList = {}
local TAB_NAMES  = {"CORE", "AIMBOT", "TARGETING", "PLAYERS", "KEYBINDS", "RESET"}
local TAB_ICONS  = {"⊕",    "◎",      "⋈",         "◈",       "⌘",        "↺"}
local TAB_W      = 78

-- create tab buttons
for i, name in ipairs(TAB_NAMES) do
    local xOff = 8 + (i - 1) * (TAB_W + 4)
    local btn = Instance.new("TextButton", TabBar)
    btn.Name             = name
    btn.Size             = UDim2.new(0, TAB_W, 1, -6)
    btn.Position         = UDim2.new(0, xOff, 0, 3)
    btn.BackgroundTransparency = 1
    btn.Text             = TAB_ICONS[i] .. "  " .. name
    btn.TextColor3       = P.Grey
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 12
    btn.ZIndex           = 5
    Tabs[name]    = btn
    TabBtnList[i] = {btn = btn, x = xOff}
end

-- create content frames (all at same position, shown/hidden on tab switch)
for i, name in ipairs(TAB_NAMES) do
    local f = Instance.new("ScrollingFrame", ContentHolder)
    f.Name                  = name
    f.Size                  = UDim2.new(1, 0, 1, 0)
    f.Position              = UDim2.new(0, 0, 0, 0)
    f.BackgroundTransparency = 1
    f.BorderSizePixel       = 0
    f.ScrollBarThickness    = 3
    f.ScrollBarImageColor3  = P.Accent
    f.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    f.CanvasSize            = UDim2.new(0, 0, 0, 0)
    f.ZIndex                = 2
    f.Visible               = false  -- hidden until switched to
    TabFrames[name] = f
end

local function SwitchTab(name)
    local idx = table.find(TAB_NAMES, name)
    if not idx then return end

    -- hide all tabs instantly, show new one
    for _, tname in ipairs(TAB_NAMES) do
        TabFrames[tname].Visible = false
    end
    TabFrames[name].Visible = true

    ActiveTab = name

    -- slide pill to active tab
    local pillX = TabBtnList[idx].x
    Tween(TabPill, 0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out,
        {Position = UDim2.new(0, pillX, 1, -3), Size = UDim2.new(0, TAB_W, 0, 3)})

    -- colour tabs
    for _, entry in ipairs(TabBtnList) do
        Tween(entry.btn, 0.18, nil, nil,
            {TextColor3 = entry.btn.Name == name and P.Accent or P.Grey})
    end

    PlaySound("click.mp3", 0.3)
end

for _, name in ipairs(TAB_NAMES) do
    Tabs[name].MouseButton1Click:Connect(function() SwitchTab(name) end)
end

-- ══════════════════════════════════════════
--  TAB: CORE
-- ══════════════════════════════════════════
local CoreF = TabFrames["CORE"]

MakeSectionHeader(CoreF, 8, "MASTER CONTROLS", "⊕")

local _, espBtn,  espBar,  espPill  = MakeToggle(CoreF, 36,  "ESP  Wallhack",     "◉")
local _, aimBtn,  aimBar,  aimPill  = MakeToggle(CoreF, 86,  "AIMBOT  Enable",    "◎")
MakeSectionHeader(CoreF, 140, "AIM MODE", "◎")
local modeRow, modeLeft, modeRight = MakePillPair(CoreF, 164, "HOLD", "TOGGLE", "⏤", "⇄")

MakeSectionHeader(CoreF, 222, "CAMERA  FIELD OF VIEW", "⊞")
local _, SetFovValue, OnFovChange = MakeSlider(CoreF, 246, "Field of View",
    "⊞", 40, 120, Config.CameraFov,
    function(v) return math.round(v) .. "°" end)

-- wire core toggles
SetToggleState(espBar, espPill, Config.EspEnabled)
SetToggleState(aimBar, aimPill, Config.Enabled)

espBtn.MouseButton1Click:Connect(function()
    Config.EspEnabled = not Config.EspEnabled
    SetToggleState(espBar, espPill, Config.EspEnabled)
    PlaySound("click.mp3", 0.5)
    SaveConfig()
end)

aimBtn.MouseButton1Click:Connect(function()
    Config.Enabled = not Config.Enabled
    SetToggleState(aimBar, aimPill, Config.Enabled)
    PlaySound("click.mp3", 0.5)
    SaveConfig()
end)

local function RefreshModeButtons()
    if Config.IsHoldMode then
        Tween(modeLeft,  0.2, nil, nil, {BackgroundColor3 = P.AccentDim, TextColor3 = P.Accent})
        Tween(modeRight, 0.2, nil, nil, {BackgroundColor3 = P.DimGrey,   TextColor3 = P.Grey  })
    else
        Tween(modeLeft,  0.2, nil, nil, {BackgroundColor3 = P.DimGrey,   TextColor3 = P.Grey  })
        Tween(modeRight, 0.2, nil, nil, {BackgroundColor3 = P.AccentDim, TextColor3 = P.Accent})
    end
end
RefreshModeButtons()

modeLeft.MouseButton1Click:Connect(function()
    Config.IsHoldMode = true; RefreshModeButtons(); PlaySound("click.mp3", 0.5); SaveConfig()
end)
modeRight.MouseButton1Click:Connect(function()
    Config.IsHoldMode = false; RefreshModeButtons(); PlaySound("click.mp3", 0.5); SaveConfig()
end)

OnFovChange(function(v)
    Config.CameraFov = v
    Camera.FieldOfView = v
end)

-- ══════════════════════════════════════════
--  TAB: AIMBOT
-- ══════════════════════════════════════════
local AimF = TabFrames["AIMBOT"]

MakeSectionHeader(AimF, 8, "PRESET", "◎")
local resetRow, legitBtn, aggBtn = MakePillPair(AimF, 32, "LEGIT", "AGGRESSIVE", "●", "▲")

MakeSectionHeader(AimF, 90, "PARAMETERS", "◈")
local _, SetSmooth, OnSmoothChange = MakeSlider(AimF, 114, "Smoothness",
    "◌", 0.05, 1.0, Config.Smoothness,
    function(v) return string.format("%.2f", v) end)

local _, SetPred, OnPredChange = MakeSlider(AimF, 176, "Prediction",
    "⤳", 0.0, 0.5, Config.Prediction,
    function(v) return string.format("%.2f", v) end)

local _, SetFov, OnFovAimChange = MakeSlider(AimF, 238, "Aim FOV Radius",
    "◎", 50, 700, Config.FovRadius,
    function(v) return math.round(v) .. "px" end)

-- wire preset
local function RefreshPreset()
    if Config.IsAggressive then
        Tween(legitBtn, 0.2, nil, nil, {BackgroundColor3 = P.DimGrey,   TextColor3 = P.Grey })
        Tween(aggBtn,   0.2, nil, nil, {BackgroundColor3 = Color3.fromRGB(100,0,0), TextColor3 = P.Red})
    else
        Tween(legitBtn, 0.2, nil, nil, {BackgroundColor3 = P.AccentDim, TextColor3 = P.Accent})
        Tween(aggBtn,   0.2, nil, nil, {BackgroundColor3 = P.DimGrey,   TextColor3 = P.Grey })
    end
end
RefreshPreset()

legitBtn.MouseButton1Click:Connect(function()
    Config.IsAggressive = false
    Config.Smoothness   = Config.Smoothness_Legit
    Config.Prediction   = Config.Prediction_Legit
    Config.FovRadius    = Config.FovRadius_Legit
    SetSmooth(Config.Smoothness)
    SetPred(Config.Prediction)
    SetFov(Config.FovRadius)
    RefreshPreset()
    PlaySound("click.mp3", 0.5)
    SaveConfig()
end)

aggBtn.MouseButton1Click:Connect(function()
    Config.IsAggressive = true
    Config.Smoothness   = Config.Smoothness_Aggressive
    Config.Prediction   = Config.Prediction_Aggressive
    Config.FovRadius    = Config.FovRadius_Aggressive
    SetSmooth(Config.Smoothness)
    SetPred(Config.Prediction)
    SetFov(Config.FovRadius)
    RefreshPreset()
    PlaySound("click.mp3", 0.5)
    SaveConfig()
end)

OnSmoothChange(function(v) Config.Smoothness = v; SaveConfig() end)
OnPredChange(function(v)   Config.Prediction = v; SaveConfig() end)
OnFovAimChange(function(v) Config.FovRadius  = v; SaveConfig() end)

-- ══════════════════════════════════════════
--  TAB: TARGETING
-- ══════════════════════════════════════════
local TgtF = TabFrames["TARGETING"]

MakeSectionHeader(TgtF, 8, "MODE", "⋈")

-- Static "always on" closest label
local closestInfo = Instance.new("Frame", TgtF)
closestInfo.Size             = UDim2.new(1, -24, 0, 42)
closestInfo.Position         = UDim2.new(0, 12, 0, 32)
closestInfo.BackgroundColor3 = P.Card
closestInfo.BorderSizePixel  = 0
closestInfo.ZIndex           = 3
Instance.new("UICorner", closestInfo).CornerRadius = UDim.new(0, 8)

local ciBar = Instance.new("Frame", closestInfo)
ciBar.Size             = UDim2.new(0, 3, 0, 26)
ciBar.Position         = UDim2.new(0, 0, 0.5, -13)
ciBar.BackgroundColor3 = P.Accent
ciBar.BorderSizePixel  = 0
ciBar.ZIndex           = 4
Instance.new("UICorner", ciBar).CornerRadius = UDim.new(1, 0)

local ciWM = Instance.new("TextLabel", closestInfo)
ciWM.Size              = UDim2.new(0, 38, 1, 0)
ciWM.Position          = UDim2.new(0, 6, 0, 0)
ciWM.BackgroundTransparency = 1
ciWM.Text              = "⊛"
ciWM.TextColor3        = P.Accent
ciWM.TextTransparency  = 0.65
ciWM.Font              = Enum.Font.GothamBold
ciWM.TextSize          = 26
ciWM.ZIndex            = 4

local ciLbl = Instance.new("TextLabel", closestInfo)
ciLbl.Size             = UDim2.new(0.7, 0, 1, 0)
ciLbl.Position         = UDim2.new(0, 40, 0, 0)
ciLbl.BackgroundTransparency = 1
ciLbl.Text             = "CLOSEST  [always active]"
ciLbl.TextColor3       = P.White
ciLbl.Font             = Enum.Font.GothamBold
ciLbl.TextSize         = 14
ciLbl.TextXAlignment   = Enum.TextXAlignment.Left
ciLbl.ZIndex           = 4

local ciPill = Instance.new("TextLabel", closestInfo)
ciPill.Size            = UDim2.new(0, 52, 0, 22)
ciPill.Position        = UDim2.new(1, -62, 0.5, -11)
ciPill.BackgroundColor3 = P.AccentDim
ciPill.TextColor3      = P.Accent
ciPill.Text            = "ON ∞"
ciPill.Font            = Enum.Font.GothamBold
ciPill.TextSize        = 12
ciPill.ZIndex          = 5
Instance.new("UICorner", ciPill).CornerRadius = UDim.new(0, 5)

local _, hpBtn,  hpBar,  hpPill  = MakeToggle(TgtF, 82,  "LOWEST HP  target weakest", "♡")
local _, spBtn,  spBar,  spPill  = MakeToggle(TgtF, 132, "SPECIFIC  player list picks", "◈")

MakeSectionHeader(TgtF, 190, "NOTE", "◉")
local note = Instance.new("TextLabel", TgtF)
note.Size             = UDim2.new(1, -24, 0, 48)
note.Position         = UDim2.new(0, 12, 0, 212)
note.BackgroundColor3 = Color3.fromRGB(18, 28, 22)
note.BorderSizePixel  = 0
note.Text             = "  When SPECIFIC is on + targets are tagged in Players tab, aimbot only locks onto those. CLOSEST + LOWEST HP picks the weakest player in FOV."
note.TextColor3       = P.Grey
note.Font             = Enum.Font.Gotham
note.TextSize         = 12
note.TextWrapped      = true
note.TextXAlignment   = Enum.TextXAlignment.Left
note.TextYAlignment   = Enum.TextYAlignment.Top
note.ZIndex           = 3
Instance.new("UICorner", note).CornerRadius = UDim.new(0, 8)

SetToggleState(hpBar, hpPill, Config.TargetLowestHP)
SetToggleState(spBar, spPill, Config.TargetSpecific)

hpBtn.MouseButton1Click:Connect(function()
    Config.TargetLowestHP = not Config.TargetLowestHP
    SetToggleState(hpBar, hpPill, Config.TargetLowestHP)
    PlaySound("click.mp3", 0.5)
    SaveConfig()
end)
spBtn.MouseButton1Click:Connect(function()
    Config.TargetSpecific = not Config.TargetSpecific
    SetToggleState(spBar, spPill, Config.TargetSpecific)
    PlaySound("click.mp3", 0.5)
    SaveConfig()
end)

-- ══════════════════════════════════════════
--  TAB: PLAYERS
-- ══════════════════════════════════════════
local PlayF = TabFrames["PLAYERS"]

MakeSectionHeader(PlayF, 8, "PLAYER LIST", "◈")

local hint = Instance.new("TextLabel", PlayF)
hint.Size             = UDim2.new(1, -24, 0, 20)
hint.Position         = UDim2.new(0, 12, 0, 30)
hint.BackgroundTransparency = 1
hint.Text             = "LEFT CLICK  =  Target (purple)   |   RIGHT CLICK  =  Ally (green)   |   same click  =  deselect"
hint.TextColor3       = P.Grey
hint.Font             = Enum.Font.Gotham
hint.TextSize         = 11
hint.TextXAlignment   = Enum.TextXAlignment.Left
hint.ZIndex           = 3

local ListContainer = Instance.new("Frame", PlayF)
ListContainer.Name            = "ListContainer"
ListContainer.Size            = UDim2.new(1, -24, 0, 270)
ListContainer.Position        = UDim2.new(0, 12, 0, 54)
ListContainer.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
ListContainer.BorderSizePixel = 0
ListContainer.ClipsDescendants = true
ListContainer.ZIndex          = 3
Instance.new("UICorner", ListContainer).CornerRadius = UDim.new(0, 10)

local ListScroll = Instance.new("ScrollingFrame", ListContainer)
ListScroll.Size               = UDim2.new(1, 0, 1, 0)
ListScroll.BackgroundTransparency = 1
ListScroll.BorderSizePixel    = 0
ListScroll.ScrollBarThickness = 3
ListScroll.ScrollBarImageColor3 = P.Accent
ListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ListScroll.CanvasSize         = UDim2.new(0, 0, 0, 0)
ListScroll.ZIndex             = 4

local ListLayout = Instance.new("UIListLayout", ListScroll)
ListLayout.Padding    = UDim.new(0, 4)
ListLayout.SortOrder  = Enum.SortOrder.Name
local ListPad = Instance.new("UIPadding", ListScroll)
ListPad.PaddingTop    = UDim.new(0, 6)
ListPad.PaddingBottom = UDim.new(0, 6)
ListPad.PaddingLeft   = UDim.new(0, 6)
ListPad.PaddingRight  = UDim.new(0, 6)

-- Empty state label
local EmptyLbl = Instance.new("TextLabel", ListScroll)
EmptyLbl.Name             = "__empty"
EmptyLbl.Size             = UDim2.new(1, 0, 0, 40)
EmptyLbl.BackgroundTransparency = 1
EmptyLbl.Text             = "no players found"
EmptyLbl.TextColor3       = P.Grey
EmptyLbl.Font             = Enum.Font.Gotham
EmptyLbl.TextSize         = 13
EmptyLbl.ZIndex           = 5

local function UpdatePlayerList()
    local inGame = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then inGame[p.Name] = true end
    end

    -- remove stale
    for _, v in pairs(ListScroll:GetChildren()) do
        if v:IsA("Frame") and v.Name ~= "__empty" and not inGame[v.Name] then
            Tween(v, 0.15, nil, nil, {BackgroundTransparency = 1})
            game:GetService("Debris"):AddItem(v, 0.2)
        end
    end

    local hasPlayers = false
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            hasPlayers = true
            local status   = PlayerStatus[p.Name]
            local existing = ListScroll:FindFirstChild(p.Name)

            if not existing then
                local row = Instance.new("Frame", ListScroll)
                row.Name             = p.Name
                row.Size             = UDim2.new(1, 0, 0, 38)
                row.BackgroundColor3 = P.Card
                row.BorderSizePixel  = 0
                row.BackgroundTransparency = 0
                row.ZIndex           = 5
                Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

                -- dot
                local dot = Instance.new("Frame", row)
                dot.Name             = "Dot"
                dot.Size             = UDim2.new(0, 8, 0, 8)
                dot.Position         = UDim2.new(0, 10, 0.5, -4)
                dot.BackgroundColor3 = P.Grey
                dot.BorderSizePixel  = 0
                dot.ZIndex           = 6
                Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

                -- name
                local nameLbl = Instance.new("TextLabel", row)
                nameLbl.Name         = "NameLbl"
                nameLbl.Size         = UDim2.new(1, -130, 1, 0)
                nameLbl.Position     = UDim2.new(0, 26, 0, 0)
                nameLbl.BackgroundTransparency = 1
                nameLbl.Text         = p.Name
                nameLbl.TextColor3   = P.White
                nameLbl.Font         = Enum.Font.GothamBold
                nameLbl.TextSize     = 14
                nameLbl.TextXAlignment = Enum.TextXAlignment.Left
                nameLbl.ZIndex       = 6

                -- badge
                local badge = Instance.new("TextLabel", row)
                badge.Name           = "Badge"
                badge.Size           = UDim2.new(0, 68, 0, 22)
                badge.Position       = UDim2.new(1, -76, 0.5, -11)
                badge.BackgroundTransparency = 1
                badge.TextColor3     = P.Grey
                badge.Text           = ""
                badge.Font           = Enum.Font.GothamBold
                badge.TextSize       = 12
                badge.ZIndex         = 6
                Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 5)

                -- left click = target / deselect target
                local hitL = Instance.new("TextButton", row)
                hitL.Size            = UDim2.new(0.5, 0, 1, 0)
                hitL.Position        = UDim2.new(0, 0, 0, 0)
                hitL.BackgroundTransparency = 1
                hitL.Text            = ""
                hitL.ZIndex          = 7
                hitL.MouseButton1Click:Connect(function()
                    PlayerStatus[p.Name] = (PlayerStatus[p.Name] == "target") and nil or "target"
                    PlaySound("click.mp3", 0.4)
                    UpdatePlayerList()
                end)

                -- right click = ally / deselect ally
                local hitR = Instance.new("TextButton", row)
                hitR.Size            = UDim2.new(0.5, 0, 1, 0)
                hitR.Position        = UDim2.new(0.5, 0, 0, 0)
                hitR.BackgroundTransparency = 1
                hitR.Text            = ""
                hitR.ZIndex          = 7
                hitR.MouseButton2Click:Connect(function()
                    PlayerStatus[p.Name] = (PlayerStatus[p.Name] == "ally") and nil or "ally"
                    PlaySound("click.mp3", 0.4)
                    UpdatePlayerList()
                end)

                existing = row
            end

            -- refresh colours
            local dot    = existing:FindFirstChild("Dot")
            local nLbl   = existing:FindFirstChild("NameLbl")
            local badge  = existing:FindFirstChild("Badge")

            if status == "ally" then
                Tween(existing, 0.18, nil, nil, {BackgroundColor3 = Color3.fromRGB(10, 38, 26)})
                if dot   then dot.BackgroundColor3  = P.Accent end
                if nLbl  then nLbl.TextColor3       = P.Accent end
                if badge then
                    badge.Text            = "◈ ALLY"
                    badge.TextColor3      = P.Accent
                    badge.BackgroundColor3 = P.AccentDim
                    badge.BackgroundTransparency = 0
                end
            elseif status == "target" then
                Tween(existing, 0.18, nil, nil, {BackgroundColor3 = Color3.fromRGB(30, 10, 50)})
                if dot   then dot.BackgroundColor3  = P.Purple end
                if nLbl  then nLbl.TextColor3       = P.Purple end
                if badge then
                    badge.Text            = "◎ TARGET"
                    badge.TextColor3      = P.Purple
                    badge.BackgroundColor3 = P.PurpleDim
                    badge.BackgroundTransparency = 0
                end
            else
                Tween(existing, 0.18, nil, nil, {BackgroundColor3 = P.Card})
                if dot   then dot.BackgroundColor3  = P.Grey  end
                if nLbl  then nLbl.TextColor3       = P.White end
                if badge then
                    badge.Text = ""
                    badge.BackgroundTransparency = 1
                end
            end
        end
    end

    EmptyLbl.Visible = not hasPlayers
end

-- ══════════════════════════════════════════
--  TAB: KEYBINDS
-- ══════════════════════════════════════════
local KeyF = TabFrames["KEYBINDS"]

MakeSectionHeader(KeyF, 8, "KEYBINDS", "⌘")

local KeyDefs = {
    {label = "AIM  (hold/toggle)",  icon = "◎", configKey = "AimKey",  y = 32 },
    {label = "OPEN  GUI",           icon = "⊕", configKey = "GuiKey",  y = 88 },
    {label = "TERMINATE  script",   icon = "✕", configKey = "KillKey", y = 144},
}

local KeyRows = {}

for _, kd in ipairs(KeyDefs) do
    local row = Instance.new("Frame", KeyF)
    row.Size             = UDim2.new(1, -24, 0, 50)
    row.Position         = UDim2.new(0, 12, 0, kd.y)
    row.BackgroundColor3 = P.Card
    row.BorderSizePixel  = 0
    row.ZIndex           = 3
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local wm = Instance.new("TextLabel", row)
    wm.Size              = UDim2.new(0, 36, 1, 0)
    wm.Position          = UDim2.new(0, 6, 0, 0)
    wm.BackgroundTransparency = 1
    wm.Text              = kd.icon
    wm.TextColor3        = P.Accent
    wm.TextTransparency  = 0.70
    wm.Font              = Enum.Font.GothamBold
    wm.TextSize          = 26
    wm.ZIndex            = 4

    local lbl = Instance.new("TextLabel", row)
    lbl.Size             = UDim2.new(0.55, 0, 1, 0)
    lbl.Position         = UDim2.new(0, 38, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = kd.label
    lbl.TextColor3       = P.White
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextSize         = 14
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 4

    local keyPill = Instance.new("TextButton", row)
    keyPill.Name         = "KeyPill"
    keyPill.Size         = UDim2.new(0, 100, 0, 28)
    keyPill.Position     = UDim2.new(1, -112, 0.5, -14)
    keyPill.BackgroundColor3 = P.DimGrey
    keyPill.TextColor3   = P.Accent
    keyPill.Font         = Enum.Font.GothamBold
    keyPill.TextSize     = 13
    keyPill.BorderSizePixel = 0
    keyPill.ZIndex       = 5
    Instance.new("UICorner", keyPill).CornerRadius = UDim.new(0, 6)

    -- set initial label
    local curKey = Config[kd.configKey]
    keyPill.Text = tostring(curKey.Name or curKey):upper()

    keyPill.MouseButton1Click:Connect(function()
        if Binding then return end
        Binding    = true
        BindTarget = kd.configKey
        keyPill.Text       = "[ press... ]"
        keyPill.TextColor3 = P.Red
        Tween(keyPill, 0.2, nil, nil, {BackgroundColor3 = Color3.fromRGB(50, 0, 0)})
        PlaySound("click.mp3", 0.5)
    end)

    KeyRows[kd.configKey] = keyPill
end

-- ══════════════════════════════════════════
--  TAB: RESET
-- ══════════════════════════════════════════
local RstF = TabFrames["RESET"]

MakeSectionHeader(RstF, 8, "RESET TO DEFAULTS", "↺")

-- helper: a reset row with label + flash-confirm button
local function MakeResetRow(parent, yPos, labelText, iconText, onReset)
    local row = Instance.new("Frame", parent)
    row.Size             = UDim2.new(1, -24, 0, 48)
    row.Position         = UDim2.new(0, 12, 0, yPos)
    row.BackgroundColor3 = P.Card
    row.BorderSizePixel  = 0
    row.ZIndex           = 3
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local wm = Instance.new("TextLabel", row)
    wm.Size              = UDim2.new(0, 36, 1, 0)
    wm.Position          = UDim2.new(0, 6, 0, 0)
    wm.BackgroundTransparency = 1
    wm.Text              = iconText or "↺"
    wm.TextColor3        = P.Red
    wm.TextTransparency  = 0.65
    wm.Font              = Enum.Font.GothamBold
    wm.TextSize          = 24
    wm.ZIndex            = 4

    local lbl = Instance.new("TextLabel", row)
    lbl.Size             = UDim2.new(0.6, 0, 1, 0)
    lbl.Position         = UDim2.new(0, 38, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = labelText
    lbl.TextColor3       = P.White
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextSize         = 14
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 4

    local resetBtn = Instance.new("TextButton", row)
    resetBtn.Size        = UDim2.new(0, 90, 0, 28)
    resetBtn.Position    = UDim2.new(1, -100, 0.5, -14)
    resetBtn.BackgroundColor3 = Color3.fromRGB(60, 15, 15)
    resetBtn.TextColor3  = P.Red
    resetBtn.Text        = "↺  RESET"
    resetBtn.Font        = Enum.Font.GothamBold
    resetBtn.TextSize    = 13
    resetBtn.BorderSizePixel = 0
    resetBtn.ZIndex      = 5
    Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 6)

    resetBtn.MouseButton1Click:Connect(function()
        PlaySound("click.mp3", 0.6)
        -- flash red confirm
        Tween(resetBtn, 0.1, nil, nil, {BackgroundColor3 = P.Red, TextColor3 = P.Black})
        resetBtn.Text = "✓ DONE"
        task.delay(0.6, function()
            Tween(resetBtn, 0.2, nil, nil, {BackgroundColor3 = Color3.fromRGB(60,15,15), TextColor3 = P.Red})
            resetBtn.Text = "↺  RESET"
        end)
        onReset()
        SaveConfig()
    end)

    return row
end

-- individual reset rows
MakeResetRow(RstF, 36, "Aimbot Settings", "◎", function()
    Config.IsAggressive = Defaults.IsAggressive
    Config.Smoothness   = Defaults.Smoothness
    Config.Prediction   = Defaults.Prediction
    Config.FovRadius    = Defaults.FovRadius
    Config.IsHoldMode   = Defaults.IsHoldMode
    Config.Enabled      = Defaults.Enabled
    -- refresh UI
    SetSmooth(Config.Smoothness)
    SetPred(Config.Prediction)
    SetFov(Config.FovRadius)
    RefreshPreset()
    RefreshModeButtons()
    SetToggleState(aimBar, aimPill, Config.Enabled)
end)

MakeResetRow(RstF, 92, "Keybinds", "⌘", function()
    Config.AimKey  = Defaults.AimKey
    Config.GuiKey  = Defaults.GuiKey
    Config.KillKey = Defaults.KillKey
    -- refresh keybind pills
    for _, kd in ipairs({"AimKey","GuiKey","KillKey"}) do
        local pill = KeyRows[kd]
        if pill then
            local v = Config[kd]
            pill.Text = tostring(v.Name or v):upper()
            pill.TextColor3 = P.Accent
            Tween(pill, 0.2, nil, nil, {BackgroundColor3 = P.DimGrey})
        end
    end
end)

MakeResetRow(RstF, 148, "ESP", "◉", function()
    Config.EspEnabled = Defaults.EspEnabled
    SetToggleState(espBar, espPill, Config.EspEnabled)
end)

MakeResetRow(RstF, 204, "Targeting", "⋈", function()
    Config.TargetLowestHP = Defaults.TargetLowestHP
    Config.TargetSpecific = Defaults.TargetSpecific
    SetToggleState(hpBar, hpPill, Config.TargetLowestHP)
    SetToggleState(spBar, spPill, Config.TargetSpecific)
end)

MakeResetRow(RstF, 260, "Camera FOV", "⊞", function()
    Config.CameraFov   = Defaults.CameraFov
    Camera.FieldOfView = Defaults.CameraFov
    SetFovValue(Defaults.CameraFov)
end)

-- divider
local divider = Instance.new("Frame", RstF)
divider.Size             = UDim2.new(1, -24, 0, 1)
divider.Position         = UDim2.new(0, 12, 0, 322)
divider.BackgroundColor3 = P.Border
divider.BorderSizePixel  = 0
divider.ZIndex           = 3

-- nuke all button
local nukeRow = Instance.new("Frame", RstF)
nukeRow.Size             = UDim2.new(1, -24, 0, 52)
nukeRow.Position         = UDim2.new(0, 12, 0, 332)
nukeRow.BackgroundColor3 = Color3.fromRGB(30, 8, 8)
nukeRow.BorderSizePixel  = 0
nukeRow.ZIndex           = 3
Instance.new("UICorner", nukeRow).CornerRadius = UDim.new(0, 8)
local nukeStroke = Instance.new("UIStroke", nukeRow)
nukeStroke.Color       = P.Red
nukeStroke.Thickness   = 1
nukeStroke.Transparency = 0.6

local nukeLbl = Instance.new("TextLabel", nukeRow)
nukeLbl.Size             = UDim2.new(0.6, 0, 1, 0)
nukeLbl.Position         = UDim2.new(0, 14, 0, 0)
nukeLbl.BackgroundTransparency = 1
nukeLbl.Text             = "↺  RESET EVERYTHING"
nukeLbl.TextColor3       = P.Red
nukeLbl.Font             = Enum.Font.GothamBold
nukeLbl.TextSize         = 15
nukeLbl.TextXAlignment   = Enum.TextXAlignment.Left
nukeLbl.ZIndex           = 4

local nukeBtn = Instance.new("TextButton", nukeRow)
nukeBtn.Size             = UDim2.new(1, 0, 1, 0)
nukeBtn.BackgroundTransparency = 1
nukeBtn.Text             = ""
nukeBtn.ZIndex           = 5

nukeBtn.MouseButton1Click:Connect(function()
    PlaySound("click.mp3", 0.8)
    Tween(nukeRow, 0.12, nil, nil, {BackgroundColor3 = Color3.fromRGB(80, 0, 0)})
    nukeLbl.Text = "✓  ALL RESET"
    task.delay(1, function()
        Tween(nukeRow, 0.3, nil, nil, {BackgroundColor3 = Color3.fromRGB(30, 8, 8)})
        nukeLbl.Text = "↺  RESET EVERYTHING"
    end)
    -- apply all defaults
    for k, v in pairs(Defaults) do Config[k] = v end
    -- refresh all UI
    SetSmooth(Config.Smoothness); SetPred(Config.Prediction); SetFov(Config.FovRadius)
    SetFovValue(Config.CameraFov)
    Camera.FieldOfView = Config.CameraFov
    RefreshPreset(); RefreshModeButtons()
    SetToggleState(espBar, espPill, Config.EspEnabled)
    SetToggleState(aimBar, aimPill, Config.Enabled)
    SetToggleState(hpBar,  hpPill,  Config.TargetLowestHP)
    SetToggleState(spBar,  spPill,  Config.TargetSpecific)
    for _, kd in ipairs({"AimKey","GuiKey","KillKey"}) do
        local pill = KeyRows[kd]
        if pill then
            local v = Config[kd]
            pill.Text = tostring(v.Name or v):upper()
            pill.TextColor3 = P.Accent
            Tween(pill, 0.2, nil, nil, {BackgroundColor3 = P.DimGrey})
        end
    end
    SaveConfig()
end)

-- ══════════════════════════════════════════
--  LOADING SCREEN
-- ══════════════════════════════════════════
local LoadFrame = Instance.new("Frame", ScreenGui)
LoadFrame.Size              = UDim2.new(0, 360, 0, 130)
LoadFrame.Position          = UDim2.new(0.5, -180, 0.5, -65)
LoadFrame.BackgroundColor3  = Color3.fromRGB(14, 14, 18)
LoadFrame.BorderSizePixel   = 0
Instance.new("UICorner", LoadFrame).CornerRadius = UDim.new(0, 12)

local LoadWM = Instance.new("TextLabel", LoadFrame)
LoadWM.Size              = UDim2.new(1, 0, 1, 0)
LoadWM.BackgroundTransparency = 1
LoadWM.Text              = "⊕"
LoadWM.TextColor3        = P.Accent
LoadWM.TextTransparency  = 0.88
LoadWM.Font              = Enum.Font.GothamBold
LoadWM.TextSize          = 110

local LoadText = Instance.new("TextLabel", LoadFrame)
LoadText.Size            = UDim2.new(1, 0, 0, 52)
LoadText.BackgroundTransparency = 1
LoadText.Text            = "LOADING  CRUSTY HUB . . ."
LoadText.TextColor3      = P.White
LoadText.Font            = Enum.Font.GothamBold
LoadText.TextSize        = 20

local BarBack = Instance.new("Frame", LoadFrame)
BarBack.Size             = UDim2.new(0.82, 0, 0, 5)
BarBack.Position         = UDim2.new(0.09, 0, 0.78, 0)
BarBack.BackgroundColor3 = P.DimGrey
BarBack.BorderSizePixel  = 0
Instance.new("UICorner", BarBack).CornerRadius = UDim.new(1, 0)

local BarFill = Instance.new("Frame", BarBack)
BarFill.Size             = UDim2.new(0, 0, 1, 0)
BarFill.BackgroundColor3 = P.Accent
BarFill.BorderSizePixel  = 0
Instance.new("UICorner", BarFill).CornerRadius = UDim.new(1, 0)

-- ══════════════════════════════════════════
--  CORE ENGINE
-- ══════════════════════════════════════════
local function IsAlly(player)
    if LocalPlayer.Team and player.Team
        and LocalPlayer.Team.Name == "Marines"
        and player.Team and player.Team.Name == "Marines" then return true end
    return PlayerStatus[player.Name] == "ally"
end

local function GetEspColor(player)
    local s = PlayerStatus[player.Name]
    if s == "ally" or IsAlly(player) then return P.Accent end
    if s == "target" then return P.Purple end
    return P.Red
end

local function Create3DBox(player)
    local char = player.Character or player.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart", 5)
    if not root then return end
    if ESP_Table[player] and ESP_Table[player].Box then
        pcall(function() ESP_Table[player].Box:Destroy() end)
    end
    local Box = Instance.new("BoxHandleAdornment")
    Box.Name         = "BountyBox"
    Box.AlwaysOnTop  = true
    Box.ZIndex       = 10
    Box.Transparency = 0.6
    Box.Size         = Vector3.new(4.5, 6, 4.5)
    Box.Adornee      = root
    Box.Parent       = root
    ESP_Table[player] = { Box = Box, Root = root }
end

local function GlobalCleanup()
    Config.Enabled = false
    -- restore original camera FOV
    Camera.FieldOfView = OriginalFov
    -- fade GUI out before destroying
    Tween(Main, 0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In,
        {Position = UDim2.new(0.5, -270, 1.5, 0)})
    task.wait(0.4)
    RunService:UnbindFromRenderStep("BountySync")
    for _, player in pairs(Players:GetPlayers()) do
        pcall(function()
            if player.Character then
                for _, child in pairs(player.Character:GetDescendants()) do
                    if child.Name == "BountyBox" then child:Destroy() end
                end
            end
        end)
    end
    ScreenGui:Destroy()
end

-- MASTER SYNC LOOP
RunService:BindToRenderStep("BountySync", Enum.RenderPriority.Camera.Value + 1, function()
    local mousePos = UserInputService:GetMouseLocation()

    -- check if any specific targets are selected
    local anySpecific = false
    if Config.TargetSpecific then
        for _, p in pairs(Players:GetPlayers()) do
            if PlayerStatus[p.Name] == "target" then anySpecific = true; break end
        end
    end

    local target, finalAimPos = nil, nil
    local closestDist = Config.FovRadius
    local lowestHP    = math.huge

    for player, data in pairs(ESP_Table) do
        pcall(function()
            if player.Parent and player.Character and data.Root and data.Box then
                local ally = IsAlly(player)
                data.Box.Visible = Config.EspEnabled
                data.Box.Color3  = GetEspColor(player)

                if Config.Enabled and not ally then
                    local canTarget = false
                    if LocalPlayer.Team then
                        canTarget = (LocalPlayer.Team.Name == "Pirates")
                            or (LocalPlayer.Team.Name == "Marines"
                                and player.Team and player.Team.Name == "Pirates")
                    else
                        canTarget = true
                    end
                    if anySpecific and PlayerStatus[player.Name] ~= "target" then
                        canTarget = false
                    end

                    if canTarget then
                        local predicted = data.Root.Position + (data.Root.Velocity * Config.Prediction)
                        local sPos, onScreen = Camera:WorldToViewportPoint(predicted)
                        if onScreen then
                            local screenDist = (Vector2.new(sPos.X, sPos.Y) - mousePos).Magnitude
                            if Config.TargetLowestHP then
                                if screenDist < Config.FovRadius then
                                    local hum = player.Character:FindFirstChildOfClass("Humanoid")
                                    local hp  = hum and hum.Health or math.huge
                                    if hp < lowestHP then
                                        lowestHP = hp; target = player; finalAimPos = sPos
                                    end
                                end
                            else
                                if screenDist < closestDist then
                                    closestDist = screenDist; target = player; finalAimPos = sPos
                                end
                            end
                        end
                    end
                end
            else
                if data.Box then data.Box.Visible = false end
            end
        end)
    end

    if Config.Enabled then
        local isInput = false
        if Config.IsHoldMode then
            isInput = UserInputService:IsKeyDown(Config.AimKey)
                or (Config.AimKey == Enum.UserInputType.MouseButton2
                    and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2))
        else
            isInput = Config.AimActive
        end
        if isInput and target and finalAimPos and typeof(mousemoverel) == "function" then
            mousemoverel(
                (finalAimPos.X - mousePos.X) * Config.Smoothness,
                (finalAimPos.Y - mousePos.Y) * Config.Smoothness
            )
        end
    end
end)

-- ══════════════════════════════════════════
--  INPUT HANDLER
-- ══════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, processed)
    -- keybind capture
    if Binding then
        local newKey = (input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode) or input.UserInputType
        Config[BindTarget] = newKey
        local pill = KeyRows[BindTarget]
        if pill then
            pill.Text      = tostring(newKey.Name or newKey):upper()
            pill.TextColor3 = P.Accent
            Tween(pill, 0.2, nil, nil, {BackgroundColor3 = P.DimGrey})
        end
        Binding    = false
        BindTarget = nil
        PlaySound("click.mp3", 0.8)
        SaveConfig()
        return
    end

    if processed then return end

    -- GUI toggle
    if input.KeyCode == Config.GuiKey then
        GuiVisible = not GuiVisible
        if GuiVisible then
            PlaySound("open.mp3", 0.6)
            Spring(Main, 0.55, {Position = UDim2.new(0.5, -270, 0.5, -190)})
        else
            PlaySound("close.mp3", 0.6)
            Tween(Main, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In,
                {Position = UDim2.new(0.5, -270, 1.5, 0)})
        end
        return
    end

    if input.KeyCode == Config.KillKey then
        GlobalCleanup(); return
    end

    if not Config.IsHoldMode and
        (input.KeyCode == Config.AimKey or input.UserInputType == Config.AimKey) then
        Config.AimActive = not Config.AimActive
    end
end)

-- ══════════════════════════════════════════
--  REFRESH LOOP
-- ══════════════════════════════════════════
task.spawn(function()
    while task.wait(Config.RefreshRate) and ScreenGui.Parent do
        -- clean invalid ESP entries
        for player, data in pairs(ESP_Table) do
            if not player.Parent or not player.Character
                or not player.Character:FindFirstChild("HumanoidRootPart") then
                if data.Box then pcall(function() data.Box:Destroy() end) end
                ESP_Table[player] = nil
            end
        end
        -- add new/respawned
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local valid = ESP_Table[p] and ESP_Table[p].Box and ESP_Table[p].Box.Parent
                if not valid then pcall(function() Create3DBox(p) end) end
            end
        end
        -- sync team label
        TeamLbl.Text = "FACTION: " ..
            (LocalPlayer.Team and LocalPlayer.Team.Name:upper() or "—")
        -- sync player list
        UpdatePlayerList()
    end
end)

-- ══════════════════════════════════════════
--  INIT — LOADING ANIMATION THEN OPEN
-- ══════════════════════════════════════════
task.spawn(function()
    PlaySound("startup.mp3", 0.5)
    BarFill:TweenSize(UDim2.new(1, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Linear, 4, true)
    task.wait(4)
    Tween(LoadFrame, 0.4, nil, nil, {BackgroundTransparency = 1})
    Tween(LoadText,  0.4, nil, nil, {TextTransparency = 1})
    Tween(LoadWM,    0.4, nil, nil, {TextTransparency = 1})
    task.wait(0.5)
    LoadFrame:Destroy()
    -- slide GUI in
    GuiVisible = true
    PlaySound("open.mp3", 0.6)
    Spring(Main, 0.6, {Position = UDim2.new(0.5, -270, 0.5, -190)})
    task.wait(0.1)
    SwitchTab("CORE")
    UpdatePlayerList()
end)
