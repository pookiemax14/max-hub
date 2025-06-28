local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = workspace
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local aimbotEnabled = false
local rightClickHeld = false
local mouseDown = false
local fovSize = 10
local aimbotTargetPart = 'Head'
local fovColor = Color3.fromRGB(255, 255, 255)
local aimbotStrength = 1

local enemyESPEnabled = false
local teamESPEnabled = false
local tracersEnabled = false
local usernamesEnabled = false

local enemyESPColor = Color3.fromRGB(255, 0, 0)
local teamESPColor = Color3.fromRGB(0, 255, 0)

local movementSpeed = 16
local jumpPower = 50

local flyEnabled = false
local flySpeed = 50

local circle = Drawing.new('Circle')
circle.Visible = false
circle.Color = fovColor
circle.Thickness = 1
circle.NumSides = 100
circle.Radius = fovSize
circle.Filled = false
circle.Transparency = 1

local espBoxes = {}
local tracerLines = {}
local nameTexts = {}

local humanoid
local teleportTween
local bodyGyro, bodyVelocity

local spinAngle = 0
local teleportingToTarget = false

local autoClicking = false
local autoClickDelay = 0.05

local function getHumanoid()
    if LocalPlayer.Character then
        return LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    end
    return nil
end

local function applyMovement()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if flyEnabled then
        hum.WalkSpeed = 0
        hum.JumpPower = 0

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            if not bodyGyro then
                bodyGyro = Instance.new("BodyGyro", hrp)
                bodyGyro.P = 9e4
                bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                bodyGyro.CFrame = hrp.CFrame
            end
            if not bodyVelocity then
                bodyVelocity = Instance.new("BodyVelocity", hrp)
                bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                bodyVelocity.Velocity = Vector3.new(0,0,0)
            end

            local moveDirection = Vector3.new(0,0,0)
            local cameraCFrame = Workspace.CurrentCamera.CFrame

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDirection = moveDirection + cameraCFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDirection = moveDirection - cameraCFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDirection = moveDirection - cameraCFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDirection = moveDirection + cameraCFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDirection = moveDirection + Vector3.new(0,1,0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                moveDirection = moveDirection - Vector3.new(0,1,0)
            end

            if moveDirection.Magnitude > 0 then
                bodyVelocity.Velocity = moveDirection.Unit * flySpeed
                bodyGyro.CFrame = cameraCFrame
            else
                bodyVelocity.Velocity = Vector3.new(0,0,0)
            end
        end
    else
        if hum.WalkSpeed ~= movementSpeed then
            hum.WalkSpeed = movementSpeed
        end
        if hum.JumpPower ~= jumpPower then
            hum.JumpPower = jumpPower
        end
        if bodyGyro then
            bodyGyro:Destroy()
            bodyGyro = nil
        end
        if bodyVelocity then
            bodyVelocity:Destroy()
            bodyVelocity = nil
        end
    end
end

local function isEnemy(player)
    local localTeam = LocalPlayer.Team
    local playerTeam = player.Team
    if not localTeam or not playerTeam then
        return true
    end
    if localTeam.TeamColor and playerTeam.TeamColor then
        return localTeam.TeamColor ~= playerTeam.TeamColor
    end
    return playerTeam ~= localTeam
end

local function isFullyLoaded(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return humanoid and humanoid.Health > 0 and root and root.Position.Y > 5 and character:FindFirstChild("Head")
end

local function projectToScreen(pos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
    if onScreen and screenPos.Z > 0 then
        return Vector2.new(screenPos.X, screenPos.Y)
    end
    return nil
end

local function calculateBox(player)
    local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local heightStuds = 7.3
    local baseWidthStuds = heightStuds / 5
    local widthStuds = baseWidthStuds * 1.5

    local rootCFrame = rootPart.CFrame
    local top = rootCFrame.Position + Vector3.new(0, heightStuds / 2, 0)
    local bottom = rootCFrame.Position - Vector3.new(0, heightStuds / 2, 0)

    local topScreen = projectToScreen(top)
    local bottomScreen = projectToScreen(bottom)
    if not topScreen or not bottomScreen then return nil end

    local boxHeight = (bottomScreen - topScreen).Magnitude
    local boxWidth = math.max(boxHeight / (heightStuds / widthStuds), 15)

    local topLeft = Vector2.new(topScreen.X - boxWidth / 2, topScreen.Y)
    return topLeft, boxWidth, boxHeight
end

local function getClosestTarget()
    local closestPlayer = nil
    local shortestDistance = math.huge
    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return nil end
    local localPos = localRoot.Position

    for _, player in pairs(Players:GetPlayers()) do
        if
            player ~= LocalPlayer
            and player.Character
            and player.Character:FindFirstChild(aimbotTargetPart)
            and player.Character:FindFirstChild('Humanoid')
            and isFullyLoaded(player.Character)
            and isEnemy(player)
        then
            local targetPart = player.Character[aimbotTargetPart]
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            if not onScreen then continue end

            local screenVec = Vector2.new(screenPos.X, screenPos.Y)
            if not ((Vector2.new(Mouse.X, Mouse.Y) - screenVec).Magnitude <= fovSize) then continue end

            local targetPos = player.Character.HumanoidRootPart.Position
            local dist = (targetPos - localPos).Magnitude
            if dist < shortestDistance then
                shortestDistance = dist
                closestPlayer = player
            end
        end
    end
    return closestPlayer
end

local function clearESPForPlayer(player)
    if espBoxes[player] then
        espBoxes[player].Visible = false
        espBoxes[player] = nil
    end
    if tracerLines[player] then
        tracerLines[player].Visible = false
        tracerLines[player] = nil
    end
    if nameTexts[player] then
        nameTexts[player].Visible = false
        nameTexts[player] = nil
    end
end

local function onCharacterRemoving(player)
    clearESPForPlayer(player)
end

local function onPlayerAdded(player)
    player.CharacterRemoving:Connect(function()
        clearESPForPlayer(player)
    end)
end

for _, player in pairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)

local teleportTween

local function smoothTeleport(targetCFrame)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    if teleportTween then
        teleportTween:Cancel()
        teleportTween = nil
    end

    local humanoidRoot = char.HumanoidRootPart
    local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    teleportTween = TweenService:Create(humanoidRoot, tweenInfo, {CFrame = targetCFrame})
    teleportTween:Play()
end

local killAllEnabled = false
local autoFarmEnabled = false

local spinAngle = 0
local teleportingToTarget = false

local function universalAutoClicker()
    while autoClicking do
        local success, err = pcall(function()
            VirtualInputManager:SendMouseButtonEvent(
                UserInputService:GetMouseLocation().X,
                UserInputService:GetMouseLocation().Y,
                true,
                game
            )
            VirtualInputManager:SendMouseButtonEvent(
                UserInputService:GetMouseLocation().X,
                UserInputService:GetMouseLocation().Y,
                false,
                game
            )
        end)

        if not success then
            local char = LocalPlayer.Character
            if char then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool and tool.Activate then
                    pcall(function()
                        tool:Activate()
                    end)
                end
            end
        end

        wait(autoClickDelay)
    end
end

local autoClickDelay = 0.05

local function killAllLoop()
    while killAllEnabled do
        if not isFullyLoaded(LocalPlayer.Character) then
            wait(0.5)
            continue
        end
        local enemy = getClosestTarget()
        if enemy
            and enemy.Character
            and enemy.Character:FindFirstChild("HumanoidRootPart")
            and isFullyLoaded(enemy.Character) then

            local hrp = enemy.Character.HumanoidRootPart
            local offset = Vector3.new(0, 3, 6)
            local targetCFrame = hrp.CFrame * CFrame.new(offset)
            if targetCFrame.p.Y > 5 then
                smoothTeleport(targetCFrame)
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, hrp.Position)
            end
        end
        wait(0.3)
    end
end

local function autoFarmLoop()
    while autoFarmEnabled do
        if not isFullyLoaded(LocalPlayer.Character) then
            wait(0.5)
            continue
        end

        local enemy = getClosestTarget()
        if enemy
            and enemy.Character
            and enemy.Character:FindFirstChild("HumanoidRootPart")
            and isFullyLoaded(enemy.Character) then

            teleportingToTarget = true

            local hrp = enemy.Character.HumanoidRootPart
            local offset = Vector3.new(0, 3, 6)
            local targetCFrame = hrp.CFrame * CFrame.new(offset)

            if targetCFrame.p.Y > 5 then
                smoothTeleport(targetCFrame)

                local targetPart = enemy.Character[aimbotTargetPart]
                local camPos = Camera.CFrame.Position
                local desiredLook = (targetPart.Position - camPos).Unit
                local newCFrame = CFrame.new(camPos, camPos + desiredLook)
                Camera.CFrame = newCFrame
            end

            teleportingToTarget = false
        else
            spinAngle = (spinAngle + 30) % 360
            local currentCFrame = Camera.CFrame
            local spinCFrame = CFrame.Angles(0, math.rad(spinAngle), 0)
            Camera.CFrame = CFrame.new(currentCFrame.Position) * spinCFrame

            wait(0.05)
        end

        wait(0.05)
    end
end

RunService.RenderStepped:Connect(function()
    circle.Position = Vector2.new(Mouse.X, Mouse.Y + 36)
    circle.Radius = fovSize
    circle.Color = fovColor
    circle.Visible = aimbotEnabled and (rightClickHeld or autoFarmEnabled)

    if aimbotEnabled and (rightClickHeld or autoFarmEnabled) then
        local currentTarget = getClosestTarget()
        if currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChild(aimbotTargetPart) and
           currentTarget.Character:FindFirstChild('Humanoid') and currentTarget.Character.Humanoid.Health > 0 and
           isEnemy(currentTarget) then

            local targetPart = currentTarget.Character[aimbotTargetPart]
            local currentCFrame = Camera.CFrame
            local newLookVector = (targetPart.Position - currentCFrame.Position).Unit

            local lerpCFrame = CFrame.new(currentCFrame.Position, currentCFrame.Position + currentCFrame.LookVector:Lerp(newLookVector, math.clamp(aimbotStrength / 10, 0, 1)))
            Camera.CFrame = lerpCFrame
        end
    end

    humanoid = getHumanoid()
    applyMovement()

    for _, player in pairs(Players:GetPlayers()) do
        local valid = player ~= LocalPlayer
            and player.Character
            and player.Character:FindFirstChild('HumanoidRootPart')
            and player.Character:FindFirstChild('Humanoid')
            and player.Character.Humanoid.Health > 0

        if valid then
            local isEnemyPlayer = isEnemy(player)
            local showESP = (isEnemyPlayer and enemyESPEnabled) or (not isEnemyPlayer and teamESPEnabled)
            local boxColor = isEnemyPlayer and enemyESPColor or teamESPColor

            if showESP then
                local topLeft, boxWidth, boxHeight = calculateBox(player)
                if topLeft then
                    if not espBoxes[player] then
                        espBoxes[player] = Drawing.new("Square")
                        espBoxes[player].Thickness = 2
                        espBoxes[player].Filled = false
                    end
                    local box = espBoxes[player]
                    box.Position = topLeft
                    box.Size = Vector2.new(boxWidth, boxHeight)
                    box.Color = boxColor
                    box.Visible = true
                elseif espBoxes[player] then
                    espBoxes[player].Visible = false
                    espBoxes[player] = nil
                end
            elseif espBoxes[player] then
                espBoxes[player].Visible = false
                espBoxes[player] = nil
            end

            if tracersEnabled and isEnemyPlayer then
                local rootPosScreen = projectToScreen(player.Character.HumanoidRootPart.Position)
                if rootPosScreen then
                    if not tracerLines[player] then
                        tracerLines[player] = Drawing.new("Line")
                        tracerLines[player].Thickness = 1
                    end
                    local line = tracerLines[player]
                    line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    line.To = rootPosScreen
                    line.Color = enemyESPColor
                    line.Visible = true
                elseif tracerLines[player] then
                    tracerLines[player].Visible = false
                    tracerLines[player] = nil
                end
            elseif tracerLines[player] then
                tracerLines[player].Visible = false
                tracerLines[player] = nil
            end

            if usernamesEnabled then
                local head = player.Character:FindFirstChild("Head")
                if head then
                    local headPosScreen = projectToScreen(head.Position + Vector3.new(0, 0.5, 0))
                    if headPosScreen then
                        if not nameTexts[player] then
                            nameTexts[player] = Drawing.new("Text")
                            nameTexts[player].Center = true
                            nameTexts[player].Outline = true
                            nameTexts[player].Font = 3
                            nameTexts[player].Size = 16
                        end
                        local text = nameTexts[player]
                        text.Text = player.Name
                        text.Position = headPosScreen
                        text.Color = boxColor
                        text.Visible = true
                    elseif nameTexts[player] then
                        nameTexts[player].Visible = false
                        nameTexts[player] = nil
                    end
                elseif nameTexts[player] then
                    nameTexts[player].Visible = false
                    nameTexts[player] = nil
                end
            elseif nameTexts[player] then
                nameTexts[player].Visible = false
                nameTexts[player] = nil
            end
        else
            clearESPForPlayer(player)
        end
    end
end)

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 and aimbotEnabled then
        rightClickHeld = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        rightClickHeld = false
    end
end)

local Window = Rayfield:CreateWindow({
    Name = 'Xen Hub V2',
    LoadingTitle = 'Loading...',
    LoadingSubtitle = 'Please wait',
    Theme = 'AmberGlow',
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false, Invite = 'noinvitelink', RememberJoins = true },
    KeySystem = true,
    KeySettings = {
        Title = 'Xen key system',
        Subtitle = 'Enter your key',
        Note = 'Obtain your key from our website',
        FileName = 'Key',
        SaveKey = true,
        GrabKeyFromSite = false,
        Key = { 'xenhubv1' },
    },
    Size = Vector2.new(600, 400),
})

local MainTab = Window:CreateTab('Main', 4483362458)
local MainSection = MainTab:CreateSection('Rage Cheat')

MainTab:CreateToggle({
    Name = 'Toggle Aimbot',
    CurrentValue = false,
    Flag = 'FeatureToggle',
    Callback = function(Value)
        aimbotEnabled = Value
        if not Value then
            rightClickHeld = false
            mouseDown = false
        end
    end,
})

MainTab:CreateSlider({
    Name = 'Aimbot Strength',
    Range = { 0, 10 },
    Increment = 1,
    Suffix = '',
    CurrentValue = 10,
    Flag = 'Slider1',
    Callback = function(Value)
        aimbotStrength = Value
    end,
})

MainTab:CreateDropdown({
    Name = 'Aimbot Target',
    Options = { 'Head', 'Torso', 'HumanoidRootPart' },
    CurrentOption = { 'Head' },
    MultipleOptions = false,
    Flag = 'Dropdown1',
    Callback = function(Option)
        aimbotTargetPart = Option[1] or 'Head'
    end,
})

local FovSection = MainTab:CreateSection('FOV')

MainTab:CreateSlider({
    Name = 'Fov Size',
    Range = { 0, 500 },
    Increment = 10,
    Suffix = '',
    CurrentValue = fovSize,
    Flag = 'Slider2',
    Callback = function(Value)
        fovSize = Value
    end,
})

MainTab:CreateColorPicker({
    Name = 'Fov Color',
    Color = fovColor,
    Flag = 'ColorPicker1',
    Callback = function(Value)
        fovColor = Value
    end,
})

MainTab:CreateLabel("Aimbot always ON and shooting in autofarm")

local EspTab = Window:CreateTab('ESP', 4483362458)
local EspSection = EspTab:CreateSection('ESP Settings')

EspTab:CreateToggle({
    Name = 'Enemy ESP',
    CurrentValue = false,
    Flag = 'EnemyESPEnable',
    Callback = function(Value)
        enemyESPEnabled = Value
    end,
})

EspTab:CreateColorPicker({
    Name = 'Enemy ESP Color',
    Color = Color3.fromRGB(255, 0, 0),
    Flag = 'EnemyESPColorPicker',
    Callback = function(Value)
        enemyESPColor = Value
    end,
})

EspTab:CreateToggle({
    Name = 'Team ESP',
    CurrentValue = false,
    Flag = 'TeamESPEnable',
    Callback = function(Value)
        teamESPEnabled = Value
    end,
})

EspTab:CreateColorPicker({
    Name = 'Team ESP Color',
    Color = Color3.fromRGB(0, 255, 0),
    Flag = 'TeamESPColorPicker',
    Callback = function(Value)
        teamESPColor = Value
    end,
})

EspTab:CreateToggle({
    Name = 'Tracers',
    CurrentValue = false,
    Flag = 'TracersToggle',
    Callback = function(Value)
        tracersEnabled = Value
    end,
})

EspTab:CreateToggle({
    Name = 'Usernames',
    CurrentValue = false,
    Flag = 'UsernamesToggle',
    Callback = function(Value)
        usernamesEnabled = Value
    end,
})

local MovementTab = Window:CreateTab('Movement', 4483362458)
local MovementSection = MovementTab:CreateSection('Movement and Jump')

MovementTab:CreateSlider({
    Name = 'Walk Speed',
    Range = { 1, 100 },
    Increment = 1,
    Suffix = '',
    CurrentValue = 16,
    Flag = 'WalkSpeedSlider',
    Callback = function(Value)
        movementSpeed = Value
    end,
})

MovementTab:CreateSlider({
    Name = 'Jump Power',
    Range = { 10, 150 },
    Increment = 1,
    Suffix = '',
    CurrentValue = 50,
    Flag = 'JumpPowerSlider',
    Callback = function(Value)
        jumpPower = Value
    end,
})

MovementTab:CreateToggle({
    Name = 'Fly',
    CurrentValue = false,
    Flag = 'FlyToggle',
    Callback = function(Value)
        flyEnabled = Value
    end,
})

MovementTab:CreateSlider({
    Name = 'Fly Speed',
    Range = { 1, 200 },
    Increment = 1,
    Suffix = '',
    CurrentValue = 50,
    Flag = 'FlySpeedSlider',
    Callback = function(Value)
        flySpeed = Value
    end,
})

local MiscTab = Window:CreateTab('Misc', 4483362458)
local MiscSection = MiscTab:CreateSection('Misc Features')

MiscTab:CreateToggle({
    Name = 'Kill All (Teleport Behind Enemies Smooth)',
    CurrentValue = false,
    Flag = 'KillAllToggle',
    Callback = function(Value)
        killAllEnabled = Value
        if Value then
            coroutine.wrap(killAllLoop)()
        end
    end,
})

MiscTab:CreateToggle({
    Name = 'AutoFarm (Kill All + Aimbot + AutoShoot)',
    CurrentValue = false,
    Flag = 'AutoFarmToggle',
    Callback = function(Value)
        autoFarmEnabled = Value
        if Value then
            aimbotEnabled = true
            fovSize = 500
            rightClickHeld = true
            aimbotStrength = 10
            mouseDown = true
            coroutine.wrap(autoFarmLoop)()
            if not autoClicking then
                autoClicking = true
                coroutine.wrap(universalAutoClicker)()
            end
        else
            aimbotEnabled = false
            rightClickHeld = false
            mouseDown = false
            autoClicking = false
        end
    end,
})

Rayfield:LoadConfiguration()

