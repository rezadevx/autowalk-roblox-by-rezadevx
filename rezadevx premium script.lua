local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local HAS_FS = (writefile and readfile and isfile and listfiles and delfile and makefolder)
local FOLDER_NAME = "rezadevxautowalk"

if HAS_FS and not isfolder(FOLDER_NAME) then
    makefolder(FOLDER_NAME)
end

local MacroData = {}
local AnimDict = {}
local NextAnimId = 1
local AnimCache = {}

local State = "Idle"
local Connection = nil
local PlaybackSpeed = 1.0

local RecordStartTime = 0
local PlaybackCurrentTime = 0
local PlaybackIndex = 1
local LastForcedSample = 0

local AP_Mover, AO_Mover, MoverAttachment

local function CleanupMovers()
    if AP_Mover then AP_Mover:Destroy() AP_Mover = nil end
    if AO_Mover then AO_Mover:Destroy() AO_Mover = nil end
    if MoverAttachment then MoverAttachment:Destroy() MoverAttachment = nil end
end

local function ResetToIdleState()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if hum then
        local animator = hum:FindFirstChild("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                track:Stop(0)
            end
        end
    end
    if char:FindFirstChild("Animate") then
        char.Animate.Disabled = false
    end
    LocalPlayer:Move(Vector3.zero, false)
    CleanupMovers()
end

local function CleanConn()
    if Connection then
        Connection:Disconnect()
        Connection = nil
    end
    ResetToIdleState()
end

local guiParent = pcall(function() return CoreGui.Name end) and CoreGui or LocalPlayer:WaitForChild("PlayerGui")
if guiParent:FindFirstChild("rezadevx_premium") then
    guiParent.rezadevx_premium:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "rezadevx_premium"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = guiParent

local function mkCorner(p, r)
    local c = Instance.new("UICorner", p)
    c.CornerRadius = UDim.new(0, r or 8)
end

local function mkStroke(p, col, th)
    local s = Instance.new("UIStroke", p)
    s.Color = col
    s.Thickness = th or 1
end

local BG       = Color3.fromRGB(9, 11, 17)
local HDR      = Color3.fromRGB(13, 15, 23)
local PANEL    = Color3.fromRGB(15, 18, 27)
local CARD     = Color3.fromRGB(19, 22, 33)
local CARDHOV  = Color3.fromRGB(26, 30, 46)
local DIV      = Color3.fromRGB(30, 34, 52)
local GOLD     = Color3.fromRGB(192, 162, 112)
local GOLD2    = Color3.fromRGB(148, 122, 80)
local BLUE     = Color3.fromRGB(82, 112, 192)
local TXT1     = Color3.fromRGB(228, 228, 238)
local TXT2     = Color3.fromRGB(140, 145, 168)

local COL_REC  = Color3.fromRGB(158, 42, 52)
local COL_RECH = Color3.fromRGB(185, 58, 68)
local COL_STP  = Color3.fromRGB(55, 60, 82)
local COL_STPH = Color3.fromRGB(70, 76, 104)
local COL_PLY  = Color3.fromRGB(34, 146, 90)
local COL_PLYH = Color3.fromRGB(44, 172, 108)
local COL_PSE  = Color3.fromRGB(165, 110, 36)
local COL_PSEH = Color3.fromRGB(194, 132, 48)
local COL_DEL  = Color3.fromRGB(136, 38, 48)
local COL_DELH = Color3.fromRGB(160, 52, 62)

local OpenBtn = Instance.new("ImageButton")
OpenBtn.Name = "OpenBtn"
OpenBtn.Size = UDim2.new(0, 44, 0, 44)
OpenBtn.Position = UDim2.new(0, 12, 0.5, -22)
OpenBtn.BackgroundColor3 = HDR
OpenBtn.Image = "rbxassetid://6035047409"
OpenBtn.ImageColor3 = GOLD
OpenBtn.Visible = false
OpenBtn.Parent = ScreenGui
mkCorner(OpenBtn, 22)
mkStroke(OpenBtn, GOLD, 1.5)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 510, 0, 430)
MainFrame.Position = UDim2.new(0.5, -255, 0.5, -215)
MainFrame.BackgroundColor3 = BG
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui
mkCorner(MainFrame, 14)
mkStroke(MainFrame, GOLD, 1)

local DropShadow = Instance.new("ImageLabel")
DropShadow.AnchorPoint = Vector2.new(0.5, 0.5)
DropShadow.BackgroundTransparency = 1
DropShadow.Position = UDim2.new(0.5, 0, 0.5, 10)
DropShadow.Size = UDim2.new(1, 65, 1, 65)
DropShadow.ZIndex = -1
DropShadow.Image = "rbxassetid://6015897843"
DropShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
DropShadow.ImageTransparency = 0.42
DropShadow.ScaleType = Enum.ScaleType.Slice
DropShadow.SliceCenter = Rect.new(49, 49, 450, 450)
DropShadow.Parent = MainFrame

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 50)
Header.BackgroundColor3 = HDR
Header.BorderSizePixel = 0
Header.Parent = MainFrame
mkCorner(Header, 14)

local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1, 0, 0, 16)
HeaderFix.Position = UDim2.new(0, 0, 1, -16)
HeaderFix.BackgroundColor3 = HDR
HeaderFix.BorderSizePixel = 0
HeaderFix.Parent = Header

local GoldLine = Instance.new("Frame")
GoldLine.Size = UDim2.new(1, -24, 0, 1)
GoldLine.Position = UDim2.new(0, 12, 0, 50)
GoldLine.BackgroundColor3 = GOLD
GoldLine.BackgroundTransparency = 0.55
GoldLine.BorderSizePixel = 0
GoldLine.Parent = MainFrame

local BrandDot = Instance.new("Frame")
BrandDot.Size = UDim2.new(0, 7, 0, 7)
BrandDot.AnchorPoint = Vector2.new(0, 0.5)
BrandDot.Position = UDim2.new(0, 15, 0.5, 0)
BrandDot.BackgroundColor3 = GOLD
BrandDot.BorderSizePixel = 0
BrandDot.Parent = Header
mkCorner(BrandDot, 4)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -115, 0, 20)
Title.Position = UDim2.new(0, 28, 0, 9)
Title.BackgroundTransparency = 1
Title.RichText = true
Title.Text = 'REZADEVX  <font color="rgb(192,162,112)">PREMIUM</font>'
Title.TextColor3 = TXT1
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local VerLabel = Instance.new("TextLabel")
VerLabel.Size = UDim2.new(0, 160, 0, 12)
VerLabel.Position = UDim2.new(0, 28, 0, 33)
VerLabel.BackgroundTransparency = 1
VerLabel.Text = "Macro Studio  ·  v7.0"
VerLabel.TextColor3 = GOLD2
VerLabel.Font = Enum.Font.Gotham
VerLabel.TextSize = 9
VerLabel.TextXAlignment = Enum.TextXAlignment.Left
VerLabel.Parent = Header

local MinBtn = Instance.new("TextButton")
MinBtn.Name = "MinBtn"
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.AnchorPoint = Vector2.new(1, 0.5)
MinBtn.Position = UDim2.new(1, -42, 0.5, 0)
MinBtn.BackgroundColor3 = CARD
MinBtn.Text = "—"
MinBtn.TextColor3 = TXT2
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 16
MinBtn.AutoButtonColor = false
MinBtn.Parent = Header
mkCorner(MinBtn, 8)
mkStroke(MinBtn, DIV, 1)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.AnchorPoint = Vector2.new(1, 0.5)
CloseBtn.Position = UDim2.new(1, -8, 0.5, 0)
CloseBtn.BackgroundColor3 = COL_REC
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = TXT1
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = Header
mkCorner(CloseBtn, 8)

local function CreateBtn(parent, name, text, baseCol, hovCol, yPos, h)
    local b = Instance.new("TextButton")
    b.Name = name
    b.Size = UDim2.new(1, 0, 0, h or 34)
    b.Position = UDim2.new(0, 0, 0, yPos)
    b.BackgroundColor3 = baseCol
    b.Text = text
    b.TextColor3 = TXT1
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.AutoButtonColor = false
    b.Parent = parent
    mkCorner(b, 8)
    mkStroke(b, baseCol:Lerp(Color3.new(1, 1, 1), 0.18), 1)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = hovCol}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = baseCol}):Play()
    end)
    return b
end

local function SectionLbl(parent, text, yPos)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 14)
    l.Position = UDim2.new(0, 0, 0, yPos)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = GOLD2
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 9
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local LeftPanel = Instance.new("Frame")
LeftPanel.Name = "LeftPanel"
LeftPanel.Size = UDim2.new(0, 228, 0, 362)
LeftPanel.Position = UDim2.new(0, 12, 0, 58)
LeftPanel.BackgroundTransparency = 1
LeftPanel.Parent = MainFrame

local StatusPanel = Instance.new("Frame")
StatusPanel.Name = "StatusPanel"
StatusPanel.Size = UDim2.new(1, 0, 0, 32)
StatusPanel.Position = UDim2.new(0, 0, 0, 0)
StatusPanel.BackgroundColor3 = CARD
StatusPanel.Parent = LeftPanel
mkCorner(StatusPanel, 8)
mkStroke(StatusPanel, DIV, 1)

local StatusDot = Instance.new("Frame")
StatusDot.Name = "StatusDot"
StatusDot.Size = UDim2.new(0, 8, 0, 8)
StatusDot.AnchorPoint = Vector2.new(0, 0.5)
StatusDot.Position = UDim2.new(0, 10, 0.5, 0)
StatusDot.BackgroundColor3 = TXT2
StatusDot.BorderSizePixel = 0
StatusDot.Parent = StatusPanel
mkCorner(StatusDot, 4)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Size = UDim2.new(1, -26, 1, 0)
StatusLabel.Position = UDim2.new(0, 24, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Idle"
StatusLabel.TextColor3 = TXT2
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.TextSize = 11
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = StatusPanel

SectionLbl(LeftPanel, "REKAM", 40)
local RecordBtn = CreateBtn(LeftPanel, "RecordBtn", "⬤  REKAM", COL_REC, COL_RECH, 56)
local StopBtn   = CreateBtn(LeftPanel, "StopBtn",   "■  STOP / SIMPAN", COL_STP, COL_STPH, 96)

SectionLbl(LeftPanel, "KECEPATAN PUTAR", 140)

local SpeedFrame = Instance.new("Frame")
SpeedFrame.Name = "SpeedFrame"
SpeedFrame.Size = UDim2.new(1, 0, 0, 34)
SpeedFrame.Position = UDim2.new(0, 0, 0, 156)
SpeedFrame.BackgroundColor3 = CARD
SpeedFrame.Parent = LeftPanel
mkCorner(SpeedFrame, 8)
mkStroke(SpeedFrame, DIV, 1)

local SpeedMinBtn = Instance.new("TextButton")
SpeedMinBtn.Name = "SpeedMinBtn"
SpeedMinBtn.Size = UDim2.new(0, 34, 1, -8)
SpeedMinBtn.AnchorPoint = Vector2.new(0, 0.5)
SpeedMinBtn.Position = UDim2.new(0, 4, 0.5, 0)
SpeedMinBtn.BackgroundColor3 = PANEL
SpeedMinBtn.Text = "−"
SpeedMinBtn.TextColor3 = TXT1
SpeedMinBtn.Font = Enum.Font.GothamBold
SpeedMinBtn.TextSize = 16
SpeedMinBtn.AutoButtonColor = false
SpeedMinBtn.Parent = SpeedFrame
mkCorner(SpeedMinBtn, 6)

local SpeedText = Instance.new("TextLabel")
SpeedText.Name = "SpeedText"
SpeedText.Size = UDim2.new(1, -80, 1, 0)
SpeedText.Position = UDim2.new(0, 40, 0, 0)
SpeedText.BackgroundTransparency = 1
SpeedText.Text = "1.0×"
SpeedText.TextColor3 = GOLD
SpeedText.Font = Enum.Font.GothamBold
SpeedText.TextSize = 13
SpeedText.Parent = SpeedFrame

local SpeedMaxBtn = Instance.new("TextButton")
SpeedMaxBtn.Name = "SpeedMaxBtn"
SpeedMaxBtn.Size = UDim2.new(0, 34, 1, -8)
SpeedMaxBtn.AnchorPoint = Vector2.new(1, 0.5)
SpeedMaxBtn.Position = UDim2.new(1, -4, 0.5, 0)
SpeedMaxBtn.BackgroundColor3 = PANEL
SpeedMaxBtn.Text = "+"
SpeedMaxBtn.TextColor3 = TXT1
SpeedMaxBtn.Font = Enum.Font.GothamBold
SpeedMaxBtn.TextSize = 16
SpeedMaxBtn.AutoButtonColor = false
SpeedMaxBtn.Parent = SpeedFrame
mkCorner(SpeedMaxBtn, 6)

SectionLbl(LeftPanel, "PUTAR", 198)
local PlayBtn  = CreateBtn(LeftPanel, "PlayBtn",  "▶  PUTAR REKAMAN",  COL_PLY,  COL_PLYH,  214)
local PauseBtn = CreateBtn(LeftPanel, "PauseBtn", "⏸  JEDA / LANJUT", COL_PSE,  COL_PSEH,  254)

SectionLbl(LeftPanel, "NAMA FILE", 298)

local FileInput = Instance.new("TextBox")
FileInput.Name = "FileInput"
FileInput.Size = UDim2.new(1, 0, 0, 34)
FileInput.Position = UDim2.new(0, 0, 0, 314)
FileInput.BackgroundColor3 = CARD
FileInput.TextColor3 = TXT1
FileInput.PlaceholderText = "Nama file rekaman..."
FileInput.PlaceholderColor3 = TXT2
FileInput.Font = Enum.Font.GothamMedium
FileInput.TextSize = 12
FileInput.ClearTextOnFocus = false
FileInput.Parent = LeftPanel
mkCorner(FileInput, 8)
mkStroke(FileInput, DIV, 1)
local FIPad = Instance.new("UIPadding", FileInput)
FIPad.PaddingLeft = UDim.new(0, 10)

local RightPanel = Instance.new("Frame")
RightPanel.Name = "RightPanel"
RightPanel.Size = UDim2.new(0, 246, 0, 362)
RightPanel.Position = UDim2.new(0, 252, 0, 58)
RightPanel.BackgroundColor3 = PANEL
RightPanel.BorderSizePixel = 0
RightPanel.Parent = MainFrame
mkCorner(RightPanel, 10)
mkStroke(RightPanel, DIV, 1)

local RightHeader = Instance.new("Frame")
RightHeader.Name = "RightHeader"
RightHeader.Size = UDim2.new(1, 0, 0, 34)
RightHeader.BackgroundColor3 = CARD
RightHeader.BorderSizePixel = 0
RightHeader.Parent = RightPanel
mkCorner(RightHeader, 10)

local RightHeaderFix = Instance.new("Frame")
RightHeaderFix.Size = UDim2.new(1, 0, 0, 14)
RightHeaderFix.Position = UDim2.new(0, 0, 1, -14)
RightHeaderFix.BackgroundColor3 = CARD
RightHeaderFix.BorderSizePixel = 0
RightHeaderFix.Parent = RightHeader

local FileTitle = Instance.new("TextLabel")
FileTitle.Name = "FileTitle"
FileTitle.Size = UDim2.new(1, -52, 1, 0)
FileTitle.Position = UDim2.new(0, 12, 0, 0)
FileTitle.BackgroundTransparency = 1
FileTitle.Text = "DATABASE REKAMAN"
FileTitle.TextColor3 = GOLD2
FileTitle.Font = Enum.Font.GothamBold
FileTitle.TextSize = 10
FileTitle.TextXAlignment = Enum.TextXAlignment.Left
FileTitle.Parent = RightHeader

local FileBadge = Instance.new("TextLabel")
FileBadge.Name = "FileBadge"
FileBadge.Size = UDim2.new(0, 28, 0, 18)
FileBadge.AnchorPoint = Vector2.new(1, 0.5)
FileBadge.Position = UDim2.new(1, -8, 0.5, 0)
FileBadge.BackgroundColor3 = BLUE:Lerp(Color3.new(0, 0, 0), 0.35)
FileBadge.Text = "0"
FileBadge.TextColor3 = TXT1
FileBadge.Font = Enum.Font.GothamBold
FileBadge.TextSize = 10
FileBadge.Parent = RightHeader
mkCorner(FileBadge, 5)

local RPDiv = Instance.new("Frame")
RPDiv.Size = UDim2.new(1, -16, 0, 1)
RPDiv.Position = UDim2.new(0, 8, 0, 34)
RPDiv.BackgroundColor3 = DIV
RPDiv.BorderSizePixel = 0
RPDiv.Parent = RightPanel

local FileScroll = Instance.new("ScrollingFrame")
FileScroll.Name = "FileScroll"
FileScroll.Size = UDim2.new(1, -8, 0, 284)
FileScroll.Position = UDim2.new(0, 4, 0, 40)
FileScroll.BackgroundTransparency = 1
FileScroll.ScrollBarThickness = 3
FileScroll.ScrollBarImageColor3 = GOLD2
FileScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
FileScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
FileScroll.Parent = RightPanel

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 4)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Parent = FileScroll

local ScrollPad = Instance.new("UIPadding", FileScroll)
ScrollPad.PaddingTop = UDim.new(0, 2)
ScrollPad.PaddingLeft = UDim.new(0, 2)
ScrollPad.PaddingRight = UDim.new(0, 2)

local DelBtn = Instance.new("TextButton")
DelBtn.Name = "DelBtn"
DelBtn.Size = UDim2.new(1, -16, 0, 30)
DelBtn.Position = UDim2.new(0, 8, 1, -38)
DelBtn.BackgroundColor3 = COL_DEL
DelBtn.Text = "✕  HAPUS FILE INI"
DelBtn.TextColor3 = TXT1
DelBtn.Font = Enum.Font.GothamBold
DelBtn.TextSize = 11
DelBtn.AutoButtonColor = false
DelBtn.Parent = RightPanel
mkCorner(DelBtn, 7)
mkStroke(DelBtn, COL_DEL:Lerp(Color3.new(1, 1, 1), 0.18), 1)
DelBtn.MouseEnter:Connect(function()
    TweenService:Create(DelBtn, TweenInfo.new(0.15), {BackgroundColor3 = COL_DELH}):Play()
end)
DelBtn.MouseLeave:Connect(function()
    TweenService:Create(DelBtn, TweenInfo.new(0.15), {BackgroundColor3 = COL_DEL}):Play()
end)

MinBtn.Activated:Connect(function()
    MainFrame.Visible = false
    OpenBtn.Visible = true
end)

OpenBtn.Activated:Connect(function()
    MainFrame.Visible = true
    OpenBtn.Visible = false
end)

CloseBtn.Activated:Connect(function()
    CleanConn()
    ScreenGui:Destroy()
end)

local dragging, dragInput, dragStart, startPos

local function isInteractive(pos)
    local objs = guiParent:GetGuiObjectsAtPosition(pos.X, pos.Y)
    for _, obj in ipairs(objs) do
        if obj:IsA("TextButton") or obj:IsA("TextBox") or obj:IsA("ScrollingFrame") or obj:IsA("ImageButton") then
            return true
        end
    end
    return false
end

MainFrame.InputBegan:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not isInteractive(input.Position) then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

SpeedMinBtn.Activated:Connect(function()
    PlaybackSpeed = math.clamp(PlaybackSpeed - 0.1, 0.1, 5.0)
    SpeedText.Text = string.format("%.1f×", PlaybackSpeed)
end)

SpeedMaxBtn.Activated:Connect(function()
    PlaybackSpeed = math.clamp(PlaybackSpeed + 0.1, 0.1, 5.0)
    SpeedText.Text = string.format("%.1f×", PlaybackSpeed)
end)

local function RefreshFileList()
    for _, child in ipairs(FileScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    if not HAS_FS then return end
    local files = listfiles(FOLDER_NAME)
    local count = 0
    for _, filePath in ipairs(files) do
        local fileName = string.match(filePath, "([^/\\]+)%.json$")
        if fileName then
            count = count + 1
            local fileBtn = Instance.new("TextButton")
            fileBtn.Size = UDim2.new(1, 0, 0, 28)
            fileBtn.BackgroundColor3 = CARD
            fileBtn.Text = ""
            fileBtn.AutoButtonColor = false
            fileBtn.Parent = FileScroll
            mkCorner(fileBtn, 6)

            local fileIcon = Instance.new("TextLabel", fileBtn)
            fileIcon.Size = UDim2.new(0, 18, 1, 0)
            fileIcon.Position = UDim2.new(0, 8, 0, 0)
            fileIcon.BackgroundTransparency = 1
            fileIcon.Text = "▪"
            fileIcon.TextColor3 = GOLD2
            fileIcon.Font = Enum.Font.GothamBold
            fileIcon.TextSize = 10

            local fileNameLbl = Instance.new("TextLabel", fileBtn)
            fileNameLbl.Size = UDim2.new(1, -30, 1, 0)
            fileNameLbl.Position = UDim2.new(0, 24, 0, 0)
            fileNameLbl.BackgroundTransparency = 1
            fileNameLbl.Text = fileName
            fileNameLbl.TextColor3 = TXT1
            fileNameLbl.Font = Enum.Font.GothamMedium
            fileNameLbl.TextSize = 11
            fileNameLbl.TextXAlignment = Enum.TextXAlignment.Left
            fileNameLbl.ClipsDescendants = true

            fileBtn.MouseEnter:Connect(function()
                TweenService:Create(fileBtn, TweenInfo.new(0.12), {BackgroundColor3 = CARDHOV}):Play()
            end)
            fileBtn.MouseLeave:Connect(function()
                TweenService:Create(fileBtn, TweenInfo.new(0.12), {BackgroundColor3 = CARD}):Play()
            end)

            fileBtn.Activated:Connect(function()
                FileInput.Text = fileName
                local success, data = pcall(function()
                    return HttpService:JSONDecode(readfile(filePath))
                end)
                if success and type(data) == "table" then
                    MacroData = data.Frames or {}
                    AnimDict = data.Dict or {}
                    StatusLabel.Text = "Loaded  ·  " .. #MacroData .. " frames"
                    StatusDot.BackgroundColor3 = BLUE
                    for _, b in ipairs(FileScroll:GetChildren()) do
                        if b:IsA("TextButton") then
                            b.BackgroundColor3 = CARD
                        end
                    end
                    fileBtn.BackgroundColor3 = BLUE:Lerp(Color3.new(0, 0, 0), 0.38)
                end
            end)
        end
    end
    FileBadge.Text = tostring(count)
end

RefreshFileList()

local function AutoSaveData()
    if not HAS_FS or #MacroData == 0 then return end
    local name = FileInput.Text
    if name == "" then
        name = "Rekaman_" .. os.date("%H%M%S")
        FileInput.Text = name
    end
    name = name:gsub("[^%w%_]", "")
    local path = FOLDER_NAME .. "/" .. name .. ".json"
    pcall(function()
        writefile(path, HttpService:JSONEncode({Dict = AnimDict, Frames = MacroData}))
    end)
    RefreshFileList()
end

DelBtn.Activated:Connect(function()
    if not HAS_FS then return end
    local name = FileInput.Text:gsub("[^%w%_]", "")
    if name ~= "" then
        local path = FOLDER_NAME .. "/" .. name .. ".json"
        if isfile(path) then
            delfile(path)
            FileInput.Text = ""
            table.clear(MacroData)
            table.clear(AnimDict)
            StatusLabel.Text = "File terhapus"
            StatusDot.BackgroundColor3 = TXT2
            RefreshFileList()
        end
    end
end)

local function GetAnimId(assetIdStr)
    if not AnimDict[assetIdStr] then
        AnimDict[assetIdStr] = NextAnimId
        NextAnimId = NextAnimId + 1
    end
    return AnimDict[assetIdStr]
end

local DOT_COLORS = {
    Idle      = TXT2,
    Recording = Color3.fromRGB(220, 58, 68),
    Playing   = Color3.fromRGB(44, 200, 118),
    Paused    = Color3.fromRGB(200, 145, 48),
}

local function UpdateUI()
    local t = 0
    if State == "Recording" then
        t = os.clock() - RecordStartTime
    elseif State == "Playing" then
        t = PlaybackCurrentTime
    end
    StatusLabel.Text = string.format("%s  ·  %d frames  ·  %.1fs", State, #MacroData, t)
    StatusDot.BackgroundColor3 = DOT_COLORS[State] or TXT2
end

local function SetupMovers(root)
    CleanupMovers()
    MoverAttachment = Instance.new("Attachment", workspace.Terrain)
    local rootAtt = root:FindFirstChild("RootAttachment") or Instance.new("Attachment", root)

    AP_Mover = Instance.new("AlignPosition")
    AP_Mover.Attachment0 = rootAtt
    AP_Mover.Attachment1 = MoverAttachment
    AP_Mover.Mode = Enum.PositionAlignmentMode.TwoAttachment
    AP_Mover.RigidityEnabled = false
    AP_Mover.Responsiveness = 200
    AP_Mover.MaxForce = math.huge
    AP_Mover.MaxVelocity = math.huge
    AP_Mover.Parent = root

    AO_Mover = Instance.new("AlignOrientation")
    AO_Mover.Attachment0 = rootAtt
    AO_Mover.Attachment1 = MoverAttachment
    AO_Mover.Mode = Enum.OrientationAlignmentMode.TwoAttachment
    AO_Mover.RigidityEnabled = false
    AO_Mover.Responsiveness = 200
    AO_Mover.MaxTorque = math.huge
    AO_Mover.MaxAngularVelocity = math.huge
    AO_Mover.Parent = root
end

local DoStop, DoPlay

RecordBtn.Activated:Connect(function()
    if State == "Recording" then return end
    CleanConn()
    table.clear(MacroData)
    table.clear(AnimDict)
    NextAnimId = 1
    State = "Recording"
    RecordStartTime = os.clock()
    LastForcedSample = 0

    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")
    local hum  = char:WaitForChild("Humanoid")
    local animator = hum:WaitForChild("Animator")

    local lastPos = root.Position
    local lastRot = root.CFrame.LookVector
    local lastUp  = root.CFrame.UpVector

    table.insert(MacroData, {
        t    = 0,
        px   = root.Position.X,        py   = root.Position.Y,        pz   = root.Position.Z,
        lx   = root.CFrame.LookVector.X, ly = root.CFrame.LookVector.Y, lz = root.CFrame.LookVector.Z,
        ux   = root.CFrame.UpVector.X,   uy = root.CFrame.UpVector.Y,   uz = root.CFrame.UpVector.Z,
        mdx  = 0, mdy = 0, mdz = 0,
        vx   = 0, vy  = 0, vz  = 0,
        jump = false,
        humState = hum:GetState().Value,
        anims = {}
    })

    Connection = RunService.Heartbeat:Connect(function()
        if math.max(hum.Health, 0) == 0 then DoStop() return end

        local t    = os.clock() - RecordStartTime
        local pos  = root.Position
        local look = root.CFrame.LookVector
        local up   = root.CFrame.UpVector
        local vel  = root.AssemblyLinearVelocity
        local isJump = hum.Jump or hum:GetState() == Enum.HumanoidStateType.Jumping

        local dist  = (pos - lastPos).Magnitude
        local angle = math.acos(math.clamp(look:Dot(lastRot), -1, 1))
        local aUp   = math.acos(math.clamp(up:Dot(lastUp),   -1, 1))
        local forcedTime = math.max(t - LastForcedSample - 0.05, 0) ~= 0

        if math.max(dist - 0.01, 0) ~= 0 or math.max(angle - 0.003, 0) ~= 0 or math.max(aUp - 0.003, 0) ~= 0 or isJump or forcedTime then
            local activeAnims = {}
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                if track.Animation then
                    local sId = GetAnimId(track.Animation.AnimationId)
                    table.insert(activeAnims, {
                        i  = sId,
                        tp = track.TimePosition,
                        w  = track.WeightCurrent,
                        s  = track.Speed,
                        lp = track.Looped and 1 or 0
                    })
                end
            end

            table.insert(MacroData, {
                t        = t,
                px       = pos.X,  py  = pos.Y,  pz  = pos.Z,
                lx       = look.X, ly  = look.Y, lz  = look.Z,
                ux       = up.X,   uy  = up.Y,   uz  = up.Z,
                mdx      = hum.MoveDirection.X, mdy = hum.MoveDirection.Y, mdz = hum.MoveDirection.Z,
                vx       = vel.X,  vy  = vel.Y,  vz  = vel.Z,
                jump     = isJump,
                humState = hum:GetState().Value,
                anims    = activeAnims
            })

            lastPos = pos
            lastRot = look
            lastUp  = up
            LastForcedSample = t
            UpdateUI()
        end
    end)
    UpdateUI()
end)

DoStop = function()
    local wasRec = (State == "Recording")
    CleanConn()
    State = "Idle"
    UpdateUI()
    if wasRec and #MacroData > 0 then
        AutoSaveData()
        StatusLabel.Text = "Auto-Saved  ·  " .. #MacroData .. " frames"
        StatusDot.BackgroundColor3 = GOLD
    end
end

StopBtn.Activated:Connect(DoStop)

DoPlay = function()
    if #MacroData == 0 then return end

    local resumeFromPause = (State == "Paused")

    CleanConn()
    State = "Playing"

    if not resumeFromPause then
        PlaybackIndex = 1
        PlaybackCurrentTime = 0
    end

    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")
    local hum  = char:WaitForChild("Humanoid")
    local animator = hum:WaitForChild("Animator")

    if char:FindFirstChild("Animate") then char.Animate.Disabled = true end
    SetupMovers(root)

    local RevDict = {}
    for assetStr, idNum in pairs(AnimDict) do
        RevDict[idNum] = assetStr
        if not AnimCache[assetStr] then
            local animInst = Instance.new("Animation")
            animInst.AnimationId = assetStr
            AnimCache[assetStr] = animator:LoadAnimation(animInst)
        end
    end

    Connection = RunService.Stepped:Connect(function(_, dt)
        if State == "Paused" then return end
        if math.max(hum.Health, 0) == 0 then DoStop() return end

        PlaybackCurrentTime = PlaybackCurrentTime + (dt * PlaybackSpeed)

        while MacroData[PlaybackIndex] and math.min(MacroData[PlaybackIndex].t, PlaybackCurrentTime) == MacroData[PlaybackIndex].t do
            PlaybackIndex = PlaybackIndex + 1
        end

        local currentF = MacroData[PlaybackIndex]
        local prevF    = MacroData[PlaybackIndex - 1]

        if not currentF then
            DoStop()
            StatusLabel.Text = "Playback selesai"
            return
        end

        if prevF then
            local alpha = math.clamp(
                (PlaybackCurrentTime - prevF.t) / (currentF.t - prevF.t), 0, 1
            )

            local pPos  = Vector3.new(prevF.px,  prevF.py,  prevF.pz)
            local cPos  = Vector3.new(currentF.px, currentF.py, currentF.pz)
            local pLook = Vector3.new(prevF.lx,  prevF.ly,  prevF.lz)
            local cLook = Vector3.new(currentF.lx, currentF.ly, currentF.lz)
            local pUp   = Vector3.new(prevF.ux  or 0, prevF.uy  or 1, prevF.uz  or 0)
            local cUp   = Vector3.new(currentF.ux or 0, currentF.uy or 1, currentF.uz or 0)
            local pMD   = Vector3.new(prevF.mdx, prevF.mdy, prevF.mdz)
            local cMD   = Vector3.new(currentF.mdx, currentF.mdy, currentF.mdz)

            local lerpedPos  = pPos:Lerp(cPos,   alpha)
            local lerpedLook = pLook:Lerp(cLook, alpha)
            local lerpedUp   = pUp:Lerp(cUp,     alpha)
            local lerpedMD   = pMD:Lerp(cMD,     alpha)

            if MoverAttachment then
                if lerpedLook.Magnitude ~= 0 then
                    MoverAttachment.CFrame = CFrame.lookAt(lerpedPos, lerpedPos + lerpedLook)
                else
                    MoverAttachment.CFrame = CFrame.new(lerpedPos)
                end
            end

            if math.max(lerpedMD.Magnitude - 0.05, 0) ~= 0 then
                LocalPlayer:Move(lerpedMD, false)
            else
                LocalPlayer:Move(Vector3.zero, false)
            end

            if prevF.jump then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.delay(0.05, function()
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                end)
            end

            local activeThisFrame = {}
            for _, animData in ipairs(prevF.anims or {}) do
                local assetStr = RevDict[animData.i]
                if assetStr then
                    local track = AnimCache[assetStr]
                    if track then
                        if not track.IsPlaying then track:Play() end
                        track.TimePosition = animData.tp
                        track:AdjustWeight(animData.w)
                        track:AdjustSpeed(animData.s * PlaybackSpeed)
                        activeThisFrame[track] = true
                    end
                end
            end

            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                if not activeThisFrame[track] then track:Stop(0) end
            end
        end
        UpdateUI()
    end)
    UpdateUI()
end

PlayBtn.Activated:Connect(DoPlay)

PauseBtn.Activated:Connect(function()
    if State == "Playing" then
        State = "Paused"
        ResetToIdleState()
        UpdateUI()
    elseif State == "Paused" then
        DoPlay()
    end
end)

print("[REZADEVX PREMIUM] v7.0 Loaded — Ultra-Detail Recording + Instant Idle Active")
