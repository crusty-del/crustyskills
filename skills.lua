-- ╔══════════════════════════════════════════════════════╗
-- ║         CRUSTY SKILLS  v7  — BOUNTY STEALTH SUITE    ║
-- ╚══════════════════════════════════════════════════════╝

-- ══════════════════════════════════════════
--  ASSET CACHE
--  Pulls all icons and sounds from executor workspace on launch.
--  Drop files flat in your Velocity workspace folder.
-- ══════════════════════════════════════════
print("executed")
local AssetCache = {}

local function RefreshAssets()
    AssetCache = {}
    if not getcustomasset then return end
    local paths = {
        "icon_core.png","icon_aimbot.png","icon_targeting.png","icon_players.png",
        "icon_keybinds.png","icon_reset.png","icon_esp.png","icon_hold.png",
        "icon_toggle.png","icon_legit.png","icon_aggressive.png","icon_hp.png",
        "icon_specific.png","icon_camera.png","icon_terminate.png","icon_closest.png",
        "icon_slider.png","icon_note.png","icon_watermark.png","bg.png",
        "click.mp3","hover.mp3","open.mp3","close.mp3","startup.mp3",
    }
    for _, path in ipairs(paths) do
        local ok, id = pcall(getcustomasset, path)
        if ok and id then AssetCache[path] = id end
    end
end

RefreshAssets()

-- ══════════════════════════════════════════
--  ICON SYMBOL TABLE
--  img = workspace filename, fallback = unicode if file missing
-- ══════════════════════════════════════════
local S = {
    Core       = { img="icon_core.png",       fallback="⊕" },
    Aimbot     = { img="icon_aimbot.png",      fallback="◎" },
    Targeting  = { img="icon_targeting.png",   fallback="⋈" },
    Players    = { img="icon_players.png",     fallback="◈" },
    Keybinds   = { img="icon_keybinds.png",    fallback="⌘" },
    Reset      = { img="icon_reset.png",       fallback="↺" },
    ESP        = { img="icon_esp.png",         fallback="◉" },
    Hold       = { img="icon_hold.png",        fallback="⏤" },
    Toggle     = { img="icon_toggle.png",      fallback="⇄" },
    Legit      = { img="icon_legit.png",       fallback="●" },
    Aggressive = { img="icon_aggressive.png",  fallback="▲" },
    HP         = { img="icon_hp.png",          fallback="♡" },
    Specific   = { img="icon_specific.png",    fallback="◈" },
    Camera     = { img="icon_camera.png",      fallback="⊞" },
    Terminate  = { img="icon_terminate.png",   fallback="✕" },
    Closest    = { img="icon_closest.png",     fallback="⊛" },
    Slider     = { img="icon_slider.png",      fallback="◈" },
    Note       = { img="icon_note.png",        fallback="◉" },
    Watermark  = { img="icon_watermark.png",   fallback="◎" },
}

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
    AimKey                = Enum.KeyCode.Q,
    GuiKey                = Enum.KeyCode.Nine,
    KillKey               = Enum.KeyCode.F8,
    Enabled               = true,
    IsHoldMode            = true,
    AimActive             = false,
    IsAggressive          = false,
    Smoothness            = 0.15,
    Prediction            = 0.12,
    FovRadius             = 350,
    Smoothness_Legit      = 0.15,
    Prediction_Legit      = 0.12,
    FovRadius_Legit       = 350,
    Smoothness_Aggressive = 0.90,
    Prediction_Aggressive = 0.20,
    FovRadius_Aggressive  = 500,
    EspEnabled            = true,
    TargetLowestHP        = false,
    TargetSpecific        = false,
    CameraFov             = 70,
    RefreshRate           = 0.1,
}

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
--  STATE
-- ══════════════════════════════════════════
local ESP_Table    = {}
local PlayerStatus = {}
local Binding      = false
local BindTarget   = nil
local GuiVisible   = false
local Terminated   = false
local OriginalFov  = Camera.FieldOfView
local InputConn    = nil
local NotifBusy    = false
local CombatTable  = {}  -- player -> tick() of last combat event

-- ── DISTANCE CULL ─────────────────────────────────────────
-- Players whose HumanoidRootPart is farther than this (studs)
-- will NOT get an ESP box generated. Keeps performance clean
-- and stops rendering ghosts on the other side of the map.
local ESP_CULL_DISTANCE = 1000  -- studs — raise if your game needs it

-- ══════════════════════════════════════════
--  CONFIG PERSISTENCE
-- ══════════════════════════════════════════
local CONFIG_FILE = "crustyskills_config.json"

local function EncodeConfig()
    local skip = {
        AimActive=true, RefreshRate=true,
        Smoothness_Legit=true, Prediction_Legit=true, FovRadius_Legit=true,
        Smoothness_Aggressive=true, Prediction_Aggressive=true, FovRadius_Aggressive=true,
    }
    local parts = {}
    for k,v in pairs(Config) do
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
    for k,v in s:gmatch('"([^"]+)":([^,}]+)') do
        v = v:gsub('"',''):match("^%s*(.-)%s*$")
        if Config[k] ~= nil then
            if v == "true" then Config[k] = true
            elseif v == "false" then Config[k] = false
            elseif tonumber(v) then Config[k] = tonumber(v)
            else
                local ok,e = pcall(function() return Enum.KeyCode[v] end)
                if ok and e then Config[k] = e
                else
                    local ok2,e2 = pcall(function() return Enum.UserInputType[v] end)
                    if ok2 and e2 then Config[k] = e2 end
                end
            end
        end
    end
end

local function SaveConfig()
    if writefile then
        pcall(function() writefile(CONFIG_FILE, EncodeConfig()) end)
    end
end

if isfile and isfile(CONFIG_FILE) and readfile then
    pcall(function() DecodeAndApply(readfile(CONFIG_FILE)) end)
end




-- ══════════════════════════════════════════
--  SOUND
-- ══════════════════════════════════════════
local function PlaySound(file, vol)
    if Terminated then return end
    local id = AssetCache[file]
    if id then
        local s = Instance.new("Sound", game:GetService("SoundService"))
        s.SoundId = id
        s.Volume  = vol or 0.6
        s:Play()
        game:GetService("Debris"):AddItem(s, 3)
    end
end

-- ══════════════════════════════════════════
--  PALETTE
-- ══════════════════════════════════════════
local P = {
    BG        = Color3.fromRGB(10,  10,  12 ),
    Surface   = Color3.fromRGB(14,  14,  18 ),
    Card      = Color3.fromRGB(18,  18,  22 ),
    CardHover = Color3.fromRGB(26,  26,  32 ),
    Border    = Color3.fromRGB(50,  50,  60 ),
    DimGrey   = Color3.fromRGB(30,  30,  38 ),
    Frost     = Color3.fromRGB(200, 210, 225),
    Accent    = Color3.fromRGB(80,  180, 255),
    AccentDim = Color3.fromRGB(15,  45,  80 ),
    Purple    = Color3.fromRGB(170, 80,  255),
    PurpleDim = Color3.fromRGB(50,  0,   100),
    Green     = Color3.fromRGB(0,   220, 130),
    GreenDim  = Color3.fromRGB(0,   70,  45 ),
    Red       = Color3.fromRGB(255, 70,  70 ),
    White     = Color3.fromRGB(235, 235, 240),
    Grey      = Color3.fromRGB(130, 130, 145),
    Black     = Color3.fromRGB(0,   0,   0  ),
}

-- ══════════════════════════════════════════
--  TWEEN HELPERS
-- ══════════════════════════════════════════
local function Tween(obj, t, style, dir, props)
    if Terminated then return end
    if not obj or not obj.Parent then return end
    style = style or Enum.EasingStyle.Quart
    dir   = dir   or Enum.EasingDirection.Out
    TweenService:Create(obj, TweenInfo.new(t, style, dir), props):Play()
end

local function Spring(obj, t, props)
    Tween(obj, t, Enum.EasingStyle.Back, Enum.EasingDirection.Out, props)
end

-- ══════════════════════════════════════════
--  ICON HELPER
--  MakeIcon(parent, symbol, size, xPos, yAnchor)
--  Returns the created instance so caller can tint it
-- ══════════════════════════════════════════
local function MakeIcon(parent, symbol, size, xPos, zIndex, isWatermark)
    size    = size   or 20
    xPos    = xPos   or 6
    zIndex  = zIndex or 4

    -- load from asset cache (populated at launch from workspace)
    local hasPng = false
    local imgId  = nil
    if symbol and symbol.img then
        imgId = AssetCache[symbol.img]
        if imgId then hasPng = true end
    end

    if hasPng then
        local img = Instance.new("ImageLabel", parent)
        img.Name               = "Icon"
        img.Size               = UDim2.new(0, size, 0, size)
        img.Position           = UDim2.new(0, xPos, 0.5, -size/2)
        img.BackgroundTransparency = 1
        img.Image              = imgId
        img.ImageColor3        = P.White
        img:SetAttribute("IsWatermark", isWatermark == true)
        img.ScaleType          = Enum.ScaleType.Fit
        img.ZIndex             = zIndex
        return img
    else
        -- fallback to text symbol
        local lbl = Instance.new("TextLabel", parent)
        lbl.Name               = "Icon"
        lbl.Size               = UDim2.new(0, size + 10, 1, 0)
        lbl.Position           = UDim2.new(0, xPos - 2, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text               = (symbol and symbol.fallback) or "◈"
        lbl.TextColor3         = P.Grey
        lbl.TextTransparency   = 0.35
        lbl.Font               = Enum.Font.GothamBold
        lbl.TextSize           = size + 4
        lbl.ZIndex             = zIndex
        return lbl
    end
end

-- tint helper — works for both ImageLabel and TextLabel
local function TintIcon(icon, color, transparency)
    if not icon then return end
    -- watermark icons keep their original PNG colors, never tinted
    if icon:IsA("ImageLabel") and icon:GetAttribute("IsWatermark") then return end
    transparency = transparency or 0
    if icon:IsA("ImageLabel") then
        icon.ImageColor3        = color
        icon.ImageTransparency  = transparency
    else
        icon.TextColor3         = color
        icon.TextTransparency   = transparency
    end
end

-- ══════════════════════════════════════════
--  GUI ROOT
-- ══════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
ScreenGui.Name           = "CrustySkills_v6"
ScreenGui.DisplayOrder   = 100
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local Main = Instance.new("Frame", ScreenGui)
Main.Name                   = "Main"
Main.Size                   = UDim2.new(0, 560, 0, 390)
Main.Position               = UDim2.new(0.5, -280, 1.6, 0)
Main.BackgroundColor3       = P.BG
Main.BackgroundTransparency = 0.82
Main.BorderSizePixel        = 0
Main.Active                 = true
Main.Draggable              = true
Main.ClipsDescendants       = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 16)

local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color        = P.Accent
MainStroke.Thickness    = 1
MainStroke.Transparency = 0.72

-- background image
local BgImage = Instance.new("ImageLabel", Main)
BgImage.Size               = UDim2.new(1, 0, 1, 0)
BgImage.BackgroundTransparency = 1
BgImage.BorderSizePixel    = 0
BgImage.ScaleType          = Enum.ScaleType.Crop
BgImage.ZIndex             = 0
BgImage.ImageTransparency  = 0.30
Instance.new("UICorner", BgImage).CornerRadius = UDim.new(0, 16)

if AssetCache["bg.png"] then
    pcall(function() BgImage.Image = AssetCache["bg.png"] end)
else
    BgImage.BackgroundColor3       = P.Surface
    BgImage.BackgroundTransparency = 0.5
end

-- frost overlay
local FrostOverlay = Instance.new("Frame", Main)
FrostOverlay.Size                   = UDim2.new(1, 0, 1, 0)
FrostOverlay.BackgroundColor3       = P.Frost
FrostOverlay.BackgroundTransparency = 0.88
FrostOverlay.BorderSizePixel        = 0
FrostOverlay.ZIndex                 = 1
Instance.new("UICorner", FrostOverlay).CornerRadius = UDim.new(0, 16)

-- ── HEADER ──────────────────────────────────────────────
local Header = Instance.new("Frame", Main)
Header.Size                   = UDim2.new(1, 0, 0, 54)
Header.BackgroundColor3       = P.BG
Header.BackgroundTransparency = 0.72
Header.BorderSizePixel        = 0
Header.ZIndex                 = 4
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 16)

local HdrFill = Instance.new("Frame", Header)
HdrFill.Size                   = UDim2.new(1, 0, 0.5, 0)
HdrFill.Position               = UDim2.new(0, 0, 0.5, 0)
HdrFill.BackgroundColor3       = P.BG
HdrFill.BackgroundTransparency = 0.72
HdrFill.BorderSizePixel        = 0
HdrFill.ZIndex                 = 4

local HdrStroke = Instance.new("UIStroke", Header)
HdrStroke.Color           = P.Border
HdrStroke.Thickness       = 1
HdrStroke.Transparency    = 0.65
HdrStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- watermark icon in header
local WMarkIcon = MakeIcon(Header, S.Watermark, 38, -2, 5, true)
if WMarkIcon:IsA("ImageLabel") then
    WMarkIcon.Size     = UDim2.new(0, 38, 0, 38)
    WMarkIcon.Position = UDim2.new(0, 4, 0.5, -19)
    -- PNG watermark: no tint, keeps original colors
else
    WMarkIcon.Size     = UDim2.new(0, 50, 1, 0)
    WMarkIcon.Position = UDim2.new(0, -6, 0, 0)
    WMarkIcon.TextSize = 50
    TintIcon(WMarkIcon, P.Accent, 0.78)  -- fallback text symbol only
end

local TitleLbl = Instance.new("TextLabel", Header)
TitleLbl.Size               = UDim2.new(0, 220, 1, 0)
TitleLbl.Position           = UDim2.new(0, 48, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text               = "CRUSTY SKILLS"
TitleLbl.TextColor3         = P.White
TitleLbl.Font               = Enum.Font.GothamBold
TitleLbl.TextSize           = 22
TitleLbl.TextXAlignment     = Enum.TextXAlignment.Left
TitleLbl.ZIndex             = 5

local TeamLbl = Instance.new("TextLabel", Header)
TeamLbl.Size               = UDim2.new(0, 220, 1, 0)
TeamLbl.Position           = UDim2.new(1, -228, 0, 0)
TeamLbl.BackgroundTransparency = 1
TeamLbl.Text               = "FACTION: —"
TeamLbl.TextColor3         = P.Grey
TeamLbl.Font               = Enum.Font.Gotham
TeamLbl.TextSize           = 13
TeamLbl.TextXAlignment     = Enum.TextXAlignment.Right
TeamLbl.ZIndex             = 5

-- ── TAB BAR ─────────────────────────────────────────────
local TabBar = Instance.new("Frame", Main)
TabBar.Size                   = UDim2.new(1, 0, 0, 38)
TabBar.Position               = UDim2.new(0, 0, 0, 54)
TabBar.BackgroundColor3       = P.BG
TabBar.BackgroundTransparency = 0.75
TabBar.BorderSizePixel        = 0
TabBar.ZIndex                 = 4

local TabStroke = Instance.new("UIStroke", TabBar)
TabStroke.Color           = P.Border
TabStroke.Thickness       = 1
TabStroke.Transparency    = 0.65
TabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local TabPill = Instance.new("Frame", TabBar)
TabPill.Size             = UDim2.new(0, 80, 0, 3)
TabPill.Position         = UDim2.new(0, 6, 1, -3)
TabPill.BackgroundColor3 = P.Accent
TabPill.BorderSizePixel  = 0
TabPill.ZIndex           = 6
Instance.new("UICorner", TabPill).CornerRadius = UDim.new(1, 0)

-- ── CONTENT HOLDER ──────────────────────────────────────
local ContentHolder = Instance.new("Frame", Main)
ContentHolder.Name                   = "ContentHolder"
ContentHolder.Size                   = UDim2.new(1, 0, 1, -92)
ContentHolder.Position               = UDim2.new(0, 0, 0, 92)
ContentHolder.BackgroundTransparency = 1
ContentHolder.ClipsDescendants       = false
ContentHolder.ZIndex                 = 2

-- ══════════════════════════════════════════
--  NOTIFICATION
-- ══════════════════════════════════════════
local NotifFrame = Instance.new("Frame", ScreenGui)
NotifFrame.Name                   = "Notif"
NotifFrame.Size                   = UDim2.new(0, 240, 0, 44)
NotifFrame.Position               = UDim2.new(1, 20, 1, -60)
NotifFrame.BackgroundColor3       = P.BG
NotifFrame.BackgroundTransparency = 0.2
NotifFrame.BorderSizePixel        = 0
NotifFrame.ZIndex                 = 200
Instance.new("UICorner", NotifFrame).CornerRadius = UDim.new(0, 10)

local NotifStroke = Instance.new("UIStroke", NotifFrame)
NotifStroke.Thickness   = 1
NotifStroke.Color       = P.Accent
NotifStroke.Transparency = 0.45

local NotifIconHolder = Instance.new("Frame", NotifFrame)
NotifIconHolder.Size               = UDim2.new(0, 36, 1, 0)
NotifIconHolder.BackgroundTransparency = 1
NotifIconHolder.ZIndex             = 201

local NotifIconInst = MakeIcon(NotifIconHolder, S.Aimbot, 20, 8, 201)
TintIcon(NotifIconInst, P.Accent, 0)

local NotifText = Instance.new("TextLabel", NotifFrame)
NotifText.Size               = UDim2.new(1, -44, 1, 0)
NotifText.Position           = UDim2.new(0, 42, 0, 0)
NotifText.BackgroundTransparency = 1
NotifText.Text               = "AIMBOT ON"
NotifText.TextColor3         = P.White
NotifText.Font               = Enum.Font.GothamBold
NotifText.TextSize           = 15
NotifText.TextXAlignment     = Enum.TextXAlignment.Left
NotifText.ZIndex             = 201

local function ShowNotif(text, isOn)
    NotifText.Text        = text
    NotifText.TextColor3  = isOn and P.Accent or P.Grey
    NotifStroke.Color     = isOn and P.Accent or P.Border
    TintIcon(NotifIconInst, isOn and P.Accent or P.White, 0)

    NotifFrame.Position = UDim2.new(1, 20, 1, -60)
    Spring(NotifFrame, 0.45, {Position = UDim2.new(1, -250, 1, -60)})

    task.delay(2, function()
        TweenService:Create(NotifFrame,
            TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            {Position = UDim2.new(1, 20, 1, -60)}):Play()
        task.wait(0.4)
        NotifBusy = false
    end)
end

local function Notify(text, isOn, force)
    if NotifBusy and not force then return end
    NotifBusy = true
    ShowNotif(text, isOn)
end

-- ══════════════════════════════════════════
--  UI HELPERS
-- ══════════════════════════════════════════
local function MakeSectionHeader(parent, yPos, text, symbol)
    local row = Instance.new("Frame", parent)
    row.Size                   = UDim2.new(1, -24, 0, 22)
    row.Position               = UDim2.new(0, 12, 0, yPos)
    row.BackgroundTransparency = 1
    row.ZIndex                 = 3

    local ico = MakeIcon(row, symbol, 14, 0, 3)
    TintIcon(ico, P.Accent, 0)
    if ico:IsA("TextLabel") then ico.TextSize = 13 end

    local lbl = Instance.new("TextLabel", row)
    lbl.Size               = UDim2.new(1, -22, 1, 0)
    lbl.Position           = UDim2.new(0, 20, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text               = text
    lbl.TextColor3         = P.Accent
    lbl.Font               = Enum.Font.GothamBold
    lbl.TextSize           = 12
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.ZIndex             = 3
    return lbl
end

-- Toggle: row, btn, bar, pill, icon
local function MakeToggle(parent, yPos, labelText, symbol)
    local row = Instance.new("Frame", parent)
    row.Size                   = UDim2.new(1, -24, 0, 44)
    row.Position               = UDim2.new(0, 12, 0, yPos)
    row.BackgroundColor3       = P.Card
    row.BackgroundTransparency = 0.55
    row.BorderSizePixel        = 0
    row.ZIndex                 = 3
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    local rs = Instance.new("UIStroke", row)
    rs.Color = P.Border; rs.Thickness = 1; rs.Transparency = 0.7

    local bar = Instance.new("Frame", row)
    bar.Size                   = UDim2.new(0, 3, 0, 26)
    bar.Position               = UDim2.new(0, 0, 0.5, -13)
    bar.BackgroundColor3       = P.Accent
    bar.BackgroundTransparency = 1
    bar.BorderSizePixel        = 0
    bar.ZIndex                 = 4
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local ico = MakeIcon(row, symbol, 28, 6, 4)
    TintIcon(ico, P.White, 0)
    if ico:IsA("ImageLabel") then
        ico.Size     = UDim2.new(0, 28, 0, 28)
        ico.Position = UDim2.new(0, 6, 0.5, -14)
    else
        ico.TextSize = 26
    end

    local lbl = Instance.new("TextLabel", row)
    lbl.Size               = UDim2.new(0, 220, 1, 0)
    lbl.Position           = UDim2.new(0, 42, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text               = labelText
    lbl.TextColor3         = P.White
    lbl.Font               = Enum.Font.GothamBold
    lbl.TextSize           = 14
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.ZIndex             = 4

    local pill = Instance.new("TextLabel", row)
    pill.Name              = "StatusPill"
    pill.Size              = UDim2.new(0, 52, 0, 22)
    pill.Position          = UDim2.new(1, -62, 0.5, -11)
    pill.BackgroundColor3  = P.DimGrey
    pill.TextColor3        = P.Grey
    pill.Text              = "OFF"
    pill.Font              = Enum.Font.GothamBold
    pill.TextSize          = 12
    pill.ZIndex            = 5
    Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 5)

    local btn = Instance.new("TextButton", row)
    btn.Size               = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text               = ""
    btn.ZIndex             = 6

    btn.MouseEnter:Connect(function()
        PlaySound("hover.mp3", 0.12)
        Tween(row, 0.18, nil, nil, {BackgroundColor3=P.CardHover, BackgroundTransparency=0.45})
        Tween(row, 0.18, nil, nil, {Position=UDim2.new(0, 10, 0, yPos)})
    end)
    btn.MouseLeave:Connect(function()
        Tween(row, 0.18, nil, nil, {BackgroundColor3=P.Card, BackgroundTransparency=0.55})
        Tween(row, 0.18, nil, nil, {Position=UDim2.new(0, 12, 0, yPos)})
    end)

    return row, btn, bar, pill, ico
end

local function SetToggleState(bar, pill, state)
    if state then
        Tween(bar,  0.22, nil, nil, {BackgroundTransparency=0})
        Tween(pill, 0.22, nil, nil, {BackgroundColor3=P.Accent, TextColor3=P.Black})
        pill.Text = "ON"
    else
        Tween(bar,  0.22, nil, nil, {BackgroundTransparency=1})
        Tween(pill, 0.22, nil, nil, {BackgroundColor3=P.DimGrey, TextColor3=P.Grey})
        pill.Text = "OFF"
    end
end

-- PillPair: row, leftBtn, rightBtn
local function MakePillPair(parent, yPos, leftText, rightText, leftSym, rightSym)
    local row = Instance.new("Frame", parent)
    row.Size                   = UDim2.new(1, -24, 0, 44)
    row.Position               = UDim2.new(0, 12, 0, yPos)
    row.BackgroundColor3       = P.Card
    row.BackgroundTransparency = 0.55
    row.BorderSizePixel        = 0
    row.ZIndex                 = 3
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    local rs = Instance.new("UIStroke", row)
    rs.Color = P.Border; rs.Thickness = 1; rs.Transparency = 0.7

    local function MakePill(text, sym, xOff, w)
        local p = Instance.new("TextButton", row)
        p.Size             = UDim2.new(0, w, 0, 28)
        p.Position         = UDim2.new(0, xOff, 0.5, -14)
        p.BackgroundColor3 = P.DimGrey
        p.TextColor3       = P.Grey
        p.Text             = ""   -- clear default "Button" text
        p.BorderSizePixel  = 0
        p.ZIndex           = 5
        p.ClipsDescendants = false
        Instance.new("UICorner", p).CornerRadius = UDim.new(0, 6)

        -- icon inside pill
        local pillIco = MakeIcon(p, sym, 20, 6, 6)
        TintIcon(pillIco, P.White, 0)
        if pillIco:IsA("ImageLabel") then
            pillIco.Size     = UDim2.new(0, 20, 0, 20)
            pillIco.Position = UDim2.new(0, 6, 0.5, -10)
        else
            pillIco.TextSize = 18
        end

        local pillLbl = Instance.new("TextLabel", p)
        pillLbl.Size               = UDim2.new(1, -32, 1, 0)
        pillLbl.Position           = UDim2.new(0, 30, 0, 0)
        pillLbl.BackgroundTransparency = 1
        pillLbl.Text               = text
        pillLbl.TextColor3         = P.Grey
        pillLbl.Font               = Enum.Font.GothamBold
        pillLbl.TextSize           = 13
        pillLbl.ZIndex             = 6

        return p, pillIco, pillLbl
    end

    local L, Lico, Llbl = MakePill(leftText,  leftSym,  8,   232)
    local R, Rico, Rlbl = MakePill(rightText, rightSym, 248, 232)
    return row, L, R, Lico, Llbl, Rico, Rlbl
end

-- Slider: row, SetValue, OnChange
local function MakeSlider(parent, yPos, labelText, symbol, minVal, maxVal, initVal, displayFmt)
    displayFmt = displayFmt or function(v) return string.format("%.2f", v) end

    local row = Instance.new("Frame", parent)
    row.Size                   = UDim2.new(1, -24, 0, 56)
    row.Position               = UDim2.new(0, 12, 0, yPos)
    row.BackgroundColor3       = P.Card
    row.BackgroundTransparency = 0.55
    row.BorderSizePixel        = 0
    row.ZIndex                 = 3
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    local rs = Instance.new("UIStroke", row)
    rs.Color = P.Border; rs.Thickness = 1; rs.Transparency = 0.7

    local ico = MakeIcon(row, symbol, 24, 6, 4)
    TintIcon(ico, P.White, 0)
    if ico:IsA("ImageLabel") then
        ico.Size     = UDim2.new(0, 24, 0, 24)
        ico.Position = UDim2.new(0, 6, 0, 4)
    else
        ico.TextSize = 22
    end

    local lbl = Instance.new("TextLabel", row)
    lbl.Size               = UDim2.new(0, 200, 0, 24)
    lbl.Position           = UDim2.new(0, 36, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text               = labelText
    lbl.TextColor3         = P.White
    lbl.Font               = Enum.Font.GothamBold
    lbl.TextSize           = 13
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.ZIndex             = 4

    local valLbl = Instance.new("TextLabel", row)
    valLbl.Size               = UDim2.new(0, 90, 0, 24)
    valLbl.Position           = UDim2.new(1, -96, 0, 4)
    valLbl.BackgroundTransparency = 1
    valLbl.Text               = displayFmt(initVal)
    valLbl.TextColor3         = P.Accent
    valLbl.Font               = Enum.Font.GothamBold
    valLbl.TextSize           = 13
    valLbl.TextXAlignment     = Enum.TextXAlignment.Right
    valLbl.ZIndex             = 4

    local trackBG = Instance.new("Frame", row)
    trackBG.Size             = UDim2.new(1, -20, 0, 5)
    trackBG.Position         = UDim2.new(0, 10, 0, 40)
    trackBG.BackgroundColor3 = P.DimGrey
    trackBG.BorderSizePixel  = 0
    trackBG.ZIndex           = 4
    Instance.new("UICorner", trackBG).CornerRadius = UDim.new(1, 0)

    local trackFill = Instance.new("Frame", trackBG)
    trackFill.Size             = UDim2.new((initVal-minVal)/(maxVal-minVal), 0, 1, 0)
    trackFill.BackgroundColor3 = P.Accent
    trackFill.BorderSizePixel  = 0
    trackFill.ZIndex           = 5
    Instance.new("UICorner", trackFill).CornerRadius = UDim.new(1, 0)

    local thumb = Instance.new("Frame", trackBG)
    thumb.Size             = UDim2.new(0, 13, 0, 13)
    thumb.AnchorPoint      = Vector2.new(0.5, 0.5)
    thumb.Position         = UDim2.new((initVal-minVal)/(maxVal-minVal), 0, 0.5, 0)
    thumb.BackgroundColor3 = P.White
    thumb.BorderSizePixel  = 0
    thumb.ZIndex           = 6
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)

    local dragging = false
    local hitbox = Instance.new("TextButton", trackBG)
    hitbox.Size               = UDim2.new(1, 0, 0, 22)
    hitbox.Position           = UDim2.new(0, 0, 0.5, -11)
    hitbox.BackgroundTransparency = 1
    hitbox.Text               = ""
    hitbox.ZIndex             = 7

    local currentVal = initVal
    local onChanged  = nil

    local function UpdateFromX(absX)
        local r = math.clamp((absX - trackBG.AbsolutePosition.X) / trackBG.AbsoluteSize.X, 0, 1)
        local v = minVal + (maxVal - minVal) * r
        if (maxVal - minVal) >= 10 then v = math.round(v) end
        currentVal = v
        local fr = (v - minVal) / (maxVal - minVal)
        trackFill.Size = UDim2.new(fr, 0, 1, 0)
        thumb.Position = UDim2.new(fr, 0, 0.5, 0)
        valLbl.Text    = displayFmt(v)
        if onChanged then onChanged(v) end
    end

    hitbox.MouseButton1Down:Connect(function(x) dragging = true; UpdateFromX(x) end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            UpdateFromX(inp.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

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

-- ══════════════════════════════════════════
--  TAB SYSTEM
-- ══════════════════════════════════════════
local Tabs, TabFrames, TabBtnList = {}, {}, {}
local TAB_NAMES = {"CORE","AIMBOT","TARGETING","PLAYERS","KEYBINDS","RESET"}
local TAB_SYMS  = {S.Core, S.Aimbot, S.Targeting, S.Players, S.Keybinds, S.Reset}
local TAB_W     = 80

for i, name in ipairs(TAB_NAMES) do
    local xOff = 6 + (i-1) * (TAB_W + 3)
    local btn = Instance.new("TextButton", TabBar)
    btn.Name               = name
    btn.Size               = UDim2.new(0, TAB_W, 1, -6)
    btn.Position           = UDim2.new(0, xOff, 0, 3)
    btn.BackgroundTransparency = 1
    btn.Text               = ""
    btn.ZIndex             = 5

    -- icon inside tab button
    local tabIco = MakeIcon(btn, TAB_SYMS[i], 18, 4, 6)
    TintIcon(tabIco, P.White, 0)
    if tabIco:IsA("ImageLabel") then
        tabIco.Size     = UDim2.new(0, 18, 0, 18)
        tabIco.Position = UDim2.new(0, 4, 0.5, -9)
    else
        tabIco.TextSize = 16
    end

    local tabLbl = Instance.new("TextLabel", btn)
    tabLbl.Name               = "TabLbl"
    tabLbl.Size               = UDim2.new(1, -24, 1, 0)
    tabLbl.Position           = UDim2.new(0, 24, 0, 0)
    tabLbl.BackgroundTransparency = 1
    tabLbl.Text               = name
    tabLbl.TextColor3         = P.Grey
    tabLbl.Font               = Enum.Font.GothamBold
    tabLbl.TextSize           = 11
    tabLbl.ZIndex             = 6

    Tabs[name]    = {btn=btn, ico=tabIco, lbl=tabLbl}
    TabBtnList[i] = {btn=btn, ico=tabIco, lbl=tabLbl, x=xOff}
end

for _, name in ipairs(TAB_NAMES) do
    local f = Instance.new("ScrollingFrame", ContentHolder)
    f.Name                   = name
    f.Size                   = UDim2.new(1, 0, 1, 0)
    f.Position               = UDim2.new(0, 0, 0, 0)
    f.BackgroundTransparency = 1
    f.BorderSizePixel        = 0
    f.ScrollBarThickness     = 3
    f.ScrollBarImageColor3   = P.Accent
    f.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    f.CanvasSize             = UDim2.new(0, 0, 0, 0)
    f.ZIndex                 = 2
    f.Visible                = false
    TabFrames[name] = f
end

local function SwitchTab(name)
    local idx = table.find(TAB_NAMES, name)
    if not idx then return end
    for _, n in ipairs(TAB_NAMES) do TabFrames[n].Visible = false end
    TabFrames[name].Visible = true
    Tween(TabPill, 0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out,
        {Position=UDim2.new(0, TabBtnList[idx].x, 1, -3), Size=UDim2.new(0, TAB_W, 0, 3)})
    for _, entry in ipairs(TabBtnList) do
        local active = entry.btn.Name == name
        Tween(entry.lbl, 0.18, nil, nil, {TextColor3 = active and P.Accent or P.Grey})
        TintIcon(entry.ico, active and P.Accent or P.White, 0)
    end
    PlaySound("click.mp3", 0.3)
end

for _, name in ipairs(TAB_NAMES) do
    Tabs[name].btn.MouseButton1Click:Connect(function() SwitchTab(name) end)
end

-- ══════════════════════════════════════════
--  TAB: CORE
-- ══════════════════════════════════════════
local CoreF = TabFrames["CORE"]
MakeSectionHeader(CoreF, 8,   "MASTER CONTROLS", S.Core)
local _, espBtn, espBar, espPill   = MakeToggle(CoreF, 34,  "ESP  Wallhack",  S.ESP)
local _, aimBtn, aimBar, aimPill   = MakeToggle(CoreF, 86,  "AIMBOT  Enable", S.Aimbot)
MakeSectionHeader(CoreF, 140, "AIM MODE", S.Aimbot)
local _, modeLeft, modeRight = MakePillPair(CoreF, 162, "HOLD", "TOGGLE", S.Hold, S.Toggle)
MakeSectionHeader(CoreF, 220, "CAMERA  FIELD OF VIEW", S.Camera)
local _, SetFovValue, OnFovChange = MakeSlider(CoreF, 242, "Field of View", S.Camera,
    40, 120, Config.CameraFov, function(v) return math.round(v).."°" end)

SetToggleState(espBar, espPill, Config.EspEnabled)
SetToggleState(aimBar, aimPill, Config.Enabled)

espBtn.MouseButton1Click:Connect(function()
    Config.EspEnabled = not Config.EspEnabled
    SetToggleState(espBar, espPill, Config.EspEnabled)
    PlaySound("click.mp3", 0.5); SaveConfig()
end)
aimBtn.MouseButton1Click:Connect(function()
    Config.Enabled = not Config.Enabled
    SetToggleState(aimBar, aimPill, Config.Enabled)
    PlaySound("click.mp3", 0.5); SaveConfig()
end)

local function RefreshModeButtons()
    if Config.IsHoldMode then
        Tween(modeLeft,  0.2, nil, nil, {BackgroundColor3=P.AccentDim, TextColor3=P.Accent})
        Tween(modeRight, 0.2, nil, nil, {BackgroundColor3=P.DimGrey,   TextColor3=P.Grey  })
    else
        Tween(modeLeft,  0.2, nil, nil, {BackgroundColor3=P.DimGrey,   TextColor3=P.Grey  })
        Tween(modeRight, 0.2, nil, nil, {BackgroundColor3=P.AccentDim, TextColor3=P.Accent})
    end
end
RefreshModeButtons()

modeLeft.MouseButton1Click:Connect(function()
    Config.IsHoldMode = true
    RefreshModeButtons(); PlaySound("click.mp3", 0.5); SaveConfig()
end)
modeRight.MouseButton1Click:Connect(function()
    Config.IsHoldMode = false
    RefreshModeButtons(); PlaySound("click.mp3", 0.5); SaveConfig()
end)

OnFovChange(function(v) Config.CameraFov = v; Camera.FieldOfView = v end)

-- ══════════════════════════════════════════
--  TAB: AIMBOT
-- ══════════════════════════════════════════
local AimF = TabFrames["AIMBOT"]
MakeSectionHeader(AimF, 8,  "PRESET",     S.Aimbot)
local _, legitBtn, aggBtn = MakePillPair(AimF, 30, "LEGIT", "AGGRESSIVE", S.Legit, S.Aggressive)
MakeSectionHeader(AimF, 88, "PARAMETERS", S.Slider)
local _, SetSmooth, OnSmoothChange = MakeSlider(AimF, 110, "Smoothness",     S.Slider, 0.05, 1.0,  Config.Smoothness,  function(v) return string.format("%.2f",v) end)
local _, SetPred,   OnPredChange   = MakeSlider(AimF, 174, "Prediction",     S.Slider, 0.0,  0.5,  Config.Prediction,  function(v) return string.format("%.2f",v) end)
local _, SetFov,    OnFovAimChange = MakeSlider(AimF, 238, "Aim FOV Radius", S.Aimbot, 50,   700,  Config.FovRadius,   function(v) return math.round(v).."px" end)

local function RefreshPreset()
    if Config.IsAggressive then
        Tween(legitBtn, 0.2, nil, nil, {BackgroundColor3=P.DimGrey,             TextColor3=P.Grey })
        Tween(aggBtn,   0.2, nil, nil, {BackgroundColor3=Color3.fromRGB(70,0,0), TextColor3=P.Red  })
    else
        Tween(legitBtn, 0.2, nil, nil, {BackgroundColor3=P.AccentDim, TextColor3=P.Accent})
        Tween(aggBtn,   0.2, nil, nil, {BackgroundColor3=P.DimGrey,   TextColor3=P.Grey  })
    end
end
RefreshPreset()

legitBtn.MouseButton1Click:Connect(function()
    Config.IsAggressive=false
    Config.Smoothness=Config.Smoothness_Legit; Config.Prediction=Config.Prediction_Legit; Config.FovRadius=Config.FovRadius_Legit
    SetSmooth(Config.Smoothness); SetPred(Config.Prediction); SetFov(Config.FovRadius)
    RefreshPreset(); PlaySound("click.mp3",0.5); SaveConfig()
end)
aggBtn.MouseButton1Click:Connect(function()
    Config.IsAggressive=true
    Config.Smoothness=Config.Smoothness_Aggressive; Config.Prediction=Config.Prediction_Aggressive; Config.FovRadius=Config.FovRadius_Aggressive
    SetSmooth(Config.Smoothness); SetPred(Config.Prediction); SetFov(Config.FovRadius)
    RefreshPreset(); PlaySound("click.mp3",0.5); SaveConfig()
end)

OnSmoothChange(function(v) Config.Smoothness=v; SaveConfig() end)
OnPredChange(function(v)   Config.Prediction=v; SaveConfig() end)
OnFovAimChange(function(v) Config.FovRadius=v;  SaveConfig() end)

-- ══════════════════════════════════════════
--  TAB: TARGETING
-- ══════════════════════════════════════════
local TgtF = TabFrames["TARGETING"]
MakeSectionHeader(TgtF, 8, "MODE", S.Targeting)

-- always-on closest row (static, no toggle)
local ciRow = Instance.new("Frame", TgtF)
ciRow.Size=UDim2.new(1,-24,0,44); ciRow.Position=UDim2.new(0,12,0,30)
ciRow.BackgroundColor3=P.Card; ciRow.BackgroundTransparency=0.55
ciRow.BorderSizePixel=0; ciRow.ZIndex=3
Instance.new("UICorner",ciRow).CornerRadius=UDim.new(0,8)
local ciS=Instance.new("UIStroke",ciRow); ciS.Color=P.Accent; ciS.Thickness=1; ciS.Transparency=0.55

local ciAccBar=Instance.new("Frame",ciRow)
ciAccBar.Size=UDim2.new(0,3,0,26); ciAccBar.Position=UDim2.new(0,0,0.5,-13)
ciAccBar.BackgroundColor3=P.Accent; ciAccBar.BorderSizePixel=0; ciAccBar.ZIndex=4
Instance.new("UICorner",ciAccBar).CornerRadius=UDim.new(1,0)

local ciIco = MakeIcon(ciRow, S.Closest, 28, 6, 4)
TintIcon(ciIco, P.White, 0)
if ciIco:IsA("ImageLabel") then
    ciIco.Size=UDim2.new(0,28,0,28); ciIco.Position=UDim2.new(0,6,0.5,-14)
else ciIco.TextSize=26 end

local ciLbl=Instance.new("TextLabel",ciRow)
ciLbl.Size=UDim2.new(0.65,0,1,0); ciLbl.Position=UDim2.new(0,42,0,0)
ciLbl.BackgroundTransparency=1; ciLbl.Text="CLOSEST  [always active]"
ciLbl.TextColor3=P.White; ciLbl.Font=Enum.Font.GothamBold
ciLbl.TextSize=13; ciLbl.TextXAlignment=Enum.TextXAlignment.Left; ciLbl.ZIndex=4

local ciPill=Instance.new("TextLabel",ciRow)
ciPill.Size=UDim2.new(0,52,0,22); ciPill.Position=UDim2.new(1,-62,0.5,-11)
ciPill.BackgroundColor3=P.AccentDim; ciPill.TextColor3=P.Accent
ciPill.Text="ON ∞"; ciPill.Font=Enum.Font.GothamBold; ciPill.TextSize=12; ciPill.ZIndex=5
Instance.new("UICorner",ciPill).CornerRadius=UDim.new(0,5)

local _, hpBtn, hpBar, hpPill  = MakeToggle(TgtF,  82, "LOWEST HP  target weakest",   S.HP)
local _, spBtn, spBar, spPill  = MakeToggle(TgtF, 134, "SPECIFIC  player list picks",  S.Specific)

MakeSectionHeader(TgtF, 190, "NOTE", S.Note)
local note=Instance.new("TextLabel",TgtF)
note.Size=UDim2.new(1,-24,0,52); note.Position=UDim2.new(0,12,0,212)
note.BackgroundColor3=P.DimGrey; note.BackgroundTransparency=0.55; note.BorderSizePixel=0
note.Text="  SPECIFIC filters to tagged players only. LOWEST HP picks weakest in FOV. Both stack."
note.TextColor3=P.Grey; note.Font=Enum.Font.Gotham; note.TextSize=12
note.TextWrapped=true; note.TextXAlignment=Enum.TextXAlignment.Left
note.TextYAlignment=Enum.TextYAlignment.Top; note.ZIndex=3
Instance.new("UICorner",note).CornerRadius=UDim.new(0,8)

SetToggleState(hpBar,hpPill,Config.TargetLowestHP)
SetToggleState(spBar,spPill,Config.TargetSpecific)

hpBtn.MouseButton1Click:Connect(function()
    Config.TargetLowestHP=not Config.TargetLowestHP
    SetToggleState(hpBar,hpPill,Config.TargetLowestHP); PlaySound("click.mp3",0.5); SaveConfig()
end)
spBtn.MouseButton1Click:Connect(function()
    Config.TargetSpecific=not Config.TargetSpecific
    SetToggleState(spBar,spPill,Config.TargetSpecific); PlaySound("click.mp3",0.5); SaveConfig()
end)

-- ══════════════════════════════════════════
--  TAB: PLAYERS
-- ══════════════════════════════════════════
local PlayF = TabFrames["PLAYERS"]
MakeSectionHeader(PlayF, 8, "PLAYER LIST", S.Players)

local hint=Instance.new("TextLabel",PlayF)
hint.Size=UDim2.new(1,-24,0,18); hint.Position=UDim2.new(0,12,0,30)
hint.BackgroundTransparency=1
hint.Text="L-CLICK = Target (purple)   |   R-CLICK = Ally (green)   |   same = deselect"
hint.TextColor3=P.Grey; hint.Font=Enum.Font.Gotham; hint.TextSize=11
hint.TextXAlignment=Enum.TextXAlignment.Left; hint.ZIndex=3

local ListContainer=Instance.new("Frame",PlayF)
ListContainer.Size=UDim2.new(1,-24,0,268); ListContainer.Position=UDim2.new(0,12,0,52)
ListContainer.BackgroundColor3=P.BG; ListContainer.BackgroundTransparency=0.6
ListContainer.BorderSizePixel=0; ListContainer.ClipsDescendants=true; ListContainer.ZIndex=3
Instance.new("UICorner",ListContainer).CornerRadius=UDim.new(0,10)
local lcS=Instance.new("UIStroke",ListContainer); lcS.Color=P.Border; lcS.Thickness=1; lcS.Transparency=0.6

local ListScroll=Instance.new("ScrollingFrame",ListContainer)
ListScroll.Size=UDim2.new(1,0,1,0); ListScroll.BackgroundTransparency=1
ListScroll.BorderSizePixel=0; ListScroll.ScrollBarThickness=3
ListScroll.ScrollBarImageColor3=P.Accent; ListScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
ListScroll.CanvasSize=UDim2.new(0,0,0,0); ListScroll.ZIndex=4

local ListLayout=Instance.new("UIListLayout",ListScroll)
ListLayout.Padding=UDim.new(0,4); ListLayout.SortOrder=Enum.SortOrder.Name
local ListPad=Instance.new("UIPadding",ListScroll)
ListPad.PaddingTop=UDim.new(0,6); ListPad.PaddingBottom=UDim.new(0,6)
ListPad.PaddingLeft=UDim.new(0,6); ListPad.PaddingRight=UDim.new(0,6)

local EmptyLbl=Instance.new("TextLabel",ListScroll)
EmptyLbl.Name="__empty"; EmptyLbl.Size=UDim2.new(1,0,0,40)
EmptyLbl.BackgroundTransparency=1; EmptyLbl.Text="no players in server"
EmptyLbl.TextColor3=P.Grey; EmptyLbl.Font=Enum.Font.Gotham; EmptyLbl.TextSize=13; EmptyLbl.ZIndex=5

local function UpdateEmptyLabel()
    local has=false
    for _,v in pairs(ListScroll:GetChildren()) do
        if v:IsA("Frame") and v.Name~="__empty" then has=true; break end
    end
    EmptyLbl.Visible=not has
end

local function RefreshPlayerRow(pName)
    if Terminated then return end
    local existing=ListScroll:FindFirstChild(pName)

    if not existing then
        local row=Instance.new("Frame",ListScroll)
        row.Name=pName; row.Size=UDim2.new(1,0,0,38)
        row.BackgroundColor3=P.Card; row.BackgroundTransparency=0.45
        row.BorderSizePixel=0; row.ZIndex=5
        Instance.new("UICorner",row).CornerRadius=UDim.new(0,7)

        local dot=Instance.new("Frame",row)
        dot.Name="Dot"; dot.Size=UDim2.new(0,8,0,8); dot.Position=UDim2.new(0,10,0.5,-4)
        dot.BackgroundColor3=P.Grey; dot.BorderSizePixel=0; dot.ZIndex=6
        Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)

        local nameLbl=Instance.new("TextLabel",row)
        nameLbl.Name="NameLbl"; nameLbl.Size=UDim2.new(1,-130,1,0); nameLbl.Position=UDim2.new(0,26,0,0)
        nameLbl.BackgroundTransparency=1; nameLbl.Text=pName; nameLbl.TextColor3=P.White
        nameLbl.Font=Enum.Font.GothamBold; nameLbl.TextSize=14
        nameLbl.TextXAlignment=Enum.TextXAlignment.Left; nameLbl.ZIndex=6

        local badge=Instance.new("TextLabel",row)
        badge.Name="Badge"; badge.Size=UDim2.new(0,72,0,22); badge.Position=UDim2.new(1,-78,0.5,-11)
        badge.BackgroundTransparency=1; badge.Text=""; badge.TextColor3=P.Grey
        badge.Font=Enum.Font.GothamBold; badge.TextSize=12; badge.ZIndex=6
        Instance.new("UICorner",badge).CornerRadius=UDim.new(0,5)

        -- SINGLE full-row button — L-click = target, R-click = ally
        local hit=Instance.new("TextButton",row)
        hit.Size=UDim2.new(1,0,1,0); hit.BackgroundTransparency=1; hit.Text=""; hit.ZIndex=7

        hit.MouseButton1Click:Connect(function()
            local n=row.Name
            -- toggle target; clear ally if switching
            if PlayerStatus[n]=="target" then
                PlayerStatus[n]=nil
            else
                PlayerStatus[n]="target"
            end
            PlaySound("click.mp3",0.4); RefreshPlayerRow(n)
        end)

        hit.MouseButton2Click:Connect(function()
            local n=row.Name
            -- toggle ally; clear target if switching
            if PlayerStatus[n]=="ally" then
                PlayerStatus[n]=nil
            else
                PlayerStatus[n]="ally"
            end
            PlaySound("click.mp3",0.4); RefreshPlayerRow(n)
        end)

        existing=row
    end

    local status=PlayerStatus[pName]
    local dot=existing:FindFirstChild("Dot")
    local nLbl=existing:FindFirstChild("NameLbl")
    local badge=existing:FindFirstChild("Badge")

    if status=="ally" then
        Tween(existing,0.18,nil,nil,{BackgroundColor3=Color3.fromRGB(6,24,16),BackgroundTransparency=0.3})
        if dot   then dot.BackgroundColor3=P.Green end
        if nLbl  then nLbl.TextColor3=P.Green end
        if badge then badge.Text="◈ ALLY"; badge.TextColor3=P.Green; badge.BackgroundColor3=P.GreenDim; badge.BackgroundTransparency=0 end
    elseif status=="target" then
        Tween(existing,0.18,nil,nil,{BackgroundColor3=Color3.fromRGB(22,6,40),BackgroundTransparency=0.3})
        if dot   then dot.BackgroundColor3=P.Purple end
        if nLbl  then nLbl.TextColor3=P.Purple end
        if badge then badge.Text="◎ TARGET"; badge.TextColor3=P.Purple; badge.BackgroundColor3=P.PurpleDim; badge.BackgroundTransparency=0 end
    else
        Tween(existing,0.18,nil,nil,{BackgroundColor3=P.Card,BackgroundTransparency=0.45})
        if dot   then dot.BackgroundColor3=P.Grey end
        if nLbl  then nLbl.TextColor3=P.White end
        if badge then badge.Text=""; badge.BackgroundTransparency=1 end
    end
    UpdateEmptyLabel()
end

local function RemovePlayerRow(pName)
    local row=ListScroll:FindFirstChild(pName)
    if row then row:Destroy() end
    UpdateEmptyLabel()
end

local function UpdatePlayerList()
    if Terminated then return end
    local inGame={}
    for _,p in pairs(Players:GetPlayers()) do if p~=LocalPlayer then inGame[p.Name]=true end end
    for _,v in pairs(ListScroll:GetChildren()) do
        if v:IsA("Frame") and v.Name~="__empty" and not inGame[v.Name] then v:Destroy() end
    end
    for _,p in pairs(Players:GetPlayers()) do
        if p~=LocalPlayer then RefreshPlayerRow(p.Name) end
    end
    UpdateEmptyLabel()
end

-- ══════════════════════════════════════════
--  TAB: KEYBINDS
-- ══════════════════════════════════════════
local KeyF=TabFrames["KEYBINDS"]
MakeSectionHeader(KeyF,8,"KEYBINDS",S.Keybinds)

local KeyDefs={
    {label="AIM  (hold/toggle)", sym=S.Aimbot,   configKey="AimKey",  y=30 },
    {label="OPEN  GUI",          sym=S.Core,      configKey="GuiKey",  y=88 },
    {label="TERMINATE  script",  sym=S.Terminate, configKey="KillKey", y=146},
}
local KeyRows={}

for _,kd in ipairs(KeyDefs) do
    local row=Instance.new("Frame",KeyF)
    row.Size=UDim2.new(1,-24,0,50); row.Position=UDim2.new(0,12,0,kd.y)
    row.BackgroundColor3=P.Card; row.BackgroundTransparency=0.55
    row.BorderSizePixel=0; row.ZIndex=3
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)
    local rs=Instance.new("UIStroke",row); rs.Color=P.Border; rs.Thickness=1; rs.Transparency=0.7

    local ico=MakeIcon(row,kd.sym,28,6,4)
    TintIcon(ico, P.White, 0)
    if ico:IsA("ImageLabel") then
        ico.Size=UDim2.new(0,28,0,28); ico.Position=UDim2.new(0,6,0.5,-14)
    else ico.TextSize=26 end

    local lbl=Instance.new("TextLabel",row)
    lbl.Size=UDim2.new(0.55,0,1,0); lbl.Position=UDim2.new(0,42,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=kd.label; lbl.TextColor3=P.White
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=14
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=4

    local keyPill=Instance.new("TextButton",row)
    keyPill.Name="KeyPill"; keyPill.Size=UDim2.new(0,100,0,28); keyPill.Position=UDim2.new(1,-112,0.5,-14)
    keyPill.BackgroundColor3=P.DimGrey; keyPill.TextColor3=P.Accent
    keyPill.Font=Enum.Font.GothamBold; keyPill.TextSize=13; keyPill.BorderSizePixel=0; keyPill.ZIndex=5
    Instance.new("UICorner",keyPill).CornerRadius=UDim.new(0,6)

    local curKey=Config[kd.configKey]
    keyPill.Text=tostring(curKey.Name or curKey):upper()

    keyPill.MouseButton1Click:Connect(function()
        if Binding then return end
        Binding=true; BindTarget=kd.configKey
        keyPill.Text="[ press... ]"; keyPill.TextColor3=P.Red
        Tween(keyPill,0.2,nil,nil,{BackgroundColor3=Color3.fromRGB(50,0,0)})
        PlaySound("click.mp3",0.5)
    end)
    KeyRows[kd.configKey]=keyPill
end

-- ══════════════════════════════════════════
--  TAB: RESET
-- ══════════════════════════════════════════
local RstF=TabFrames["RESET"]
MakeSectionHeader(RstF,8,"RESET TO DEFAULTS",S.Reset)

local function MakeResetRow(parent,yPos,labelText,sym,onReset)
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,-24,0,48); row.Position=UDim2.new(0,12,0,yPos)
    row.BackgroundColor3=P.Card; row.BackgroundTransparency=0.55
    row.BorderSizePixel=0; row.ZIndex=3
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)

    local ico=MakeIcon(row,sym,28,6,4)
    TintIcon(ico,P.Red,0.5)
    if ico:IsA("ImageLabel") then
        ico.Size=UDim2.new(0,28,0,28); ico.Position=UDim2.new(0,6,0.5,-14)
    else ico.TextSize=26 end

    local lbl=Instance.new("TextLabel",row)
    lbl.Size=UDim2.new(0.6,0,1,0); lbl.Position=UDim2.new(0,42,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=labelText; lbl.TextColor3=P.White
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=14
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=4

    local rBtn=Instance.new("TextButton",row)
    rBtn.Size=UDim2.new(0,90,0,28); rBtn.Position=UDim2.new(1,-100,0.5,-14)
    rBtn.BackgroundColor3=Color3.fromRGB(55,12,12); rBtn.TextColor3=P.Red
    rBtn.Text="↺  RESET"; rBtn.Font=Enum.Font.GothamBold
    rBtn.TextSize=13; rBtn.BorderSizePixel=0; rBtn.ZIndex=5
    Instance.new("UICorner",rBtn).CornerRadius=UDim.new(0,6)

    rBtn.MouseButton1Click:Connect(function()
        PlaySound("click.mp3",0.6)
        Tween(rBtn,0.1,nil,nil,{BackgroundColor3=P.Red,TextColor3=P.Black})
        rBtn.Text="✓ DONE"
        task.delay(0.7,function()
            Tween(rBtn,0.2,nil,nil,{BackgroundColor3=Color3.fromRGB(55,12,12),TextColor3=P.Red})
            rBtn.Text="↺  RESET"
        end)
        onReset(); SaveConfig()
    end)
    return row
end

MakeResetRow(RstF,32,"Aimbot Settings",S.Aimbot,function()
    Config.IsAggressive=Defaults.IsAggressive; Config.Smoothness=Defaults.Smoothness
    Config.Prediction=Defaults.Prediction; Config.FovRadius=Defaults.FovRadius
    Config.IsHoldMode=Defaults.IsHoldMode; Config.Enabled=Defaults.Enabled
    SetSmooth(Config.Smoothness); SetPred(Config.Prediction); SetFov(Config.FovRadius)
    RefreshPreset(); RefreshModeButtons(); SetToggleState(aimBar,aimPill,Config.Enabled)
end)
MakeResetRow(RstF,88,"Keybinds",S.Keybinds,function()
    Config.AimKey=Defaults.AimKey; Config.GuiKey=Defaults.GuiKey; Config.KillKey=Defaults.KillKey
    for _,k in ipairs({"AimKey","GuiKey","KillKey"}) do
        local pill=KeyRows[k]
        if pill then local v=Config[k]; pill.Text=tostring(v.Name or v):upper(); pill.TextColor3=P.Accent; Tween(pill,0.2,nil,nil,{BackgroundColor3=P.DimGrey}) end
    end
end)
MakeResetRow(RstF,144,"ESP",S.ESP,function()
    Config.EspEnabled=Defaults.EspEnabled; SetToggleState(espBar,espPill,Config.EspEnabled)
end)
MakeResetRow(RstF,200,"Targeting",S.Targeting,function()
    Config.TargetLowestHP=Defaults.TargetLowestHP; Config.TargetSpecific=Defaults.TargetSpecific
    SetToggleState(hpBar,hpPill,Config.TargetLowestHP); SetToggleState(spBar,spPill,Config.TargetSpecific)
end)
MakeResetRow(RstF,256,"Camera FOV",S.Camera,function()
    Config.CameraFov=Defaults.CameraFov; Camera.FieldOfView=Defaults.CameraFov; SetFovValue(Defaults.CameraFov)
end)

local div=Instance.new("Frame",RstF)
div.Size=UDim2.new(1,-24,0,1); div.Position=UDim2.new(0,12,0,318)
div.BackgroundColor3=P.Border; div.BackgroundTransparency=0.55; div.BorderSizePixel=0; div.ZIndex=3

local nukeRow=Instance.new("Frame",RstF)
nukeRow.Size=UDim2.new(1,-24,0,52); nukeRow.Position=UDim2.new(0,12,0,328)
nukeRow.BackgroundColor3=Color3.fromRGB(28,6,6); nukeRow.BackgroundTransparency=0.2
nukeRow.BorderSizePixel=0; nukeRow.ZIndex=3
Instance.new("UICorner",nukeRow).CornerRadius=UDim.new(0,8)
local nukeStroke=Instance.new("UIStroke",nukeRow)
nukeStroke.Color=P.Red; nukeStroke.Thickness=1; nukeStroke.Transparency=0.55

local nukeLbl=Instance.new("TextLabel",nukeRow)
nukeLbl.Size=UDim2.new(1,-20,1,0); nukeLbl.Position=UDim2.new(0,14,0,0)
nukeLbl.BackgroundTransparency=1; nukeLbl.Text="↺  RESET EVERYTHING"
nukeLbl.TextColor3=P.Red; nukeLbl.Font=Enum.Font.GothamBold
nukeLbl.TextSize=15; nukeLbl.TextXAlignment=Enum.TextXAlignment.Left; nukeLbl.ZIndex=4

local nukeBtn=Instance.new("TextButton",nukeRow)
nukeBtn.Size=UDim2.new(1,0,1,0); nukeBtn.BackgroundTransparency=1; nukeBtn.Text=""; nukeBtn.ZIndex=5

nukeBtn.MouseButton1Click:Connect(function()
    PlaySound("click.mp3",0.8)
    Tween(nukeRow,0.12,nil,nil,{BackgroundColor3=Color3.fromRGB(70,0,0)}); nukeLbl.Text="✓  ALL RESET"
    task.delay(1,function() Tween(nukeRow,0.3,nil,nil,{BackgroundColor3=Color3.fromRGB(28,6,6)}); nukeLbl.Text="↺  RESET EVERYTHING" end)
    for k,v in pairs(Defaults) do Config[k]=v end
    SetSmooth(Config.Smoothness); SetPred(Config.Prediction); SetFov(Config.FovRadius)
    SetFovValue(Config.CameraFov); Camera.FieldOfView=Config.CameraFov
    RefreshPreset(); RefreshModeButtons()
    SetToggleState(espBar,espPill,Config.EspEnabled); SetToggleState(aimBar,aimPill,Config.Enabled)
    SetToggleState(hpBar,hpPill,Config.TargetLowestHP); SetToggleState(spBar,spPill,Config.TargetSpecific)
    for _,k in ipairs({"AimKey","GuiKey","KillKey"}) do
        local pill=KeyRows[k]; if pill then local v=Config[k]; pill.Text=tostring(v.Name or v):upper(); pill.TextColor3=P.Accent; Tween(pill,0.2,nil,nil,{BackgroundColor3=P.DimGrey}) end
    end
    SaveConfig()
end)

-- ══════════════════════════════════════════
--  LOADING SCREEN
-- ══════════════════════════════════════════
local LoadFrame=Instance.new("Frame",ScreenGui)
LoadFrame.Size=UDim2.new(0,380,0,160); LoadFrame.Position=UDim2.new(0.5,-190,0.5,-80)
LoadFrame.BackgroundColor3=P.BG; LoadFrame.BackgroundTransparency=0.08; LoadFrame.BorderSizePixel=0
Instance.new("UICorner",LoadFrame).CornerRadius=UDim.new(0,14)
local lsStroke=Instance.new("UIStroke",LoadFrame); lsStroke.Color=P.Accent; lsStroke.Thickness=1; lsStroke.Transparency=0.5

local LoadWM=Instance.new("TextLabel",LoadFrame)
LoadWM.Size=UDim2.new(1,0,1,0); LoadWM.BackgroundTransparency=1; LoadWM.Text="◎"
LoadWM.TextColor3=P.Accent; LoadWM.TextTransparency=0.88; LoadWM.Font=Enum.Font.GothamBold; LoadWM.TextSize=130

local LoadTitle=Instance.new("TextLabel",LoadFrame)
LoadTitle.Size=UDim2.new(1,0,0,36); LoadTitle.Position=UDim2.new(0,0,0,10)
LoadTitle.BackgroundTransparency=1; LoadTitle.Text="CRUSTY SKILLS"
LoadTitle.TextColor3=P.White; LoadTitle.Font=Enum.Font.GothamBold; LoadTitle.TextSize=24

local LoadStatus=Instance.new("TextLabel",LoadFrame)
LoadStatus.Size=UDim2.new(1,-20,0,22); LoadStatus.Position=UDim2.new(0,10,0,46)
LoadStatus.BackgroundTransparency=1; LoadStatus.Text="Initializing..."
LoadStatus.TextColor3=P.Grey; LoadStatus.Font=Enum.Font.Gotham; LoadStatus.TextSize=13; LoadStatus.TextXAlignment=Enum.TextXAlignment.Left

local BarBack=Instance.new("Frame",LoadFrame)
BarBack.Size=UDim2.new(0.88,0,0,5); BarBack.Position=UDim2.new(0.06,0,0,80)
BarBack.BackgroundColor3=P.DimGrey; BarBack.BorderSizePixel=0
Instance.new("UICorner",BarBack).CornerRadius=UDim.new(1,0)

local BarFill=Instance.new("Frame",BarBack)
BarFill.Size=UDim2.new(0,0,1,0); BarFill.BackgroundColor3=P.Accent; BarFill.BorderSizePixel=0
Instance.new("UICorner",BarFill).CornerRadius=UDim.new(1,0)

local LoadDetails=Instance.new("TextLabel",LoadFrame)
LoadDetails.Size=UDim2.new(1,-20,0,60); LoadDetails.Position=UDim2.new(0,10,0,92)
LoadDetails.BackgroundTransparency=1; LoadDetails.Text=""
LoadDetails.TextColor3=P.Grey; LoadDetails.Font=Enum.Font.Gotham; LoadDetails.TextSize=12
LoadDetails.TextXAlignment=Enum.TextXAlignment.Left; LoadDetails.TextYAlignment=Enum.TextYAlignment.Top; LoadDetails.TextWrapped=true

local function SetProgress(ratio,status,details)
    TweenService:Create(BarFill,TweenInfo.new(0.4),{Size=UDim2.new(ratio,0,1,0)}):Play()
    if status  then LoadStatus.Text=status   end
    if details then LoadDetails.Text=details end
end

-- ══════════════════════════════════════════
--  CORE ENGINE
-- ══════════════════════════════════════════
local function IsAlly(player)
    -- ally = only what you manually tagged via R-click in the player list
    return PlayerStatus[player.Name] == "ally"
end

local function GetEspColor(player)
    if IsAlly(player) then return P.Green  end
    if PlayerStatus[player.Name]=="target" then return P.Purple end
    return P.Red  -- enemy/neutral = red always
end

local function Create3DBox(player)
    if not player or not player.Parent then return end
    local char=player.Character; if not char then return end
    local root=char:FindFirstChild("HumanoidRootPart"); if not root then return end

    -- ── DISTANCE CULL: skip box if player is way too far away ──
    local myChar  = LocalPlayer.Character
    local myRoot  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if myRoot and (myRoot.Position - root.Position).Magnitude > ESP_CULL_DISTANCE then return end

    -- destroy old box + tracer if rebuilding
    if ESP_Table[player] then
        pcall(function() ESP_Table[player].Box:Destroy() end)
    end

    local Box=Instance.new("BoxHandleAdornment")
    Box.Name="BountyBox"; Box.AlwaysOnTop=true; Box.ZIndex=10
    Box.Transparency=0.55; Box.Size=Vector3.new(4.5,6,4.5)
    Box.Color3=Color3.fromRGB(255,70,70)
    Box.Adornee=root; Box.Parent=root


    -- Hook combat detection on humanoid
    local hum=char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.HealthChanged:Connect(function(newHp)
            if Terminated then return end
            -- if localplayer's character exists and this player took damage,
            -- check if our character has a local humanoid that also recently changed
            -- Simple heuristic: any health drop = combat with someone, mark as combat
            local myChar=LocalPlayer.Character
            local myHum=myChar and myChar:FindFirstChildOfClass("Humanoid")
            -- mark combat if this player lost HP (they were hit — possibly by us)
            if newHp < (hum.MaxHealth * 0.999) then
                CombatTable[player]=tick()
            end
        end)
        -- also watch our own humanoid: if we take damage, anyone in close range is in combat
        local myChar=LocalPlayer.Character
        local myHum=myChar and myChar:FindFirstChildOfClass("Humanoid")
        if myHum then
            myHum.HealthChanged:Connect(function()
                if Terminated then return end
                -- mark all players within 60 studs as combat
                if root and root.Parent then
                    local myRoot=myChar:FindFirstChild("HumanoidRootPart")
                    if myRoot and (myRoot.Position-root.Position).Magnitude < 60 then
                        CombatTable[player]=tick()
                    end
                end
            end)
        end
    end

    ESP_Table[player]={Box=Box, Root=root}
end

local function CleanESP(player)
    -- destroy tracked box + tracer
    if ESP_Table[player] then
        pcall(function() ESP_Table[player].Box:Destroy() end)
        ESP_Table[player]=nil
    end
    -- sweep character for orphaned boxes
    pcall(function()
        if player.Character then
            for _,c in pairs(player.Character:GetDescendants()) do
                if c.Name=="BountyBox" then c:Destroy() end
            end
        end
    end)
    -- sweep workspace for any boxes attached to this player by name
    pcall(function()
        for _,v in pairs(workspace:GetDescendants()) do
            if (v.Name=="BountyBox" and v:IsA("BoxHandleAdornment"))
                local adornee=v.Adornee
                if adornee and adornee.Parent and adornee.Parent.Name==player.Name then
                    v:Destroy()
                end
            end
        end
    end)
end

local function GlobalCleanup()
    if Terminated then return end
    Terminated = true
    Config.Enabled   = false
    Config.AimActive = false

    -- 1. restore camera
    Camera.FieldOfView = OriginalFov

    -- 2. disconnect ALL connections so nothing fires after kill
    if InputConn         then InputConn:Disconnect();         InputConn         = nil end
    if PlayerAddedConn   then PlayerAddedConn:Disconnect();   PlayerAddedConn   = nil end
    if PlayerRemovingConn then PlayerRemovingConn:Disconnect(); PlayerRemovingConn = nil end

    -- 3. unbind render step immediately
    pcall(function() RunService:UnbindFromRenderStep("BountySync") end)

    -- 4. destroy every tracked ESP box + tracer
    for _, data in pairs(ESP_Table) do
        pcall(function() data.Box:Destroy() end)
    end
    ESP_Table = {}

    -- 5. nuclear workspace sweep — catches any orphaned boxes/tracers
    pcall(function()
        for _, v in pairs(workspace:GetDescendants()) do
            if (v.Name == "BountyBox"    and v:IsA("BoxHandleAdornment"))
                v:Destroy()
            end
        end
    end)

    -- 6. kill GUI with fade
    if Main and Main.Parent then
        TweenService:Create(Main, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            {Position = UDim2.new(0.5, -280, 1.6, 0)}):Play()
    end
    task.wait(0.35)
    if ScreenGui and ScreenGui.Parent then
        ScreenGui:Destroy()
    end
    -- script fully dead — no error() so console stays clean
end

-- ── EVENT-DRIVEN PLAYER TRACKING ────────────────────────
local PlayerAddedConn    = nil
local PlayerRemovingConn = nil

local function RegisterPlayer(player)
    if player == LocalPlayer then return end
    -- hook CharacterAdded — Terminated guard so respawns after F8 do nothing
    player.CharacterAdded:Connect(function()
        if Terminated then return end
        task.wait(0.5)
        if Terminated then return end
        pcall(function() Create3DBox(player) end)
    end)
    if player.Character then
        pcall(function() Create3DBox(player) end)
    end
    RefreshPlayerRow(player.Name)
end

local function OnPlayerAdded(player)
    if Terminated then return end
    RegisterPlayer(player)
end

local function OnPlayerRemoving(player)
    if player==LocalPlayer then return end
    pcall(function() CleanESP(player) end)
    PlayerStatus[player.Name]=nil
    if not Terminated then RemovePlayerRow(player.Name) end
end

PlayerAddedConn    = Players.PlayerAdded:Connect(OnPlayerAdded)
PlayerRemovingConn = Players.PlayerRemoving:Connect(OnPlayerRemoving)

-- Pre-load ALL players already in the server right now
for _,p in pairs(Players:GetPlayers()) do
    RegisterPlayer(p)
end

-- MASTER SYNC LOOP
RunService:BindToRenderStep("BountySync",Enum.RenderPriority.Camera.Value+1,function()
    if Terminated then return end
    local mousePos=UserInputService:GetMouseLocation()

    local anySpecific=false
    if Config.TargetSpecific then
        for _,p in pairs(Players:GetPlayers()) do
            if PlayerStatus[p.Name]=="target" then anySpecific=true; break end
        end
    end

    local target,finalAimPos=nil,nil
    local closestDist=math.huge  -- world distance in studs, reset each frame
    local lowestHP=math.huge     -- reset each frame

    for player,data in pairs(ESP_Table) do
        -- validate: player still in game, has character and a live root
        if player.Parent and player.Character
            and data.Root and data.Root.Parent then

            local ally = IsAlly(player)

            -- ESP box updates (only if box exists)
            if data.Box and data.Box.Parent then
                data.Box.Color3  = GetEspColor(player)
                data.Box.Visible = Config.EspEnabled
            end

            -- ── AIMBOT TARGETING ──
            if Config.Enabled and not ally then
                local canTarget = true
                local myTeam    = LocalPlayer.Team
                local theirTeam = player.Team
                -- same team = skip
                if myTeam and theirTeam and myTeam == theirTeam then
                    canTarget = false
                end
                -- specific mode filter
                if anySpecific and PlayerStatus[player.Name] ~= "target" then
                    canTarget = false
                end

                if canTarget then
                    local vel       = data.Root.Velocity
                    if typeof(vel) ~= "Vector3" then vel = Vector3.new(0,0,0) end
                    local predicted = data.Root.Position + (vel * Config.Prediction)
                    local sPos, onScreen = Camera:WorldToViewportPoint(predicted)

                    -- must be in front of camera to aim at
                    if onScreen then
                        if Config.TargetLowestHP then
                            -- LOWEST HP: no FOV gate, just pick the enemy with least HP
                            local hum = player.Character:FindFirstChildOfClass("Humanoid")
                            if hum and hum.Health > 0 and hum.Health < lowestHP then
                                lowestHP    = hum.Health
                                target      = player
                                finalAimPos = sPos
                            end
                        else
                            -- CLOSEST: pure 3D world distance to local player
                            local myChar = LocalPlayer.Character
                            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                            if myRoot then
                                local worldDist = (myRoot.Position - data.Root.Position).Magnitude
                                if worldDist < closestDist then
                                    closestDist = worldDist
                                    target      = player
                                    finalAimPos = sPos
                                end
                            end
                        end
                    end
                end
            end
        else
            -- root gone — hide box if it exists
            if data.Box then pcall(function() data.Box.Visible = false end) end
        end
    end

    if Config.Enabled then
        local isInput=false
        if Config.IsHoldMode then
            isInput=UserInputService:IsKeyDown(Config.AimKey)
                or(Config.AimKey==Enum.UserInputType.MouseButton2
                    and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2))
        else
            -- toggle mode: just mirror AimActive, same logic as hold
            isInput=Config.AimActive
        end

        -- Ctrl suppresses aimbot while held (toggle mode only makes sense, works in both)
        local ctrlHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

        if isInput and not ctrlHeld and target and finalAimPos then
            pcall(mousemoverel,
                (finalAimPos.X - mousePos.X) * Config.Smoothness,
                (finalAimPos.Y - mousePos.Y) * Config.Smoothness
            )
        end
    end
end)

-- ESP maintenance loop (100ms)
local CtrlWasHeld = false
task.spawn(function()
    while task.wait(Config.RefreshRate) and not Terminated and ScreenGui.Parent do
        -- clean dead entries and rebuild if root changed
        for player,data in pairs(ESP_Table) do
            local char=player.Character
            local root=char and char:FindFirstChild("HumanoidRootPart")
            if not player.Parent or not char or not root then
                -- player/char gone — destroy and remove
                if data.Box then pcall(function() data.Box:Destroy() end) end
                ESP_Table[player]=nil
            elseif data.Root ~= root then
                -- root changed (respawn) — destroy old box and rebuild if still in range
                if data.Box then pcall(function() data.Box:Destroy() end) end
                ESP_Table[player] = nil
                pcall(function() Create3DBox(player) end)  -- cull check inside Create3DBox
            end
        end
        -- expire old combat flags (> 6 seconds old)
        local now=tick()
        for p,t in pairs(CombatTable) do
            if (now-t) > 6 then CombatTable[p]=nil end
        end
        -- sync team label
        TeamLbl.Text="FACTION: "..(LocalPlayer.Team and LocalPlayer.Team.Name:upper() or "—")
        -- ctrl notification
        local ctrlNow = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
        if ctrlNow ~= CtrlWasHeld then
            CtrlWasHeld = ctrlNow
            if Config.Enabled and Config.AimActive then
                if ctrlNow then
                    Notify("CTRL HELD  —  aim paused", false)
                else
                    Notify("CTRL released  —  aim active", true)
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════
--  INPUT HANDLER
-- ══════════════════════════════════════════
InputConn=UserInputService.InputBegan:Connect(function(input,processed)
    if Terminated then return end

    -- keybind capture — runs before everything, ignores processed
    if Binding then
        local newKey=(input.KeyCode~=Enum.KeyCode.Unknown and input.KeyCode) or input.UserInputType
        Config[BindTarget]=newKey
        local pill=KeyRows[BindTarget]
        if pill then
            pill.Text=tostring(newKey.Name or newKey):upper()
            pill.TextColor3=P.Accent
            Tween(pill,0.2,nil,nil,{BackgroundColor3=P.DimGrey})
        end
        Binding=false; BindTarget=nil; PlaySound("click.mp3",0.8); SaveConfig()
        return
    end

    -- toggle aim — must run BEFORE processed guard so it always fires
    if not Config.IsHoldMode then
        if input.KeyCode==Config.AimKey or input.UserInputType==Config.AimKey then
            Config.AimActive=not Config.AimActive
            if Config.AimActive then
                Notify("AIMBOT  ON",  true,  true)
            else
                Notify("AIMBOT  OFF", false, true)
            end
            return  -- don't fall through
        end
    end

    if processed then return end

    -- GUI open/close
    if input.KeyCode==Config.GuiKey then
        GuiVisible=not GuiVisible
        if GuiVisible then
            PlaySound("open.mp3",0.6)
            Spring(Main,0.55,{Position=UDim2.new(0.5,-280,0.5,-195)})
        else
            PlaySound("close.mp3",0.6)
            TweenService:Create(Main,TweenInfo.new(0.4,Enum.EasingStyle.Back,Enum.EasingDirection.In),
                {Position=UDim2.new(0.5,-280,1.6,0)}):Play()
        end
        return
    end

    -- terminate
    if input.KeyCode==Config.KillKey then
        GlobalCleanup()
    end
end)

-- ══════════════════════════════════════════
--  LOADING SEQUENCE
-- ══════════════════════════════════════════
task.spawn(function()
    PlaySound("startup.mp3",0.5)

    SetProgress(0.05,"Waiting for character...","")
    local w=0; while not LocalPlayer.Character and w<5 do task.wait(0.1); w=w+0.1 end

    SetProgress(0.18,"Resolving faction...",""); task.wait(0.5)
    local faction=LocalPlayer.Team and LocalPlayer.Team.Name or "None"
    TeamLbl.Text="FACTION: "..faction:upper()
    SetProgress(0.30,"Faction: "..faction:upper(),""); task.wait(0.4)

    SetProgress(0.44,"Building ESP...","")
    local built=0
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer then
            if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                pcall(function() Create3DBox(p) end)
                built=built+1; LoadDetails.Text="ESP: "..p.Name; task.wait(0.06)
            end
        end
    end
    SetProgress(0.62,"ESP ready — "..built.." player(s)",""); task.wait(0.35)

    SetProgress(0.76,"Building player list...","")
    UpdatePlayerList(); task.wait(0.35)

    SetProgress(0.88,"Applying saved config...","")
    Camera.FieldOfView=Config.CameraFov; SetFovValue(Config.CameraFov)
    SetSmooth(Config.Smoothness); SetPred(Config.Prediction); SetFov(Config.FovRadius)
    RefreshPreset(); RefreshModeButtons()
    SetToggleState(espBar,espPill,Config.EspEnabled); SetToggleState(aimBar,aimPill,Config.Enabled)
    SetToggleState(hpBar,hpPill,Config.TargetLowestHP); SetToggleState(spBar,spPill,Config.TargetSpecific)
    task.wait(0.4)

    SetProgress(1.0,"Ready.","All systems online."); task.wait(0.9)

    for _,obj in ipairs({LoadFrame,LoadTitle,LoadStatus,LoadDetails,LoadWM,BarBack,BarFill}) do
        TweenService:Create(obj,TweenInfo.new(0.45),{BackgroundTransparency=1}):Play()
        if obj:IsA("TextLabel") then TweenService:Create(obj,TweenInfo.new(0.45),{TextTransparency=1}):Play() end
    end
    task.wait(0.5); LoadFrame:Destroy()

    GuiVisible=true; PlaySound("open.mp3",0.6)
    Spring(Main,0.65,{Position=UDim2.new(0.5,-280,0.5,-195)})
    task.wait(0.15); SwitchTab("CORE")
end)
