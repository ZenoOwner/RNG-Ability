-- ZenoHub | RNG Ability Farm
pcall(function() game:GetService("CoreGui"):FindFirstChild("ZenoHub"):Destroy() end)
pcall(function() game:GetService("CoreGui"):FindFirstChild("ZenoLoader"):Destroy() end)

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local lp = Players.LocalPlayer

local ABILITIES = {
    {category="Confirmed", name="Nanotech", rarity="1/400", detect={"nanotech","nanoblade"}, moves={
        {remote="Nanoblade", cooldown=5},
        {remote="NanoClient", cooldown=8},
        {remote="VECTOR-SLASH", cooldown=6},
    }},
    {category="Confirmed", name="Hit", rarity="1/500", detect={"hit"}, moves={
        {remote="Timeskip", cooldown=4},
        {remote="HitTimestop", cooldown=6},
        {remote="HitTSEffect", cooldown=5},
    }},
    {category="Confirmed", name="Explosion", rarity="1/833", detect={"explosion"}, moves={
        {remote="ExplosionServer", cooldown=8},
        {remote="EnergyBlast", cooldown=10},
    }},
    {category="Confirmed", name="Sonic", rarity="1/1000", detect={"sonic"}, moves={
        {remote="SpringBoostServer", cooldown=5},
        {remote="SonicBOOM", cooldown=8},
        {remote="RushServer", cooldown=6},
        {remote="SonicBeamDamage", cooldown=140},
    }},
    {category="Confirmed", name="Star", rarity="1/556", detect={"star"}, moves={
        {remote="Star", cooldown=5},
        {remote="BlazingStarServer", cooldown=8},
        {remote="FallenStarsServer", cooldown=12},
    }},
    {category="Unconfirmed", name="Kaioken", rarity="1/200", detect={"kaioken"}, moves={}},
    {category="Unconfirmed", name="Gravity", rarity="???", detect={"gravity"}, moves={}},
    {category="Unconfirmed", name="Dragon", rarity="???", detect={"dragon"}, moves={}},
    {category="Unconfirmed", name="Chaos Control", rarity="???", detect={"chaos"}, moves={}},
    {category="Unconfirmed", name="Oblivion", rarity="???", detect={"oblivion"}, moves={}},
    {category="Unconfirmed", name="Night Guy", rarity="???", detect={"night","nightguy"}, moves={}},
}

local SAFE_POS  = Vector3.new(-1333.34912109375, 179.49998474121094, 1050.5540771484375)
local FIGHT_POS = Vector3.new(0.01, 303.22, -0.83)
local LOBBY_POS = Vector3.new(99.74, 11.29, -106.97)
local LOW_HP = 30
local FULL_HP = 90

local rolling, farming, active = false, false, false
local m1Enabled = false
local rollCount, lastAbility = 0, "None"
local selectedAbility = nil
local moveIndex = 1
local lastMoveTimes = {}
local m1Thread, farmThread, rollThread = nil, nil, nil

local function tpTo(pos)
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = CFrame.new(pos) end
end

local function getHealth()
    local char = lp.Character
    if not char then return 100 end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health or 100
end

local function isInCutscene(p)
    if not p.Character then return true end
    local hum = p.Character:FindFirstChildOfClass("Humanoid")
    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return true end
    return hum.WalkSpeed == 0 or hrp.Anchored
end

local function getLowestTarget()
    local lowest, target = math.huge, nil
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= lp and p.Character and not isInCutscene(p) then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and hum.Health < lowest then
                lowest = hum.Health
                target = p
            end
        end
    end
    return target
end

local function tpAbove(target)
    if not target or not target.Character then return end
    local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and tHRP then
        hrp.CFrame = CFrame.new(tHRP.Position + Vector3.new(0,4,0), tHRP.Position)
    end
end

local VirtualUser = game:GetService("VirtualUser")
lp.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

local FreezeRemote = RS:WaitForChild("FreezePlayer")
local InvFreeze = RS:WaitForChild("InventoryFreeze")

FreezeRemote.OnClientEvent:Connect(function(val)
    if not val then return end
    task.wait(0.05)
    local char = lp.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 16 hum.JumpPower = 50 end
    for _, v in pairs(char:GetDescendants()) do
        if v:IsA("BasePart") then v.Anchored = false end
    end
end)

InvFreeze.OnClientEvent:Connect(function(val)
    if not val then return end
    task.wait(0.05)
    local char = lp.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 16 hum.JumpPower = 50 end
end)

local RollAnnouncement = RS:WaitForChild("RollAnnouncement")
local Roll = RS:WaitForChild("Roll")

RollAnnouncement.OnClientEvent:Connect(function(username, abilityName, rarity)
    if tostring(username):lower() ~= lp.Name:lower() then return end
    rollCount = rollCount + 1
    lastAbility = tostring(abilityName) .. " (" .. tostring(rarity) .. ")"
    if not rolling or not selectedAbility then return end
    local clean = tostring(abilityName):lower():gsub("[%s%-_]","")
    for _, kw in pairs(selectedAbility.detect) do
        if clean:find(kw) then
            rolling = false
            if rollThread then task.cancel(rollThread) rollThread = nil end
            task.wait(0.5)
            farming = true
            moveIndex = 1
            lastMoveTimes = {}
            farmThread = task.spawn(startFarm)
            return
        end
    end
end)

local function stopM1()
    if m1Thread then task.cancel(m1Thread) m1Thread = nil end
end

local function startM1()
    stopM1()
    m1Thread = task.spawn(function()
        while farming and m1Enabled do
            local t = getLowestTarget()
            if t then tpAbove(t) end
            pcall(function()
                mouse1press()
                task.wait(0.05)
                mouse1release()
            end)
            task.wait(0.1)
        end
    end)
end

local function stopAll()
    rolling = false
    farming = false
    active = false
    m1Enabled = false
    stopM1()
    if rollThread then task.cancel(rollThread) rollThread = nil end
    if farmThread then task.cancel(farmThread) farmThread = nil end
end

function startFarm()
    tpTo(FIGHT_POS)
    task.wait(1)
    while farming do
        if getHealth() < LOW_HP then
            stopM1()
            tpTo(SAFE_POS)
            repeat task.wait(1) until getHealth() >= FULL_HP or not farming
            if not farming then break end
            tpTo(FIGHT_POS)
            task.wait(1)
        end

        -- unconfirmed = only M1 if enabled, no ability firing
        if selectedAbility.category == "Unconfirmed" then
            if m1Enabled and not m1Thread then startM1() end
            task.wait(0.1)
        else
            local target = getLowestTarget()
            if target and target.Character then
                tpAbove(target)
                task.wait(0.05)
                local moves = selectedAbility.moves
                local now = tick()
                local move = moves[moveIndex]
                local lastTime = lastMoveTimes[moveIndex] or 0
                if now - lastTime >= move.cooldown then
                    stopM1()
                    pcall(function()
                        local r = RS:FindFirstChild(move.remote, true)
                        if r then r:FireServer() end
                    end)
                    lastMoveTimes[moveIndex] = now
                    moveIndex = (moveIndex % #moves) + 1
                else
                    if m1Enabled and not m1Thread then startM1() end
                end
            else
                stopM1()
                local char = lp.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then hrp.CFrame = hrp.CFrame * CFrame.new(0,0,-5) end
                end
            end
            task.wait(0.1)
        end
    end
    stopM1()
end

lp.CharacterAdded:Connect(function()
    if farming or rolling then
        stopAll()
        task.wait(3)
        tpTo(LOBBY_POS)
    end
end)

-- GUI
local sg = Instance.new("ScreenGui")
sg.Name = "ZenoHub"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.Parent = game:GetService("CoreGui")

-- Loading screen
local loadBG = Instance.new("Frame", sg)
loadBG.Size = UDim2.fromScale(1,1)
loadBG.BackgroundColor3 = Color3.fromRGB(3,3,8)
loadBG.BorderSizePixel = 0
loadBG.ZIndex = 100

local lf = Instance.new("Frame", loadBG)
lf.Size = UDim2.fromOffset(240,180)
lf.Position = UDim2.new(0.5,-120,0.5,-90)
lf.BackgroundColor3 = Color3.fromRGB(6,6,18)
lf.BorderSizePixel = 0
lf.ZIndex = 101
Instance.new("UICorner", lf).CornerRadius = UDim.new(0,12)
local lfs = Instance.new("UIStroke", lf)
lfs.Color = Color3.fromRGB(0,200,255)
lfs.Thickness = 2

local ltitle = Instance.new("TextLabel", lf)
ltitle.Size = UDim2.new(1,0,0,44)
ltitle.Position = UDim2.new(0,0,0,12)
ltitle.BackgroundTransparency = 1
ltitle.Text = "⚡ ZenoHub"
ltitle.TextSize = 28
ltitle.Font = Enum.Font.GothamBold
ltitle.TextXAlignment = Enum.TextXAlignment.Center
ltitle.ZIndex = 102

local lsub = Instance.new("TextLabel", lf)
lsub.Size = UDim2.new(1,0,0,14)
lsub.Position = UDim2.new(0,0,0,56)
lsub.BackgroundTransparency = 1
lsub.TextColor3 = Color3.fromRGB(0,200,255)
lsub.Text = "RNG Ability Farm"
lsub.TextSize = 11
lsub.Font = Enum.Font.Gotham
lsub.TextXAlignment = Enum.TextXAlignment.Center
lsub.ZIndex = 102

local lwarn = Instance.new("TextLabel", lf)
lwarn.Size = UDim2.new(1,0,0,12)
lwarn.Position = UDim2.new(0,0,0,72)
lwarn.BackgroundTransparency = 1
lwarn.TextColor3 = Color3.fromRGB(255,60,60)
lwarn.Text = "⚠️ USE AT YOUR OWN RISK"
lwarn.TextSize = 9
lwarn.Font = Enum.Font.GothamBold
lwarn.TextXAlignment = Enum.TextXAlignment.Center
lwarn.ZIndex = 102

local lbarBG = Instance.new("Frame", lf)
lbarBG.Size = UDim2.new(0.8,0,0,5)
lbarBG.Position = UDim2.new(0.1,0,0,96)
lbarBG.BackgroundColor3 = Color3.fromRGB(20,20,40)
lbarBG.BorderSizePixel = 0
lbarBG.ZIndex = 102
Instance.new("UICorner", lbarBG).CornerRadius = UDim.new(1,0)

local lbar = Instance.new("Frame", lbarBG)
lbar.Size = UDim2.new(0,0,1,0)
lbar.BackgroundColor3 = Color3.fromRGB(0,200,255)
lbar.BorderSizePixel = 0
lbar.ZIndex = 103
Instance.new("UICorner", lbar).CornerRadius = UDim.new(1,0)

local lstat = Instance.new("TextLabel", lf)
lstat.Size = UDim2.new(1,0,0,12)
lstat.Position = UDim2.new(0,0,0,107)
lstat.BackgroundTransparency = 1
lstat.TextColor3 = Color3.fromRGB(100,150,200)
lstat.Text = "Initializing..."
lstat.TextSize = 9
lstat.Font = Enum.Font.Gotham
lstat.TextXAlignment = Enum.TextXAlignment.Center
lstat.ZIndex = 102

local hueL = 0
local rgbConn = RunService.Heartbeat:Connect(function(dt)
    hueL = (hueL + dt*0.4) % 1
    ltitle.TextColor3 = Color3.fromHSV(hueL, 1, 1)
end)

task.spawn(function()
    local steps = {
        {0.2,"Connecting remotes..."},
        {0.4,"Setting up anti-freeze..."},
        {0.6,"Loading abilities..."},
        {0.8,"Building GUI..."},
        {1.0,"Ready!"},
    }
    for _, s in ipairs(steps) do
        TweenService:Create(lbar, TweenInfo.new(0.4), {Size=UDim2.new(s[1],0,1,0)}):Play()
        lstat.Text = s[2]
        task.wait(0.5)
    end
    task.wait(0.3)
    rgbConn:Disconnect()
    TweenService:Create(loadBG, TweenInfo.new(0.5), {BackgroundTransparency=1}):Play()
    for _, v in pairs(lf:GetDescendants()) do
        pcall(function()
            if v:IsA("TextLabel") then
                TweenService:Create(v, TweenInfo.new(0.4), {TextTransparency=1}):Play()
            elseif v:IsA("Frame") then
                TweenService:Create(v, TweenInfo.new(0.4), {BackgroundTransparency=1}):Play()
            end
        end)
    end
    task.wait(0.6)
    loadBG:Destroy()
end)

-- Reopen btn (bottom right)
local reopenBtn = Instance.new("TextButton", sg)
reopenBtn.Size = UDim2.fromOffset(26,26)
reopenBtn.Position = UDim2.new(1,-34,1,-34)
reopenBtn.BackgroundColor3 = Color3.fromRGB(0,180,255)
reopenBtn.TextColor3 = Color3.fromRGB(255,255,255)
reopenBtn.Text = "⚡"
reopenBtn.TextSize = 12
reopenBtn.Font = Enum.Font.GothamBold
reopenBtn.BorderSizePixel = 0
reopenBtn.ZIndex = 50
Instance.new("UICorner", reopenBtn).CornerRadius = UDim.new(0,6)

-- Main frame
local main = Instance.new("ScrollingFrame", sg)
main.Size = UDim2.fromOffset(175,360)
main.Position = UDim2.new(0.5,-87,0.5,-180)
main.BackgroundColor3 = Color3.fromRGB(5,8,18)
main.BorderSizePixel = 0
main.ScrollBarThickness = 2
main.ScrollBarImageColor3 = Color3.fromRGB(0,200,255)
main.CanvasSize = UDim2.fromOffset(0,0)
main.AutomaticCanvasSize = Enum.AutomaticSize.Y
main.Active = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0,10)

local border = Instance.new("Frame", main)
border.Size = UDim2.new(1,4,1,4)
border.Position = UDim2.new(0,-2,0,-2)
border.BorderSizePixel = 0
border.ZIndex = main.ZIndex - 1
Instance.new("UICorner", border).CornerRadius = UDim.new(0,12)

local hue = 0
RunService.Heartbeat:Connect(function(dt)
    hue = (hue + dt*0.3) % 1
    border.BackgroundColor3 = Color3.fromHSV(hue, 0.9, 1)
end)

local pad = Instance.new("Frame", main)
pad.Size = UDim2.new(1,0,0,0)
pad.BackgroundTransparency = 1
pad.AutomaticSize = Enum.AutomaticSize.Y
local layout = Instance.new("UIListLayout", pad)
layout.Padding = UDim.new(0,3)
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
local padInset = Instance.new("UIPadding", pad)
padInset.PaddingTop = UDim.new(0,3)
padInset.PaddingBottom = UDim.new(0,5)
padInset.PaddingLeft = UDim.new(0,4)
padInset.PaddingRight = UDim.new(0,4)

-- Title bar
local titleBar = Instance.new("Frame", main)
titleBar.Size = UDim2.new(1,0,0,28)
titleBar.BackgroundColor3 = Color3.fromRGB(0,18,40)
titleBar.BorderSizePixel = 0
titleBar.Active = true
titleBar.ZIndex = 10
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0,10)
local tbFix = Instance.new("Frame", titleBar)
tbFix.Size = UDim2.new(1,0,0.5,0)
tbFix.Position = UDim2.new(0,0,0.5,0)
tbFix.BackgroundColor3 = Color3.fromRGB(0,18,40)
tbFix.BorderSizePixel = 0
tbFix.ZIndex = 10

local titleLbl = Instance.new("TextLabel", titleBar)
titleLbl.Size = UDim2.new(1,-32,1,0)
titleLbl.Position = UDim2.new(0,7,0,0)
titleLbl.BackgroundTransparency = 1
titleLbl.TextColor3 = Color3.fromRGB(0,200,255)
titleLbl.Text = "⚡ ZenoHub"
titleLbl.TextSize = 11
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 11

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.fromOffset(18,18)
closeBtn.Position = UDim2.new(1,-22,0.5,-9)
closeBtn.BackgroundColor3 = Color3.fromRGB(180,0,50)
closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
closeBtn.Text = "✕"
closeBtn.TextSize = 9
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 11
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,4)

closeBtn.MouseButton1Click:Connect(function() main.Visible = false end)
reopenBtn.MouseButton1Click:Connect(function() main.Visible = not main.Visible end)

local dragging, dragStart, startPos2 = false, nil, nil
titleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true dragStart = i.Position startPos2 = main.Position
    end
end)
titleBar.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
        local d = i.Position - dragStart
        main.Position = UDim2.new(startPos2.X.Scale, startPos2.X.Offset+d.X, startPos2.Y.Scale, startPos2.Y.Offset+d.Y)
    end
end)
titleBar.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

local spacer = Instance.new("Frame", pad)
spacer.Size = UDim2.new(1,0,0,28)
spacer.BackgroundTransparency = 1

local function makeLbl(text, color, big, bold)
    local l = Instance.new("TextLabel", pad)
    l.Size = UDim2.new(1,-4,0, big and 13 or 11)
    l.BackgroundTransparency = 1
    l.TextColor3 = color
    l.Text = text
    l.TextSize = big and 10 or 8
    l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Center
    l.TextTruncate = Enum.TextTruncate.AtEnd
    return l
end

local function makeDivider()
    local d = Instance.new("Frame", pad)
    d.Size = UDim2.new(0.9,0,0,1)
    d.BackgroundColor3 = Color3.fromRGB(0,200,255)
    d.BackgroundTransparency = 0.75
    d.BorderSizePixel = 0
end

local function makeSection(text, color)
    local l = Instance.new("TextLabel", pad)
    l.Size = UDim2.new(1,-4,0,12)
    l.BackgroundTransparency = 1
    l.TextColor3 = color
    l.Text = text
    l.TextSize = 9
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Center
end

makeLbl("⚠️ USE AT YOUR OWN RISK", Color3.fromRGB(255,60,60), true, true)
local statusLbl = makeLbl("💤 Idle", Color3.fromRGB(150,150,150), true, true)
local rollLbl   = makeLbl("🎲 Rolls: 0", Color3.fromRGB(180,200,255), false, false)
local targetLbl = makeLbl("🎯 No target", Color3.fromRGB(255,100,100), false, false)

makeDivider()

-- M1 toggle (always visible)
local m1Toggle = Instance.new("TextButton", pad)
m1Toggle.Size = UDim2.new(1,-4,0,22)
m1Toggle.BackgroundColor3 = Color3.fromRGB(10,18,35)
m1Toggle.TextColor3 = Color3.fromRGB(180,180,180)
m1Toggle.Text = "👊 M1 Spam: OFF"
m1Toggle.TextSize = 9
m1Toggle.Font = Enum.Font.GothamBold
m1Toggle.BorderSizePixel = 0
Instance.new("UICorner", m1Toggle).CornerRadius = UDim.new(0,5)
local m1Stroke = Instance.new("UIStroke", m1Toggle)
m1Stroke.Color = Color3.fromRGB(60,60,80)
m1Stroke.Thickness = 1

local m1Warn = makeLbl("⚠️ Can't move while active", Color3.fromRGB(255,165,0), false, false)
m1Warn.Visible = false

m1Toggle.MouseButton1Click:Connect(function()
    if not farming then return end
    m1Enabled = not m1Enabled
    if m1Enabled then
        m1Toggle.Text = "👊 M1 Spam: ON"
        m1Toggle.BackgroundColor3 = Color3.fromRGB(0,40,90)
        m1Toggle.TextColor3 = Color3.fromRGB(0,220,255)
        m1Stroke.Color = Color3.fromRGB(0,200,255)
        m1Warn.Visible = true
        startM1()
    else
        m1Toggle.Text = "👊 M1 Spam: OFF"
        m1Toggle.BackgroundColor3 = Color3.fromRGB(10,18,35)
        m1Toggle.TextColor3 = Color3.fromRGB(180,180,180)
        m1Stroke.Color = Color3.fromRGB(60,60,80)
        m1Warn.Visible = false
        stopM1()
    end
end)

makeDivider()

local selectedBtn = nil
local function makeAbilityBtn(ability)
    local btn = Instance.new("TextButton", pad)
    btn.Size = UDim2.new(1,-4,0,22)
    btn.BackgroundColor3 = Color3.fromRGB(10,18,35)
    btn.TextColor3 = Color3.fromRGB(180,210,255)
    btn.Text = ability.name .. "  " .. ability.rarity
    btn.TextSize = 9
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,5)
    local st = Instance.new("UIStroke", btn)
    st.Color = Color3.fromRGB(0,80,160)
    st.Thickness = 1
    btn.MouseButton1Click:Connect(function()
        if selectedBtn then
            selectedBtn.BackgroundColor3 = Color3.fromRGB(10,18,35)
            selectedBtn.TextColor3 = Color3.fromRGB(180,210,255)
            local s = selectedBtn:FindFirstChildOfClass("UIStroke")
            if s then s.Color = Color3.fromRGB(0,80,160) end
        end
        selectedAbility = ability
        selectedBtn = btn
        btn.BackgroundColor3 = Color3.fromRGB(0,40,90)
        btn.TextColor3 = Color3.fromRGB(0,220,255)
        st.Color = Color3.fromRGB(0,200,255)
    end)
end

makeSection("── CONFIRMED ──", Color3.fromRGB(0,220,120))
for _, a in ipairs(ABILITIES) do if a.category == "Confirmed" then makeAbilityBtn(a) end end
makeDivider()
makeSection("── UNCONFIRMED ──", Color3.fromRGB(255,165,0))
makeLbl("(Use abilities yourself)", Color3.fromRGB(180,140,80), false, false)
for _, a in ipairs(ABILITIES) do if a.category == "Unconfirmed" then makeAbilityBtn(a) end end
makeDivider()

local startBtn = Instance.new("TextButton", pad)
startBtn.Size = UDim2.new(1,-4,0,26)
startBtn.BackgroundColor3 = Color3.fromRGB(0,130,60)
startBtn.TextColor3 = Color3.fromRGB(255,255,255)
startBtn.Text = "▶  START"
startBtn.TextSize = 11
startBtn.Font = Enum.Font.GothamBold
startBtn.BorderSizePixel = 0
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0,6)

local goBackBtn = Instance.new("TextButton", pad)
goBackBtn.Size = UDim2.new(1,-4,0,22)
goBackBtn.BackgroundColor3 = Color3.fromRGB(10,18,35)
goBackBtn.TextColor3 = Color3.fromRGB(0,200,255)
goBackBtn.Text = "⚔️  Go to Fight Arena"
goBackBtn.TextSize = 9
goBackBtn.Font = Enum.Font.GothamBold
goBackBtn.BorderSizePixel = 0
Instance.new("UICorner", goBackBtn).CornerRadius = UDim.new(0,5)
local gbStroke = Instance.new("UIStroke", goBackBtn)
gbStroke.Color = Color3.fromRGB(0,120,200)
gbStroke.Thickness = 1

goBackBtn.MouseButton1Click:Connect(function() tpTo(FIGHT_POS) end)

-- Stop popup
local popup = Instance.new("Frame", sg)
popup.Size = UDim2.fromOffset(190,95)
popup.Position = UDim2.new(0.5,-95,0.5,-47)
popup.BackgroundColor3 = Color3.fromRGB(6,10,22)
popup.BorderSizePixel = 0
popup.Visible = false
popup.ZIndex = 200
Instance.new("UICorner", popup).CornerRadius = UDim.new(0,10)
Instance.new("UIStroke", popup).Color = Color3.fromRGB(0,200,255)

local popLbl = Instance.new("TextLabel", popup)
popLbl.Size = UDim2.new(1,0,0,28)
popLbl.Position = UDim2.new(0,0,0,6)
popLbl.BackgroundTransparency = 1
popLbl.TextColor3 = Color3.fromRGB(255,255,255)
popLbl.Text = "Stopped! Where to?"
popLbl.TextSize = 11
popLbl.Font = Enum.Font.GothamBold
popLbl.TextXAlignment = Enum.TextXAlignment.Center
popLbl.ZIndex = 201

local popFight = Instance.new("TextButton", popup)
popFight.Size = UDim2.new(0.45,0,0,26)
popFight.Position = UDim2.new(0.04,0,0,40)
popFight.BackgroundColor3 = Color3.fromRGB(0,130,200)
popFight.TextColor3 = Color3.fromRGB(255,255,255)
popFight.Text = "⚔️ Arena"
popFight.TextSize = 9
popFight.Font = Enum.Font.GothamBold
popFight.BorderSizePixel = 0
popFight.ZIndex = 201
Instance.new("UICorner", popFight).CornerRadius = UDim.new(0,5)

local popStay = Instance.new("TextButton", popup)
popStay.Size = UDim2.new(0.45,0,0,26)
popStay.Position = UDim2.new(0.51,0,0,40)
popStay.BackgroundColor3 = Color3.fromRGB(60,60,80)
popStay.TextColor3 = Color3.fromRGB(255,255,255)
popStay.Text = "📍 Stay"
popStay.TextSize = 9
popStay.Font = Enum.Font.GothamBold
popStay.BorderSizePixel = 0
popStay.ZIndex = 201
Instance.new("UICorner", popStay).CornerRadius = UDim.new(0,5)

popFight.MouseButton1Click:Connect(function() popup.Visible = false tpTo(FIGHT_POS) end)
popStay.MouseButton1Click:Connect(function() popup.Visible = false end)

startBtn.MouseButton1Click:Connect(function()
    if not active then
        if not selectedAbility then
            statusLbl.Text = "⚠️ Pick an ability first!"
            statusLbl.TextColor3 = Color3.fromRGB(255,60,60)
            return
        end
        active = true
        rolling = true
        farming = false
        moveIndex = 1
        lastMoveTimes = {}
        m1Enabled = false
        m1Toggle.Text = "👊 M1 Spam: OFF"
        m1Toggle.BackgroundColor3 = Color3.fromRGB(10,18,35)
        m1Toggle.TextColor3 = Color3.fromRGB(180,180,180)
        m1Stroke.Color = Color3.fromRGB(60,60,80)
        m1Warn.Visible = false
        startBtn.Text = "⏹  STOP"
        startBtn.BackgroundColor3 = Color3.fromRGB(160,30,30)
        tpTo(SAFE_POS)
        rollThread = task.spawn(function()
            while rolling do
                pcall(function() Roll:FireServer() end)
                task.wait(0)
            end
        end)
    else
        stopAll()
        m1Toggle.Text = "👊 M1 Spam: OFF"
        m1Toggle.BackgroundColor3 = Color3.fromRGB(10,18,35)
        m1Toggle.TextColor3 = Color3.fromRGB(180,180,180)
        m1Stroke.Color = Color3.fromRGB(60,60,80)
        m1Warn.Visible = false
        startBtn.Text = "▶  START"
        startBtn.BackgroundColor3 = Color3.fromRGB(0,130,60)
        popup.Visible = true
    end
end)

RunService.Heartbeat:Connect(function()
    rollLbl.Text = "🎲 Rolls: " .. rollCount .. "  |  " .. lastAbility
    local t = getLowestTarget()
    targetLbl.Text = "🎯 " .. (t and t.Name or "No target")
    if not active then
        statusLbl.Text = "💤 Idle"
        statusLbl.TextColor3 = Color3.fromRGB(150,150,150)
    elseif rolling then
        statusLbl.Text = "🎲 Rolling for " .. selectedAbility.name .. "..."
        statusLbl.TextColor3 = Color3.fromRGB(255,165,0)
    elseif farming then
        if getHealth() < LOW_HP then
            statusLbl.Text = "💊 Regening..."
            statusLbl.TextColor3 = Color3.fromRGB(255,50,50)
        elseif m1Thread then
            statusLbl.Text = "👊 M1 spamming..."
            statusLbl.TextColor3 = Color3.fromRGB(255,200,0)
        elseif selectedAbility.category == "Unconfirmed" then
            statusLbl.Text = "⚔️ Farming - use ur abilities!"
            statusLbl.TextColor3 = Color3.fromRGB(255,165,0)
        else
            statusLbl.Text = "⚔️ " .. selectedAbility.moves[moveIndex].remote
            statusLbl.TextColor3 = Color3.fromRGB(0,255,100)
        end
    end
end)
