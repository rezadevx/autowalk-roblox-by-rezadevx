local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local CONFIG = { 
    Folder = "rezadevx_autowalk" 
}


local THEME = {
    BaseDark = Color3.fromRGB(15, 17, 24),
    PanelDark = Color3.fromRGB(22, 25, 35),
    Outline = Color3.fromRGB(50, 55, 75),
    OutlineHover = Color3.fromRGB(88, 101, 242),
    TextWhite = Color3.fromRGB(245, 245, 255),
    TextGray = Color3.fromRGB(160, 165, 180),
    Accent = Color3.fromRGB(88, 101, 242), 
    Action = {
        Record = Color3.fromRGB(240, 71, 71), 
        Play = Color3.fromRGB(67, 181, 129),
        Pause = Color3.fromRGB(250, 166, 26), 
        Resume = Color3.fromRGB(0, 176, 244),
        Stop = Color3.fromRGB(114, 118, 125), 
        Delete = Color3.fromRGB(240, 71, 71)
    }
}

local FSM = { HasAccess = (writefile and readfile and isfile and listfiles and delfile and makefolder) ~= nil }
function FSM:Init() if self.HasAccess and not isfolder(CONFIG.Folder) then pcall(makefolder, CONFIG.Folder) end end
function FSM:Save(fileName, data)
    if not self.HasAccess then return false end
    fileName = fileName:gsub("[^%w%_]", "") if fileName == "" then fileName = "Macro_" .. os.date("%H%M%S") end
    local path = CONFIG.Folder .. "/" .. fileName .. ".json"
    local success, encoded = pcall(function() return HttpService:JSONEncode(data) end)
    if success then pcall(writefile, path, encoded) return true, fileName end return false, nil
end
function FSM:Load(fileName)
    if not self.HasAccess then return nil end
    local path = CONFIG.Folder .. "/" .. fileName .. ".json"
    if isfile(path) then
        local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
        if success and type(decoded) == "table" then return decoded end
    end return nil
end


local MacroEngine = {
    State = "Idle", Speed = 1.0, Frames = {}, AnimDict = {}, AnimCache = {},
    DictCounter = 1, StartTime = 0, CurrentTime = 0, PlaybackIndex = 1,
    Bin = {}, PhysicsProps = {}, IsM1Down = false, LastM1State = false,
    ShowPath = false, PathFolder = nil, LoopEnabled = false
}

local PlayerMods = {
    AntiAfk = false, Fly = false, FlySpeed = 50, FlyConn = nil
}

UserInputService.InputBegan:Connect(function(input, gpe) if input.UserInputType == Enum.UserInputType.MouseButton1 then MacroEngine.IsM1Down = true end end)
UserInputService.InputEnded:Connect(function(input, gpe) if input.UserInputType == Enum.UserInputType.MouseButton1 then MacroEngine.IsM1Down = false end end)


function MacroEngine:DrawLine(p1, p2)
    local dist = (p1 - p2).Magnitude if dist < 0.05 then return end
    local part = Instance.new("Part")
    part.Anchored = true part.CanCollide = false part.CastShadow = false part.Material = Enum.Material.Neon part.Color = THEME.Accent
    part.Transparency = 0.5 part.Size = Vector3.new(0.12, 0.12, dist)
    part.CFrame = CFrame.lookAt(p1, p2) * CFrame.new(0, 0, -dist/2) part.Parent = self.PathFolder return part
end

function MacroEngine:RenderPath()
    if self.PathFolder then self.PathFolder:Destroy() end
    if not self.ShowPath then return end
    if #self.Frames < 2 then return end
    self.PathFolder = Instance.new("Folder") self.PathFolder.Name = "rezadevx_VisualPath" self.PathFolder.Parent = workspace
    for i = 1, #self.Frames - 1 do
        local f1, f2 = self.Frames[i], self.Frames[i+1]
        self:DrawLine(Vector3.new(f1.px, f1.py, f1.pz), Vector3.new(f2.px, f2.py, f2.pz))
    end
end

function MacroEngine:CleanUpMovers()
    if self.PhysicsProps.AP then self.PhysicsProps.AP:Destroy() self.PhysicsProps.AP = nil end
    if self.PhysicsProps.AO then self.PhysicsProps.AO:Destroy() self.PhysicsProps.AO = nil end
    if self.PhysicsProps.Att then self.PhysicsProps.Att:Destroy() self.PhysicsProps.Att = nil end
end

function MacroEngine:CleanUp()
    for _, item in ipairs(self.Bin) do if typeof(item) == "RBXScriptConnection" then item:Disconnect() elseif typeof(item) == "Instance" then pcall(function() item:Destroy() end) end end
    table.clear(self.Bin)
    if self.LastM1State then VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1) self.LastM1State = false end
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    self:ResetCharacterState()
end

function MacroEngine:ResetCharacterState()
    local char = LocalPlayer.Character if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if hum and hum:FindFirstChild("Animator") then for _, track in ipairs(hum.Animator:GetPlayingAnimationTracks()) do track:Stop(0) end end
    if char:FindFirstChild("Animate") then char.Animate.Disabled = false end
    LocalPlayer:Move(Vector3.zero, false) self:CleanUpMovers()
end

function MacroEngine:SetupPhysics(root)
    self:CleanUpMovers()
    local MoverAttachment = Instance.new("Attachment", workspace.Terrain)
    local rootAtt = root:FindFirstChild("RootAttachment") or Instance.new("Attachment", root)
    local AP = Instance.new("AlignPosition") AP.Attachment0 = rootAtt AP.Attachment1 = MoverAttachment AP.Mode = Enum.PositionAlignmentMode.TwoAttachment AP.RigidityEnabled = false AP.Responsiveness = 200 AP.MaxForce = math.huge AP.MaxVelocity = math.huge AP.Parent = root
    local AO = Instance.new("AlignOrientation") AO.Attachment0 = rootAtt AO.Attachment1 = MoverAttachment AO.Mode = Enum.OrientationAlignmentMode.TwoAttachment AO.RigidityEnabled = false AO.Responsiveness = 200 AO.MaxTorque = math.huge AO.MaxAngularVelocity = math.huge AO.Parent = root
    self.PhysicsProps.Att = MoverAttachment self.PhysicsProps.AP = AP self.PhysicsProps.AO = AO
    table.insert(self.Bin, MoverAttachment) table.insert(self.Bin, AP) table.insert(self.Bin, AO)
end

function MacroEngine:GetAnimId(assetStr)
    if not self.AnimDict[assetStr] then self.AnimDict[assetStr] = self.DictCounter self.DictCounter = self.DictCounter + 1 end return self.AnimDict[assetStr]
end

function MacroEngine:GetClosestFrame(currentPos)
    if #self.Frames == 0 then return 1, 0 end
    local minSqDist = math.huge local closestIdx = 1
    for i, frame in ipairs(self.Frames) do
        local sqDist = (currentPos - Vector3.new(frame.px, frame.py, frame.pz)).Magnitude
        if sqDist < minSqDist then minSqDist = sqDist closestIdx = i end
    end return closestIdx, self.Frames[closestIdx].t
end

function MacroEngine:Record()
    if self.State ~= "Idle" then self:Stop() end
    self:CleanUp() table.clear(self.Frames) table.clear(self.AnimDict)
    self.DictCounter = 1 self.StartTime = os.clock() self.State = "Recording"
    if self.PathFolder then self.PathFolder:Destroy() self.PathFolder = nil end
    if self.ShowPath then self.PathFolder = Instance.new("Folder") self.PathFolder.Name = "rezadevx_VisualPath" self.PathFolder.Parent = workspace end

    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart") local hum = char:WaitForChild("Humanoid") local animator = hum:WaitForChild("Animator")
    local lastPos = root.Position local lastRot = root.CFrame.LookVector local lastM1 = self.IsM1Down local lastTool = nil

    table.insert(self.Frames, { t = 0, px = root.Position.X, py = root.Position.Y, pz = root.Position.Z, lx = root.CFrame.LookVector.X, ly = root.CFrame.LookVector.Y, lz = root.CFrame.LookVector.Z, mdx = 0, mdy = 0, mdz = 0, jump = false, tool = nil, m1 = false, anims = {} })

    table.insert(self.Bin, RunService.Heartbeat:Connect(function()
        if hum.Health <= 0 then self.State = "Idle" self:CleanUp() return end
        local currentPos = root.Position local currentRot = root.CFrame.LookVector
        local currentToolObj = char:FindFirstChildOfClass("Tool") local currentToolName = currentToolObj and currentToolObj.Name or nil
        local isJump = hum.Jump or hum:GetState() == Enum.HumanoidStateType.Jumping
        local dist = (currentPos - lastPos).Magnitude local angle = math.acos(math.clamp(currentRot:Dot(lastRot), -1, 1))
        
        if dist > 0.1 or angle > 0.017 or isJump or self.IsM1Down ~= lastM1 or currentToolName ~= lastTool then
            local activeAnims = {}
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do if track.Animation then table.insert(activeAnims, { i = self:GetAnimId(track.Animation.AnimationId), tp = track.TimePosition, w = track.WeightCurrent, s = track.Speed }) end end
            table.insert(self.Frames, { t = os.clock() - self.StartTime, px = currentPos.X, py = currentPos.Y, pz = currentPos.Z, lx = currentRot.X, ly = currentRot.Y, lz = currentRot.Z, mdx = hum.MoveDirection.X, mdy = hum.MoveDirection.Y, mdz = hum.MoveDirection.Z, jump = isJump, tool = currentToolName, m1 = self.IsM1Down, anims = activeAnims })
            if self.ShowPath and self.PathFolder then self:DrawLine(lastPos, currentPos) end
            lastPos = currentPos lastRot = currentRot lastM1 = self.IsM1Down lastTool = currentToolName
        end
    end))
end

function MacroEngine:Play()
    if #self.Frames == 0 or self.State == "Playing" then return end
    self:CleanUp() self.State = "Playing"
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart") local hum = char:WaitForChild("Humanoid") local animator = hum:WaitForChild("Animator")

    local startIdx, startTime = self:GetClosestFrame(root.Position)
    self.PlaybackIndex = startIdx self.CurrentTime = startTime self.LastM1State = false
    if char:FindFirstChild("Animate") then char.Animate.Disabled = true end
    self:SetupPhysics(root)
    
    local RevDict = {}
    for assetStr, idNum in pairs(self.AnimDict) do RevDict[idNum] = assetStr if not self.AnimCache[assetStr] then local animInst = Instance.new("Animation") animInst.AnimationId = assetStr self.AnimCache[assetStr] = animator:LoadAnimation(animInst) end end

    table.insert(self.Bin, RunService.Stepped:Connect(function(_, dt)
        if self.State == "Paused" then return end
        if hum.Health <= 0 then self.State = "Idle" self:CleanUp() return end
        self.CurrentTime = self.CurrentTime + (dt * self.Speed)
        while self.Frames[self.PlaybackIndex] and self.Frames[self.PlaybackIndex].t <= self.CurrentTime do self.PlaybackIndex = self.PlaybackIndex + 1 end
        
        local cF = self.Frames[self.PlaybackIndex] local pF = self.Frames[self.PlaybackIndex - 1]
        
        -- LOOP LOGIC
        if not cF then 
            if self.LoopEnabled then
                self.PlaybackIndex = 1
                self.CurrentTime = 0
                return
            else
                self.State = "Idle" self:CleanUp() return 
            end
        end

        if pF then
            local timeDiff = cF.t - pF.t local alpha = timeDiff > 0 and math.clamp((self.CurrentTime - pF.t) / timeDiff, 0, 1) or 1
            local pPos = Vector3.new(pF.px, pF.py, pF.pz) local cPos = Vector3.new(cF.px, cF.py, cF.pz)
            local pLook = Vector3.new(pF.lx, pF.ly, pF.lz) local cLook = Vector3.new(cF.lx, cF.ly, cF.lz)
            local pMD = Vector3.new(pF.mdx, pF.mdy, pF.mdz) local cMD = Vector3.new(cF.mdx, cF.mdy, cF.mdz)
            local lerpedPos = pPos:Lerp(cPos, alpha) local lerpedLook = pLook:Lerp(cLook, alpha) local lerpedMD = pMD:Lerp(cMD, alpha)

            if self.PhysicsProps.Att then if lerpedLook.Magnitude > 0.001 then self.PhysicsProps.Att.CFrame = CFrame.lookAt(lerpedPos, lerpedPos + lerpedLook) else self.PhysicsProps.Att.CFrame = CFrame.new(lerpedPos) end end
            if lerpedMD.Magnitude > 0.05 then LocalPlayer:Move(lerpedMD, false) else LocalPlayer:Move(Vector3.zero, false) end
            if pF.jump then VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game) task.delay(0.05, function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end) end

            local currentTool = char:FindFirstChildOfClass("Tool")
            if pF.tool then if not currentTool or currentTool.Name ~= pF.tool then local targetTool = LocalPlayer.Backpack:FindFirstChild(pF.tool) if targetTool then hum:EquipTool(targetTool) end end elseif currentTool then hum:UnequipTools() end

            if pF.m1 ~= nil then
                if pF.m1 and not self.LastM1State then VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1) self.LastM1State = true elseif not pF.m1 and self.LastM1State then VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1) self.LastM1State = false end
            end

            local activeThisFrame = {}
            for _, animData in ipairs(pF.anims or {}) do
                local assetStr = RevDict[animData.i]
                if assetStr then local track = self.AnimCache[assetStr] if track then if not track.IsPlaying then track:Play() end track.TimePosition = animData.tp track:AdjustWeight(animData.w) track:AdjustSpeed(animData.s * self.Speed) activeThisFrame[track] = true end end
            end
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do if not activeThisFrame[track] then track:Stop(0) end end
        end
    end))
end

function MacroEngine:Pause() if self.State == "Playing" then self.State = "Paused" self:ResetCharacterState() end end
function MacroEngine:Resume() if self.State == "Paused" then local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() if char:FindFirstChild("Animate") then char.Animate.Disabled = true end self:SetupPhysics(char:WaitForChild("HumanoidRootPart")) self.State = "Playing" end end
function MacroEngine:Stop() local wasRec = (self.State == "Recording") self.State = "Idle" self:CleanUp() return wasRec end

-- [PLAYER & SETTINGS FUNCTIONS]
local function ToggleAntiAfk(state)
    PlayerMods.AntiAfk = state
    if state then
        LocalPlayer.Idled:Connect(function()
            if PlayerMods.AntiAfk then VirtualUser:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame) task.wait(1) VirtualUser:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame) end
        end)
    end
end

local function BoostFPS()
    local function disableEffects(instance)
        if instance:IsA("BasePart") and not instance:IsA("MeshPart") then instance.Material = Enum.Material.SmoothPlastic instance.Reflectance = 0
        elseif instance:IsA("Decal") or instance:IsA("Texture") then instance.Transparency = 1
        elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail") then instance.Enabled = false end
    end
    for _, v in pairs(workspace:GetDescendants()) do disableEffects(v) end
    workspace.DescendantAdded:Connect(disableEffects)
    game:GetService("Lighting").GlobalShadows = false
    game:GetService("Lighting").FogEnd = 9e9
    for _, v in pairs(game:GetService("Lighting"):GetChildren()) do if v:IsA("PostEffect") then v.Enabled = false end end
    if workspace:FindFirstChildOfClass("Terrain") then workspace.Terrain.WaterWaveSize = 0 workspace.Terrain.WaterWaveSpeed = 0 workspace.Terrain.WaterReflectance = 0 workspace.Terrain.WaterTransparency = 1 end
end

local function ToggleFly(state)
    PlayerMods.Fly = state
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart local hum = char:FindFirstChild("Humanoid")
    
    if state then
        for _, cp in ipairs(char:GetDescendants()) do if cp:IsA("BasePart") then cp.CanCollide = false end end
        hum.PlatformStand = true
        local bg = Instance.new("BodyGyro", hrp) bg.P = 9e4 bg.maxTorque = Vector3.new(9e9, 9e9, 9e9) bg.cframe = hrp.CFrame
        local bv = Instance.new("BodyVelocity", hrp) bv.velocity = Vector3.new(0,0.1,0) bv.maxForce = Vector3.new(9e9, 9e9, 9e9)
        PlayerMods.FlyConn = RunService.RenderStepped:Connect(function()
            if not PlayerMods.Fly then bg:Destroy() bv:Destroy() PlayerMods.FlyConn:Disconnect() return end
            local cam = workspace.CurrentCamera
            bg.cframe = cam.CFrame
            local moveDir = Vector3.new()
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
            bv.velocity = moveDir * PlayerMods.FlySpeed
        end)
    else
        if PlayerMods.FlyConn then PlayerMods.FlyConn:Disconnect() end
        hum.PlatformStand = false
        for _, cp in ipairs(char:GetDescendants()) do if cp:IsA("BasePart") then cp.CanCollide = true end end
    end
end

local function ServerHop()
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local success, result = pcall(function() return game:HttpGet(url) end)
    if success then
        local data = HttpService:JSONDecode(result)
        if data and data.data then
            for _, server in ipairs(data.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer) return
                end
            end
        end
    end
end

FSM:Init()



local UI = { Parent = pcall(function() return CoreGui.Name end) and CoreGui or LocalPlayer:WaitForChild("PlayerGui") }
if UI.Parent:FindFirstChild("rezadevx_premium") then UI.Parent.rezadevx_premium:Destroy() end

local function ApplyCorner(obj, rad) Instance.new("UICorner", obj).CornerRadius = UDim.new(0, rad) end
local function ApplyStroke(obj, color, thick) local s = Instance.new("UIStroke", obj) s.Color = color s.Thickness = thick s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.LineJoinMode = Enum.LineJoinMode.Round return s end

local ScreenGui = Instance.new("ScreenGui") ScreenGui.Name = "rezadevx_premium" ScreenGui.ResetOnSpawn = false ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling ScreenGui.Parent = UI.Parent

local OpenBtn = Instance.new("ImageButton", ScreenGui) OpenBtn.Size = UDim2.new(0, 45, 0, 45) OpenBtn.Position = UDim2.new(0, 20, 0.5, -22) OpenBtn.BackgroundColor3 = THEME.BaseDark OpenBtn.BackgroundTransparency = 0.2 OpenBtn.Image = "rbxassetid://6035047409" OpenBtn.Visible = false ApplyCorner(OpenBtn, 12) ApplyStroke(OpenBtn, THEME.Accent, 1.5)

local MainFrame = Instance.new("Frame", ScreenGui) MainFrame.Size = UDim2.new(0, 620, 0, 480) MainFrame.Position = UDim2.new(0.5, -310, 0.5, -240) MainFrame.BackgroundColor3 = THEME.BaseDark MainFrame.BackgroundTransparency = 0.1 MainFrame.Active = true ApplyCorner(MainFrame, 10) ApplyStroke(MainFrame, THEME.Outline, 1.5)

local DropShadow = Instance.new("ImageLabel", MainFrame) DropShadow.AnchorPoint = Vector2.new(0.5, 0.5) DropShadow.Position = UDim2.new(0.5, 0, 0.5, 5) DropShadow.Size = UDim2.new(1, 45, 1, 45) DropShadow.BackgroundTransparency = 1 DropShadow.ZIndex = -1 DropShadow.Image = "rbxassetid://6015897843" DropShadow.ImageTransparency = 0.4 DropShadow.ImageColor3 = Color3.new(0,0,0) DropShadow.ScaleType = Enum.ScaleType.Slice DropShadow.SliceCenter = Rect.new(49, 49, 450, 450)

local Header = Instance.new("Frame", MainFrame) Header.Size = UDim2.new(1, 0, 0, 40) Header.BackgroundTransparency = 1
local HeaderStroke = Instance.new("Frame", Header) HeaderStroke.Size = UDim2.new(1, 0, 0, 1) HeaderStroke.Position = UDim2.new(0, 0, 1, 0) HeaderStroke.BackgroundColor3 = THEME.Outline HeaderStroke.BorderSizePixel = 0
local HeaderGradient = Instance.new("UIGradient", HeaderStroke) HeaderGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, THEME.Accent), ColorSequenceKeypoint.new(0.5, THEME.Action.Resume), ColorSequenceKeypoint.new(1, THEME.Outline)})

local Title = Instance.new("TextLabel", Header) Title.Size = UDim2.new(1, -100, 1, 0) Title.Position = UDim2.new(0, 15, 0, 0) Title.BackgroundTransparency = 1 Title.Text = "rezadevx premium" Title.TextColor3 = THEME.TextWhite Title.Font = Enum.Font.GothamBold Title.TextSize = 14 Title.TextXAlignment = Enum.TextXAlignment.Left

local function CreateHeaderBtn(pos, txt, color)
    local b = Instance.new("TextButton", Header) b.Size = UDim2.new(0, 26, 0, 26) b.Position = pos b.BackgroundTransparency = 1 b.Text = txt b.TextColor3 = color b.Font = Enum.Font.GothamBold b.TextSize = 13 ApplyCorner(b, 6) local s = ApplyStroke(b, THEME.Outline, 1)
    b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.2), {BackgroundTransparency = 0.8, BackgroundColor3 = color}):Play() TweenService:Create(s, TweenInfo.new(0.2), {Color = color}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play() TweenService:Create(s, TweenInfo.new(0.2), {Color = THEME.Outline}):Play() end) return b
end
local MinBtn = CreateHeaderBtn(UDim2.new(1, -70, 0.5, -13), "-", THEME.TextWhite)
local CloseBtn = CreateHeaderBtn(UDim2.new(1, -38, 0.5, -13), "X", THEME.Action.Record)


local Sidebar = Instance.new("Frame", MainFrame) Sidebar.Size = UDim2.new(0, 160, 1, -41) Sidebar.Position = UDim2.new(0, 0, 0, 41) Sidebar.BackgroundTransparency = 1
local SidebarStroke = Instance.new("Frame", Sidebar) SidebarStroke.Size = UDim2.new(0, 1, 1, 0) SidebarStroke.Position = UDim2.new(1, 0, 0, 0) SidebarStroke.BackgroundColor3 = THEME.Outline SidebarStroke.BorderSizePixel = 0

local ProfileFrame = Instance.new("Frame", Sidebar) ProfileFrame.Size = UDim2.new(1, -16, 0, 44) ProfileFrame.Position = UDim2.new(0, 8, 0, 10) ProfileFrame.BackgroundColor3 = THEME.PanelDark ProfileFrame.BackgroundTransparency = 0.5 ApplyCorner(ProfileFrame, 6) ApplyStroke(ProfileFrame, THEME.Outline, 1)
local AvatarImg = Instance.new("ImageLabel", ProfileFrame) AvatarImg.Size = UDim2.new(0, 30, 0, 30) AvatarImg.Position = UDim2.new(0, 6, 0.5, -15) AvatarImg.BackgroundTransparency = 1 AvatarImg.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420) ApplyCorner(AvatarImg, 15) ApplyStroke(AvatarImg, THEME.OutlineHover, 1)
local NameText = Instance.new("TextLabel", ProfileFrame) NameText.Size = UDim2.new(1, -42, 0, 14) NameText.Position = UDim2.new(0, 42, 0.5, -14) NameText.BackgroundTransparency = 1 NameText.Text = string.sub(LocalPlayer.DisplayName, 1, 12) NameText.TextColor3 = THEME.TextWhite NameText.Font = Enum.Font.GothamBold NameText.TextSize = 12 NameText.TextXAlignment = Enum.TextXAlignment.Left
local UserText = Instance.new("TextLabel", ProfileFrame) UserText.Size = UDim2.new(1, -42, 0, 12) UserText.Position = UDim2.new(0, 42, 0.5, 2) UserText.BackgroundTransparency = 1 UserText.Text = "@" .. string.sub(LocalPlayer.Name, 1, 12) UserText.TextColor3 = THEME.TextGray UserText.Font = Enum.Font.GothamMedium UserText.TextSize = 10 UserText.TextXAlignment = Enum.TextXAlignment.Left

local TabContainer = Instance.new("Frame", Sidebar) TabContainer.Size = UDim2.new(1, -16, 1, -70) TabContainer.Position = UDim2.new(0, 8, 0, 65) TabContainer.BackgroundTransparency = 1
local TabListLayout = Instance.new("UIListLayout", TabContainer) TabListLayout.Padding = UDim.new(0, 6)

local ContentArea = Instance.new("Frame", MainFrame) ContentArea.Size = UDim2.new(1, -161, 1, -41) ContentArea.Position = UDim2.new(0, 161, 0, 41) ContentArea.BackgroundTransparency = 1
local Tabs = {}

local function CreateTab(name, id)
    local btn = Instance.new("TextButton", TabContainer) btn.Size = UDim2.new(1, 0, 0, 32) btn.BackgroundTransparency = 1 btn.Text = "  " .. name btn.TextColor3 = THEME.TextGray btn.Font = Enum.Font.GothamBold btn.TextSize = 12 btn.TextXAlignment = Enum.TextXAlignment.Left ApplyCorner(btn, 6)
    local frame = Instance.new("Frame", ContentArea) frame.Size = UDim2.new(1, -20, 1, -20) frame.Position = UDim2.new(0, 10, 0, 10) frame.BackgroundTransparency = 1 frame.Visible = false
    Tabs[id] = {Btn = btn, Frame = frame}
    
    btn.MouseButton1Click:Connect(function()
        for tId, tData in pairs(Tabs) do
            if tId == id then tData.Frame.Visible = true TweenService:Create(tData.Btn, TweenInfo.new(0.2), {BackgroundColor3 = THEME.PanelDark, BackgroundTransparency = 0, TextColor3 = THEME.Accent}):Play()
            else tData.Frame.Visible = false TweenService:Create(tData.Btn, TweenInfo.new(0.2), {BackgroundTransparency = 1, TextColor3 = THEME.TextGray}):Play() end
        end
    end)
    return frame
end

local TabAutoWalk = CreateTab("Auto Walk", "autowalk")
local TabPlayer = CreateTab("Player Menu", "player")
local TabSettings = CreateTab("Settings", "settings")


local function CreateButton(parent, text, color, layoutOrder)
    local btn = Instance.new("TextButton", parent) btn.Size = UDim2.new(1, 0, 0, 32) btn.BackgroundTransparency = 1 btn.BackgroundColor3 = color btn.LayoutOrder = layoutOrder btn.Text = text btn.TextColor3 = color btn.Font = Enum.Font.GothamBold btn.TextSize = 12 btn.AutoButtonColor = false ApplyCorner(btn, 6) local s = ApplyStroke(btn, color, 1)
    btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.85, TextColor3 = THEME.TextWhite}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 1, TextColor3 = color}):Play() end) return btn
end


local AWLeft = Instance.new("Frame", TabAutoWalk) AWLeft.Size = UDim2.new(0.48, 0, 1, 0) AWLeft.BackgroundTransparency = 1
local AWLeftLayout = Instance.new("UIListLayout", AWLeft) AWLeftLayout.Padding = UDim.new(0, 6) AWLeftLayout.SortOrder = Enum.SortOrder.LayoutOrder

local AWRight = Instance.new("Frame", TabAutoWalk) AWRight.Size = UDim2.new(0.48, 0, 1, 0) AWRight.Position = UDim2.new(0.52, 0, 0, 0) AWRight.BackgroundColor3 = THEME.PanelDark AWRight.BackgroundTransparency = 0.5 ApplyCorner(AWRight, 8) ApplyStroke(AWRight, THEME.Outline, 1)

local StatusPanel = Instance.new("TextLabel", AWLeft) StatusPanel.Size = UDim2.new(1, 0, 0, 30) StatusPanel.BackgroundTransparency = 1 StatusPanel.LayoutOrder = 1 StatusPanel.Text = "Status: Idle" StatusPanel.TextColor3 = THEME.Accent StatusPanel.Font = Enum.Font.GothamBold StatusPanel.TextSize = 12 ApplyCorner(StatusPanel, 6) ApplyStroke(StatusPanel, THEME.Outline, 1)

local RecordBtn = CreateButton(AWLeft, "RECORD ALL (F5)", THEME.Action.Record, 2)
local PlayBtn = CreateButton(AWLeft, "PLAY NATIVE SYNC", THEME.Action.Play, 3)

local PRFrame = Instance.new("Frame", AWLeft) PRFrame.Size = UDim2.new(1, 0, 0, 32) PRFrame.BackgroundTransparency = 1 PRFrame.LayoutOrder = 4
local PRLay = Instance.new("UIListLayout", PRFrame) PRLay.FillDirection = Enum.FillDirection.Horizontal PRLay.Padding = UDim.new(0, 6)
local PauseBtn = CreateButton(PRFrame, "PAUSE", THEME.Action.Pause, 1) PauseBtn.Size = UDim2.new(0.5, -3, 1, 0)
local ResumeBtn = CreateButton(PRFrame, "RESUME", THEME.Action.Resume, 2) ResumeBtn.Size = UDim2.new(0.5, -3, 1, 0)

local StopBtn = CreateButton(AWLeft, "STOP & SAVE", THEME.Action.Stop, 5)


local LVFrame = Instance.new("Frame", AWLeft) LVFrame.Size = UDim2.new(1, 0, 0, 32) LVFrame.BackgroundTransparency = 1 LVFrame.LayoutOrder = 6
local LVLay = Instance.new("UIListLayout", LVFrame) LVLay.FillDirection = Enum.FillDirection.Horizontal LVLay.Padding = UDim.new(0, 6)
local LoopBtn = CreateButton(LVFrame, "LOOP: OFF", THEME.TextGray, 1) LoopBtn.Size = UDim2.new(0.5, -3, 1, 0) LoopBtn.UIStroke.Color = THEME.Outline
local PathBtn = CreateButton(LVFrame, "VISUAL: OFF", THEME.TextGray, 2) PathBtn.Size = UDim2.new(0.5, -3, 1, 0) PathBtn.UIStroke.Color = THEME.Outline

LoopBtn.MouseButton1Click:Connect(function()
    MacroEngine.LoopEnabled = not MacroEngine.LoopEnabled
    if MacroEngine.LoopEnabled then LoopBtn.Text = "LOOP: ON" LoopBtn.TextColor3 = THEME.Accent LoopBtn.UIStroke.Color = THEME.Accent else LoopBtn.Text = "LOOP: OFF" LoopBtn.TextColor3 = THEME.TextGray LoopBtn.UIStroke.Color = THEME.Outline end
end)
PathBtn.MouseButton1Click:Connect(function()
    MacroEngine.ShowPath = not MacroEngine.ShowPath
    if MacroEngine.ShowPath then PathBtn.Text = "VISUAL: ON" PathBtn.TextColor3 = THEME.Accent PathBtn.UIStroke.Color = THEME.Accent MacroEngine:RenderPath() else PathBtn.Text = "VISUAL: OFF" PathBtn.TextColor3 = THEME.TextGray PathBtn.UIStroke.Color = THEME.Outline if MacroEngine.PathFolder then MacroEngine.PathFolder:Destroy() MacroEngine.PathFolder = nil end end
end)

local SpeedFrame = Instance.new("Frame", AWLeft) SpeedFrame.Size = UDim2.new(1, 0, 0, 32) SpeedFrame.BackgroundTransparency = 1 SpeedFrame.LayoutOrder = 7 ApplyCorner(SpeedFrame, 6) ApplyStroke(SpeedFrame, THEME.Outline, 1)
local SpeedMin = Instance.new("TextButton", SpeedFrame) SpeedMin.Size = UDim2.new(0.25, 0, 1, 0) SpeedMin.BackgroundTransparency = 1 SpeedMin.Text = "-" SpeedMin.TextColor3 = THEME.TextGray SpeedMin.Font = Enum.Font.GothamBold SpeedMin.TextSize = 16
local SpeedMax = Instance.new("TextButton", SpeedFrame) SpeedMax.Size = UDim2.new(0.25, 0, 1, 0) SpeedMax.Position = UDim2.new(0.75, 0, 0, 0) SpeedMax.BackgroundTransparency = 1 SpeedMax.Text = "+" SpeedMax.TextColor3 = THEME.TextGray SpeedMax.Font = Enum.Font.GothamBold SpeedMax.TextSize = 16
local SpeedText = Instance.new("TextLabel", SpeedFrame) SpeedText.Size = UDim2.new(0.5, 0, 1, 0) SpeedText.Position = UDim2.new(0.25, 0, 0, 0) SpeedText.BackgroundTransparency = 1 SpeedText.Text = "Speed: 1.0x" SpeedText.TextColor3 = THEME.TextWhite SpeedText.Font = Enum.Font.GothamMedium SpeedText.TextSize = 11


local FileTitle = Instance.new("TextLabel", AWRight) FileTitle.Size = UDim2.new(1, 0, 0, 26) FileTitle.BackgroundTransparency = 1 FileTitle.Text = "SAVED FILE" FileTitle.TextColor3 = THEME.TextGray FileTitle.Font = Enum.Font.GothamBold FileTitle.TextSize = 11
local FileScroll = Instance.new("ScrollingFrame", AWRight) FileScroll.Size = UDim2.new(1, -16, 1, -110) FileScroll.Position = UDim2.new(0, 8, 0, 26) FileScroll.BackgroundTransparency = 1 FileScroll.ScrollBarThickness = 2 FileScroll.ScrollBarImageColor3 = THEME.OutlineHover FileScroll.CanvasSize = UDim2.new(0, 0, 0, 0) FileScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
local ScrollLayout = Instance.new("UIListLayout", FileScroll) ScrollLayout.Padding = UDim.new(0, 6)
local FileInput = Instance.new("TextBox", AWRight) FileInput.Size = UDim2.new(1, -16, 0, 30) FileInput.Position = UDim2.new(0, 8, 1, -74) FileInput.BackgroundTransparency = 1 FileInput.TextColor3 = THEME.TextWhite FileInput.PlaceholderText = "Enter File Name..." FileInput.PlaceholderColor3 = THEME.TextGray FileInput.Font = Enum.Font.GothamMedium FileInput.TextSize = 11 ApplyCorner(FileInput, 6) ApplyStroke(FileInput, THEME.Outline, 1)
local DelBtn = CreateButton(AWRight, "DELETE SELECTED", THEME.Action.Delete, 0) DelBtn.Size = UDim2.new(1, -16, 0, 30) DelBtn.Position = UDim2.new(0, 8, 1, -38)


local PlrLayout = Instance.new("UIListLayout", TabPlayer) PlrLayout.Padding = UDim.new(0, 8)
local function CreateToggleBtn(parent, text, callback)
    local btn = CreateButton(parent, text .. ": OFF", THEME.TextGray, 0) btn.UIStroke.Color = THEME.Outline
    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        if state then btn.Text = text .. ": ON" btn.TextColor3 = THEME.Accent btn.UIStroke.Color = THEME.Accent else btn.Text = text .. ": OFF" btn.TextColor3 = THEME.TextGray btn.UIStroke.Color = THEME.Outline end
        callback(state)
    end) return btn
end

CreateToggleBtn(TabPlayer, "ANTI-AFK (Prevent Kick)", ToggleAntiAfk)
local fpsBtn = CreateButton(TabPlayer, "ACTIVATE FPS BOOST", THEME.Action.Resume, 0)
fpsBtn.MouseButton1Click:Connect(function() BoostFPS() fpsBtn.Text = "FPS BOOST ACTIVE" fpsBtn.TextColor3 = THEME.TextGray fpsBtn.UIStroke.Color = THEME.Outline end)
CreateToggleBtn(TabPlayer, "C-FLY (Camera Fly)", ToggleFly)

local CreditsFrame = Instance.new("Frame", TabPlayer) CreditsFrame.Size = UDim2.new(1, 0, 0, 80) CreditsFrame.Position = UDim2.new(0,0,1,-80) CreditsFrame.BackgroundColor3 = THEME.PanelDark CreditsFrame.BackgroundTransparency = 0.5 ApplyCorner(CreditsFrame, 6) ApplyStroke(CreditsFrame, THEME.Outline, 1)
local CreditsTxt = Instance.new("TextLabel", CreditsFrame) CreditsTxt.Size = UDim2.new(1, -20, 1, -20) CreditsTxt.Position = UDim2.new(0, 10, 0, 10) CreditsTxt.BackgroundTransparency = 1 CreditsTxt.Text = "Premium Auto Walk Script\nCreated by rezadevx\nEnjoy the smooth execution!" CreditsTxt.TextColor3 = THEME.TextGray CreditsTxt.Font = Enum.Font.GothamMedium CreditsTxt.TextSize = 12


local SetLayout = Instance.new("UIListLayout", TabSettings) SetLayout.Padding = UDim.new(0, 8)

local Set1 = CreateButton(TabSettings, "DESTROY GUI", THEME.Action.Delete, 1)
Set1.MouseButton1Click:Connect(function() MacroEngine:CleanUp() ScreenGui:Destroy() end)
local Set2 = CreateButton(TabSettings, "EXIT ROBLOX", THEME.Action.Delete, 2)
Set2.MouseButton1Click:Connect(function() game:Shutdown() end)
local Set3 = CreateButton(TabSettings, "REJOIN SERVER", THEME.Action.Resume, 3)
Set3.MouseButton1Click:Connect(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
local Set4 = CreateButton(TabSettings, "FIND EMPTY SERVER (SERVER HOP)", THEME.Accent, 4)
Set4.MouseButton1Click:Connect(function() Set4.Text = "SEARCHING..." ServerHop() end)


local dragging, dragInput, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true dragStart = input.Position startPos = MainFrame.Position input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end) end
end)
Header.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end end)
UserInputService.InputChanged:Connect(function(input) if input == dragInput and dragging then local delta = input.Position - dragStart MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)

MinBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false OpenBtn.Visible = true end)
OpenBtn.MouseButton1Click:Connect(function() MainFrame.Visible = true OpenBtn.Visible = false end)
CloseBtn.MouseButton1Click:Connect(function() MacroEngine:CleanUp() if MacroEngine.PathFolder then MacroEngine.PathFolder:Destroy() end ScreenGui:Destroy() end)

local function RefreshUI()
    for _, child in ipairs(FileScroll:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    if not FSM.HasAccess then return end
    for _, filePath in ipairs(listfiles(CONFIG.Folder)) do
        local fileName = string.match(filePath, "([^/\\]+)%.json$")
        if fileName then
            local fileBtn = Instance.new("TextButton", FileScroll) fileBtn.Size = UDim2.new(1, 0, 0, 26) fileBtn.BackgroundTransparency = 1 fileBtn.BackgroundColor3 = THEME.Accent fileBtn.Text = fileName fileBtn.TextColor3 = THEME.TextGray fileBtn.Font = Enum.Font.GothamMedium fileBtn.TextSize = 11 fileBtn.TextXAlignment = Enum.TextXAlignment.Left Instance.new("UIPadding", fileBtn).PaddingLeft = UDim.new(0, 10) ApplyCorner(fileBtn, 4) local stroke = ApplyStroke(fileBtn, THEME.Outline, 1)
            fileBtn.MouseEnter:Connect(function() if stroke.Color ~= THEME.Accent then TweenService:Create(fileBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.9, TextColor3 = THEME.TextWhite}):Play() end end)
            fileBtn.MouseLeave:Connect(function() if stroke.Color ~= THEME.Accent then TweenService:Create(fileBtn, TweenInfo.new(0.2), {BackgroundTransparency = 1, TextColor3 = THEME.TextGray}):Play() end end)
            fileBtn.MouseButton1Click:Connect(function()
                FileInput.Text = fileName local data = FSM:Load(fileName)
                if data then
                    MacroEngine.Frames = data.Frames or {} MacroEngine.AnimDict = data.Dict or {} StatusPanel.Text = "Status: Loaded (" .. #MacroEngine.Frames .. " frames)"
                    for _, b in ipairs(FileScroll:GetChildren()) do if b:IsA("TextButton") then b.BackgroundTransparency = 1 b.UIStroke.Color = THEME.Outline b.TextColor3 = THEME.TextGray end end
                    fileBtn.BackgroundTransparency = 0.8 stroke.Color = THEME.Accent fileBtn.TextColor3 = THEME.TextWhite MacroEngine:RenderPath()
                end
            end)
        end
    end
end

RunService.RenderStepped:Connect(function()
    if MacroEngine.State == "Recording" then StatusPanel.Text = string.format("REC | F: %d | %.1fs", #MacroEngine.Frames, os.clock() - MacroEngine.StartTime) StatusPanel.TextColor3 = THEME.Action.Record
    elseif MacroEngine.State == "Playing" then StatusPanel.Text = string.format("PLAY | F: %d | %.1fs", #MacroEngine.Frames, MacroEngine.CurrentTime) StatusPanel.TextColor3 = THEME.Action.Play
    elseif MacroEngine.State == "Paused" then StatusPanel.Text = string.format("PAUSED | F: %d", #MacroEngine.Frames) StatusPanel.TextColor3 = THEME.Action.Pause
    else StatusPanel.TextColor3 = THEME.Accent end
end)

RecordBtn.MouseButton1Click:Connect(function() MacroEngine:Record() end) PlayBtn.MouseButton1Click:Connect(function() MacroEngine:Play() end)
PauseBtn.MouseButton1Click:Connect(function() MacroEngine:Pause() end) ResumeBtn.MouseButton1Click:Connect(function() MacroEngine:Resume() end)
StopBtn.MouseButton1Click:Connect(function()
    if MacroEngine:Stop() and #MacroEngine.Frames > 0 then local success, savedName = FSM:Save(FileInput.Text, {Dict = MacroEngine.AnimDict, Frames = MacroEngine.Frames}) if success then FileInput.Text = savedName StatusPanel.Text = "Status: Saved" RefreshUI() end end
    if MacroEngine.State == "Idle" then StatusPanel.Text = "Status: Idle" end
end)
DelBtn.MouseButton1Click:Connect(function()
    if not FSM.HasAccess then return end local name = FileInput.Text:gsub("[^%w%_]", "") local path = CONFIG.Folder .. "/" .. name .. ".json"
    if name ~= "" and isfile(path) then delfile(path) FileInput.Text = "" table.clear(MacroEngine.Frames) table.clear(MacroEngine.AnimDict) if MacroEngine.PathFolder then MacroEngine.PathFolder:Destroy() end StatusPanel.Text = "Status: Deleted" RefreshUI() end
end)
SpeedMin.MouseButton1Click:Connect(function() MacroEngine.Speed = math.clamp(MacroEngine.Speed - 0.1, 0.1, 5.0) SpeedText.Text = string.format("Speed: %.1fx", MacroEngine.Speed) end)
SpeedMax.MouseButton1Click:Connect(function() MacroEngine.Speed = math.clamp(MacroEngine.Speed + 0.1, 0.1, 5.0) SpeedText.Text = string.format("Speed: %.1fx", MacroEngine.Speed) end)

Tabs["autowalk"].Btn.BackgroundColor3 = THEME.PanelDark
Tabs["autowalk"].Btn.BackgroundTransparency = 0
Tabs["autowalk"].Btn.TextColor3 = THEME.Accent
Tabs["autowalk"].Frame.Visible = true
RefreshUI()