local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local CONFIG = { 
    Folder = "rezadevx_autowalk" 
}

local THEME = {
    Background = Color3.fromRGB(18, 19, 24),
    PanelBG = Color3.fromRGB(24, 26, 33),
    Stroke = Color3.fromRGB(45, 48, 60),
    TextPrimary = Color3.fromRGB(240, 245, 255),
    TextSecondary = Color3.fromRGB(150, 155, 170),
    Accent = Color3.fromRGB(88, 101, 242),
    BtnHover = 0.15,
    Colors = {
        Record = Color3.fromRGB(235, 87, 87), 
        Play = Color3.fromRGB(39, 174, 96),
        Pause = Color3.fromRGB(242, 153, 74), 
        Resume = Color3.fromRGB(45, 156, 219),
        Stop = Color3.fromRGB(130, 130, 140), 
        Delete = Color3.fromRGB(192, 57, 43)
    }
}

local FSM = { 
    HasAccess = (writefile and readfile and isfile and listfiles and delfile and makefolder) ~= nil 
}

function FSM:Init() 
    if self.HasAccess and not isfolder(CONFIG.Folder) then 
        pcall(makefolder, CONFIG.Folder) 
    end 
end

function FSM:Save(fileName, data)
    if not self.HasAccess then return false end
    fileName = fileName:gsub("[^%w%_]", "")
    if fileName == "" then fileName = "Macro_" .. os.date("%H%M%S") end
    local path = CONFIG.Folder .. "/" .. fileName .. ".json"
    
    local success, encoded = pcall(function() return HttpService:JSONEncode(data) end)
    if success then 
        pcall(writefile, path, encoded)
        return true, fileName 
    end
    return false, nil
end

function FSM:Load(fileName)
    if not self.HasAccess then return nil end
    local path = CONFIG.Folder .. "/" .. fileName .. ".json"
    if isfile(path) then
        local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
        if success and type(decoded) == "table" then return decoded end
    end 
    return nil
end

local MacroEngine = {
    State = "Idle", 
    Speed = 1.0, 
    Frames = {}, 
    AnimDict = {}, 
    AnimCache = {},
    DictCounter = 1, 
    StartTime = 0, 
    CurrentTime = 0, 
    PlaybackIndex = 1,
    Bin = {}, 
    PhysicsProps = {},
    IsM1Down = false, 
    LastM1State = false, 
    OrgStats = {}
}

UserInputService.InputBegan:Connect(function(input, gpe)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then 
        MacroEngine.IsM1Down = true 
    end
end)

UserInputService.InputEnded:Connect(function(input, gpe)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then 
        MacroEngine.IsM1Down = false 
    end
end)

function MacroEngine:CleanUp()
    for _, item in ipairs(self.Bin) do
        if typeof(item) == "RBXScriptConnection" then item:Disconnect()
        elseif typeof(item) == "Instance" then pcall(function() item:Destroy() end) end
    end
    table.clear(self.Bin)
    
    if self.LastM1State then
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        self.LastM1State = false
    end
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    
    self:ResetCharacterState()
end

function MacroEngine:ResetCharacterState()
    local char = LocalPlayer.Character
    if not char then return end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    local hum = char:FindFirstChild("Humanoid")
    if hum then
        if self.OrgStats.WS then hum.WalkSpeed = self.OrgStats.WS end
        if self.OrgStats.JP then hum.JumpPower = self.OrgStats.JP end
        if self.OrgStats.AutoRot ~= nil then hum.AutoRotate = self.OrgStats.AutoRot end
        
        local animator = hum:FindFirstChild("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                track:Stop(0)
            end
        end
    end
    
    if self.OrgStats.Grav then workspace.Gravity = self.OrgStats.Grav end
    LocalPlayer:Move(Vector3.zero, true)
end

function MacroEngine:SetupPhysics(root)
    local MoverAttachment = Instance.new("Attachment", workspace.Terrain)
    local rootAtt = root:FindFirstChild("RootAttachment") or Instance.new("Attachment", root)
    
    local AO = Instance.new("AlignOrientation")
    AO.Attachment0 = rootAtt
    AO.Attachment1 = MoverAttachment
    AO.Mode = Enum.OrientationAlignmentMode.TwoAttachment
    AO.RigidityEnabled = false
    AO.Responsiveness = 150
    AO.MaxTorque = math.huge
    AO.Parent = root

    table.insert(self.Bin, MoverAttachment)
    table.insert(self.Bin, AO)
    self.PhysicsProps.TargetCF = MoverAttachment
end

function MacroEngine:GetAnimId(assetStr)
    if not self.AnimDict[assetStr] then 
        self.AnimDict[assetStr] = self.DictCounter
        self.DictCounter = self.DictCounter + 1 
    end
    return self.AnimDict[assetStr]
end

function MacroEngine:GetClosestFrame(currentPos)
    if #self.Frames == 0 then return 1, 0 end
    local minSqDist = math.huge
    local closestIdx = 1
    
    for i, frame in ipairs(self.Frames) do
        local fPos = frame.cf and Vector3.new(frame.cf[1], frame.cf[2], frame.cf[3]) or Vector3.new(frame.px, frame.py, frame.pz)
        local sqDist = (currentPos - fPos).Magnitude
        if sqDist < minSqDist then 
            minSqDist = sqDist
            closestIdx = i 
        end
    end
    return closestIdx, self.Frames[closestIdx].t
end

function MacroEngine:Record()
    if self.State ~= "Idle" then self:Stop() end
    self:CleanUp()
    table.clear(self.Frames)
    table.clear(self.AnimDict)
    self.DictCounter = 1
    self.StartTime = os.clock()
    self.State = "Recording"

    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")
    local hum = char:WaitForChild("Humanoid")
    local animator = hum:WaitForChild("Animator")

    self.OrgStats = {
        WS = hum.WalkSpeed, 
        JP = hum.JumpPower, 
        Grav = workspace.Gravity,
        AutoRot = hum.AutoRotate
    }

    table.insert(self.Bin, RunService.Heartbeat:Connect(function()
        if hum.Health <= 0 then 
            self.State = "Idle"
            self:CleanUp()
            return 
        end
        
        local activeAnims = {}
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            if track.Animation then 
                table.insert(activeAnims, { 
                    i = self:GetAnimId(track.Animation.AnimationId), 
                    tp = track.TimePosition, 
                    w = track.WeightCurrent, 
                    s = track.Speed 
                }) 
            end
        end
        
        local currentTool = char:FindFirstChildOfClass("Tool")
        local isJump = hum.Jump or hum:GetState() == Enum.HumanoidStateType.Jumping
        
        table.insert(self.Frames, {
            t = os.clock() - self.StartTime,
            cf = {root.CFrame:GetComponents()},
            md = {hum.MoveDirection.X, hum.MoveDirection.Y, hum.MoveDirection.Z},
            st = hum:GetState().Value, 
            jump = isJump,
            ws = hum.WalkSpeed, 
            jp = hum.JumpPower, 
            grav = workspace.Gravity,
            tool = currentTool and currentTool.Name or nil, 
            m1 = self.IsM1Down,
            anims = activeAnims
        })
    end))
end

function MacroEngine:Play()
    if #self.Frames == 0 or self.State == "Playing" then return end
    self:CleanUp()
    self.State = "Playing"

    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")
    local hum = char:WaitForChild("Humanoid")
    local animator = hum:WaitForChild("Animator")

    self.OrgStats = {
        WS = hum.WalkSpeed, 
        JP = hum.JumpPower, 
        Grav = workspace.Gravity,
        AutoRot = hum.AutoRotate
    }

    local startIdx, startTime = self:GetClosestFrame(root.Position)
    self.PlaybackIndex = startIdx
    self.CurrentTime = startTime
    self.LastM1State = false

    hum.AutoRotate = false
    self:SetupPhysics(root)
    
    local RevDict = {}
    for assetStr, idNum in pairs(self.AnimDict) do 
        RevDict[idNum] = assetStr 
        if not self.AnimCache[assetStr] then
            local animInst = Instance.new("Animation")
            animInst.AnimationId = assetStr
            self.AnimCache[assetStr] = animator:LoadAnimation(animInst)
        end
    end

    table.insert(self.Bin, RunService.Stepped:Connect(function(_, dt)
        if hum.Health <= 0 then 
            self.State = "Idle"
            self:CleanUp()
            return 
        end
        
        self.CurrentTime = self.CurrentTime + (dt * self.Speed)

        while self.Frames[self.PlaybackIndex] and self.Frames[self.PlaybackIndex].t <= self.CurrentTime do 
            self.PlaybackIndex = self.PlaybackIndex + 1 
        end

        local cF = self.Frames[self.PlaybackIndex]
        local pF = self.Frames[self.PlaybackIndex - 1]
        
        if not cF then 
            self.State = "Idle"
            self:CleanUp()
            return 
        end

        if pF then
            local timeDiff = cF.t - pF.t
            local alpha = timeDiff > 0 and math.clamp((self.CurrentTime - pF.t) / timeDiff, 0, 1) or 1

            local pCFrame = CFrame.new(unpack(pF.cf))
            local cCFrame = CFrame.new(unpack(cF.cf))
            local targetCF = pCFrame:Lerp(cCFrame, alpha)
            
            if self.PhysicsProps.TargetCF then 
                self.PhysicsProps.TargetCF.WorldCFrame = targetCF 
            end
            
            if pF.grav then workspace.Gravity = pF.grav end
            if pF.ws then hum.WalkSpeed = pF.ws end
            if pF.jp then hum.JumpPower = pF.jp end

            local pMD = Vector3.new(unpack(pF.md))
            local cMD = Vector3.new(unpack(cF.md))
            local blendMD = pMD:Lerp(cMD, alpha)
            
            if blendMD.Magnitude > 0.01 then 
                LocalPlayer:Move(blendMD, false) 
            else 
                LocalPlayer:Move(Vector3.zero, false) 
            end

            if (root.Position - targetCF.Position).Magnitude > 3 then
                root.CFrame = targetCF
            end

            if pF.st and hum:GetState().Value ~= pF.st then 
                pcall(function() hum:ChangeState(pF.st) end) 
            end
            
            if pF.jump then
                hum.Jump = true
            end

            local currentTool = char:FindFirstChildOfClass("Tool")
            if pF.tool then
                if not currentTool or currentTool.Name ~= pF.tool then
                    local targetTool = LocalPlayer.Backpack:FindFirstChild(pF.tool)
                    if targetTool then 
                        hum:EquipTool(targetTool) 
                    end
                end
            elseif currentTool then
                hum:UnequipTools()
            end

            if pF.m1 ~= nil then
                if pF.m1 and not self.LastM1State then
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    self.LastM1State = true
                elseif not pF.m1 and self.LastM1State then
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                    self.LastM1State = false
                end
            end

            local activeThisFrame = {}
            for _, animData in ipairs(pF.anims or {}) do
                local assetStr = RevDict[animData.i]
                if assetStr and self.AnimCache[assetStr] then
                    local track = self.AnimCache[assetStr]
                    if not track.IsPlaying then 
                        track:Play() 
                        track.TimePosition = animData.tp
                    else
                        if math.abs(track.TimePosition - animData.tp) > 0.15 then
                            track.TimePosition = animData.tp
                        end
                    end
                    track:AdjustWeight(animData.w, 0)
                    track:AdjustSpeed(animData.s * self.Speed)
                    activeThisFrame[track] = true
                end
            end
            
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do 
                if not activeThisFrame[track] then 
                    track:Stop(0.1) 
                end 
            end
        end
    end))
end

function MacroEngine:Pause()
    if self.State == "Playing" then 
        self.State = "Paused"
        self:CleanUp() 
    end
end

function MacroEngine:Resume()
    if self.State == "Paused" then
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local hum = char:WaitForChild("Humanoid")
        hum.AutoRotate = false
        self:SetupPhysics(char:WaitForChild("HumanoidRootPart"))
        self.State = "Playing"
    end
end

function MacroEngine:Stop()
    local wasRec = (self.State == "Recording")
    self.State = "Idle"
    self:CleanUp()
    return wasRec
end

local UI = { Parent = pcall(function() return CoreGui.Name end) and CoreGui or LocalPlayer:WaitForChild("PlayerGui") }
if UI.Parent:FindFirstChild("rezadevx_premium") then UI.Parent.rezadevx_premium:Destroy() end

local function ApplyCorner(obj, rad) 
    Instance.new("UICorner", obj).CornerRadius = UDim.new(0, rad) 
end

local function ApplyStroke(obj, color, thick) 
    local s = Instance.new("UIStroke", obj)
    s.Color = color
    s.Thickness = thick
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "rezadevx_premium"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = UI.Parent

local OpenBtn = Instance.new("ImageButton", ScreenGui)
OpenBtn.Size = UDim2.new(0, 45, 0, 45)
OpenBtn.Position = UDim2.new(0, 20, 0.5, -22)
OpenBtn.BackgroundColor3 = THEME.PanelBG
OpenBtn.Image = "rbxassetid://6035047409"
OpenBtn.Visible = false
ApplyCorner(OpenBtn, 12)
ApplyStroke(OpenBtn, THEME.Stroke, 1.5)

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 520, 0, 390)
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -195)
MainFrame.BackgroundColor3 = THEME.Background
MainFrame.Active = true
ApplyCorner(MainFrame, 12)
ApplyStroke(MainFrame, THEME.Stroke, 1.5)

local DropShadow = Instance.new("ImageLabel", MainFrame)
DropShadow.AnchorPoint = Vector2.new(0.5, 0.5)
DropShadow.Position = UDim2.new(0.5, 0, 0.5, 4)
DropShadow.Size = UDim2.new(1, 40, 1, 40)
DropShadow.BackgroundTransparency = 1
DropShadow.ZIndex = -1
DropShadow.Image = "rbxassetid://6015897843"
DropShadow.ImageTransparency = 0.6
DropShadow.ImageColor3 = Color3.new(0,0,0)
DropShadow.ScaleType = Enum.ScaleType.Slice
DropShadow.SliceCenter = Rect.new(49, 49, 450, 450)

local Header = Instance.new("Frame", MainFrame)
Header.Size = UDim2.new(1, 0, 0, 45)
Header.BackgroundTransparency = 1

local HeaderStroke = Instance.new("Frame", Header)
HeaderStroke.Size = UDim2.new(1, 0, 0, 1)
HeaderStroke.Position = UDim2.new(0, 0, 1, 0)
HeaderStroke.BackgroundColor3 = THEME.Stroke
HeaderStroke.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(1, -100, 1, 0)
Title.Position = UDim2.new(0, 20, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "rezadevx premium macro"
Title.TextColor3 = THEME.TextPrimary
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left

local function CreateHeaderBtn(pos, txt, color)
    local b = Instance.new("TextButton", Header)
    b.Size = UDim2.new(0, 30, 0, 30)
    b.Position = pos
    b.BackgroundColor3 = THEME.Background
    b.Text = txt
    b.TextColor3 = color
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    ApplyCorner(b, 8)
    ApplyStroke(b, THEME.Stroke, 1)
    b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.2), {BackgroundColor3 = THEME.PanelBG}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.2), {BackgroundColor3 = THEME.Background}):Play() end)
    return b
end

local MinBtn = CreateHeaderBtn(UDim2.new(1, -75, 0.5, -15), "-", THEME.TextPrimary)
local CloseBtn = CreateHeaderBtn(UDim2.new(1, -40, 0.5, -15), "X", THEME.Colors.Record)

local Content = Instance.new("Frame", MainFrame)
Content.Size = UDim2.new(1, -40, 1, -65)
Content.Position = UDim2.new(0, 20, 0, 55)
Content.BackgroundTransparency = 1

local LeftPanel = Instance.new("Frame", Content)
LeftPanel.Size = UDim2.new(0.48, 0, 1, 0)
LeftPanel.BackgroundTransparency = 1
local LeftLayout = Instance.new("UIListLayout", LeftPanel)
LeftLayout.SortOrder = Enum.SortOrder.LayoutOrder
LeftLayout.Padding = UDim.new(0, 8)

local RightPanel = Instance.new("Frame", Content)
RightPanel.Size = UDim2.new(0.48, 0, 1, 0)
RightPanel.Position = UDim2.new(0.52, 0, 0, 0)
RightPanel.BackgroundColor3 = THEME.PanelBG
ApplyCorner(RightPanel, 8)
ApplyStroke(RightPanel, THEME.Stroke, 1)

local StatusPanel = Instance.new("TextLabel", LeftPanel)
StatusPanel.Size = UDim2.new(1, 0, 0, 32)
StatusPanel.BackgroundColor3 = THEME.PanelBG
StatusPanel.LayoutOrder = 1
StatusPanel.Text = "Status: Idle"
StatusPanel.TextColor3 = THEME.Accent
StatusPanel.Font = Enum.Font.GothamMedium
StatusPanel.TextSize = 12
ApplyCorner(StatusPanel, 6)
ApplyStroke(StatusPanel, THEME.Stroke, 1)

local function CreateControlBtn(parent, text, color, order)
    local Btn = Instance.new("TextButton", parent)
    Btn.Size = UDim2.new(1, 0, 0, 34)
    Btn.BackgroundColor3 = color
    Btn.LayoutOrder = order
    Btn.Text = text
    Btn.TextColor3 = Color3.new(1,1,1)
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 13
    Btn.AutoButtonColor = false
    ApplyCorner(Btn, 6)
    Btn.MouseEnter:Connect(function() TweenService:Create(Btn, TweenInfo.new(0.2), {BackgroundColor3 = color:Lerp(Color3.new(1,1,1), THEME.BtnHover)}):Play() end)
    Btn.MouseLeave:Connect(function() TweenService:Create(Btn, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play() end)
    return Btn
end

local RecordBtn = CreateControlBtn(LeftPanel, "RECORD ALL (F5)", THEME.Colors.Record, 2)
local PlayBtn   = CreateControlBtn(LeftPanel, "PLAY NATIVE SYNC", THEME.Colors.Play, 3)

local PauseResumeFrame = Instance.new("Frame", LeftPanel)
PauseResumeFrame.Size = UDim2.new(1, 0, 0, 34)
PauseResumeFrame.BackgroundTransparency = 1
PauseResumeFrame.LayoutOrder = 4
local PR_Layout = Instance.new("UIListLayout", PauseResumeFrame)
PR_Layout.FillDirection = Enum.FillDirection.Horizontal
PR_Layout.Padding = UDim.new(0, 8)

local PauseBtn = CreateControlBtn(PauseResumeFrame, "PAUSE", THEME.Colors.Pause, 1)
PauseBtn.Size = UDim2.new(0.5, -4, 1, 0)
local ResumeBtn = CreateControlBtn(PauseResumeFrame, "RESUME", THEME.Colors.Resume, 2)
ResumeBtn.Size = UDim2.new(0.5, -4, 1, 0)

local StopBtn = CreateControlBtn(LeftPanel, "STOP & SAVE", THEME.Colors.Stop, 5)

local SpeedFrame = Instance.new("Frame", LeftPanel)
SpeedFrame.Size = UDim2.new(1, 0, 0, 34)
SpeedFrame.BackgroundColor3 = THEME.PanelBG
SpeedFrame.LayoutOrder = 6
ApplyCorner(SpeedFrame, 6)
ApplyStroke(SpeedFrame, THEME.Stroke, 1)

local SpeedMin = Instance.new("TextButton", SpeedFrame)
SpeedMin.Size = UDim2.new(0.25, 0, 1, 0)
SpeedMin.BackgroundTransparency = 1
SpeedMin.Text = "-"
SpeedMin.TextColor3 = THEME.TextSecondary
SpeedMin.Font = Enum.Font.GothamBold
SpeedMin.TextSize = 16

local SpeedMax = Instance.new("TextButton", SpeedFrame)
SpeedMax.Size = UDim2.new(0.25, 0, 1, 0)
SpeedMax.Position = UDim2.new(0.75, 0, 0, 0)
SpeedMax.BackgroundTransparency = 1
SpeedMax.Text = "+"
SpeedMax.TextColor3 = THEME.TextSecondary
SpeedMax.Font = Enum.Font.GothamBold
SpeedMax.TextSize = 16

local SpeedText = Instance.new("TextLabel", SpeedFrame)
SpeedText.Size = UDim2.new(0.5, 0, 1, 0)
SpeedText.Position = UDim2.new(0.25, 0, 0, 0)
SpeedText.BackgroundTransparency = 1
SpeedText.Text = "Speed: 1.0x"
SpeedText.TextColor3 = THEME.TextPrimary
SpeedText.Font = Enum.Font.GothamBold
SpeedText.TextSize = 12

local FileTitle = Instance.new("TextLabel", RightPanel)
FileTitle.Size = UDim2.new(1, 0, 0, 30)
FileTitle.BackgroundTransparency = 1
FileTitle.Text = "SAVED MACROS"
FileTitle.TextColor3 = THEME.TextSecondary
FileTitle.Font = Enum.Font.GothamBold
FileTitle.TextSize = 11

local FileScroll = Instance.new("ScrollingFrame", RightPanel)
FileScroll.Size = UDim2.new(1, -20, 1, -120)
FileScroll.Position = UDim2.new(0, 10, 0, 30)
FileScroll.BackgroundTransparency = 1
FileScroll.ScrollBarThickness = 3
FileScroll.ScrollBarImageColor3 = THEME.Stroke
FileScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
FileScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
local ScrollLayout = Instance.new("UIListLayout", FileScroll)
ScrollLayout.Padding = UDim.new(0, 5)
ScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder

local FileInput = Instance.new("TextBox", RightPanel)
FileInput.Size = UDim2.new(1, -20, 0, 32)
FileInput.Position = UDim2.new(0, 10, 1, -80)
FileInput.BackgroundColor3 = THEME.Background
FileInput.TextColor3 = THEME.TextPrimary
FileInput.PlaceholderText = "Enter File Name..."
FileInput.PlaceholderColor3 = THEME.TextSecondary
FileInput.Font = Enum.Font.GothamMedium
FileInput.TextSize = 12
ApplyCorner(FileInput, 6)
ApplyStroke(FileInput, THEME.Stroke, 1)

local DelBtn = CreateControlBtn(RightPanel, "DELETE SELECTED", THEME.Colors.Delete, 0)
DelBtn.Size = UDim2.new(1, -20, 0, 32)
DelBtn.Position = UDim2.new(0, 10, 1, -42)

local dragging, dragInput, dragStart, startPos

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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

Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then 
        dragInput = input 
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then 
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) 
    end
end)

MinBtn.MouseButton1Click:Connect(function() 
    MainFrame.Visible = false
    OpenBtn.Visible = true 
end)

OpenBtn.MouseButton1Click:Connect(function() 
    MainFrame.Visible = true
    OpenBtn.Visible = false 
end)

CloseBtn.MouseButton1Click:Connect(function() 
    MacroEngine:CleanUp()
    ScreenGui:Destroy() 
end)

local function RefreshUI()
    for _, child in ipairs(FileScroll:GetChildren()) do 
        if child:IsA("TextButton") then child:Destroy() end 
    end
    if not FSM.HasAccess then return end
    
    for _, filePath in ipairs(listfiles(CONFIG.Folder)) do
        local fileName = string.match(filePath, "([^/\\]+)%.json$")
        if fileName then
            local fileBtn = Instance.new("TextButton", FileScroll)
            fileBtn.Size = UDim2.new(1, 0, 0, 28)
            fileBtn.BackgroundColor3 = THEME.Background
            fileBtn.Text = fileName
            fileBtn.TextColor3 = THEME.TextPrimary
            fileBtn.Font = Enum.Font.GothamMedium
            fileBtn.TextSize = 12
            fileBtn.TextXAlignment = Enum.TextXAlignment.Left
            Instance.new("UIPadding", fileBtn).PaddingLeft = UDim.new(0, 10)
            ApplyCorner(fileBtn, 6)
            local stroke = ApplyStroke(fileBtn, THEME.Stroke, 1)
            
            fileBtn.MouseButton1Click:Connect(function()
                FileInput.Text = fileName
                local data = FSM:Load(fileName)
                if data then
                    MacroEngine.Frames = data.Frames or {}
                    MacroEngine.AnimDict = data.Dict or {}
                    StatusPanel.Text = "Status: Loaded (" .. #MacroEngine.Frames .. " frames)"
                    for _, b in ipairs(FileScroll:GetChildren()) do 
                        if b:IsA("TextButton") then 
                            b.BackgroundColor3 = THEME.Background
                            b.UIStroke.Color = THEME.Stroke 
                        end 
                    end
                    fileBtn.BackgroundColor3 = THEME.PanelBG
                    stroke.Color = THEME.Accent
                end
            end)
        end
    end
end

RunService.RenderStepped:Connect(function()
    if MacroEngine.State == "Recording" then 
        StatusPanel.Text = string.format("REC | F: %d | %.1fs", #MacroEngine.Frames, os.clock() - MacroEngine.StartTime)
    elseif MacroEngine.State == "Playing" then 
        StatusPanel.Text = string.format("PLAY | F: %d | %.1fs", #MacroEngine.Frames, MacroEngine.CurrentTime)
    elseif MacroEngine.State == "Paused" then 
        StatusPanel.Text = string.format("PAUSED | F: %d", #MacroEngine.Frames) 
    end
end)

RecordBtn.MouseButton1Click:Connect(function() MacroEngine:Record() end)
PlayBtn.MouseButton1Click:Connect(function() MacroEngine:Play() end)
PauseBtn.MouseButton1Click:Connect(function() MacroEngine:Pause() end)
ResumeBtn.MouseButton1Click:Connect(function() MacroEngine:Resume() end)

StopBtn.MouseButton1Click:Connect(function()
    if MacroEngine:Stop() and #MacroEngine.Frames > 0 then
        local success, savedName = FSM:Save(FileInput.Text, {Dict = MacroEngine.AnimDict, Frames = MacroEngine.Frames})
        if success then 
            FileInput.Text = savedName
            StatusPanel.Text = "Status: Saved (" .. #MacroEngine.Frames .. " f)"
            RefreshUI() 
        end
    end
    if MacroEngine.State == "Idle" then 
        StatusPanel.Text = "Status: Idle" 
    end
end)

DelBtn.MouseButton1Click:Connect(function()
    if not FSM.HasAccess then return end
    local name = FileInput.Text:gsub("[^%w%_]", "")
    local path = CONFIG.Folder .. "/" .. name .. ".json"
    if name ~= "" and isfile(path) then 
        delfile(path)
        FileInput.Text = ""
        table.clear(MacroEngine.Frames)
        table.clear(MacroEngine.AnimDict)
        StatusPanel.Text = "Status: Deleted"
        RefreshUI() 
    end
end)

SpeedMin.MouseButton1Click:Connect(function() 
    MacroEngine.Speed = math.clamp(MacroEngine.Speed - 0.1, 0.1, 5.0)
    SpeedText.Text = string.format("Speed: %.1fx", MacroEngine.Speed) 
end)

SpeedMax.MouseButton1Click:Connect(function() 
    MacroEngine.Speed = math.clamp(MacroEngine.Speed + 0.1, 0.1, 5.0)
    SpeedText.Text = string.format("Speed: %.1fx", MacroEngine.Speed) 
end)

FSM:Init()
RefreshUI()