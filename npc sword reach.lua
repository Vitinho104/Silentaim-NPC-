-- 🔥 HITBOX EXPANDER AGRESSIVO TOTAL (NPCs + Players)
-- ✅ Acerta TODOS os NPCs dentro do alcance simultaneamente
-- ✅ Reach: 50 studs (máximo configurável: 100)
-- ✅ ZERO spam de notificações durante combate
-- ✅ Modo agressivo: detecta QUALQUER modelo com Humanoid como NPC
-- ✅ Interface Mano Gustavo UI profissional

-- [1] CARREGAR LIBRARY
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Mano-Gustavo/Mano-Gustavo-Library/refs/heads/main/library.lua"))()

if not Library then
    warn("❌ Falha ao carregar a Mano Gustavo UI Library")
    return
end

-- [2] CRIAR JANELA PRINCIPAL
local Window = Library:CreateWindow({
    Title = "💥 Hitbox Total",
    Keybind = Enum.KeyCode.RightControl,
    Author = "NPC Annihilator"
})

-- [3] CRIAR TABS E SECTIONS
local TabMain = Window:CreateTab("Principal")
local SectionConfig = TabMain:CreateSection("Configurações")
local SectionTargets = TabMain:CreateSection("Alvos")
local SectionVisual = TabMain:CreateSection("Visual")

-- [4] VARIÁVEIS GLOBAIS
local active = true
local reachValue = 10 -- 🔥 ALCANCE PADRÃO: 50 STUDS
local reachType = "Sphere"
local damageEnabled = true
local visualizerEnabled = false
local hitPlayers = true
local hitNPCs = true
local aggressiveMode = true -- 🔥 MODO AGRESSIVO ATIVADO
local npcCache = {}
local visualizer = Instance.new("Part")
local lastHitTime = 0
local hitCounter = 0

-- Configurar visualizer
visualizer.Name = "HitboxVisualizer"
visualizer.BrickColor = BrickColor.new("Bright blue")
visualizer.Transparency = 0.75
visualizer.Anchored = true
visualizer.CanCollide = false
visualizer.Size = Vector3.new(0.5, 0.5, 0.5)
visualizer.BottomSurface = Enum.SurfaceType.Smooth
visualizer.TopSurface = Enum.SurfaceType.Smooth
visualizer.Parent = nil

-- [5] COMPONENTES DA UI
local ToggleMain = SectionConfig:CreateToggle("Ativado", function(state)
    active = state
    if not state then
        visualizer.Parent = nil
        hitCounter = 0
    end
end, true)

local SliderReach = SectionConfig:CreateSlider("Reach", 5, 100, 50, function(value)
    reachValue = value
end)
SliderReach:SetTooltip("Alcance do hitbox em studs (padrão: 50)")

local DropdownMode = SectionConfig:CreateDropdown("Modo de Detecção", {"Sphere", "Line"}, function(mode)
    reachType = mode
end)
DropdownMode:SetTooltip("Sphere = área redonda | Line = raio frontal")

local ToggleDamage = SectionConfig:CreateToggle("Dano Automático", function(state)
    damageEnabled = state
end, true)

local ToggleVisualizer = SectionVisual:CreateToggle("Visualizador", function(state)
    visualizerEnabled = state
    visualizer.Parent = state and workspace or nil
end, false)

local ToggleHitPlayers = SectionTargets:CreateToggle("Atingir Jogadores", function(state)
    hitPlayers = state
end, true)

local ToggleHitNPCs = SectionTargets:CreateToggle("Atingir NPCs", function(state)
    hitNPCs = state
end, true)

local ToggleAggressive = SectionTargets:CreateToggle("⚠️ Modo Agressivo", function(state)
    aggressiveMode = state
    -- Forçar atualização do cache
    lastCacheUpdate = 0
end, true)

-- [6] BOTÃO DE KILL SCRIPT
SectionConfig:CreateButton("❌ Desativar Script", function()
    active = false
    visualizer:Destroy()
    pcall(function() Window:Destroy() end)
    Library:Notification({
        Title = "Desativado",
        Text = "Hitbox Total desligado",
        Duration = 3,
        Type = "Success"
    })
end)

-- [7] CACHE OTIMIZADO DE NPCs (ANTI-LAG)
local lastCacheUpdate = 0
local cacheInterval = 1.2

spawn(function()
    while wait(cacheInterval) do
        if not active then continue end
        
        lastCacheUpdate = tick()
        npcCache = {}
        local processed = 0
        
        -- Método 1: Pastas específicas (rápido)
        local npcFolders = {"NPCs", "Enemies", "Bots", "Mobs", "Targets", "Characters", "Spawns"}
        for _, folderName in ipairs(npcFolders) do
            local folder = workspace:FindFirstChild(folderName)
            if folder then
                for _, obj in ipairs(folder:GetDescendants()) do
                    if obj:IsA("Model") and obj ~= game.Players.LocalPlayer.Character then
                        local humanoid = obj:FindFirstChildOfClass("Humanoid")
                        local hrp = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
                        
                        if humanoid and humanoid.Health > 0 and hrp then
                            table.insert(npcCache, hrp)
                        end
                    end
                end
            end
        end
        
        -- Método 2: Modo Agressivo (otimizado com pausas)
        if aggressiveMode then
            local descendants = workspace:GetDescendants()
            for i, obj in ipairs(descendants) do
                if obj:IsA("Model") and obj ~= game.Players.LocalPlayer.Character then
                    local humanoid = obj:FindFirstChildOfClass("Humanoid")
                    local hrp = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
                    
                    if humanoid and humanoid.Health > 0 and hrp then
                        -- Evitar duplicatas
                        local exists = false
                        for _, cached in ipairs(npcCache) do
                            if cached == hrp then
                                exists = true
                                break
                            end
                        end
                        if not exists then
                            table.insert(npcCache, hrp)
                        end
                    end
                end
                
                -- Micro-pausa a cada 150 objetos para evitar lag
                if i % 150 == 0 then wait() end
            end
        end
    end
end)

-- [8] FUNÇÃO DE DANO OTIMIZADA (ACERTA TODOS OS ALVOS)
local function applyDamageToAll(targets, handle)
    if not handle or #targets == 0 then return end
    
    local currentTime = tick()
    hitCounter += #targets
    
    -- Feedback silencioso (sem spam!)
    if currentTime - lastHitTime > 1.5 then
        lastHitTime = currentTime
        Library:Notification({
            Title = "💥 " .. hitCounter .. " hits",
            Text = "Alvos atingidos nos últimos 1.5s",
            Duration = 1.8,
            Type = "Success"
        })
        hitCounter = 0
    end
    
    -- 🔥 ACERTAR TODOS OS ALVOS SIMULTANEAMENTE
    for _, hrp in ipairs(targets) do
        if not hrp or not hrp.Parent then continue end
        
        local character = hrp.Parent
        if character == game.Players.LocalPlayer.Character then continue end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        
        -- Sistema de dano AGRESSIVO
        if damageEnabled then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function()
                        firetouchinterest(part, handle, 0)
                        firetouchinterest(part, handle, 1)
                    end)
                end
            end
        else
            pcall(function()
                firetouchinterest(hrp, handle, 0)
                firetouchinterest(hrp, handle, 1)
            end)
        end
    end
end

-- [9] SISTEMA PRINCIPAL (RenderStepped)
game:GetService("RunService").RenderStepped:Connect(function()
    if not active or not game.Players.LocalPlayer.Character then return end
    
    local tool = game.Players.LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if not tool then
        if visualizerEnabled then visualizer.Parent = nil end
        return
    end
    
    local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildOfClass("Part")
    if not handle then return end
    
    -- Atualizar visualizer
    if visualizerEnabled then
        visualizer.Parent = workspace
        visualizer.CFrame = handle.CFrame
        
        if reachType == "Sphere" then
            visualizer.Shape = Enum.PartType.Ball
            visualizer.Size = Vector3.new(reachValue * 2, reachValue * 2, reachValue * 2)
        else
            visualizer.Shape = Enum.PartType.Block
            visualizer.Size = Vector3.new(1, 0.8, reachValue)
            visualizer.CFrame = handle.CFrame * CFrame.new(0, 0, -reachValue / 2)
        end
    else
        visualizer.Parent = nil
    end
    
    -- 🔸 MODO SPHERE (RECOMENDADO PARA NPCs)
    if reachType == "Sphere" then
        local targets = {}
        
        -- 🔹 JOGADORES
        if hitPlayers then
            for _, player in ipairs(game.Players:GetPlayers()) do
                if player ~= game.Players.LocalPlayer and player.Character then
                    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and (hrp.Position - handle.Position).Magnitude <= reachValue then
                        table.insert(targets, hrp)
                    end
                end
            end
        end
        
        -- 🔹 NPCs (CACHE AGRESSIVO)
        if hitNPCs then
            for _, hrp in ipairs(npcCache) do
                if hrp and hrp.Parent and (hrp.Position - handle.Position).Magnitude <= reachValue then
                    table.insert(targets, hrp)
                end
            end
        end
        
        -- 🔥 ACERTAR TODOS OS ALVOS DE UMA VEZ
        if #targets > 0 then
            applyDamageToAll(targets, handle)
        end
    
    -- 🔸 MODO LINE (Raycast - acerta múltiplos alvos na linha)
    elseif reachType == "Line" then
        local targets = {}
        local origin = handle.Position
        local direction = handle.CFrame.LookVector * -reachValue
        
        -- Whitelist otimizada
        local whitelist = {}
        
        if hitPlayers then
            for _, player in ipairs(game.Players:GetPlayers()) do
                if player ~= game.Players.LocalPlayer and player.Character then
                    for _, part in ipairs(player.Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            table.insert(whitelist, part)
                        end
                    end
                end
            end
        end
        
        if hitNPCs then
            for _, hrp in ipairs(npcCache) do
                if hrp and hrp.Parent then
                    for _, part in ipairs(hrp.Parent:GetChildren()) do
                        if part:IsA("BasePart") then
                            table.insert(whitelist, part)
                        end
                    end
                end
            end
        end
        
        if #whitelist > 0 then
            -- Raycast múltiplo (simulação)
            for _, part in ipairs(whitelist) do
                local distance = (part.Position - origin).Magnitude
                local directionToPart = (part.Position - origin).Unit
                local dot = directionToPart:Dot(handle.CFrame.LookVector * -1)
                
                if distance <= reachValue and dot > 0.7 then -- Dentro do cone de visão
                    table.insert(targets, part)
                end
            end
            
            -- 🔥 ACERTAR TODOS NA LINHA
            if #targets > 0 then
                applyDamageToAll(targets, handle)
            end
        end
    end
end)

-- [10] KEYBIND PARA TOGGLE RÁPIDO (H)
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.H then
        active = not active
        ToggleMain:Set(active)
        
        Library:Notification({
            Title = active and "✅ ATIVADO" or "❌ DESATIVADO",
            Text = "Hitbox Total " .. (active and "LIGADO 🔥" or "desligado"),
            Duration = 2,
            Type = active and "Success" or "Error"
        })
    end
end)

-- [11] NOTIFICAÇÃO DE INICIALIZAÇÃO (SEM SPAM!)
Library:Notification({
    Title = "💥 HITBOX TOTAL",
    Text = "Reach: 50 studs\nModo Agressivo: ATIVADO\nAcerta TODOS os NPCs simultaneamente",
    Duration = 5,
    Type = "Success"
})

-- ✅ SCRIPT PRONTO PARA USO
-- 🔹 Pressione H para toggle rápido
-- 🔹 RightControl para abrir menu
-- 🔹 ZERO spam de notificações durante combate
-- 🔹 Acerta TODOS os NPCs dentro do alcance de uma vez
