--// CONFIGURAÇÕES
_G.SilentAim = false
_G.FOV = 150
_G.VisibleCheck = true
_G.TeamCheck = true
_G.TeamCheckForNPCs = false
_G.Prediction = 0.165
_G.UpdateRate = 0.2
_G.TargetMode = "NPCs" -- "NPCs", "Players", "Both"
_G.AimPart = "Head" -- "Head", "Torso", "Both", "Random"

--// SERVIÇOS
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

--// FOV CIRCLE
local Circle = Drawing.new("Circle")
Circle.Color = Color3.fromRGB(0, 255, 0)
Circle.Thickness = 2
Circle.Visible = false
Circle.Radius = _G.FOV
Circle.Transparency = 0.7
Circle.Filled = false

--// VARIÁVEIS
local CurrentTarget = nil
local TargetPart = nil
local TargetInRange = false
local NPCCache = {}
local PlayerCache = {}
local LastCacheUpdate = 0
local CacheUpdateInterval = 2
local FloatButton = nil
local MainUI = nil
local PulseConnection = nil

--// VARIÁVEIS PARA HOOKS (não limpar)
local oldNamecall = nil
local oldIndex = nil

--// FUNÇÃO DE LIMPEZA DA UI APENAS
local function CleanupUIOnly()
    -- Limpar círculo FOV
    if Circle then 
        Circle.Visible = false
    end
    
    -- Limpar botão flutuante
    if PulseConnection then
        PulseConnection:Disconnect()
        PulseConnection = nil
    end
    
    if FloatButton and FloatButton.Parent then
        FloatButton:Destroy()
        FloatButton = nil
    end
    
    -- Limpar UI principal
    pcall(function()
        if game:GetService("CoreGui"):FindFirstChild("SilentAimCompactUI") then
            game:GetService("CoreGui").SilentAimCompactUI:Destroy()
        end
    end)
    
    CurrentTarget = nil
    TargetPart = nil
    TargetInRange = false
    NPCCache = {}
    PlayerCache = {}
    MainUI = nil
end

--// LISTA DE TAGS DE NPCs
local NPCTags = {
    "NPC", "Npc", "npc",
    "Enemy", "enemy", "Enemies", "enemies",
    "Bot", "bot", "Bots", "bots",
    "Mob", "mob", "Mobs", "mobs",
    "Zombie", "zombie", "Zombies", "zombies",
    "Monster", "monster", "Monsters", "monsters",
    "Creature", "creature",
    "Villain", "villain",
    "Bad", "bad", "BadGuy", "badguy",
    "Hostile", "hostile",
    "Target", "target",
    "Dummy", "dummy", "Dummies", "dummies",
    "Practice", "practice",
    "Training", "training"
}

--// FUNÇÃO: É PLAYER? (OTIMIZADA)
local function IsPlayer(character)
    if not character or not character:IsA("Model") then
        return false
    end
    
    if character == LocalPlayer.Character then
        return true
    end
    
    local player = Players:GetPlayerFromCharacter(character)
    return player ~= nil
end

--// FUNÇÃO: É NPC? (OTIMIZADA)
local function IsNPC(character)
    if not character or not character:IsA("Model") then
        return false
    end
    
    if IsPlayer(character) then
        return false
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local head = character:FindFirstChild("Head")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not head or not hrp or humanoid.Health <= 0 then
        return false
    end
    
    local charName = character.Name:lower()
    for _, tag in pairs(NPCTags) do
        if charName:find(tag:lower(), 1, true) then
            return true
        end
    end
    
    return true
end

--// FUNÇÃO: VERIFICAR TIME (PLAYERS)
local function IsEnemyPlayer(player)
    if not _G.TeamCheck then
        return true
    end
    
    if not player then
        return false
    end
    
    if not LocalPlayer.Team or not player.Team then
        return true
    end
    
    return LocalPlayer.Team ~= player.Team
end

--// FUNÇÃO: VERIFICAR TIME (NPCs)
local function IsEnemyNPC(npcModel)
    if not _G.TeamCheckForNPCs then
        return true
    end
    
    -- Verificar se o NPC tem uma propriedade de time
    local npcTeamValue = npcModel:FindFirstChild("Team")
    if npcTeamValue and npcTeamValue:IsA("StringValue") then
        local npcTeam = npcTeamValue.Value
        local localTeam = LocalPlayer.Team and LocalPlayer.Team.Name or ""
        
        -- Verificar se o time do NPC é diferente do seu
        if npcTeam and localTeam and npcTeam ~= localTeam then
            return true
        end
    end
    
    -- Por padrão, considerar NPCs como inimigos
    return true
end

--// FUNÇÃO: SELECIONAR PARTE DO ALVO
local function GetTargetPart(character)
    if _G.AimPart == "Head" then
        return character:FindFirstChild("Head")
    elseif _G.AimPart == "Torso" then
        return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
    elseif _G.AimPart == "Random" then
        local parts = {
            character:FindFirstChild("Head"),
            character:FindFirstChild("UpperTorso"),
            character:FindFirstChild("Torso"),
            character:FindFirstChild("HumanoidRootPart")
        }
        for _, part in pairs(parts) do
            if part then return part end
        end
    elseif _G.AimPart == "Both" then
        -- Alternar entre cabeça e torso
        local head = character:FindFirstChild("Head")
        local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
        if head and torso then
            return tick() % 1 > 0.5 and head or torso
        elseif head then
            return head
        elseif torso then
            return torso
        end
    end
    
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
end

--// FUNÇÃO: ATUALIZAR CACHES
local function UpdateCaches()
    local currentTime = tick()
    
    if currentTime - LastCacheUpdate < CacheUpdateInterval then
        return
    end
    
    LastCacheUpdate = currentTime
    
    NPCCache = {}
    PlayerCache = {}
    
    local modelsToCheck = {}
    
    for _, model in pairs(workspace:GetChildren()) do
        if model:IsA("Model") and model ~= LocalPlayer.Character then
            table.insert(modelsToCheck, model)
        end
    end
    
    local npcFolders = {"NPCs", "Enemies", "Bots", "Mobs", "Targets", "Enemy", "Hostile"}
    for _, folderName in pairs(npcFolders) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            for _, model in pairs(folder:GetChildren()) do
                if model:IsA("Model") then
                    table.insert(modelsToCheck, model)
                end
            end
        end
    end
    
    for _, model in pairs(modelsToCheck) do
        local hrp = model:FindFirstChild("HumanoidRootPart")
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        
        if hrp and humanoid and humanoid.Health > 0 then
            if IsPlayer(model) then
                PlayerCache[model] = {
                    Model = model,
                    HRP = hrp,
                    Humanoid = humanoid,
                    Player = Players:GetPlayerFromCharacter(model),
                    IsNPC = false
                }
            elseif IsNPC(model) then
                NPCCache[model] = {
                    Model = model,
                    HRP = hrp,
                    Humanoid = humanoid,
                    IsNPC = true
                }
            end
        end
    end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            
            if hrp and humanoid and humanoid.Health > 0 then
                PlayerCache[char] = {
                    Model = char,
                    HRP = hrp,
                    Humanoid = humanoid,
                    Player = player,
                    IsNPC = false
                }
            end
        end
    end
end

--// FUNÇÃO: BUSCAR TARGET
local function GetTarget()
    if not LocalPlayer.Character then 
        TargetInRange = false
        TargetPart = nil
        return nil 
    end
    
    local shortestDist = _G.FOV + 1
    local closestPart = nil
    local closestTarget = nil
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local localChar = LocalPlayer.Character
    
    TargetInRange = false
    TargetPart = nil
    
    UpdateCaches()
    
    local function ProcessTarget(data, isPlayer)
        local hrp = data.HRP
        local humanoid = data.Humanoid
        
        if hrp and humanoid and humanoid.Health > 0 then
            -- Verificar Team Check
            if isPlayer then
                if not IsEnemyPlayer(data.Player) then
                    return
                end
            else
                if not IsEnemyNPC(data.Model) then
                    return
                end
            end
            
            -- Selecionar parte do alvo
            local targetPart = GetTargetPart(data.Model)
            if not targetPart then
                targetPart = hrp
            end
            
            local targetPos = targetPart.Position
            
            if hrp.Velocity.Magnitude > 1 and _G.Prediction > 0 then
                targetPos = targetPos + (hrp.Velocity * _G.Prediction)
            end
            
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPos)
            
            if onScreen then
                local screenPoint = Vector2.new(screenPos.X, screenPos.Y)
                local dist = (screenPoint - screenCenter).Magnitude
                
                if dist <= _G.FOV then
                    TargetInRange = true
                    
                    if _G.VisibleCheck then
                        local raycastParams = RaycastParams.new()
                        raycastParams.FilterDescendantsInstances = {localChar, Camera}
                        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                        raycastParams.IgnoreWater = true
                        
                        local origin = Camera.CFrame.Position
                        local direction = (targetPos - origin).Unit * 500
                        local ray = workspace:Raycast(origin, direction, raycastParams)
                        
                        if not ray or ray.Instance:IsDescendantOf(data.Model) then
                            if dist < shortestDist then
                                shortestDist = dist
                                closestPart = targetPart
                                closestTarget = data.Model
                            end
                        end
                    else
                        if dist < shortestDist then
                            shortestDist = dist
                            closestPart = targetPart
                            closestTarget = data.Model
                        end
                    end
                end
            end
        end
    end
    
    if _G.TargetMode == "NPCs" or _G.TargetMode == "Both" then
        for _, data in pairs(NPCCache) do
            ProcessTarget(data, false)
        end
    end
    
    if _G.TargetMode == "Players" or _G.TargetMode == "Both" then
        for _, data in pairs(PlayerCache) do
            ProcessTarget(data, true)
        end
    end
    
    TargetPart = closestPart
    return closestTarget
end

--// ATUALIZAR TARGET
task.spawn(function()
    while true do
        task.wait(_G.UpdateRate)
        if _G.SilentAim then
            CurrentTarget = GetTarget()
        else
            CurrentTarget = nil
            TargetInRange = false
            TargetPart = nil
        end
    end
end)

--// HOOKS ATUALIZADOS (executar apenas uma vez)
if not oldNamecall then
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if not _G.SilentAim or not TargetPart then
            return oldNamecall(self, ...)
        end
        
        local method = getnamecallmethod()
        local args = {...}
        
        if (method == "FireServer" or method == "InvokeServer") and typeof(self) == "Instance" then
            local selfName = self.Name:lower()
            if string.find(selfName, "fire") or string.find(selfName, "hit") or string.find(selfName, "attack") or string.find(selfName, "damage") then
                local newArgs = {}
                local modified = false
                
                for i, arg in pairs(args) do
                    if typeof(arg) == "Vector3" then
                        newArgs[i] = TargetPart.Position
                        modified = true
                    elseif typeof(arg) == "CFrame" then
                        newArgs[i] = CFrame.new(TargetPart.Position)
                        modified = true
                    elseif typeof(arg) == "Ray" then
                        local origin = arg.Origin
                        newArgs[i] = Ray.new(origin, (TargetPart.Position - origin).Unit * 100)
                        modified = true
                    else
                        newArgs[i] = arg
                    end
                end
                
                if modified then
                    return oldNamecall(self, unpack(newArgs))
                end
            end
        end
        
        if method == "Raycast" and self == workspace then
            local origin = args[1]
            local direction = args[2]
            
            if origin and TargetPart then
                local newDir = (TargetPart.Position - origin).Unit * direction.Magnitude
                return oldNamecall(self, origin, newDir, args[3], args[4])
            end
        end
        
        return oldNamecall(self, ...)
    end)
end

if not oldIndex then
    oldIndex = hookmetamethod(game, "__index", function(self, key)
        if self == Mouse and _G.SilentAim and TargetPart then
            local keyLower = string.lower(key)
            if keyLower == "hit" then
                return CFrame.new(TargetPart.Position)
            elseif keyLower == "target" then
                return TargetPart
            end
        end
        return oldIndex(self, key)
    end)
end

--// ATUALIZAR CÍRCULO
local lastCircleUpdate = 0
RunService.RenderStepped:Connect(function()
    local currentTime = tick()
    
    if currentTime - lastCircleUpdate < 0.1 then
        return
    end
    
    lastCircleUpdate = currentTime
    
    Circle.Visible = _G.SilentAim
    
    if _G.SilentAim then
        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        Circle.Position = screenCenter
        Circle.Radius = _G.FOV
        
        if CurrentTarget then
            local isPlayerTarget = false
            for _, data in pairs(PlayerCache) do
                if data.Model == CurrentTarget then
                    isPlayerTarget = true
                    break
                end
            end
            
            if isPlayerTarget then
                Circle.Color = Color3.fromRGB(0, 150, 255)
            else
                Circle.Color = Color3.fromRGB(0, 255, 0)
            end
        elseif TargetInRange then
            Circle.Color = Color3.fromRGB(255, 255, 0)
        else
            Circle.Color = Color3.fromRGB(255, 50, 0)
        end
    end
end)

--// FUNÇÃO PARA LIMPAR BOTÃO FLUTUANTE
local function CleanupFloatButton()
    if PulseConnection then
        PulseConnection:Disconnect()
        PulseConnection = nil
    end
    
    if FloatButton and FloatButton.Parent then
        FloatButton:Destroy()
        FloatButton = nil
    end
end

--// CRIAÇÃO DO BOTÃO FLUTUANTE CORRIGIDO
local function CreateFloatButton(parent)
    CleanupFloatButton()
    
    -- Esperar um frame para evitar conflitos
    task.wait(0.1)
    
    FloatButton = Instance.new("TextButton")
    FloatButton.Name = "FloatButton"
    FloatButton.Size = UDim2.new(0, 60, 0, 60)
    FloatButton.AnchorPoint = Vector2.new(0.5, 0.5)
    FloatButton.Position = UDim2.new(0.95, 0, 0.1, 0)
    FloatButton.Text = "🎯"
    FloatButton.TextColor3 = Color3.fromRGB(240, 240, 240)
    FloatButton.BackgroundColor3 = Color3.fromRGB(100, 70, 200)
    FloatButton.BackgroundTransparency = 0.2
    FloatButton.Font = Enum.Font.GothamBold
    FloatButton.TextSize = 24
    FloatButton.ZIndex = 1000
    FloatButton.Parent = parent
    
    local FloatCorner = Instance.new("UICorner")
    FloatCorner.CornerRadius = UDim.new(1, 0)
    FloatCorner.Parent = FloatButton
    
    local FloatStroke = Instance.new("UIStroke")
    FloatStroke.Color = Color3.fromRGB(240, 240, 240)
    FloatStroke.Thickness = 2
    FloatStroke.Transparency = 0.3
    FloatStroke.Parent = FloatButton
    
    -- Sombra/Glow fixa (não segue mouse)
    local FloatShadow = Instance.new("ImageLabel")
    FloatShadow.Name = "FloatShadow"
    FloatShadow.Size = UDim2.new(1, 15, 1, 15)
    FloatShadow.Position = UDim2.new(0, -7.5, 0, -7.5)
    FloatShadow.Image = "rbxassetid://5554236805"
    FloatShadow.ImageColor3 = Color3.fromRGB(100, 70, 200)
    FloatShadow.ImageTransparency = 0.7
    FloatShadow.ScaleType = Enum.ScaleType.Slice
    FloatShadow.SliceCenter = Rect.new(23, 23, 277, 277)
    FloatShadow.BackgroundTransparency = 1
    FloatShadow.ZIndex = 999
    FloatShadow.Parent = FloatButton
    
    -- VARIÁVEIS DE CONTROLE DA ANIMAÇÃO
    local isDragging = false
    local isAnimating = true
    
    -- Função de animação controlável
    local function UpdatePulseAnimation()
        if not FloatButton or not FloatButton.Parent then return end
        if isDragging then return end
        
        local pulse = math.sin(tick() * 2) * 0.15 + 0.85
        FloatButton.BackgroundTransparency = 0.2 + (0.15 * (1 - pulse))
        FloatShadow.ImageTransparency = 0.7 + (0.2 * (1 - pulse))
        
        -- Rotação mais suave e controlada
        if isAnimating then
            FloatButton.Rotation = math.sin(tick() * 0.5) * 2
        end
    end
    
    -- Substitua a PulseConnection por este sistema melhorado
    PulseConnection = RunService.Heartbeat:Connect(function()
        pcall(UpdatePulseAnimation)
    end)
    
    -- Função para abrir menu
    FloatButton.MouseButton1Click:Connect(function()
        if MainUI and MainUI.Parent then
            local mainFrame = MainUI:FindFirstChild("MainFrame")
            if mainFrame then
                -- Pausar animação durante a transição
                isAnimating = false
                
                mainFrame.Visible = true
                CleanupFloatButton()
                
                -- Posicionar menu perto do botão
                local buttonPos = FloatButton.AbsolutePosition
                local screenSize = workspace.CurrentCamera.ViewportSize
                
                mainFrame.Position = UDim2.new(
                    0,
                    math.clamp(buttonPos.X - 140, 10, screenSize.X - mainFrame.AbsoluteSize.X - 10),
                    0,
                    math.clamp(buttonPos.Y + 70, 10, screenSize.Y - mainFrame.AbsoluteSize.Y - 10)
                )
                mainFrame.Size = UDim2.new(0, 0, 0, 0)
                
                local tweenIn = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, 320, 0, 400)
                })
                tweenIn:Play()
            end
        end
    end)
    
    -- Sistema de arrastar melhorado
    local draggingFloat = false
    local dragStartFloat, startPosFloat
    
    FloatButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingFloat = true
            isDragging = true  -- Pausar animação
            dragStartFloat = input.Position
            startPosFloat = FloatButton.Position
            
            TweenService:Create(FloatButton, TweenInfo.new(0.1), {
                BackgroundColor3 = Color3.fromRGB(120, 90, 220),
                Size = UDim2.new(0, 55, 0, 55)
            }):Play()
            
            -- Resetar rotação durante arrasto
            FloatButton.Rotation = 0
        end
    end)
    
    FloatButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingFloat = false
            isDragging = false  -- Retomar animação
            
            TweenService:Create(FloatButton, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(100, 70, 200),
                Size = UDim2.new(0, 60, 0, 60)
            }):Play()
            
            -- Snap to edges
            local screenSize = workspace.CurrentCamera.ViewportSize
            local buttonSize = FloatButton.AbsoluteSize
            local pos = FloatButton.Position
            
            local newX = pos.X.Offset
            local newY = pos.Y.Offset
            
            if newX < screenSize.X / 2 then
                newX = 10
            else
                newX = screenSize.X - buttonSize.X - 10
            end
            
            TweenService:Create(FloatButton, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
                Position = UDim2.new(0, newX, 0, math.clamp(newY, 10, screenSize.Y - buttonSize.Y - 10))
            }):Play()
        end
    end)
    
    local inputChangedConnection
    inputChangedConnection = UserInputService.InputChanged:Connect(function(input)
        if draggingFloat and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStartFloat
            local screenSize = workspace.CurrentCamera.ViewportSize
            local buttonSize = FloatButton.AbsoluteSize
            
            FloatButton.Position = UDim2.new(
                0,
                math.clamp(startPosFloat.X.Offset + delta.X, 0, screenSize.X - buttonSize.X),
                0,
                math.clamp(startPosFloat.Y.Offset + delta.Y, 0, screenSize.Y - buttonSize.Y)
            )
        end
    end)
    
    -- Conectar limpeza ao destruir o botão
    FloatButton.Destroying:Connect(function()
        if inputChangedConnection then
            inputChangedConnection:Disconnect()
        end
        CleanupFloatButton()
    end)
    
    return FloatButton
end

--// INTERFACE COMPACTA ATUALIZADA
local function CreateCompactMobileUI()
    -- Limpar apenas a UI existente
    CleanupUIOnly()
    task.wait(0.1)
    
    -- Verificar se já existe uma UI
    if game:GetService("CoreGui"):FindFirstChild("SilentAimCompactUI") then
        game:GetService("CoreGui").SilentAimCompactUI:Destroy()
        task.wait(0.1)
    end
    
    --// Tema Compacto
    local Theme = {
        Primary = Color3.fromRGB(15, 15, 30),
        Secondary = Color3.fromRGB(25, 25, 45),
        Accent = Color3.fromRGB(100, 70, 200),
        Success = Color3.fromRGB(40, 220, 40),
        Warning = Color3.fromRGB(255, 200, 0),
        Danger = Color3.fromRGB(230, 60, 60),
        Info = Color3.fromRGB(0, 180, 255),
        Text = Color3.fromRGB(245, 245, 245),
        TextSecondary = Color3.fromRGB(190, 190, 210)
    }
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SilentAimCompactUI"
    ScreenGui.Parent = game:GetService("CoreGui")
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 999
    
    MainUI = ScreenGui
    
    --// Menu Principal Compacto
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 320, 0, 400)
    MainFrame.AnchorPoint = Vector2.new(0, 0)
    MainFrame.Position = UDim2.new(0.02, 0, 0.15, 0)
    MainFrame.BackgroundColor3 = Theme.Primary
    MainFrame.BackgroundTransparency = 0.05
    MainFrame.Visible = true
    MainFrame.Parent = ScreenGui
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 14)
    MainCorner.Parent = MainFrame
    
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Theme.Accent
    MainStroke.Thickness = 2
    MainStroke.Transparency = 0.3
    MainStroke.Parent = MainFrame
    
    --// Cabeçalho Compacto
    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, 50)
    Header.Position = UDim2.new(0, 0, 0, 0)
    Header.BackgroundColor3 = Theme.Secondary
    Header.Parent = MainFrame
    
    local HeaderCorner = Instance.new("UICorner")
    HeaderCorner.CornerRadius = UDim.new(0, 14)
    HeaderCorner.Parent = Header
    
    local HeaderGradient = Instance.new("UIGradient")
    HeaderGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 80, 210)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 70, 200)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 60, 190))
    })
    HeaderGradient.Rotation = 90
    HeaderGradient.Parent = Header
    
    local HeaderText = Instance.new("TextLabel")
    HeaderText.Name = "HeaderText"
    HeaderText.Size = UDim2.new(0.7, 0, 1, 0)
    HeaderText.Position = UDim2.new(0.1, 0, 0, 0)
    HeaderText.Text = "🎯 SILENT AIM v2.2"
    HeaderText.TextColor3 = Theme.Text
    HeaderText.BackgroundTransparency = 1
    HeaderText.Font = Enum.Font.GothamBold
    HeaderText.TextSize = 16
    HeaderText.TextStrokeTransparency = 0.7
    HeaderText.TextStrokeColor3 = Theme.Accent
    HeaderText.Parent = Header
    
    --// Sistema de Abas Compacto
    local TabContainer = Instance.new("Frame")
    TabContainer.Name = "TabContainer"
    TabContainer.Size = UDim2.new(1, -20, 0, 35)
    TabContainer.Position = UDim2.new(0, 10, 0, 55)
    TabContainer.BackgroundTransparency = 1
    TabContainer.Parent = MainFrame
    
    local Tabs = {"Geral", "Config", "Aim", "Team"}
    local CurrentTab = "Geral"
    local TabButtons = {}
    local TabContents = {}
    
    -- Criar botões de abas
    for i, tabName in ipairs(Tabs) do
        local TabButton = Instance.new("TextButton")
        TabButton.Name = tabName .. "Tab"
        TabButton.Size = UDim2.new(0.23, 0, 1, 0)
        TabButton.Position = UDim2.new((i-1) * 0.24, 0, 0, 0)
        TabButton.Text = tabName
        TabButton.TextColor3 = Theme.TextSecondary
        TabButton.BackgroundColor3 = Theme.Secondary
        TabButton.BackgroundTransparency = 0.7
        TabButton.Font = Enum.Font.GothamBold
        TabButton.TextSize = 11
        TabButton.Parent = TabContainer
        
        local TabCorner = Instance.new("UICorner")
        TabCorner.CornerRadius = UDim.new(0, 6)
        TabCorner.Parent = TabButton
        
        TabButtons[tabName] = TabButton
        
        -- Conteúdo da aba
        local TabContent = Instance.new("ScrollingFrame")
        TabContent.Name = tabName .. "Content"
        TabContent.Size = UDim2.new(1, -20, 0, 250)
        TabContent.Position = UDim2.new(0, 10, 0, 95)
        TabContent.BackgroundTransparency = 1
        TabContent.Visible = (tabName == "Geral")
        TabContent.CanvasSize = UDim2.new(0, 0, 0, 0)
        TabContent.ScrollBarThickness = 3
        TabContent.ScrollingDirection = Enum.ScrollingDirection.Y
        TabContent.Parent = MainFrame
        
        TabContents[tabName] = TabContent
        
        TabButton.MouseButton1Click:Connect(function()
            CurrentTab = tabName
            
            -- Atualizar aparência das abas
            for name, btn in pairs(TabButtons) do
                if name == tabName then
                    TweenService:Create(btn, TweenInfo.new(0.2), {
                        BackgroundTransparency = 0.3,
                        TextColor3 = Theme.Text,
                        BackgroundColor3 = Theme.Accent
                    }):Play()
                else
                    TweenService:Create(btn, TweenInfo.new(0.2), {
                        BackgroundTransparency = 0.7,
                        TextColor3 = Theme.TextSecondary,
                        BackgroundColor3 = Theme.Secondary
                    }):Play()
                end
            end
            
            -- Mostrar/ocultar conteúdos
            for name, content in pairs(TabContents) do
                content.Visible = (name == tabName)
            end
        end)
    end
    
    -- Ativar a primeira aba
    TweenService:Create(TabButtons["Geral"], TweenInfo.new(0.2), {
        BackgroundTransparency = 0.3,
        TextColor3 = Theme.Text,
        BackgroundColor3 = Theme.Accent
    }):Play()
    
    --// CONTEÚDO DA ABA GERAL
    local GeralContent = TabContents["Geral"]
    
    -- Botão Principal de Toggle
    local ToggleContainer = Instance.new("Frame")
    ToggleContainer.Name = "ToggleContainer"
    ToggleContainer.Size = UDim2.new(1, 0, 0, 60)
    ToggleContainer.Position = UDim2.new(0, 0, 0, 0)
    ToggleContainer.BackgroundColor3 = Theme.Secondary
    ToggleContainer.Parent = GeralContent
    
    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(0, 10)
    ToggleCorner.Parent = ToggleContainer
    
    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Name = "ToggleBtn"
    ToggleBtn.Size = UDim2.new(1, 0, 1, 0)
    ToggleBtn.Position = UDim2.new(0, 0, 0, 0)
    ToggleBtn.Text = ""
    ToggleBtn.BackgroundTransparency = 1
    ToggleBtn.Parent = ToggleContainer
    
    local ToggleIcon = Instance.new("TextLabel")
    ToggleIcon.Name = "ToggleIcon"
    ToggleIcon.Size = UDim2.new(0, 35, 0, 35)
    ToggleIcon.Position = UDim2.new(0.05, 0, 0.2, 0)
    ToggleIcon.Text = "⭕"
    ToggleIcon.TextColor3 = Theme.Danger
    ToggleIcon.BackgroundTransparency = 1
    ToggleIcon.Font = Enum.Font.GothamBold
    ToggleIcon.TextSize = 24
    ToggleIcon.Parent = ToggleContainer
    
    local ToggleText = Instance.new("TextLabel")
    ToggleText.Name = "ToggleText"
    ToggleText.Size = UDim2.new(0.5, 0, 0.5, 0)
    ToggleText.Position = UDim2.new(0.2, 0, 0.15, 0)
    ToggleText.Text = "SILENT AIM"
    ToggleText.TextColor3 = Theme.Text
    ToggleText.BackgroundTransparency = 1
    ToggleText.Font = Enum.Font.GothamBold
    ToggleText.TextSize = 14
    ToggleText.TextXAlignment = Enum.TextXAlignment.Left
    ToggleText.Parent = ToggleContainer
    
    local ToggleStatus = Instance.new("Frame")
    ToggleStatus.Name = "ToggleStatus"
    ToggleStatus.Size = UDim2.new(0, 40, 0, 20)
    ToggleStatus.Position = UDim2.new(0.8, -20, 0.4, -10)
    ToggleStatus.BackgroundColor3 = Theme.Danger
    ToggleStatus.Parent = ToggleContainer
    
    local StatusCorner = Instance.new("UICorner")
    StatusCorner.CornerRadius = UDim.new(1, 0)
    StatusCorner.Parent = ToggleStatus
    
    local StatusText = Instance.new("TextLabel")
    StatusText.Name = "StatusText"
    StatusText.Size = UDim2.new(1, 0, 1, 0)
    StatusText.Text = "OFF"
    StatusText.TextColor3 = Theme.Text
    StatusText.BackgroundTransparency = 1
    StatusText.Font = Enum.Font.GothamBold
    StatusText.TextSize = 10
    StatusText.Parent = ToggleStatus
    
    -- FOV Slider Compacto
    local FOVContainer = Instance.new("Frame")
    FOVContainer.Name = "FOVContainer"
    FOVContainer.Size = UDim2.new(1, 0, 0, 60)
    FOVContainer.Position = UDim2.new(0, 0, 0, 70)
    FOVContainer.BackgroundColor3 = Theme.Secondary
    FOVContainer.Parent = GeralContent
    
    local FOVCorner = Instance.new("UICorner")
    FOVCorner.CornerRadius = UDim.new(0, 10)
    FOVCorner.Parent = FOVContainer
    
    local FOVIcon = Instance.new("TextLabel")
    FOVIcon.Name = "FOVIcon"
    FOVIcon.Size = UDim2.new(0, 30, 0, 30)
    FOVIcon.Position = UDim2.new(0.05, 0, 0.25, 0)
    FOVIcon.Text = "⭕"
    FOVIcon.TextColor3 = Theme.Info
    FOVIcon.BackgroundTransparency = 1
    FOVIcon.Font = Enum.Font.GothamBold
    FOVIcon.TextSize = 20
    FOVIcon.Parent = FOVContainer
    
    local FOVText = Instance.new("TextLabel")
    FOVText.Name = "FOVText"
    FOVText.Size = UDim2.new(0.5, 0, 0.4, 0)
    FOVText.Position = UDim2.new(0.2, 0, 0.15, 0)
    FOVText.Text = "FOV: 150"
    FOVText.TextColor3 = Theme.Text
    FOVText.BackgroundTransparency = 1
    FOVText.Font = Enum.Font.GothamBold
    FOVText.TextSize = 12
    FOVText.TextXAlignment = Enum.TextXAlignment.Left
    FOVText.Parent = FOVContainer
    
    local FOVSlider = Instance.new("Frame")
    FOVSlider.Name = "FOVSlider"
    FOVSlider.Size = UDim2.new(0.7, 0, 0, 5)
    FOVSlider.Position = UDim2.new(0.15, 0, 0.7, 0)
    FOVSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    FOVSlider.Parent = FOVContainer
    
    local FOVSliderCorner = Instance.new("UICorner")
    FOVSliderCorner.CornerRadius = UDim.new(1, 0)
    FOVSliderCorner.Parent = FOVSlider
    
    local FOVSliderFill = Instance.new("Frame")
    FOVSliderFill.Name = "FOVSliderFill"
    FOVSliderFill.Size = UDim2.new((_G.FOV - 50) / (300 - 50), 0, 1, 0)
    FOVSliderFill.Position = UDim2.new(0, 0, 0, 0)
    FOVSliderFill.BackgroundColor3 = Theme.Accent
    FOVSliderFill.Parent = FOVSlider
    
    local FOVSliderFillCorner = Instance.new("UICorner")
    FOVSliderFillCorner.CornerRadius = UDim.new(1, 0)
    FOVSliderFillCorner.Parent = FOVSliderFill
    
    -- Prediction Slider Compacto
    local PredContainer = Instance.new("Frame")
    PredContainer.Name = "PredContainer"
    PredContainer.Size = UDim2.new(1, 0, 0, 60)
    PredContainer.Position = UDim2.new(0, 0, 0, 140)
    PredContainer.BackgroundColor3 = Theme.Secondary
    PredContainer.Parent = GeralContent
    
    local PredCorner = Instance.new("UICorner")
    PredCorner.CornerRadius = UDim.new(0, 10)
    PredCorner.Parent = PredContainer
    
    local PredIcon = Instance.new("TextLabel")
    PredIcon.Name = "PredIcon"
    PredIcon.Size = UDim2.new(0, 30, 0, 30)
    PredIcon.Position = UDim2.new(0.05, 0, 0.25, 0)
    PredIcon.Text = "⚡"
    PredIcon.TextColor3 = Theme.Warning
    PredIcon.BackgroundTransparency = 1
    PredIcon.Font = Enum.Font.GothamBold
    PredIcon.TextSize = 20
    PredIcon.Parent = PredContainer
    
    local PredText = Instance.new("TextLabel")
    PredText.Name = "PredText"
    PredText.Size = UDim2.new(0.5, 0, 0.4, 0)
    PredText.Position = UDim2.new(0.2, 0, 0.15, 0)
    PredText.Text = "Predição: 0.165"
    PredText.TextColor3 = Theme.Text
    PredText.BackgroundTransparency = 1
    PredText.Font = Enum.Font.GothamBold
    PredText.TextSize = 12
    PredText.TextXAlignment = Enum.TextXAlignment.Left
    PredText.Parent = PredContainer
    
    local PredSlider = Instance.new("Frame")
    PredSlider.Name = "PredSlider"
    PredSlider.Size = UDim2.new(0.7, 0, 0, 5)
    PredSlider.Position = UDim2.new(0.15, 0, 0.7, 0)
    PredSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    PredSlider.Parent = PredContainer
    
    local PredSliderCorner = Instance.new("UICorner")
    PredSliderCorner.CornerRadius = UDim.new(1, 0)
    PredSliderCorner.Parent = PredSlider
    
    local PredSliderFill = Instance.new("Frame")
    PredSliderFill.Name = "PredSliderFill"
    PredSliderFill.Size = UDim2.new(_G.Prediction / 0.5, 0, 1, 0)
    PredSliderFill.Position = UDim2.new(0, 0, 0, 0)
    PredSliderFill.BackgroundColor3 = Theme.Warning
    PredSliderFill.Parent = PredSlider
    
    local PredSliderFillCorner = Instance.new("UICorner")
    PredSliderFillCorner.CornerRadius = UDim.new(1, 0)
    PredSliderFillCorner.Parent = PredSliderFill
    
    GeralContent.CanvasSize = UDim2.new(0, 0, 0, 210)
    
    --// CONTEÚDO DA ABA CONFIG
    local ConfigContent = TabContents["Config"]
    
    -- Botão de Modo
    local ModeCard = Instance.new("Frame")
    ModeCard.Name = "ModeCard"
    ModeCard.Size = UDim2.new(1, 0, 0, 60)
    ModeCard.Position = UDim2.new(0, 0, 0, 0)
    ModeCard.BackgroundColor3 = Theme.Secondary
    ModeCard.Parent = ConfigContent
    
    local ModeCorner = Instance.new("UICorner")
    ModeCorner.CornerRadius = UDim.new(0, 10)
    ModeCorner.Parent = ModeCard
    
    local ModeBtn = Instance.new("TextButton")
    ModeBtn.Name = "ModeBtn"
    ModeBtn.Size = UDim2.new(1, 0, 1, 0)
    ModeBtn.BackgroundTransparency = 1
    ModeBtn.Text = ""
    ModeBtn.Parent = ModeCard
    
    local ModeIcon = Instance.new("TextLabel")
    ModeIcon.Name = "ModeIcon"
    ModeIcon.Size = UDim2.new(0, 35, 0, 35)
    ModeIcon.Position = UDim2.new(0.05, 0, 0.2, 0)
    ModeIcon.Text = "🎯"
    ModeIcon.TextColor3 = Theme.Accent
    ModeIcon.BackgroundTransparency = 1
    ModeIcon.Font = Enum.Font.GothamBold
    ModeIcon.TextSize = 24
    ModeIcon.Parent = ModeCard
    
    local ModeText = Instance.new("TextLabel")
    ModeText.Name = "ModeText"
    ModeText.Size = UDim2.new(0.6, 0, 0.4, 0)
    ModeText.Position = UDim2.new(0.2, 0, 0.2, 0)
    ModeText.Text = "Modo: NPCs"
    ModeText.TextColor3 = Theme.Text
    ModeText.BackgroundTransparency = 1
    ModeText.Font = Enum.Font.GothamBold
    ModeText.TextSize = 12
    ModeText.TextXAlignment = Enum.TextXAlignment.Left
    ModeText.Parent = ModeCard
    
    local ModeLabel = Instance.new("TextLabel")
    ModeLabel.Name = "ModeLabel"
    ModeLabel.Size = UDim2.new(0.6, 0, 0.3, 0)
    ModeLabel.Position = UDim2.new(0.2, 0, 0.6, 0)
    ModeLabel.Text = "Selecionar tipo de alvo"
    ModeLabel.TextColor3 = Theme.TextSecondary
    ModeLabel.BackgroundTransparency = 1
    ModeLabel.Font = Enum.Font.Gotham
    ModeLabel.TextSize = 9
    ModeLabel.TextXAlignment = Enum.TextXAlignment.Left
    ModeLabel.Parent = ModeCard
    
    -- Botão de WallCheck
    local WallCheckCard = Instance.new("Frame")
    WallCheckCard.Name = "WallCheckCard"
    WallCheckCard.Size = UDim2.new(1, 0, 0, 60)
    WallCheckCard.Position = UDim2.new(0, 0, 0, 70)
    WallCheckCard.BackgroundColor3 = Theme.Secondary
    WallCheckCard.Parent = ConfigContent
    
    local WallCheckCorner = Instance.new("UICorner")
    WallCheckCorner.CornerRadius = UDim.new(0, 10)
    WallCheckCorner.Parent = WallCheckCard
    
    local WallCheckBtn = Instance.new("TextButton")
    WallCheckBtn.Name = "WallCheckBtn"
    WallCheckBtn.Size = UDim2.new(1, 0, 1, 0)
    WallCheckBtn.BackgroundTransparency = 1
    WallCheckBtn.Text = ""
    WallCheckBtn.Parent = WallCheckCard
    
    local WallCheckIcon = Instance.new("TextLabel")
    WallCheckIcon.Name = "WallCheckIcon"
    WallCheckIcon.Size = UDim2.new(0, 35, 0, 35)
    WallCheckIcon.Position = UDim2.new(0.05, 0, 0.2, 0)
    WallCheckIcon.Text = "👁️"
    WallCheckIcon.TextColor3 = Theme.Success
    WallCheckIcon.BackgroundTransparency = 1
    WallCheckIcon.Font = Enum.Font.GothamBold
    WallCheckIcon.TextSize = 24
    WallCheckIcon.Parent = WallCheckCard
    
    local WallCheckText = Instance.new("TextLabel")
    WallCheckText.Name = "WallCheckText"
    WallCheckText.Size = UDim2.new(0.6, 0, 0.4, 0)
    WallCheckText.Position = UDim2.new(0.2, 0, 0.2, 0)
    WallCheckText.Text = "Wall Check: ON"
    WallCheckText.TextColor3 = Theme.Text
    WallCheckText.BackgroundTransparency = 1
    WallCheckText.Font = Enum.Font.GothamBold
    WallCheckText.TextSize = 12
    WallCheckText.TextXAlignment = Enum.TextXAlignment.Left
    WallCheckText.Parent = WallCheckCard
    
    local WallCheckLabel = Instance.new("TextLabel")
    WallCheckLabel.Name = "WallCheckLabel"
    WallCheckLabel.Size = UDim2.new(0.6, 0, 0.3, 0)
    WallCheckLabel.Position = UDim2.new(0.2, 0, 0.6, 0)
    WallCheckLabel.Text = "Verificar obstáculos"
    WallCheckLabel.TextColor3 = Theme.TextSecondary
    WallCheckLabel.BackgroundTransparency = 1
    WallCheckLabel.Font = Enum.Font.Gotham
    WallCheckLabel.TextSize = 9
    WallCheckLabel.TextXAlignment = Enum.TextXAlignment.Left
    WallCheckLabel.Parent = WallCheckCard
    
    -- Botão de Performance
    local PerfCard = Instance.new("Frame")
    PerfCard.Name = "PerfCard"
    PerfCard.Size = UDim2.new(1, 0, 0, 60)
    PerfCard.Position = UDim2.new(0, 0, 0, 140)
    PerfCard.BackgroundColor3 = Theme.Secondary
    PerfCard.Parent = ConfigContent
    
    local PerfCorner = Instance.new("UICorner")
    PerfCorner.CornerRadius = UDim.new(0, 10)
    PerfCorner.Parent = PerfCard
    
    local PerfBtn = Instance.new("TextButton")
    PerfBtn.Name = "PerfBtn"
    PerfBtn.Size = UDim2.new(1, 0, 1, 0)
    PerfBtn.BackgroundTransparency = 1
    PerfBtn.Text = ""
    PerfBtn.Parent = PerfCard
    
    local PerfIcon = Instance.new("TextLabel")
    PerfIcon.Name = "PerfIcon"
    PerfIcon.Size = UDim2.new(0, 35, 0, 35)
    PerfIcon.Position = UDim2.new(0.05, 0, 0.2, 0)
    PerfIcon.Text = "⚡"
    PerfIcon.TextColor3 = Theme.Warning
    PerfIcon.BackgroundTransparency = 1
    PerfIcon.Font = Enum.Font.GothamBold
    PerfIcon.TextSize = 24
    PerfIcon.Parent = PerfCard
    
    local PerfText = Instance.new("TextLabel")
    PerfText.Name = "PerfText"
    PerfText.Size = UDim2.new(0.6, 0, 0.4, 0)
    PerfText.Position = UDim2.new(0.2, 0, 0.2, 0)
    PerfText.Text = "Performance: Normal"
    PerfText.TextColor3 = Theme.Text
    PerfText.BackgroundTransparency = 1
    PerfText.Font = Enum.Font.GothamBold
    PerfText.TextSize = 12
    PerfText.TextXAlignment = Enum.TextXAlignment.Left
    PerfText.Parent = PerfCard
    
    local PerfLabel = Instance.new("TextLabel")
    PerfLabel.Name = "PerfLabel"
    PerfLabel.Size = UDim2.new(0.6, 0, 0.3, 0)
    PerfLabel.Position = UDim2.new(0.2, 0, 0.6, 0)
    PerfLabel.Text = "Otimizar atualização"
    PerfLabel.TextColor3 = Theme.TextSecondary
    PerfLabel.BackgroundTransparency = 1
    PerfLabel.Font = Enum.Font.Gotham
    PerfLabel.TextSize = 9
    PerfLabel.TextXAlignment = Enum.TextXAlignment.Left
    PerfLabel.Parent = PerfCard
    
    ConfigContent.CanvasSize = UDim2.new(0, 0, 0, 210)
    
    --// CONTEÚDO DA ABA AIM
    local AimContent = TabContents["Aim"]
    
    -- Seletor de Parte do Corpo
    local AimPartCard = Instance.new("Frame")
    AimPartCard.Name = "AimPartCard"
    AimPartCard.Size = UDim2.new(1, 0, 0, 60)
    AimPartCard.Position = UDim2.new(0, 0, 0, 0)
    AimPartCard.BackgroundColor3 = Theme.Secondary
    AimPartCard.Parent = AimContent
    
    local AimPartCorner = Instance.new("UICorner")
    AimPartCorner.CornerRadius = UDim.new(0, 10)
    AimPartCorner.Parent = AimPartCard
    
    local AimPartBtn = Instance.new("TextButton")
    AimPartBtn.Name = "AimPartBtn"
    AimPartBtn.Size = UDim2.new(1, 0, 1, 0)
    AimPartBtn.BackgroundTransparency = 1
    AimPartBtn.Text = ""
    AimPartBtn.Parent = AimPartCard
    
    local AimPartIcon = Instance.new("TextLabel")
    AimPartIcon.Name = "AimPartIcon"
    AimPartIcon.Size = UDim2.new(0, 35, 0, 35)
    AimPartIcon.Position = UDim2.new(0.05, 0, 0.2, 0)
    AimPartIcon.Text = "👤"
    AimPartIcon.TextColor3 = Theme.Info
    AimPartIcon.BackgroundTransparency = 1
    AimPartIcon.Font = Enum.Font.GothamBold
    AimPartIcon.TextSize = 24
    AimPartIcon.Parent = AimPartCard
    
    local AimPartText = Instance.new("TextLabel")
    AimPartText.Name = "AimPartText"
    AimPartText.Size = UDim2.new(0.6, 0, 0.4, 0)
    AimPartText.Position = UDim2.new(0.2, 0, 0.2, 0)
    AimPartText.Text = "Parte: Cabeça"
    AimPartText.TextColor3 = Theme.Text
    AimPartText.BackgroundTransparency = 1
    AimPartText.Font = Enum.Font.GothamBold
    AimPartText.TextSize = 12
    AimPartText.TextXAlignment = Enum.TextXAlignment.Left
    AimPartText.Parent = AimPartCard
    
    local AimPartLabel = Instance.new("TextLabel")
    AimPartLabel.Name = "AimPartLabel"
    AimPartLabel.Size = UDim2.new(0.6, 0, 0.3, 0)
    AimPartLabel.Position = UDim2.new(0.2, 0, 0.6, 0)
    AimPartLabel.Text = "Parte do corpo para mirar"
    AimPartLabel.TextColor3 = Theme.TextSecondary
    AimPartLabel.BackgroundTransparency = 1
    AimPartLabel.Font = Enum.Font.Gotham
    AimPartLabel.TextSize = 9
    AimPartLabel.TextXAlignment = Enum.TextXAlignment.Left
    AimPartLabel.Parent = AimPartCard
    
    local AimPartStatus = Instance.new("TextLabel")
    AimPartStatus.Name = "AimPartStatus"
    AimPartStatus.Size = UDim2.new(0.2, 0, 0.3, 0)
    AimPartStatus.Position = UDim2.new(0.8, -40, 0.6, 0)
    AimPartStatus.Text = "🎯"
    AimPartStatus.TextColor3 = Theme.Success
    AimPartStatus.BackgroundTransparency = 1
    AimPartStatus.Font = Enum.Font.GothamBold
    AimPartStatus.TextSize = 12
    AimPartStatus.Parent = AimPartCard
    
    -- Informações sobre partes
    local AimInfoCard = Instance.new("Frame")
    AimInfoCard.Name = "AimInfoCard"
    AimInfoCard.Size = UDim2.new(1, 0, 0, 80)
    AimInfoCard.Position = UDim2.new(0, 0, 0, 70)
    AimInfoCard.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    AimInfoCard.BackgroundTransparency = 0.3
    AimInfoCard.Parent = AimContent
    
    local AimInfoCorner = Instance.new("UICorner")
    AimInfoCorner.CornerRadius = UDim.new(0, 8)
    AimInfoCorner.Parent = AimInfoCard
    
    local AimInfoText = Instance.new("TextLabel")
    AimInfoText.Name = "AimInfoText"
    AimInfoText.Size = UDim2.new(0.9, 0, 0.9, 0)
    AimInfoText.Position = UDim2.new(0.05, 0, 0.05, 0)
    AimInfoText.Text = "Cabeça: Dano crítico\nTorso: Dano médio\nAmbos: Alterna entre ambos\nAleatório: Partes aleatórias"
    AimInfoText.TextColor3 = Theme.TextSecondary
    AimInfoText.BackgroundTransparency = 1
    AimInfoText.Font = Enum.Font.Gotham
    AimInfoText.TextSize = 9
    AimInfoText.TextXAlignment = Enum.TextXAlignment.Left
    AimInfoText.TextYAlignment = Enum.TextYAlignment.Top
    AimInfoText.TextWrapped = true
    AimInfoText.Parent = AimInfoCard
    
    AimContent.CanvasSize = UDim2.new(0, 0, 0, 160)
    
    --// CONTEÚDO DA ABA TEAM
    local TeamContent = TabContents["Team"]
    
    -- Team Check para Players
    local TeamCheckPlayerCard = Instance.new("Frame")
    TeamCheckPlayerCard.Name = "TeamCheckPlayerCard"
    TeamCheckPlayerCard.Size = UDim2.new(1, 0, 0, 60)
    TeamCheckPlayerCard.Position = UDim2.new(0, 0, 0, 0)
    TeamCheckPlayerCard.BackgroundColor3 = Theme.Secondary
    TeamCheckPlayerCard.Parent = TeamContent
    
    local TeamCheckPlayerCorner = Instance.new("UICorner")
    TeamCheckPlayerCorner.CornerRadius = UDim.new(0, 10)
    TeamCheckPlayerCorner.Parent = TeamCheckPlayerCard
    
    local TeamCheckPlayerBtn = Instance.new("TextButton")
    TeamCheckPlayerBtn.Name = "TeamCheckPlayerBtn"
    TeamCheckPlayerBtn.Size = UDim2.new(1, 0, 1, 0)
    TeamCheckPlayerBtn.BackgroundTransparency = 1
    TeamCheckPlayerBtn.Text = ""
    TeamCheckPlayerBtn.Parent = TeamCheckPlayerCard
    
    local TeamCheckPlayerIcon = Instance.new("TextLabel")
    TeamCheckPlayerIcon.Name = "TeamCheckPlayerIcon"
    TeamCheckPlayerIcon.Size = UDim2.new(0, 35, 0, 35)
    TeamCheckPlayerIcon.Position = UDim2.new(0.05, 0, 0.2, 0)
    TeamCheckPlayerIcon.Text = "👤"
    TeamCheckPlayerIcon.TextColor3 = Theme.Info
    TeamCheckPlayerIcon.BackgroundTransparency = 1
    TeamCheckPlayerIcon.Font = Enum.Font.GothamBold
    TeamCheckPlayerIcon.TextSize = 24
    TeamCheckPlayerIcon.Parent = TeamCheckPlayerCard
    
    local TeamCheckPlayerText = Instance.new("TextLabel")
    TeamCheckPlayerText.Name = "TeamCheckPlayerText"
    TeamCheckPlayerText.Size = UDim2.new(0.6, 0, 0.4, 0)
    TeamCheckPlayerText.Position = UDim2.new(0.2, 0, 0.2, 0)
    TeamCheckPlayerText.Text = "Team Check (Players)"
    TeamCheckPlayerText.TextColor3 = Theme.Text
    TeamCheckPlayerText.BackgroundTransparency = 1
    TeamCheckPlayerText.Font = Enum.Font.GothamBold
    TeamCheckPlayerText.TextSize = 12
    TeamCheckPlayerText.TextXAlignment = Enum.TextXAlignment.Left
    TeamCheckPlayerText.Parent = TeamCheckPlayerCard
    
    local TeamCheckPlayerStatus = Instance.new("Frame")
    TeamCheckPlayerStatus.Name = "TeamCheckPlayerStatus"
    TeamCheckPlayerStatus.Size = UDim2.new(0, 40, 0, 20)
    TeamCheckPlayerStatus.Position = UDim2.new(0.8, -20, 0.4, -10)
    TeamCheckPlayerStatus.BackgroundColor3 = _G.TeamCheck and Theme.Success or Theme.Danger
    TeamCheckPlayerStatus.Parent = TeamCheckPlayerCard
    
    local TeamCheckPlayerCorner2 = Instance.new("UICorner")
    TeamCheckPlayerCorner2.CornerRadius = UDim.new(1, 0)
    TeamCheckPlayerCorner2.Parent = TeamCheckPlayerStatus
    
    local TeamCheckPlayerStatusText = Instance.new("TextLabel")
    TeamCheckPlayerStatusText.Name = "TeamCheckPlayerStatusText"
    TeamCheckPlayerStatusText.Size = UDim2.new(1, 0, 1, 0)
    TeamCheckPlayerStatusText.Text = _G.TeamCheck and "ON" or "OFF"
    TeamCheckPlayerStatusText.TextColor3 = Theme.Text
    TeamCheckPlayerStatusText.BackgroundTransparency = 1
    TeamCheckPlayerStatusText.Font = Enum.Font.GothamBold
    TeamCheckPlayerStatusText.TextSize = 10
    TeamCheckPlayerStatusText.Parent = TeamCheckPlayerStatus
    
    -- Team Check para NPCs
    local TeamCheckNPCCard = Instance.new("Frame")
    TeamCheckNPCCard.Name = "TeamCheckNPCCard"
    TeamCheckNPCCard.Size = UDim2.new(1, 0, 0, 60)
    TeamCheckNPCCard.Position = UDim2.new(0, 0, 0, 70)
    TeamCheckNPCCard.BackgroundColor3 = Theme.Secondary
    TeamCheckNPCCard.Parent = TeamContent
    
    local TeamCheckNPCCorner = Instance.new("UICorner")
    TeamCheckNPCCorner.CornerRadius = UDim.new(0, 10)
    TeamCheckNPCCorner.Parent = TeamCheckNPCCard
    
    local TeamCheckNPCBtn = Instance.new("TextButton")
    TeamCheckNPCBtn.Name = "TeamCheckNPCBtn"
    TeamCheckNPCBtn.Size = UDim2.new(1, 0, 1, 0)
    TeamCheckNPCBtn.BackgroundTransparency = 1
    TeamCheckNPCBtn.Text = ""
    TeamCheckNPCBtn.Parent = TeamCheckNPCCard
    
    local TeamCheckNPCIcon = Instance.new("TextLabel")
    TeamCheckNPCIcon.Name = "TeamCheckNPCIcon"
    TeamCheckNPCIcon.Size = UDim2.new(0, 35, 0, 35)
    TeamCheckNPCIcon.Position = UDim2.new(0.05, 0, 0.2, 0)
    TeamCheckNPCIcon.Text = "🤖"
    TeamCheckNPCIcon.TextColor3 = Theme.Warning
    TeamCheckNPCIcon.BackgroundTransparency = 1
    TeamCheckNPCIcon.Font = Enum.Font.GothamBold
    TeamCheckNPCIcon.TextSize = 24
    TeamCheckNPCIcon.Parent = TeamCheckNPCCard
    
    local TeamCheckNPCText = Instance.new("TextLabel")
    TeamCheckNPCText.Name = "TeamCheckNPCText"
    TeamCheckNPCText.Size = UDim2.new(0.6, 0, 0.4, 0)
    TeamCheckNPCText.Position = UDim2.new(0.2, 0, 0.2, 0)
    TeamCheckNPCText.Text = "Team Check (NPCs)"
    TeamCheckNPCText.TextColor3 = Theme.Text
    TeamCheckNPCText.BackgroundTransparency = 1
    TeamCheckNPCText.Font = Enum.Font.GothamBold
    TeamCheckNPCText.TextSize = 12
    TeamCheckNPCText.TextXAlignment = Enum.TextXAlignment.Left
    TeamCheckNPCText.Parent = TeamCheckNPCCard
    
    local TeamCheckNPCStatus = Instance.new("Frame")
    TeamCheckNPCStatus.Name = "TeamCheckNPCStatus"
    TeamCheckNPCStatus.Size = UDim2.new(0, 40, 0, 20)
    TeamCheckNPCStatus.Position = UDim2.new(0.8, -20, 0.4, -10)
    TeamCheckNPCStatus.BackgroundColor3 = _G.TeamCheckForNPCs and Theme.Success or Theme.Danger
    TeamCheckNPCStatus.Parent = TeamCheckNPCCard
    
    local TeamCheckNPCCorner2 = Instance.new("UICorner")
    TeamCheckNPCCorner2.CornerRadius = UDim.new(1, 0)
    TeamCheckNPCCorner2.Parent = TeamCheckNPCStatus
    
    local TeamCheckNPCStatusText = Instance.new("TextLabel")
    TeamCheckNPCStatusText.Name = "TeamCheckNPCStatusText"
    TeamCheckNPCStatusText.Size = UDim2.new(1, 0, 1, 0)
    TeamCheckNPCStatusText.Text = _G.TeamCheckForNPCs and "ON" or "OFF"
    TeamCheckNPCStatusText.TextColor3 = Theme.Text
    TeamCheckNPCStatusText.BackgroundTransparency = 1
    TeamCheckNPCStatusText.Font = Enum.Font.GothamBold
    TeamCheckNPCStatusText.TextSize = 10
    TeamCheckNPCStatusText.Parent = TeamCheckNPCStatus
    
    -- Descrição do Team Check
    local TeamCheckInfo = Instance.new("TextLabel")
    TeamCheckInfo.Name = "TeamCheckInfo"
    TeamCheckInfo.Size = UDim2.new(1, 0, 0, 60)
    TeamCheckInfo.Position = UDim2.new(0, 0, 0, 140)
    TeamCheckInfo.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    TeamCheckInfo.BackgroundTransparency = 0.7
    TeamCheckInfo.Text = "Team Check NPCs: Verifica StringValue 'Team' no NPC.\nTeam Check Players: Verifica time do jogador."
    TeamCheckInfo.TextColor3 = Theme.TextSecondary
    TeamCheckInfo.Font = Enum.Font.Gotham
    TeamCheckInfo.TextSize = 9
    TeamCheckInfo.TextWrapped = true
    TeamCheckInfo.Parent = TeamContent
    
    local TeamCheckInfoCorner = Instance.new("UICorner")
    TeamCheckInfoCorner.CornerRadius = UDim.new(0, 8)
    TeamCheckInfoCorner.Parent = TeamCheckInfo
    
    TeamContent.CanvasSize = UDim2.new(0, 0, 0, 210)
    
    --// Barra de Status
    local StatusBar = Instance.new("Frame")
    StatusBar.Name = "StatusBar"
    StatusBar.Size = UDim2.new(1, -20, 0, 40)
    StatusBar.Position = UDim2.new(0, 10, 0, 345)
    StatusBar.BackgroundColor3 = Theme.Secondary
    StatusBar.Parent = MainFrame
    
    local StatusBarCorner = Instance.new("UICorner")
    StatusBarCorner.CornerRadius = UDim.new(0, 8)
    StatusBarCorner.Parent = StatusBar
    
    local StatusIcon = Instance.new("TextLabel")
    StatusIcon.Name = "StatusIcon"
    StatusIcon.Size = UDim2.new(0, 25, 0, 25)
    StatusIcon.Position = UDim2.new(0.05, 0, 0.2, 0)
    StatusIcon.Text = "✨"
    StatusIcon.TextColor3 = Theme.Warning
    StatusIcon.BackgroundTransparency = 1
    StatusIcon.Font = Enum.Font.GothamBold
    StatusIcon.TextSize = 18
    StatusIcon.Parent = StatusBar
    
    local StatusText = Instance.new("TextLabel")
    StatusText.Name = "StatusText"
    StatusText.Size = UDim2.new(0.5, 0, 0.5, 0)
    StatusText.Position = UDim2.new(0.15, 0, 0.1, 0)
    StatusText.Text = "Pronto"
    StatusText.TextColor3 = Theme.Text
    StatusText.BackgroundTransparency = 1
    StatusText.Font = Enum.Font.GothamBold
    StatusText.TextSize = 11
    StatusText.TextXAlignment = Enum.TextXAlignment.Left
    StatusText.Parent = StatusBar
    
    local TargetCount = Instance.new("TextLabel")
    TargetCount.Name = "TargetCount"
    TargetCount.Size = UDim2.new(0.3, 0, 0.5, 0)
    TargetCount.Position = UDim2.new(0.65, 0, 0.1, 0)
    TargetCount.Text = "0/0"
    TargetCount.TextColor3 = Theme.TextSecondary
    TargetCount.BackgroundTransparency = 1
    TargetCount.Font = Enum.Font.GothamBold
    TargetCount.TextSize = 10
    TargetCount.Parent = StatusBar
    
    --// Botão de Minimizar Corrigido
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "CloseBtn"
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(0.95, -15, 0, 10)
    CloseBtn.AnchorPoint = Vector2.new(1, 0)
    CloseBtn.Text = "▼"
    CloseBtn.TextColor3 = Theme.Text
    CloseBtn.BackgroundColor3 = Theme.Accent
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 16
    CloseBtn.Parent = MainFrame
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(1, 0)
    CloseCorner.Parent = CloseBtn
    
    --// ANIMAÇÕES
    local function TweenCard(card, color)
        TweenService:Create(card, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = color
        }):Play()
    end
    
    local function PulseEffect(object)
        local originalSize = object.Size
        TweenService:Create(object, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(originalSize.X.Scale * 0.95, originalSize.X.Offset * 0.95, 
                           originalSize.Y.Scale * 0.95, originalSize.Y.Offset * 0.95)
        }):Play()
        
        task.wait(0.1)
        TweenService:Create(object, TweenInfo.new(0.15, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
            Size = originalSize
        }):Play()
    end
    
    --// FUNÇÕES DOS SLIDERS
    local function UpdateFOV(value)
        _G.FOV = math.clamp(value, 50, 300)
        FOVText.Text = "FOV: " .. math.floor(_G.FOV)
        FOVSliderFill.Size = UDim2.new((_G.FOV - 50) / (300 - 50), 0, 1, 0)
        Circle.Radius = _G.FOV
    end
    
    local function UpdatePrediction(value)
        _G.Prediction = math.clamp(value, 0, 0.5)
        PredText.Text = "Predição: " .. string.format("%.3f", _G.Prediction)
        PredSliderFill.Size = UDim2.new(_G.Prediction / 0.5, 0, 1, 0)
    end
    
    -- Slider do FOV
    FOVContainer.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            local connection
            connection = UserInputService.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    local relativeX = (input.Position.X - FOVContainer.AbsolutePosition.X) / FOVContainer.AbsoluteSize.X
                    local value = 50 + (math.clamp(relativeX, 0, 1) * (300 - 50))
                    UpdateFOV(value)
                end
            end)
            
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    connection:Disconnect()
                    PulseEffect(FOVContainer)
                end
            end)
        end
    end)
    
    -- Slider da Predição
    PredContainer.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            local connection
            connection = UserInputService.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    local relativeX = (input.Position.X - PredContainer.AbsolutePosition.X) / PredContainer.AbsoluteSize.X
                    local value = math.clamp(relativeX, 0, 1) * 0.5
                    UpdatePrediction(value)
                end
            end)
            
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    connection:Disconnect()
                    PulseEffect(PredContainer)
                end
            end)
        end
    end)
    
    --// FUNÇÕES DOS BOTÕES
    ToggleBtn.MouseButton1Click:Connect(function()
        _G.SilentAim = not _G.SilentAim
        
        PulseEffect(ToggleContainer)
        
        if _G.SilentAim then
            TweenService:Create(ToggleStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Success
            }):Play()
            
            StatusText.Text = "ON"
            ToggleIcon.Text = "✅"
            ToggleIcon.TextColor3 = Theme.Success
            
            LastCacheUpdate = 0
            UpdateCaches()
            
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "🎯 SILENT AIM",
                Text = "ATIVADO",
                Duration = 1.5,
                Icon = "rbxassetid://4483345998"
            })
        else
            TweenService:Create(ToggleStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Danger
            }):Play()
            
            StatusText.Text = "OFF"
            ToggleIcon.Text = "⭕"
            ToggleIcon.TextColor3 = Theme.Danger
        end
    end)
    
    ModeBtn.MouseButton1Click:Connect(function()
        PulseEffect(ModeCard)
        
        if _G.TargetMode == "NPCs" then
            _G.TargetMode = "Players"
            ModeText.Text = "Modo: Players"
            ModeIcon.Text = "👤"
            ModeIcon.TextColor3 = Color3.fromRGB(230, 60, 60)
            TweenCard(ModeCard, Color3.fromRGB(45, 25, 25))
        elseif _G.TargetMode == "Players" then
            _G.TargetMode = "Both"
            ModeText.Text = "Modo: Ambos"
            ModeIcon.Text = "👥"
            ModeIcon.TextColor3 = Color3.fromRGB(180, 40, 180)
            TweenCard(ModeCard, Color3.fromRGB(45, 25, 45))
        else
            _G.TargetMode = "NPCs"
            ModeText.Text = "Modo: NPCs"
            ModeIcon.Text = "🎯"
            ModeIcon.TextColor3 = Theme.Accent
            TweenCard(ModeCard, Theme.Secondary)
        end
    end)
    
    AimPartBtn.MouseButton1Click:Connect(function()
        PulseEffect(AimPartCard)
        
        if _G.AimPart == "Head" then
            _G.AimPart = "Torso"
            AimPartText.Text = "Parte: Torso"
            AimPartIcon.Text = "🩻"
            AimPartIcon.TextColor3 = Color3.fromRGB(0, 180, 255)
            TweenCard(AimPartCard, Color3.fromRGB(25, 45, 60))
        elseif _G.AimPart == "Torso" then
            _G.AimPart = "Both"
            AimPartText.Text = "Parte: Ambos"
            AimPartIcon.Text = "👥"
            AimPartIcon.TextColor3 = Color3.fromRGB(180, 40, 180)
            TweenCard(AimPartCard, Color3.fromRGB(45, 25, 45))
        elseif _G.AimPart == "Both" then
            _G.AimPart = "Random"
            AimPartText.Text = "Parte: Aleatório"
            AimPartIcon.Text = "🎲"
            AimPartIcon.TextColor3 = Color3.fromRGB(255, 150, 0)
            TweenCard(AimPartCard, Color3.fromRGB(60, 40, 25))
        else
            _G.AimPart = "Head"
            AimPartText.Text = "Parte: Cabeça"
            AimPartIcon.Text = "👤"
            AimPartIcon.TextColor3 = Theme.Info
            TweenCard(AimPartCard, Theme.Secondary)
        end
    end)
    
    WallCheckBtn.MouseButton1Click:Connect(function()
        _G.VisibleCheck = not _G.VisibleCheck
        PulseEffect(WallCheckCard)
        
        if _G.VisibleCheck then
            WallCheckText.Text = "Wall Check: ON"
            WallCheckIcon.Text = "👁️"
            WallCheckIcon.TextColor3 = Theme.Success
            TweenCard(WallCheckCard, Theme.Secondary)
        else
            WallCheckText.Text = "Wall Check: OFF"
            WallCheckIcon.Text = "👁️‍🗨️"
            WallCheckIcon.TextColor3 = Theme.Danger
            TweenCard(WallCheckCard, Color3.fromRGB(45, 25, 25))
        end
    end)
    
    PerfBtn.MouseButton1Click:Connect(function()
        PulseEffect(PerfCard)
        
        if _G.UpdateRate == 0.2 then
            _G.UpdateRate = 0.1
            CacheUpdateInterval = 1
            PerfText.Text = "Performance: Rápido"
            PerfIcon.Text = "⚡"
            PerfIcon.TextColor3 = Color3.fromRGB(255, 150, 0)
            TweenCard(PerfCard, Color3.fromRGB(45, 35, 25))
        elseif _G.UpdateRate == 0.1 then
            _G.UpdateRate = 0.3
            CacheUpdateInterval = 3
            PerfText.Text = "Performance: Lento"
            PerfIcon.Text = "🐌"
            PerfIcon.TextColor3 = Color3.fromRGB(150, 150, 255)
            TweenCard(PerfCard, Color3.fromRGB(25, 35, 45))
        else
            _G.UpdateRate = 0.2
            CacheUpdateInterval = 2
            PerfText.Text = "Performance: Normal"
            PerfIcon.Text = "⚖️"
            PerfIcon.TextColor3 = Theme.Warning
            TweenCard(PerfCard, Theme.Secondary)
        end
    end)
    
    TeamCheckPlayerBtn.MouseButton1Click:Connect(function()
        _G.TeamCheck = not _G.TeamCheck
        PulseEffect(TeamCheckPlayerCard)
        
        if _G.TeamCheck then
            TweenService:Create(TeamCheckPlayerStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Success
            }):Play()
            TeamCheckPlayerStatusText.Text = "ON"
            TeamCheckPlayerIcon.TextColor3 = Theme.Success
        else
            TweenService:Create(TeamCheckPlayerStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Danger
            }):Play()
            TeamCheckPlayerStatusText.Text = "OFF"
            TeamCheckPlayerIcon.TextColor3 = Theme.Danger
        end
    end)
    
    TeamCheckNPCBtn.MouseButton1Click:Connect(function()
        _G.TeamCheckForNPCs = not _G.TeamCheckForNPCs
        PulseEffect(TeamCheckNPCCard)
        
        if _G.TeamCheckForNPCs then
            TweenService:Create(TeamCheckNPCStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Success
            }):Play()
            TeamCheckNPCStatusText.Text = "ON"
            TeamCheckNPCIcon.TextColor3 = Theme.Success
        else
            TweenService:Create(TeamCheckNPCStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Danger
            }):Play()
            TeamCheckNPCStatusText.Text = "OFF"
            TeamCheckNPCIcon.TextColor3 = Theme.Danger
        end
    end)
    
    CloseBtn.MouseButton1Click:Connect(function()
        PulseEffect(CloseBtn)
        
        local tweenOut = TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0)
        })
        tweenOut:Play()
        
        tweenOut.Completed:Wait()
        MainFrame.Visible = false
        MainFrame.Size = UDim2.new(0, 320, 0, 400)
        
        CreateFloatButton(ScreenGui)
    end)
    
    --// ATUALIZAR STATUS EM TEMPO REAL
    task.spawn(function()
        while task.wait(0.5) do
            if _G.SilentAim then
                if CurrentTarget then
                    local isPlayer = false
                    for _, data in pairs(PlayerCache) do
                        if data.Model == CurrentTarget then
                            isPlayer = true
                            break
                        end
                    end
                    
                    if isPlayer then
                        StatusIcon.Text = "👤"
                        StatusIcon.TextColor3 = Theme.Info
                        StatusText.Text = "Player travado"
                    else
                        StatusIcon.Text = "🎯"
                        StatusIcon.TextColor3 = Theme.Success
                        StatusText.Text = "NPC travado"
                    end
                elseif TargetInRange then
                    StatusIcon.Text = "⚠️"
                    StatusIcon.TextColor3 = Theme.Warning
                    StatusText.Text = "Alvo no FOV"
                else
                    StatusIcon.Text = "🔍"
                    StatusIcon.TextColor3 = Theme.TextSecondary
                    StatusText.Text = "Buscando..."
                end
                
                local npcCount = 0
                local playerCount = 0
                
                for _, data in pairs(NPCCache) do
                    if data.Humanoid.Health > 0 then
                        npcCount = npcCount + 1
                    end
                end
                
                for _, data in pairs(PlayerCache) do
                    if data.Humanoid.Health > 0 then
                        playerCount = playerCount + 1
                    end
                end
                
                TargetCount.Text = npcCount .. "/" .. playerCount
            else
                StatusIcon.Text = "✨"
                StatusIcon.TextColor3 = Theme.Warning
                StatusText.Text = "Pronto"
                TargetCount.Text = "0/0"
            end
        end
    end)
    
    --// SISTEMA DE ARRASTAR
    local dragging = false
    local dragStart, startPos
    
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            
            TweenService:Create(Header, TweenInfo.new(0.1), {
                BackgroundColor3 = Color3.fromRGB(120, 90, 220)
            }):Play()
            
            PulseEffect(MainFrame)
        end
    end)
    
    Header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            
            TweenService:Create(Header, TweenInfo.new(0.15), {
                BackgroundColor3 = Theme.Secondary
            }):Play()
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    --// ANIMAÇÃO DE ENTRADA
    MainFrame.Size = UDim2.new(0, 0, 0, 0)
    local tweenIn = TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 320, 0, 400)
    })
    tweenIn:Play()
    
    return ScreenGui
end

--// INICIALIZAÇÃO
task.wait(0.5)
-- Apenas limpar a UI existente, NÃO os hooks
CleanupUIOnly()
CreateCompactMobileUI()

--// NOTIFICAÇÃO INICIAL
task.spawn(function()
    task.wait(1)
    
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "🎯 SILENT AIM v2.2",
        Text = "Interface compacta carregada!\nBotão flutuante otimizado!",
        Duration = 3,
        Icon = "rbxassetid://4483345998"
    })
    
    print([[
╔══════════════════════════════════════════════╗
║        SILENT AIM - COMPACT EDITION          ║
║                 VERSION 2.2                  ║
║                                              ║
║  • Mira em Cabeça/Torso/Ambos/Aleatório      ║
║  • Interface organizada (320x400)            ║
║  • Botão flutuante CORRIGIDO                 ║
║  • Sistema de arrastar melhorado             ║
║  • Prevenção de múltiplas instâncias da UI   ║
║                                              ║
║  Sistema carregado com sucesso!              ║
╚══════════════════════════════════════════════╝]])
end)

--// LIMPEZA
game:GetService("Players").PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        CleanupUIOnly()
    end
end)