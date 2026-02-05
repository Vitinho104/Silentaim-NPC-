local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Mano-Gustavo/Mano-Gustavo-Library/refs/heads/main/library.lua"
))()

-- Configurações iniciais
local config = {
    enabled = false,
    attackMode = "Normal",  -- Normal, Agressivo, BRUTO
    radius = 20,  -- VALOR INICIAL REDUZIDO (1-100)
    damage = 15,
    targetNPCs = true,
    targetPlayers = false,
    showVisual = true,
    visualOffset = 5,
    attackCooldown = 0.3,
    maxTargets = 10,  -- NOVO: Máximo de NPCs que pode acertar por ataque
    
    -- Modos separados
    useFireTouch = true,
    useTakeDamage = true,
    useRemoteEvents = true,
    touchAllParts = true,
    aggressiveNPCDetection = true,
    debugMode = false,
    
    -- Configurações específicas por modo
    normalSettings = {
        radius = 15,  -- REDUZIDO (1-100)
        offset = 5,
        cooldown = 0.5,
        color = Color3.fromRGB(0, 255, 255)
    },
    aggressiveSettings = {
        radius = 30,  -- REDUZIDO (1-100)
        offset = 8,
        cooldown = 0.2,
        color = Color3.fromRGB(255, 165, 0),
        autoAttack = true,
        detectionRange = 100
    },
    bruteSettings = {
        radius = 50,  -- REDUZIDO (1-100)
        offset = 15,
        cooldown = 0.1,
        color = Color3.fromRGB(255, 0, 0),
        bruteForceMultiplier = 3
    }
}

-- LISTA COMPLETA DE TAGS DE NPCs (DO SILENT AIM)
local NPCTags = {
    -- NPC comum
    "NPC", "Npc", "npc",
    
    -- Inimigos
    "Enemy", "enemy", "Enemies", "enemies",
    "Hostile", "hostile", "Bad", "bad", "BadGuy", "badguy",
    "Foe", "foe", "Opponent", "opponent",
    
    -- Tipos de bots/mobs
    "Bot", "bot", "Bots", "bots",
    "Mob", "mob", "Mobs", "mobs",
    "Monster", "monster", "Monsters", "monsters",
    "Zombie", "zombie", "Zombies", "zombies",
    "Creature", "creature", "Animal", "animal", "Beast", "beast",
    
    -- Vilões/adversários
    "Villain", "villain", "Villian", "villian",
    "Boss", "boss", "MiniBoss", "miniboss",
    "Guard", "guard", "Guardian", "guardian",
    "Soldier", "soldier", "Warrior", "warrior",
    "Fighter", "fighter",
    
    -- Alvos
    "Target", "target",
    "Dummy", "dummy", "Dummies", "dummies",
    "Practice", "practice", "Training", "training",
    
    -- Tipos específicos comuns
    "Skeleton", "skeleton",
    "Orc", "orc", "Goblin", "goblin",
    "Troll", "troll", "Ogre", "ogre",
    "Demon", "demon", "Devil", "devil",
    "Ghost", "ghost", "Spirit", "spirit",
    "Vampire", "vampire", "Werewolf", "werewolf",
    "Dragon", "dragon", "Wyvern", "wyvern",
    
    -- Factions/gangs
    "Gang", "gang", "Thug", "thug",
    "Bandit", "bandit", "Raider", "raider",
    "Pirate", "pirate", "Corsair", "corsair",
    
    -- Agentes
    "Agent", "agent", "Assassin", "assassin",
    "Mercenary", "mercenary", "Hunter", "hunter",
    
    -- Animações/robôs
    "Robot", "robot", "Drone", "drone",
    "Android", "android", "Cyborg", "cyborg",
    "Automaton", "automaton",
    
    -- Servos
    "Servant", "servant", "Minion", "minion",
    "Slave", "slave", "Pawn", "pawn",
    
    -- Códigos/programação
    "AI", "ai", "A.I.",
    "Char", "char", "Character", "character",
    "Model", "model",
    
    -- Eventos especiais
    "Event", "event", "Special", "special",
    "Holiday", "holiday", "Seasonal", "seasonal",
}

-- Criar janela principal
local Window = Library:CreateWindow({
    Title = "⚔️ Sword Master - DETECÇÃO AGRESSIVA FIX",
    Subtitle = "NPC Detection Fix v2.0",
    Author = "Fixed by ScriptHub",
    Keybind = Enum.KeyCode.RightControl
})

-- Serviços
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Aba principal
local TabMain = Window:CreateTab("Sword Master")
local TabDetection = Window:CreateTab("Detecção NPCs")
local TabConfig = Window:CreateTab("Configurações")

-- VARIÁVEIS DO SISTEMA
local visualPart = nil
local currentWeapon = nil
local character = nil
local lastAttackTime = 0
local canAttack = true
local lastMouseClick = 0
local isRunning = false
local npcCache = {}
local playerCache = {}
local lastCacheUpdate = 0
local cacheUpdateInterval = 1.5
local currentTarget = nil

-- ======================
-- VARIÁVEL PARA TRANSPARÊNCIA (CORRIGIDA)
-- ======================
local savedTransparency = 0.2

-- ======================
-- FUNÇÕES DE DETECÇÃO NPC (DO SILENT AIM)
-- ======================

-- Função: É Player?
local function IsPlayer(characterModel)
    if not characterModel or not characterModel:IsA("Model") then
        return false
    end
    if characterModel == LocalPlayer.Character then
        return true
    end
    local player = Players:GetPlayerFromCharacter(characterModel)
    return player ~= nil
end

-- Função: É NPC? (SISTEMA COMPLETO DO SILENT AIM)
local function IsNPC(characterModel)
    if not characterModel or not characterModel:IsA("Model") then
        return false
    end
    
    -- Ignorar se for player
    if IsPlayer(characterModel) then
        return false
    end
    
    -- Verificar componentes básicos
    local humanoid = characterModel:FindFirstChildOfClass("Humanoid")
    local head = characterModel:FindFirstChild("Head")
    local hrp = characterModel:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not head or not hrp or humanoid.Health <= 0 then
        return false
    end
    
    -- MODO AGRESSIVO: Qualquer modelo com humanoid é NPC
    if config.aggressiveNPCDetection then
        if config.debugMode then
            print("[DETECTION] NPC Detectado (Modo Agressivo):", characterModel.Name)
        end
        return true
    end
    
    local charName = characterModel.Name:lower()
    
    -- MÉTODO 1: Verificar por tags no nome
    for _, tag in pairs(NPCTags) do
        if charName:find(tag:lower(), 1, true) then
            if config.debugMode then
                print("[DETECTION] NPC por Tag:", characterModel.Name, "Tag:", tag)
            end
            return true
        end
    end
    
    -- MÉTODO 2: Verificar por pastas específicas no workspace
    local npcFolders = {
        "NPCs", "Enemies", "Bots", "Mobs", "Targets", "Enemy", "Hostile",
        "Monsters", "Zombies", "Creatures", "Characters", "Spawns",
        "EnemySpawns", "NPCSpawns", "Bosses", "Minions"
    }
    
    for _, folderName in pairs(npcFolders) do
        local folder = workspace:FindFirstChild(folderName)
        if folder and characterModel:IsDescendantOf(folder) then
            if config.debugMode then
                print("[DETECTION] NPC na Pasta:", characterModel.Name, "Pasta:", folderName)
            end
            return true
        end
    end
    
    -- MÉTODO 3: Verificar por valores/customizações específicas
    local possibleNPCIndicators = {
        "NPC", "IsNPC", "IsEnemy", "Hostile", "Enemy", 
        "IsBot", "IsMob", "IsMonster", "Team", "Faction"
    }
    
    for _, indicator in pairs(possibleNPCIndicators) do
        local value = characterModel:FindFirstChild(indicator)
        if value then
            if value:IsA("BoolValue") then
                if indicator == "NPC" or indicator == "IsNPC" or 
                   indicator == "IsEnemy" or indicator == "Hostile" then
                    if value.Value == true then
                        if config.debugMode then
                            print("[DETECTION] NPC por BoolValue:", characterModel.Name, indicator)
                        end
                        return true
                    end
                end
            elseif value:IsA("StringValue") then
                local valLower = value.Value:lower()
                if valLower == "enemy" or valLower == "hostile" or 
                   valLower == "npc" or valLower == "bot" or
                   valLower == "monster" or valLower == "mob" then
                    if config.debugMode then
                        print("[DETECTION] NPC por StringValue:", characterModel.Name, indicator, "=", value.Value)
                    end
                    return true
                end
            elseif value:IsA("IntValue") then
                if indicator == "Team" then
                    if config.debugMode then
                        print("[DETECTION] NPC por Team Value:", characterModel.Name, "Team:", value.Value)
                    end
                    return true
                end
            end
        end
    end
    
    -- MÉTODO 4: Verificar tags de CollectionService
    local tags = CollectionService:GetTags(characterModel)
    for _, tag in pairs(tags) do
        local tagLower = tag:lower()
        for _, npcTag in pairs(NPCTags) do
            if tagLower:find(npcTag:lower(), 1, true) then
                if config.debugMode then
                    print("[DETECTION] NPC por CollectionService:", characterModel.Name, "Tag:", tag)
                end
                return true
            end
        end
    end
    
    -- MÉTODO 5: Verificar pelo prefixo/sufixo no nome
    local namePatterns = {"^npc_", "^enemy_", "^bot_", "^mob_", "_npc$", "_enemy$", "_bot$"}
    for _, pattern in pairs(namePatterns) do
        if string.match(charName, pattern) then
            if config.debugMode then
                print("[DETECTION] NPC por Padrão:", characterModel.Name, "Padrão:", pattern)
            end
            return true
        end
    end
    
    -- Último recurso: Se tem estrutura de humanoide mas não é player, assumir que é NPC
    if config.debugMode then
        print("[DETECTION] NPC Genérico:", characterModel.Name)
    end
    return true
end

-- Função: Buscar NPCs em todas as pastas (Recursivo)
local function FindNPCsInWorkspaceRecursive(parent)
    local foundNPCs = {}
    
    for _, child in pairs(parent:GetChildren()) do
        if child:IsA("Model") then
            if IsNPC(child) then
                table.insert(foundNPCs, child)
            end
        end
        
        -- Procurar recursivamente em subpastas
        if not child:IsA("BasePart") and not child:IsA("Decal") and not child:IsA("Texture") then
            local subNPCs = FindNPCsInWorkspaceRecursive(child)
            for _, npc in pairs(subNPCs) do
                table.insert(foundNPCs, npc)
            end
        end
    end
    
    return foundNPCs
end

-- Função: Atualizar Cache de NPCs (OTIMIZADO - DO SILENT AIM)
local function UpdateNPCCache()
    local currentTime = tick()
    
    if currentTime - lastCacheUpdate < cacheUpdateInterval then
        return
    end
    
    lastCacheUpdate = currentTime
    
    local tempNPCCache = {}
    local tempPlayerCache = {}
    local allModels = {}
    
    -- Método 1: Modelos diretos no workspace
    local wsChildren = workspace:GetChildren()
    for _, model in pairs(wsChildren) do
        if model:IsA("Model") and model ~= LocalPlayer.Character then
            table.insert(allModels, model)
        end
    end
    
    -- Método 2: Buscar em pastas específicas
    local npcFolders = {"NPCs", "Enemies", "Bots", "Mobs", "Targets", 
                        "Characters", "Spawns", "Monsters", "Zombies",
                        "Enemy", "Hostile", "Bosses", "Minions", "Creatures"}
    
    for _, folderName in pairs(npcFolders) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            local npcsInFolder = FindNPCsInWorkspaceRecursive(folder)
            for _, npc in pairs(npcsInFolder) do
                table.insert(allModels, npc)
            end
        end
    end
    
    -- Método 3: MODO AGRESSIVO OTIMIZADO
    if config.aggressiveNPCDetection then
        local counter = 0
        local descendants = workspace:GetDescendants()
        
        for _, descendant in pairs(descendants) do
            if descendant:IsA("Model") and descendant ~= LocalPlayer.Character then
                table.insert(allModels, descendant)
                
                counter = counter + 1
                if counter % 150 == 0 then
                    task.wait() 
                end
            end
        end
    end
    
    -- Processar todos os modelos encontrados
    local processCounter = 0
    for _, model in pairs(allModels) do
        processCounter = processCounter + 1
        if processCounter % 200 == 0 then task.wait() end

        local hrp = model:FindFirstChild("HumanoidRootPart")
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        
        if hrp and humanoid and humanoid.Health > 0 then
            if IsPlayer(model) then
                tempPlayerCache[model] = {
                    Model = model,
                    HRP = hrp,
                    Humanoid = humanoid,
                    Player = Players:GetPlayerFromCharacter(model),
                    IsNPC = false
                }
            elseif IsNPC(model) then
                tempNPCCache[model] = {
                    Model = model,
                    HRP = hrp,
                    Humanoid = humanoid,
                    IsNPC = true
                }
            end
        end
    end
    
    -- Adicionar players manualmente
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            
            if hrp and humanoid and humanoid.Health > 0 then
                tempPlayerCache[char] = {
                    Model = char,
                    HRP = hrp,
                    Humanoid = humanoid,
                    Player = player,
                    IsNPC = false
                }
            end
        end
    end
    
    -- Atualizar as variáveis globais de cache
    npcCache = tempNPCCache
    playerCache = tempPlayerCache
    
    if config.debugMode then
        local npcCount = 0
        for _ in pairs(npcCache) do npcCount = npcCount + 1 end
        print("[CACHE] Atualizado - NPCs:", npcCount)
    end
end

-- ======================
-- SEÇÃO MODOS (ABA PRINCIPAL)
-- ======================

local SectionMode = TabMain:CreateSection("🎮 Modos de Ataque")

SectionMode:CreateLabel("Escolha um modo:")
SectionMode:CreateLabel("Normal: Ataca quando você ataca")
SectionMode:CreateLabel("Agressivo: Ataca NPCs automaticamente")
SectionMode:CreateLabel("BRUTO: Todas técnicas juntas")

-- Dropdown para modo
local ModeDropdown = SectionMode:CreateDropdown("Selecionar Modo", 
    {"Normal", "Agressivo", "BRUTO"}, 
    function(Selected)
        config.attackMode = Selected
        ApplyModeSettings(Selected)
        Library:Notification({
            Title = "🎮 Modo Alterado",
            Text = "Modo " .. Selected .. " ativado!",
            Duration = 3,
            Type = "Info"
        })
    end
)

-- Função para aplicar configurações do modo
local function ApplyModeSettings(mode)
    if mode == "Normal" then
        config.radius = config.normalSettings.radius
        config.visualOffset = config.normalSettings.offset
        config.attackCooldown = config.normalSettings.cooldown
        config.aggressiveNPCDetection = false
        config.useFireTouch = true
        config.useTakeDamage = true
        
    elseif mode == "Agressivo" then
        config.radius = config.aggressiveSettings.radius
        config.visualOffset = config.aggressiveSettings.offset
        config.attackCooldown = config.aggressiveSettings.cooldown
        config.aggressiveNPCDetection = true  -- ATIVA DETECÇÃO AGRESSIVA
        config.useFireTouch = true
        config.useTakeDamage = true
        
    elseif mode == "BRUTO" then
        config.radius = config.bruteSettings.radius
        config.visualOffset = config.bruteSettings.offset
        config.attackCooldown = config.bruteSettings.cooldown
        config.aggressiveNPCDetection = true  -- ATIVA DETECÇÃO AGRESSIVA
        config.useFireTouch = true
        config.useTakeDamage = true
        config.useRemoteEvents = true
    end
    
    -- Atualizar sliders se existirem
    if RadiusSlider then
        RadiusSlider:Set(config.radius)
    end
    if OffsetSlider then
        OffsetSlider:Set(config.visualOffset)
    end
    if CooldownSlider then
        CooldownSlider:Set(config.attackCooldown)
    end
    
    -- Atualizar visual
    if visualPart then
        visualPart.Color = GetModeColor(mode)
        visualPart.Size = Vector3.new(config.radius * 2, config.radius * 2, config.radius * 2)
    end
    
    -- Forçar atualização do cache
    lastCacheUpdate = 0
    UpdateNPCCache()
end

-- Função para obter cor do modo
local function GetModeColor(mode)
    if mode == "Normal" then return config.normalSettings.color end
    if mode == "Agressivo" then return config.aggressiveSettings.color end
    if mode == "BRUTO" then return config.bruteSettings.color end
    return Color3.fromRGB(0, 255, 255)
end

-- ======================
-- SEÇÃO CONTROLE PRINCIPAL (CORRIGIDA)
-- ======================

local SectionControl = TabMain:CreateSection("⚙️ Controle Principal")

-- Toggle principal
local Toggle = SectionControl:CreateToggle("Ativar Sistema", function(Value)
    config.enabled = Value
    if Value then
        Library:Notification({
            Title = "✅ Sistema Ativado",
            Text = "Sword Master está ativo!",
            Duration = 2,
            Type = "Success"
        })
        -- Forçar atualização do cache
        lastCacheUpdate = 0
        UpdateNPCCache()
    else
        CleanUpVisuals()
        Library:Notification({
            Title = "❌ Sistema Desativado",
            Text = "Sword Master desligado!",
            Duration = 2,
            Type = "Error"
        })
    end
end, false)

-- Slider do raio CORRIGIDO (1-100)
local RadiusSlider = SectionControl:CreateSlider("Raio de Ataque", 1, 100, config.radius, function(Value)
    config.radius = Value
    if visualPart then
        visualPart.Size = Vector3.new(Value * 2, Value * 2, Value * 2)
    end
end)

-- Slider do offset CORRIGIDO (0-20)
local OffsetSlider = SectionControl:CreateSlider("Distância da Arma", 0, 20, config.visualOffset, function(Value)
    config.visualOffset = Value
    if visualPart and currentWeapon then
        UpdateVisualPosition()
    end
end)

-- Slider do cooldown
local CooldownSlider = SectionControl:CreateSlider("Velocidade de Ataque", 0.05, 1.0, config.attackCooldown, function(Value)
    config.attackCooldown = Value
end)

-- Slider do dano
local DamageSlider = SectionControl:CreateSlider("Dano por Ataque", 5, 200, config.damage, function(Value)
    config.damage = Value
end)

-- Slider para limite de alvos
local MaxTargetsSlider = SectionControl:CreateSlider("Máx. Alvos por Ataque", 1, 50, config.maxTargets, function(Value)
    config.maxTargets = Value
end)

-- ======================
-- SEÇÃO MULTI-ALVO (NOVA)
-- ======================

local SectionMultiTarget = TabMain:CreateSection("🎯 Multi-Alvo")

SectionMultiTarget:CreateLabel("=== SISTEMA MULTI-ALVO ===")
SectionMultiTarget:CreateLabel("Ataca TODOS os NPCs dentro do raio!")
SectionMultiTarget:CreateLabel("Máximo configurável abaixo:")

-- Slider para limite de alvos
local MultiTargetSlider = SectionMultiTarget:CreateSlider("Limite de Alvos", 1, 100, config.maxTargets, function(Value)
    config.maxTargets = Value
    if RadiusSlider then
        RadiusSlider:Set(Value * 2)  -- Ajusta raio automaticamente
    end
end)

SectionMultiTarget:CreateButton("🔄 Testar Multi-Alvo", function()
    if not currentWeapon then
        Library:Notification({
            Title = "❌ Sem arma",
            Text = "Pegue uma arma/espada primeiro!",
            Duration = 3,
            Type = "Error"
        })
        return
    end
    
    UpdateNPCCache()
    local attackPos = GetAttackPosition()
    
    -- Contar NPCs dentro do raio
    local npcsInRange = 0
    for _, npcData in pairs(npcCache) do
        local hrp = npcData.HRP
        if hrp then
            local distance = (attackPos - hrp.Position).Magnitude
            if distance <= config.radius then
                npcsInRange = npcsInRange + 1
            end
        end
    end
    
    Library:Notification({
        Title = "🎯 Multi-Alvo Teste",
        Text = string.format("NPCs no raio: %d\nRaio atual: %.1f\nLimite: %d", 
            npcsInRange, 
            config.radius,
            config.maxTargets),
        Duration = 5,
        Type = "Info"
    })
    
    -- Realizar um ataque de teste
    if npcsInRange > 0 then
        PerformAttack()
    end
end)

-- ======================
-- SEÇÃO TÉCNICAS
-- ======================

local SectionTech = TabMain:CreateSection("🔧 Técnicas de Dano")

-- Toggle para FireTouch
local ToggleFireTouch = SectionTech:CreateToggle("FireTouchInterest", function(Value)
    config.useFireTouch = Value
end, true)

-- Toggle para TakeDamage
local ToggleTakeDamage = SectionTech:CreateToggle("TakeDamage", function(Value)
    config.useTakeDamage = Value
end, true)

-- Toggle para RemoteEvents
local ToggleRemoteEvents = SectionTech:CreateToggle("RemoteEvents (BRUTO)", function(Value)
    config.useRemoteEvents = Value
end, false)

-- Toggle para tocar todas as partes
local ToggleAllParts = SectionTech:CreateToggle("Tocar Todas Partes", function(Value)
    config.touchAllParts = Value
end, true)

-- ======================
-- SEÇÃO ALVOS
-- ======================

local SectionTargets = TabMain:CreateSection("🎯 Alvos")

-- Toggle para NPCs
local ToggleNPCs = SectionTargets:CreateToggle("Atacar NPCs", function(Value)
    config.targetNPCs = Value
    if Value then
        lastCacheUpdate = 0
        UpdateNPCCache()
    end
end, true)

-- Toggle para jogadores
local TogglePlayers = SectionTargets:CreateToggle("Atacar Jogadores", function(Value)
    config.targetPlayers = Value
end, false)

-- ======================
-- SEÇÃO VISUAL (CORRIGIDA COM VALOR SALVO)
-- ======================

local SectionVisual = TabMain:CreateSection("👁️ Visual")

-- Slider de transparência (VISIBILIDADE)
local TransparencySlider = SectionVisual:CreateSlider("Transparência do Círculo", 0, 1, savedTransparency, function(Value)
    savedTransparency = Value
    if visualPart then
        visualPart.Transparency = Value
    end
end)

-- Toggle para mostrar visual
local ToggleVisual = SectionVisual:CreateToggle("Mostrar Área de Ataque", function(Value)
    config.showVisual = Value
    if not Value and visualPart then
        visualPart:Destroy()
        visualPart = nil
    elseif Value and config.enabled and currentWeapon then
        CreateVisualPart()
    end
end, true)

-- Slider de brilho
local BrightnessSlider = SectionVisual:CreateSlider("Brilho da Luz", 0, 2, 1.2, function(Value)
    if visualPart then
        local light = visualPart:FindFirstChildOfClass("PointLight")
        if light then
            light.Brightness = Value
        end
    end
end)

-- ======================
-- FUNÇÕES DO SISTEMA SWORD (CORRIGIDAS)
-- ======================

-- Função para criar visual
local function CreateVisualPart()
    if visualPart then
        visualPart:Destroy()
    end
    
    visualPart = Instance.new("Part")
    visualPart.Name = "SwordVisual"
    visualPart.Anchored = true
    visualPart.CanCollide = false
    visualPart.Transparency = savedTransparency  -- Usa o valor salvo
    visualPart.Color = GetModeColor(config.attackMode)
    visualPart.Shape = Enum.PartType.Ball
    visualPart.Material = Enum.Material.Neon
    visualPart.Size = Vector3.new(config.radius * 2, config.radius * 2, config.radius * 2)
    
    -- Luz
    local light = Instance.new("PointLight")
    light.Brightness = 1.2
    light.Range = config.radius * 2
    light.Color = visualPart.Color
    light.Parent = visualPart
    
    -- Efeito de brilho
    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Face = Enum.NormalId.Top
    surfaceGui.Parent = visualPart
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = visualPart.Color
    frame.BackgroundTransparency = 0.7
    frame.BorderSizePixel = 0
    frame.Parent = surfaceGui
    
    visualPart.Parent = workspace
end

-- Função para atualizar posição
local function UpdateVisualPosition()
    if not visualPart or not currentWeapon then return end
    
    local weaponHandle = currentWeapon:FindFirstChild("Handle") or currentWeapon.PrimaryPart or currentWeapon
    if not weaponHandle then return end
    
    local lookVector = weaponHandle.CFrame.LookVector
    local offsetPosition = weaponHandle.Position + (lookVector * config.visualOffset)
    
    visualPart.Position = offsetPosition
    visualPart.Size = Vector3.new(config.radius * 2, config.radius * 2, config.radius * 2)
end

-- Função para obter posição de ataque
local function GetAttackPosition()
    if not currentWeapon then return nil end
    
    local weaponHandle = currentWeapon:FindFirstChild("Handle") or currentWeapon.PrimaryPart or currentWeapon
    if not weaponHandle then return nil end
    
    local lookVector = weaponHandle.CFrame.LookVector
    return weaponHandle.Position + (lookVector * config.visualOffset)
end

-- Função para aplicar dano FireTouch
local function ApplyFireTouch(target)
    if not currentWeapon then return false end
    
    local weaponHandle = currentWeapon:FindFirstChild("Handle") or currentWeapon.PrimaryPart or currentWeapon
    if not weaponHandle then return false end
    
    local success = false
    
    if config.touchAllParts then
        -- Tocar em todas as partes
        for _, part in ipairs(target:GetChildren()) do
            if part:IsA("BasePart") then
                pcall(function()
                    firetouchinterest(weaponHandle, part, 0)
                    firetouchinterest(weaponHandle, part, 1)
                    success = true
                end)
            end
        end
    else
        -- Tocar apenas no HRP
        local hrp = target:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function()
                firetouchinterest(weaponHandle, hrp, 0)
                firetouchinterest(weaponHandle, hrp, 1)
                success = true
            end)
        end
    end
    
    return success
end

-- Função para aplicar dano TakeDamage
local function ApplyTakeDamage(target)
    local humanoid = target:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    
    pcall(function()
        humanoid:TakeDamage(config.damage)
    end)
    
    return true
end

-- Função para aplicar dano com RemoteEvents
local function ApplyRemoteEvents(target)
    local humanoid = target:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    
    -- Procurar RemoteEvents simples
    local rs = game:GetService("ReplicatedStorage")
    local success = false
    
    pcall(function()
        for _, child in pairs(rs:GetDescendants()) do
            if child:IsA("RemoteEvent") and (child.Name:lower():find("damage") or child.Name:lower():find("hit")) then
                child:FireServer(target, config.damage)
                success = true
            end
        end
    end)
    
    return success
end

-- Função para aplicar dano (todas as técnicas)
local function ApplyDamage(target)
    local successCount = 0
    
    -- FireTouch
    if config.useFireTouch then
        if ApplyFireTouch(target) then
            successCount = successCount + 1
        end
    end
    
    -- TakeDamage
    if config.useTakeDamage then
        if ApplyTakeDamage(target) then
            successCount = successCount + 1
        end
    end
    
    -- RemoteEvents (só no modo BRUTO)
    if config.useRemoteEvents and config.attackMode == "BRUTO" then
        if ApplyRemoteEvents(target) then
            successCount = successCount + 1
        end
    end
    
    return successCount > 0
end

-- Detectar ataque do jogador
local function DetectPlayerAttack()
    -- No modo Agressivo ou BRUTO, ataca automaticamente
    if config.attackMode == "Agressivo" or config.attackMode == "BRUTO" then
        return true
    end
    
    -- Modo Normal: precisa de input
    local player = game.Players.LocalPlayer
    local mouse = player:GetMouse()
    if mouse and (tick() - lastMouseClick < 0.3) then
        return true
    end
    
    return false
end

-- Capturar clique
local mouse = game.Players.LocalPlayer:GetMouse()
mouse.Button1Down:Connect(function()
    lastMouseClick = tick()
end)

-- Função principal de ataque (FIXADA COM SISTEMA MULTI-ALVO)
local function PerformAttack()
    if not config.enabled or not currentWeapon or not canAttack then return end
    
    local shouldAttack = DetectPlayerAttack()
    
    if shouldAttack then
        -- Cooldown
        if tick() - lastAttackTime < config.attackCooldown then
            return
        end
        
        canAttack = false
        
        -- Atualizar cache de NPCs
        UpdateNPCCache()
        
        -- Posição de ataque
        local attackPos = GetAttackPosition()
        if not attackPos then
            canAttack = true
            return
        end
        
        -- Atualizar visual
        if config.showVisual then
            if not visualPart then
                CreateVisualPart()
            end
            UpdateVisualPosition()
            
            -- Efeito durante ataque (temporário)
            if visualPart then
                visualPart.Transparency = math.max(savedTransparency - 0.1, 0)
            end
        end
        
        -- Coletar TODOS os NPCs dentro do raio
        local targetsToHit = {}
        
        -- Coletar NPCs
        if config.targetNPCs then
            for _, npcData in pairs(npcCache) do
                local model = npcData.Model
                local hrp = npcData.HRP
                
                if hrp then
                    local distance = (attackPos - hrp.Position).Magnitude
                    
                    if distance <= config.radius then
                        table.insert(targetsToHit, {
                            type = "NPC",
                            model = model,
                            data = npcData,
                            distance = distance
                        })
                    end
                end
            end
        end
        
        -- Coletar jogadores (se configurado)
        if config.targetPlayers then
            for _, playerData in pairs(playerCache) do
                local model = playerData.Model
                local hrp = playerData.HRP
                
                if hrp then
                    local distance = (attackPos - hrp.Position).Magnitude
                    
                    if distance <= config.radius then
                        table.insert(targetsToHit, {
                            type = "Player",
                            model = model,
                            data = playerData,
                            distance = distance
                        })
                    end
                end
            end
        end
        
        -- Ordenar por distância (mais perto primeiro)
        table.sort(targetsToHit, function(a, b)
            return a.distance < b.distance
        end)
        
        -- Limitar pelo máximo de alvos configurado
        if #targetsToHit > config.maxTargets then
            for i = config.maxTargets + 1, #targetsToHit do
                targetsToHit[i] = nil
            end
        end
        
        -- Atacar todos os alvos coletados
        local hitCount = 0
        
        for _, targetInfo in pairs(targetsToHit) do
            local model = targetInfo.model
            
            -- Aplicar dano
            local success = ApplyDamage(model)
            
            if success then
                hitCount = hitCount + 1
                
                -- Efeito visual
                local hrp = targetInfo.data.HRP
                if hrp then
                    local effectColor
                    if targetInfo.type == "NPC" then
                        effectColor = Color3.fromRGB(255, 50, 50)
                    else
                        effectColor = Color3.fromRGB(50, 150, 255)
                    end
                    
                    local hitEffect = Instance.new("Part")
                    hitEffect.Size = Vector3.new(2, 2, 2) * (config.radius / 20)
                    hitEffect.Position = hrp.Position + Vector3.new(0, 3, 0)
                    hitEffect.Color = effectColor
                    hitEffect.Material = Enum.Material.Neon
                    hitEffect.Anchored = true
                    hitEffect.CanCollide = false
                    hitEffect.Transparency = 0.2
                    hitEffect.Parent = workspace
                    game:GetService("Debris"):AddItem(hitEffect, 0.3)
                    
                    -- Efeito adicional para alvos mais distantes
                    if targetInfo.distance > config.radius * 0.7 then
                        local distanceEffect = Instance.new("Part")
                        distanceEffect.Size = Vector3.new(1, 1, 1)
                        distanceEffect.Position = hrp.Position + Vector3.new(0, 5, 0)
                        distanceEffect.Color = Color3.fromRGB(255, 255, 0)
                        distanceEffect.Material = Enum.Material.Neon
                        distanceEffect.Anchored = true
                        distanceEffect.CanCollide = false
                        distanceEffect.Transparency = 0.1
                        distanceEffect.Parent = workspace
                        game:GetService("Debris"):AddItem(distanceEffect, 0.5)
                    end
                end
                
                -- Marcar como target atual (apenas o mais próximo)
                if hitCount == 1 then
                    currentTarget = model
                end
            end
            
            -- Pequeno delay entre ataques para não sobrecarregar
            if hitCount < #targetsToHit then
                task.wait(0.01)  -- 10ms entre cada ataque
            end
        end
        
        -- Atualizar tempo do último ataque
        lastAttackTime = tick()
        
        -- Feedback
        if hitCount > 0 then
            if config.debugMode then
                print("[ATTACK] Acertou", hitCount, "alvos de", #targetsToHit, "disponíveis")
            end
            
            -- Mudar cor temporariamente com base no número de acertos
            if visualPart then
                local originalColor = visualPart.Color
                
                if hitCount >= config.maxTargets then
                    visualPart.Color = Color3.fromRGB(0, 255, 0)  -- Verde (máximo)
                elseif hitCount >= config.maxTargets * 0.5 then
                    visualPart.Color = Color3.fromRGB(255, 255, 0)  -- Amarelo (metade)
                else
                    visualPart.Color = Color3.fromRGB(0, 255, 50)  -- Verde claro (poucos)
                end
                
                task.wait(0.15)
                visualPart.Color = originalColor
            end
            
            -- Notificação se atingiu muitos alvos
            if hitCount >= 5 then
                Library:Notification({
                    Title = "⚔️ MULTI-HIT!",
                    Text = string.format("Acertou %d alvos simultaneamente!", hitCount),
                    Duration = 2,
                    Type = "Success"
                })
            end
        else
            if config.debugMode then
                print("[ATTACK] Nenhum alvo atingido (", #targetsToHit, "dentro do raio)")
            end
        end
        
        -- Cooldown baseado no número de alvos atingidos
        local adjustedCooldown = config.attackCooldown
        if hitCount > 3 then
            adjustedCooldown = adjustedCooldown * 1.2  -- Cooldown maior para muitos hits
        end
        
        task.wait(adjustedCooldown)
        canAttack = true
        
        -- Resetar visual para a transparência configurada
        if visualPart then
            visualPart.Transparency = savedTransparency
        end
    end
end

-- Função para encontrar arma
local function FindCurrentWeapon()
    local player = game.Players.LocalPlayer
    character = player.Character
    if not character then return nil end
    
    -- Procurar Tool
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then
            return child
        end
    end
    
    -- Procurar qualquer coisa com Handle
    for _, child in ipairs(character:GetChildren()) do
        if child:FindFirstChild("Handle") then
            return child
        end
    end
    
    return nil
end

-- Limpeza
local function CleanUpVisuals()
    if visualPart then
        visualPart:Destroy()
        visualPart = nil
    end
    currentTarget = nil
end

-- Sistema principal
local function StartSystem()
    if isRunning then return end
    isRunning = true
    
    game:GetService("RunService").Heartbeat:Connect(function()
        currentWeapon = FindCurrentWeapon()
        
        if config.enabled and currentWeapon then
            PerformAttack()
            
            -- Atualizar posição visual
            if config.showVisual and visualPart then
                UpdateVisualPosition()
            end
        else
            CleanUpVisuals()
        end
    end)
end

local function StopSystem()
    isRunning = false
    CleanUpVisuals()
    currentWeapon = nil
end

-- Gerenciar estado
game:GetService("RunService").Heartbeat:Connect(function()
    if config.enabled and not isRunning then
        StartSystem()
    elseif not config.enabled and isRunning then
        StopSystem()
    end
end)

-- ======================
-- ABA DETECÇÃO NPCs
-- ======================

local SectionDetection = TabDetection:CreateSection("🔍 Configurações de Detecção")

SectionDetection:CreateLabel("=== DETECÇÃO AGRESSIVA ===")
SectionDetection:CreateLabel("Sistema importado do Silent Aim NPC")
SectionDetection:CreateLabel("Detecta TODOS os tipos de NPCs!")

-- Toggle modo agressivo NPCs
local ToggleAggressive = SectionDetection:CreateToggle("DETECÇÃO AGRESSIVA NPCs", function(Value)
    config.aggressiveNPCDetection = Value
    lastCacheUpdate = 0
    UpdateNPCCache()
    
    if Value then
        Library:Notification({
            Title = "🔍 DETECÇÃO AGRESSIVA",
            Text = "Ativada! Detectando TODOS os tipos de NPCs",
            Duration = 3,
            Type = "Warning"
        })
    end
end, true)

SectionDetection:CreateSlider("Intervalo Cache (s)", 0.5, 5, cacheUpdateInterval, function(Value)
    cacheUpdateInterval = Value
end)

SectionDetection:CreateToggle("Debug Mode (Console)", function(Value)
    config.debugMode = Value
end, false)

SectionDetection:CreateButton("🔄 Forçar Atualização de Cache", function()
    lastCacheUpdate = 0
    UpdateNPCCache()
    
    local npcCount = 0
    for _ in pairs(npcCache) do npcCount = npcCount + 1 end
    
    Library:Notification({
        Title = "🔄 Cache Atualizado",
        Text = string.format("NPCs Detectados: %d", npcCount),
        Duration = 3,
        Type = "Info"
    })
end)

SectionDetection:CreateButton("📊 Listar NPCs Detectados", function()
    UpdateNPCCache()
    
    local npcCount = 0
    for _ in pairs(npcCache) do npcCount = npcCount + 1 end
    
    local message = string.format("Total NPCs: %d\n\n", npcCount)
    local count = 0
    
    for npcName, _ in pairs(npcCache) do
        if count < 10 then  -- Limitar a 10 para não floodar
            message = message .. "• " .. npcName .. "\n"
            count = count + 1
        else
            message = message .. "... e mais " .. (npcCount - 10) .. " NPCs"
            break
        end
    end
    
    Library:Notification({
        Title = "📊 NPCs Detectados",
        Text = message,
        Duration = 6,
        Type = "Info"
    })
end)

-- ======================
-- SEÇÃO DE TESTE
-- ======================

local SectionTest = TabMain:CreateSection("🧪 Teste & Debug")

SectionTest:CreateButton("🔍 Testar Detecção de NPCs", function()
    UpdateNPCCache()
    local npcCount = 0
    for _ in pairs(npcCache) do npcCount = npcCount + 1 end
    
    Library:Notification({
        Title = "🔍 Detecção NPCs",
        Text = string.format("Detectados: %d NPCs", npcCount),
        Duration = 4,
        Type = "Info"
    })
    
    if config.debugMode then
        print("[DEBUG] NPCs detectados:")
        for npcName, _ in pairs(npcCache) do
            print("  -", npcName)
        end
    end
end)

SectionTest:CreateButton("🎯 Testar Ataque em NPC Próximo", function()
    if not currentWeapon then
        Library:Notification({
            Title = "❌ Sem arma",
            Text = "Pegue uma arma/espada primeiro!",
            Duration = 3,
            Type = "Error"
        })
        return
    end
    
    UpdateNPCCache()
    local attackPos = GetAttackPosition()
    
    local closestNPC = nil
    local closestDistance = math.huge
    local closestData = nil
    
    for _, npcData in pairs(npcCache) do
        local model = npcData.Model
        local hrp = npcData.HRP
        
        if hrp then
            local distance = (attackPos - hrp.Position).Magnitude
            if distance < closestDistance then
                closestDistance = distance
                closestNPC = model
                closestData = npcData
            end
        end
    end
    
    if closestNPC then
        -- Aplicar dano
        ApplyDamage(closestNPC)
        
        Library:Notification({
            Title = "🎯 Ataque Testado",
            Text = string.format("NPC: %s\nDistância: %.1f studs\nHP: %.0f/%.0f", 
                closestNPC.Name, 
                closestDistance,
                closestData.Humanoid.Health,
                closestData.Humanoid.MaxHealth),
            Duration = 5,
            Type = "Success"
        })
        
        -- Efeito especial
        if closestData.HRP then
            local effect = Instance.new("Part")
            effect.Size = Vector3.new(3, 3, 3) * (config.radius / 20)
            effect.Position = closestData.HRP.Position + Vector3.new(0, 5, 0)
            effect.Color = Color3.fromRGB(255, 255, 0)
            effect.Material = Enum.Material.Neon
            effect.Anchored = true
            effect.CanCollide = false
            effect.Transparency = 0.1
            effect.Parent = workspace
            game:GetService("Debris"):AddItem(effect, 1)
        end
    else
        Library:Notification({
            Title = "⚠️ Nenhum NPC",
            Text = "Nenhum NPC detectado no raio!",
            Duration = 3,
            Type = "Warning"
        })
    end
end)

-- Botão para configurar Modo Agressivo
SectionTest:CreateButton("⚡ Configurar Modo Agressivo", function()
    ModeDropdown:Set("Agressivo")
    ApplyModeSettings("Agressivo")
    
    Library:Notification({
        Title = "⚡ MODO AGRESSIVO",
        Text = "Configurado!\nDetecta e ataca NPCs automaticamente!",
        Duration = 4,
        Type = "Success"
    })
end)

SectionTest:CreateButton("🔥 Ativar Modo BRUTO", function()
    ModeDropdown:Set("BRUTO")
    ApplyModeSettings("BRUTO")
    
    Library:Notification({
        Title = "🔥 MODO BRUTO",
        Text = "Ativado!\nTodas técnicas + Detecção Máxima!",
        Duration = 4,
        Type = "Success"
    })
end)

-- Novo botão para teste multi-alvo avançado
SectionTest:CreateButton("🔫 Teste Multi-Alvo Avançado", function()
    if not currentWeapon then
        Library:Notification({
            Title = "❌ Sem arma",
            Text = "Pegue uma arma/espada primeiro!",
            Duration = 3,
            Type = "Error"
        })
        return
    end
    
    -- Configurar para máximo de alvos
    config.maxTargets = 100
    config.radius = 100  -- Raio máximo
    
    Library:Notification({
        Title = "🔫 MODO MULTI-ALVO MÁXIMO",
        Text = string.format("Raio: %d\nLimite: %d\nAtacando TODOS os NPCs!", 
            config.radius, config.maxTargets),
        Duration = 4,
        Type = "Warning"
    })
    
    -- Realizar ataque imediatamente
    PerformAttack()
    
    -- Reset após 3 segundos
    task.wait(3)
    config.maxTargets = 10
    config.radius = 20
    
    Library:Notification({
        Title = "🔫 MODO NORMAL",
        Text = "Configurações resetadas para padrão",
        Duration = 2,
        Type = "Info"
    })
end)

-- ======================
-- ABA CONFIGURAÇÕES
-- ======================

local SectionConfig = TabConfig:CreateSection("⚙️ Configurações Gerais")

SectionConfig:CreateLabel("=== AJUSTES FINOS ===")

SectionConfig:CreateToggle("Atacar Automaticamente (Agressivo/BRUTO)", function(Value)
    if Value then
        if config.attackMode == "Normal" then
            ModeDropdown:Set("Agressivo")
        end
    end
end, true)

SectionConfig:CreateSlider("Distância Máxima de Detecção", 50, 300, 150, function(Value)
    config.aggressiveSettings.detectionRange = Value
end)

SectionConfig:CreateButton("🔄 Reiniciar Sistema", function()
    StopSystem()
    task.wait(0.5)
    if config.enabled then
        StartSystem()
        Library:Notification({
            Title = "🔄 Sistema Reiniciado",
            Text = "Cache limpo e sistema reiniciado!",
            Duration = 3,
            Type = "Info"
        })
    end
end)

SectionConfig:CreateButton("🧹 Limpar Cache Visual", function()
    CleanUpVisuals()
    Library:Notification({
        Title = "🧹 Cache Limpo",
        Text = "Visual limpo!",
        Duration = 2,
        Type = "Info"
    })
end)

-- ======================
-- INICIALIZAÇÃO
-- ======================

-- Notificação inicial
Library:Notification({
    Title = "⚔️ SWORD MASTER FIX v2.0",
    Text = "DETECÇÃO AGRESSIVA ATIVADA!\nSistema importado do Silent Aim NPC\nMulti-Alvo Ativado!",
    Duration = 6,
    Type = "Success"
})

-- Configurar modo inicial
ApplyModeSettings("Agressivo")

print("========================================")
print("⚔️ Sword Master - DETECÇÃO AGRESSIVA FIX")
print("Versão: 2.0")
print("Sistema de detecção importado do Silent Aim NPC")
print("Modo inicial: Agressivo")
print("Multi-Alvo Ativado (Máx: " .. config.maxTargets .. ")")
print("========================================")

-- Atualizar cache inicial
task.spawn(function()
    task.wait(2)
    lastCacheUpdate = 0
    UpdateNPCCache()
end)