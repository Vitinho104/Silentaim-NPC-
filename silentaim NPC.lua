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
_G.ShowTarget = true -- Mostrar informações do alvo
_G.HitChance = 95 -- Chance de acerto (1-100%)
_G.BulletTeleport = false -- Teleporte de bala para o alvo
_G.ShowTargetName = true -- Mostrar nome do alvo
_G.ShowTargetType = true -- Mostrar tipo (NPC/Player)
_G.ShowTargetHP = true -- Mostrar HP do alvo
_G.ShowTargetDistance = true -- Mostrar distância
_G.ShowHitChance = true -- Mostrar chance de acerto
_G.HighlightTarget = false -- Highlight no alvo
_G.DebugNPCs = false -- Ativar para ver no console quais NPCs estão sendo detectados
_G.AggressiveNPCDetection = false -- Detectar TODOS os modelos não-player como NPCs (MODO AGRESSIVO)

--// SERVIÇOS
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
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

--// INFORMAÇÕES DO ALVO (TEXTO)
local TargetInfo = Drawing.new("Text")
TargetInfo.Visible = false
TargetInfo.Color = Color3.fromRGB(255, 255, 255)
TargetInfo.Size = 18
TargetInfo.Font = 2
TargetInfo.Outline = true
TargetInfo.OutlineColor = Color3.fromRGB(0, 0, 0)
TargetInfo.Text = ""

--// HIGHLIGHT DO ALVO
local TargetHighlight = nil
local HighlightConnection = nil

--// VARIÁVEIS
local CurrentTarget = nil
local TargetPart = nil
local TargetInRange = false
local NPCCache = {}
local PlayerCache = {}
local LastCacheUpdate = 0
local CacheUpdateInterval = 2

--// VARIÁVEIS PARA HOOKS (não limpar)
local oldNamecall = nil
local oldIndex = nil

--// FUNÇÃO: CRIAR HIGHLIGHT
local function CreateHighlight(target)
    if not target or not target:IsA("Model") then return nil end
    
    -- Remover highlight antigo
    if TargetHighlight then
        TargetHighlight:Destroy()
        TargetHighlight = nil
    end
    
    if HighlightConnection then
        HighlightConnection:Disconnect()
        HighlightConnection = nil
    end
    
    -- Criar novo highlight
    local highlight = Instance.new("Highlight")
    highlight.Name = "SilentAimHighlight"
    highlight.Adornee = target
    highlight.FillColor = Color3.fromRGB(255, 50, 50)
    highlight.FillTransparency = 0.7
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = game:GetService("CoreGui")
    
    -- Conectar para remover quando o target for destruído
    HighlightConnection = target.Destroying:Connect(function()
        if highlight then
            highlight:Destroy()
            TargetHighlight = nil
        end
    end)
    
    return highlight
end

--// FUNÇÃO: ATUALIZAR HIGHLIGHT
local function UpdateHighlight()
    if not _G.HighlightTarget then
        if TargetHighlight then
            TargetHighlight:Destroy()
            TargetHighlight = nil
        end
        if HighlightConnection then
            HighlightConnection:Disconnect()
            HighlightConnection = nil
        end
        return
    end
    
    if CurrentTarget then
        if not TargetHighlight or TargetHighlight.Adornee ~= CurrentTarget then
            TargetHighlight = CreateHighlight(CurrentTarget)
        end
        
        if TargetHighlight then
            -- Atualizar cores baseado no tipo de alvo
            local isPlayer = false
            for _, data in pairs(PlayerCache) do
                if data.Model == CurrentTarget then
                    isPlayer = true
                    break
                end
            end
            
            if isPlayer then
                TargetHighlight.FillColor = Color3.fromRGB(50, 150, 255)  -- Azul para players
            else
                TargetHighlight.FillColor = Color3.fromRGB(255, 50, 50)   -- Vermelho para NPCs
            end
            
            -- Pulsar quando houver hit chance alta
            if _G.HitChance >= 80 then
                local pulse = math.sin(tick() * 3) * 0.2 + 0.8
                TargetHighlight.FillTransparency = 0.7 + (0.2 * (1 - pulse))
            else
                TargetHighlight.FillTransparency = 0.7
            end
        end
    else
        if TargetHighlight then
            TargetHighlight:Destroy()
            TargetHighlight = nil
        end
        if HighlightConnection then
            HighlightConnection:Disconnect()
            HighlightConnection = nil
        end
    end
end

--// FUNÇÃO DE LIMPEZA DA UI APENAS
local function CleanupUIOnly()
    -- Limpar círculo FOV
    if Circle then 
        Circle.Visible = false
    end
    
    -- Limpar texto do alvo
    if TargetInfo then
        TargetInfo.Visible = false
        TargetInfo.Text = ""  -- Garantir que o texto seja limpo
    end
    
    -- Limpar highlight
    if TargetHighlight then
        TargetHighlight:Destroy()
        TargetHighlight = nil
    end
    
    if HighlightConnection then
        HighlightConnection:Disconnect()
        HighlightConnection = nil
    end
    
    CurrentTarget = nil
    TargetPart = nil
    TargetInRange = false
    NPCCache = {}
    PlayerCache = {}
end

--// LISTA DE TAGS DE NPCs EXPANDIDA (MELHORADA)
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

--// FUNÇÃO DE DEBUG PARA NPCs
local function DebugNPCDetection(character, reason)
    if not _G.DebugNPCs then return end
    
    print("[NPC DEBUG] Detectado:", character.Name)
    print("  Razão:", reason)
    print("  Localização:", character:GetFullName())
    
    -- Mostrar componentes importantes
    for _, child in pairs(character:GetChildren()) do
        if child:IsA("StringValue") or child:IsA("BoolValue") or child:IsA("IntValue") then
            print("  Valor:", child.Name, "=", child.Value)
        end
    end
end

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

--// FUNÇÃO: É NPC? (MELHORADA PARA DETECTAR TODOS OS TIPOS)
local function IsNPC(character)
    if not character or not character:IsA("Model") then
        return false
    end
    
    -- Ignorar se for player
    if IsPlayer(character) then
        return false
    end
    
    -- Verificar componentes básicos
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local head = character:FindFirstChild("Head")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not head or not hrp or humanoid.Health <= 0 then
        return false
    end
    
    -- MODO AGRESSIVO: Qualquer modelo com humanoid é NPC
    if _G.AggressiveNPCDetection then
        DebugNPCDetection(character, "Modo Agressivo - Estrutura de Humanoid")
        return true
    end
    
    local charName = character.Name:lower()
    
    -- MÉTODO 1: Verificar por tags no nome
    for _, tag in pairs(NPCTags) do
        if charName:find(tag:lower(), 1, true) then
            DebugNPCDetection(character, "Tag no nome: " .. tag)
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
        if folder and character:IsDescendantOf(folder) then
            DebugNPCDetection(character, "Na pasta: " .. folderName)
            return true
        end
    end
    
    -- MÉTODO 3: Verificar por valores/customizações específicas
    local possibleNPCIndicators = {
        "NPC", "IsNPC", "IsEnemy", "Hostile", "Enemy", 
        "IsBot", "IsMob", "IsMonster", "Team", "Faction"
    }
    
    for _, indicator in pairs(possibleNPCIndicators) do
        local value = character:FindFirstChild(indicator)
        if value then
            if value:IsA("BoolValue") then
                if indicator == "NPC" or indicator == "IsNPC" or 
                   indicator == "IsEnemy" or indicator == "Hostile" then
                    if value.Value == true then
                        DebugNPCDetection(character, "BoolValue: " .. indicator .. " = true")
                        return true
                    end
                end
            elseif value:IsA("StringValue") then
                local valLower = value.Value:lower()
                if valLower == "enemy" or valLower == "hostile" or 
                   valLower == "npc" or valLower == "bot" or
                   valLower == "monster" or valLower == "mob" then
                    DebugNPCDetection(character, "StringValue: " .. indicator .. " = " .. value.Value)
                    return true
                end
            elseif value:IsA("IntValue") then
                if indicator == "Team" then
                    -- Se tem um valor de time, pode ser NPC
                    DebugNPCDetection(character, "Team Value: " .. value.Value)
                    return true
                end
            end
        end
    end
    
    -- MÉTODO 4: Análise de estrutura do modelo
    -- Verificar se tem scripts de IA/Comportamento
    local hasAIBehavior = false
    for _, child in pairs(character:GetChildren()) do
        local childName = child.Name:lower()
        if child:IsA("Script") or child:IsA("LocalScript") then
            if childName:find("ai") or childName:find("behavior") or 
               childName:find("path") or childName:find("attack") or
               childName:find("patrol") or childName:find("combat") then
                hasAIBehavior = true
                break
            end
        end
    end
    
    -- MÉTODO 5: Verificar por configurações específicas
    local config = character:FindFirstChild("Configuration")
    if config then
        local npcType = config:FindFirstChild("Type") or config:FindFirstChild("NPCType")
        if npcType then
            local typeValue = tostring(npcType.Value):lower()
            if typeValue:find("npc") or typeValue:find("enemy") or
               typeValue:find("bot") or typeValue:find("monster") then
                DebugNPCDetection(character, "Configuration Type: " .. npcType.Value)
                return true
            end
        end
    end
    
    -- MÉTODO 6: Verificar tags de CollectionService (Roblox)
    local tags = CollectionService:GetTags(character)
    
    for _, tag in pairs(tags) do
        local tagLower = tag:lower()
        for _, npcTag in pairs(NPCTags) do
            if tagLower:find(npcTag:lower(), 1, true) then
                DebugNPCDetection(character, "CollectionService Tag: " .. tag)
                return true
            end
        end
    end
    
    -- MÉTODO 7: Heurística avançada - Personagens com comportamentos específicos
    -- Verificar se tem habilidades de NPC
    local npcAbilities = {
        "Attack", "Damage", "Aggro", "Patrol", "Spawn", "Respawn",
        "AI", "BehaviorTree", "StateMachine", "Combat", "Chase"
    }
    
    for _, ability in pairs(npcAbilities) do
        if character:FindFirstChild(ability) or character:FindFirstChild(ability .. "Script") then
            hasAIBehavior = true
            DebugNPCDetection(character, "Habilidade de NPC: " .. ability)
            break
        end
    end
    
    -- MÉTODO 8: Verificar animações específicas de NPC
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then
        for _, animTrack in pairs(animator:GetPlayingAnimationTracks()) do
            local animName = animTrack.Name:lower()
            if animName:find("idle") or animName:find("walk") or 
               animName:find("attack") or animName:find("death") then
                -- Animações genéricas podem indicar NPC
                hasAIBehavior = true
                DebugNPCDetection(character, "Animação de NPC: " .. animName)
                break
            end
        end
    end
    
    -- MÉTODO 9: Análise de movimento (se estiver se movendo de forma não natural para player)
    if hrp.Velocity.Magnitude > 0 then
        local movementPattern = hrp.Velocity
        -- NPCs geralmente têm movimentos mais simples/retilíneos
        if math.abs(movementPattern.X) > 10 or math.abs(movementPattern.Z) > 10 then
            if math.abs(movementPattern.Y) < 2 then -- Provavelmente não pulando
                hasAIBehavior = true
                DebugNPCDetection(character, "Padrão de movimento de NPC")
            end
        end
    end
    
    -- Se tem estrutura de humanoide, não é player, e tem indicações de IA,
    -- provavelmente é um NPC
    if hasAIBehavior then
        DebugNPCDetection(character, "Comportamento de IA detectado")
        return true
    end
    
    -- MÉTODO 10: Verificar se tem partes específicas de NPC
    local npcParts = {"HealthBar", "NameTag", "DamageNumber", "XP", "Level"}
    for _, partName in pairs(npcParts) do
        if character:FindFirstChild(partName) then
            DebugNPCDetection(character, "Parte de NPC: " .. partName)
            return true
        end
    end
    
    -- MÉTODO 11: Verificar pelo prefixo/sufixo no nome
    local namePatterns = {"^npc_", "^enemy_", "^bot_", "^mob_", "_npc$", "_enemy$", "_bot$"}
    for _, pattern in pairs(namePatterns) do
        if string.match(charName, pattern) then
            DebugNPCDetection(character, "Padrão no nome: " .. pattern)
            return true
        end
    end
    
    -- Último recurso: Se tem estrutura de humanoide mas não é player,
    -- assumir que é NPC (mais abrangente)
    DebugNPCDetection(character, "Estrutura de humanoid não-player")
    return true
end

--// FUNÇÃO: BUSCAR NPCs EM TODAS AS PASTAS (RECURSIVO)
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
    
    -- Verificar IntValue para team
    if npcTeamValue and npcTeamValue:IsA("IntValue") then
        local npcTeam = npcTeamValue.Value
        local localTeam = LocalPlayer.Team and LocalPlayer.Team.TeamColor and LocalPlayer.Team.TeamColor.Team or 0
        
        if npcTeam ~= localTeam then
            return true
        end
    end
    
    -- Verificar por BoolValue de inimigo
    local isEnemy = npcModel:FindFirstChild("IsEnemy")
    if isEnemy and isEnemy:IsA("BoolValue") and isEnemy.Value == true then
        return true
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

--// FUNÇÃO: ATUALIZAR CACHES (MELHORADA PARA DETECTAR TODOS OS NPCs)
local function UpdateCaches()
    local currentTime = tick()
    
    if currentTime - LastCacheUpdate < CacheUpdateInterval then
        return
    end
    
    LastCacheUpdate = currentTime
    
    NPCCache = {}
    PlayerCache = {}
    
    -- Buscar NPCs recursivamente no workspace
    local allModels = {}
    
    -- Método 1: Modelos diretos no workspace
    for _, model in pairs(workspace:GetChildren()) do
        if model:IsA("Model") and model ~= LocalPlayer.Character then
            table.insert(allModels, model)
        end
    end
    
    -- Método 2: Buscar em pastas específicas (recursivo)
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
    
    -- Método 3: Buscar em TODAS as pastas do workspace (mais abrangente)
    if _G.AggressiveNPCDetection then
        local allNPCs = FindNPCsInWorkspaceRecursive(workspace)
        for _, npc in pairs(allNPCs) do
            if npc ~= LocalPlayer.Character then
                table.insert(allModels, npc)
            end
        end
    end
    
    -- Processar todos os modelos encontrados
    for _, model in pairs(allModels) do
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
    
    -- Adicionar players manualmente (garantir que não perca nenhum)
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
    
    -- Remover duplicatas
    local seen = {}
    local newNPCCache = {}
    for model, data in pairs(NPCCache) do
        if not seen[model] then
            seen[model] = true
            newNPCCache[model] = data
        end
    end
    NPCCache = newNPCCache
    
    -- Debug: Mostrar quantidade de NPCs encontrados
    if _G.DebugNPCs then
        local npcCount = 0
        for _ in pairs(NPCCache) do
            npcCount = npcCount + 1
        end
        print("[NPC CACHE] NPCs encontrados:", npcCount)
        print("[NPC CACHE] Players encontrados:", #Players:GetPlayers() - 1)
        
        -- Listar NPCs detectados
        for model, data in pairs(NPCCache) do
            print("  NPC:", model.Name, "HP:", data.Humanoid.Health)
        end
    end
end

--// FUNÇÃO: BUSCAR TARGET (CORRIGIDA - WALL CHECK)
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
                
                -- ALVO DENTRO DO FOV
                if dist <= _G.FOV then
                    local isVisible = true
                    
                    -- WALL CHECK CORRIGIDO
                    if _G.VisibleCheck then
                        local raycastParams = RaycastParams.new()
                        raycastParams.FilterDescendantsInstances = {localChar, Camera}
                        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                        raycastParams.IgnoreWater = true
                        
                        local origin = Camera.CFrame.Position
                        local direction = (targetPos - origin).Unit * (targetPos - origin).Magnitude
                        local ray = workspace:Raycast(origin, direction, raycastParams)
                        
                        -- Se houver um raycast hit E não for parte do alvo
                        if ray then
                            local hitPart = ray.Instance
                            local isTargetPart = hitPart:IsDescendantOf(data.Model)
                            
                            if not isTargetPart then
                                isVisible = false
                            end
                        end
                    end
                    
                    -- CORREÇÃO: TargetInRange deve ser true se o alvo está no FOV
                    -- independente do wall check
                    TargetInRange = true
                    
                    -- Só considerar para mira se estiver visível OU se wall check estiver desativado
                    if isVisible or not _G.VisibleCheck then
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

--// FUNÇÃO: VERIFICAR SE DEVE ACERTAR (HIT CHANCE CORRETO)
local function ShouldHit()
    if _G.HitChance >= 100 then
        return true
    end
    
    if _G.HitChance <= 0 then
        return false
    end
    
    -- Gerar número aleatório de 1 a 100
    local randomNumber = math.random(1, 100)
    
    -- Se o número aleatório for menor ou igual à chance configurada, acerta
    return randomNumber <= _G.HitChance
end

--// FUNÇÃO: CALCULAR CHANCE DE ACERTO DISPLAY
local function CalculateHitChanceDisplay()
    if not CurrentTarget or not TargetPart then
        return 0
    end
    
    -- Base do HitChance configurado
    local baseChance = _G.HitChance
    
    -- Fatores que afetam a chance (apenas para display)
    local distanceFactor = 1.0
    local fovFactor = 1.0
    
    -- Fator de distância (quanto mais perto, maior a chance)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local localPos = LocalPlayer.Character.HumanoidRootPart.Position
        local targetPos = TargetPart.Position
        local distance = (targetPos - localPos).Magnitude
        
        if distance < 50 then
            distanceFactor = 1.1  -- +10% para perto
        elseif distance > 200 then
            distanceFactor = 0.8  -- -20% para longe
        end
    end
    
    -- Fator de FOV (quanto menor o FOV, maior a precisão)
    if _G.FOV < 100 then
        fovFactor = 1.15  -- +15% para FOV pequeno
    elseif _G.FOV > 250 then
        fovFactor = 0.9   -- -10% para FOV grande
    end
    
    -- Calcular chance final para display
    local finalChance = baseChance * distanceFactor * fovFactor
    
    -- Aplicar randomização (5% de variação) apenas para display
    local randomVariation = math.random(-5, 5)
    finalChance = math.clamp(finalChance + randomVariation, 1, 100)
    
    return math.floor(finalChance)
end

--// FUNÇÃO: MOSTRAR INFORMAÇÕES DO ALVO (CORRIGIDA COM SHOWHITCHANCE - BUG FIXED)
local function UpdateTargetInfo()
    if not _G.ShowTarget or not TargetInfo then
        TargetInfo.Visible = false
        TargetInfo.Text = ""  -- Limpar texto
        return
    end
    
    -- Se o SilentAim estiver desativado, não mostrar informações
    if not _G.SilentAim then
        TargetInfo.Visible = false
        TargetInfo.Text = ""  -- Limpar texto
        return
    end
    
    -- Se ShowHitChance estiver desativado E HitChance for 0, não mostrar chance
    local shouldShowHitChance = _G.ShowHitChance and _G.HitChance > 0
    
    if CurrentTarget and TargetPart then
        local screenPos, onScreen = Camera:WorldToViewportPoint(TargetPart.Position)
        
        if onScreen then
            TargetInfo.Visible = true
            TargetInfo.Position = Vector2.new(screenPos.X, screenPos.Y + 20)
            
            -- Construir texto dinamicamente baseado nas configurações
            local infoLines = {}
            
            -- Nome do alvo
            if _G.ShowTargetName then
                local targetName = CurrentTarget.Name
                local targetType = "NPC"
                
                -- Verificar se é player
                for _, data in pairs(PlayerCache) do
                    if data.Model == CurrentTarget then
                        targetType = "Player"
                        targetName = data.Player.Name
                        break
                    end
                end
                
                if _G.ShowTargetType then
                    table.insert(infoLines, string.format("[%s] %s", targetType, targetName))
                else
                    table.insert(infoLines, targetName)
                end
            end
            
            -- HP do alvo
            if _G.ShowTargetHP then
                local humanoid = CurrentTarget:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    local health = string.format("%.0f", humanoid.Health)
                    local maxHealth = string.format("%.0f", humanoid.MaxHealth)
                    table.insert(infoLines, string.format("HP: %s/%s", health, maxHealth))
                end
            end
            
            -- Distância
            if _G.ShowTargetDistance then
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local localPos = LocalPlayer.Character.HumanoidRootPart.Position
                    local targetPos = TargetPart.Position
                    local distance = string.format("%.1f", (targetPos - localPos).Magnitude)
                    table.insert(infoLines, string.format("Dist: %s studs", distance))
                end
            end
            
            -- Chance de acerto (APENAS SE A CONFIGURAÇÃO ESTIVER ATIVA E HitChance > 0)
            if shouldShowHitChance then
                local displayChance = CalculateHitChanceDisplay()
                table.insert(infoLines, string.format("Chance: %d%%", displayChance))
            end
            
            -- Juntar todas as linhas
            if #infoLines > 0 then
                TargetInfo.Text = table.concat(infoLines, "\n")
            else
                TargetInfo.Text = "Alvo travado"
            end
        else
            TargetInfo.Visible = false
            TargetInfo.Text = ""  -- Limpar texto
        end
    else
        TargetInfo.Visible = false
        TargetInfo.Text = ""  -- Limpar texto
    end
end

--// TELEPORTAR BALLET PARA O ALVO MELHORADO COM HIT CHANCE
local function TeleportBulletToTargetImproved(origin, direction, bulletName)
    if not _G.BulletTeleport or not TargetPart or not CurrentTarget then
        return origin, direction
    end
    
    -- Verificar se é realmente uma bala (baseado no nome)
    local bulletNames = {"bullet", "ammo", "shot", "projectile", "missile", "rocket", "hit", "damage", "fire", "shoot"}
    local isBullet = false
    
    for _, name in pairs(bulletNames) do
        if string.find(bulletName:lower(), name) then
            isBullet = true
            break
        end
    end
    
    if not isBullet then
        return origin, direction
    end
    
    -- Verificar Hit Chance ANTES de teleportar
    if not ShouldHit() then
        return origin, direction  -- Não teleportar, bala segue direção normal
    end
    
    -- Calcular nova direção para o alvo
    local targetPosition = TargetPart.Position
    
    -- Aplicar predição se estiver habilitada
    if _G.Prediction > 0 and TargetPart.Parent:FindFirstChild("HumanoidRootPart") then
        local hrp = TargetPart.Parent:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.Velocity.Magnitude > 1 then
            targetPosition = targetPosition + (hrp.Velocity * _G.Prediction)
        end
    end
    
    -- Adicionar pequeno offset aleatório para parecer mais natural
    local randomOffset = Vector3.new(
        (math.random() - 0.5) * 0.5,
        (math.random() - 0.5) * 0.3,
        (math.random() - 0.5) * 0.5
    )
    
    targetPosition = targetPosition + randomOffset
    
    -- Calcular direção para o alvo
    local newDirection = (targetPosition - origin).Unit * direction.Magnitude
    
    -- Retornar origem e nova direção
    return origin, newDirection
end

--// HOOKS ATUALIZADOS COM HIT CHANCE CORRETO
if not oldNamecall then
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if not _G.SilentAim or not TargetPart or not CurrentTarget then
            return oldNamecall(self, ...)
        end
        
        local method = getnamecallmethod()
        local args = {...}
        
        -- TELEPORTE DE BALA MELHORADO COM HIT CHANCE
        if _G.BulletTeleport and (method == "FireServer" or method == "InvokeServer") and typeof(self) == "Instance" then
            local selfName = self.Name:lower()
            
            -- Verificar se é uma função relacionada a tiros/balas
            local bulletFunctions = {"fire", "shoot", "bullet", "ammo", "projectile", "missile", "rocket", "hit", "damage"}
            local isBulletFunction = false
            
            for _, funcName in pairs(bulletFunctions) do
                if string.find(selfName, funcName) then
                    isBulletFunction = true
                    break
                end
            end
            
            -- Verificar se é uma RemoteEvent/RemoteFunction de dano
            if not isBulletFunction then
                local className = self.ClassName
                if className == "RemoteEvent" or className == "RemoteFunction" then
                    -- Verificar pelos argumentos
                    for _, arg in pairs(args) do
                        if type(arg) == "table" then
                            for _, value in pairs(arg) do
                                if tostring(value):find("bullet") or tostring(value):find("damage") or tostring(value):find("hit") then
                                    isBulletFunction = true
                                    break
                                end
                            end
                        end
                    end
                end
            end
            
            if isBulletFunction then
                -- Procurar argumentos de posição/direção
                local foundOrigin, foundDirection = nil, nil
                local originIndex, directionIndex = nil, nil
                
                -- Buscar origem e direção nos argumentos
                for i, arg in pairs(args) do
                    if typeof(arg) == "Vector3" then
                        -- Provavelmente é uma posição de origem
                        if not foundOrigin then
                            foundOrigin = arg
                            originIndex = i
                        elseif not foundDirection then
                            foundDirection = arg
                            directionIndex = i
                        end
                    elseif typeof(arg) == "Ray" then
                        -- Teleportar raio da bala
                        foundOrigin = arg.Origin
                        foundDirection = arg.Direction
                        originIndex = i
                        directionIndex = i
                        break
                    elseif type(arg) == "table" then
                        -- Verificar dentro de tabelas
                        for key, value in pairs(arg) do
                            if typeof(value) == "Vector3" then
                                if tostring(key):lower():find("origin") or tostring(key):lower():find("from") then
                                    foundOrigin = value
                                elseif tostring(key):lower():find("direction") or tostring(key):lower():find("to") then
                                    foundDirection = value
                                end
                            end
                        end
                    end
                end
                
                -- Se encontrou origem e direção, teleportar bala
                if foundOrigin and foundDirection then
                    local newOrigin, newDirection = TeleportBulletToTargetImproved(foundOrigin, foundDirection, selfName)
                    
                    local newArgs = {}
                    for i, oldArg in pairs(args) do
                        if i == originIndex and typeof(oldArg) == "Vector3" then
                            newArgs[i] = newOrigin
                        elseif i == directionIndex and typeof(oldArg) == "Vector3" then
                            newArgs[i] = newDirection
                        elseif i == originIndex and typeof(oldArg) == "Ray" then
                            newArgs[i] = Ray.new(newOrigin, newDirection)
                        else
                            newArgs[i] = oldArg
                        end
                    end
                    
                    return oldNamecall(self, unpack(newArgs))
                end
            end
        end
        
        -- HOOK ORIGINAL COM HIT CHANCE CORRETO
        if (method == "FireServer" or method == "InvokeServer") and typeof(self) == "Instance" then
            local selfName = self.Name:lower()
            if string.find(selfName, "fire") or string.find(selfName, "hit") or string.find(selfName, "attack") or string.find(selfName, "damage") then
                -- Verificar Hit Chance ANTES de modificar
                if not ShouldHit() then
                    return oldNamecall(self, ...)  -- Retornar normal se não passar no hit chance
                end
                
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
                -- Verificar Hit Chance ANTES de modificar
                if not ShouldHit() then
                    return oldNamecall(self, ...)  -- Retornar normal se não passar no hit chance
                end
                
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
                -- Verificar Hit Chance ANTES de modificar
                if not ShouldHit() then
                    return oldIndex(self, key)  -- Retornar normal se não passar no hit chance
                end
                return CFrame.new(TargetPart.Position)
            elseif keyLower == "target" then
                return TargetPart
            end
        end
        return oldIndex(self, key)
    end)
end

--// ATUALIZAR CÍRCULO, INFORMAÇÕES E HIGHLIGHT (COM BUG FIXED)
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
        else
            if TargetInRange then
                Circle.Color = Color3.fromRGB(255, 255, 0)  -- Amarelo: alvo no FOV mas não travado
            else
                Circle.Color = Color3.fromRGB(255, 50, 0)   -- Vermelho: nenhum alvo no FOV
            end
        end
    else
        Circle.Visible = false
    end
    
    -- Atualizar informações do alvo (CORREÇÃO DO BUG DO HIT CHANCE)
    UpdateTargetInfo()
    
    -- Atualizar highlight
    UpdateHighlight()
end)

--// ==================================================
--// MANO GUSTAVO UI LIBRARY MENU IMPLEMENTATION
--// ==================================================

--// Carregar a Library
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Mano-Gustavo/Mano-Gustavo-Library/refs/heads/main/library.lua"
))()

--// Criar a Janela Principal
local Window = Library:CreateWindow({
    Title = "🎯 Silent Aim v2.9",
    Author = "Silent Aim NPC",
    Keybind = Enum.KeyCode.RightControl
})

--// Criar Abas
local TabMain = Window:CreateTab("Principal")
local TabConfig = Window:CreateTab("Configurações")
local TabAim = Window:CreateTab("Mira")
local TabTeam = Window:CreateTab("Time")
local TabExtra = Window:CreateTab("Extra")
local TabNPC = Window:CreateTab("NPC")
local TabInfo = Window:CreateTab("Informações")

--// ABA PRINCIPAL
TabMain:CreateLabel("=== Controle Principal ===")

-- Botão de Toggle
TabMain:CreateToggle("Silent Aim", function(Value)
    _G.SilentAim = Value
    if Value then
        LastCacheUpdate = 0
        UpdateCaches()
        Library:Notification({
            Title = "🎯 SILENT AIM",
            Text = "ATIVADO",
            Duration = 1.5,
            Type = "Success"
        })
    else
        -- Limpar highlight quando desativado
        if TargetHighlight then
            TargetHighlight:Destroy()
            TargetHighlight = nil
        end
        Library:Notification({
            Title = "🎯 SILENT AIM",
            Text = "DESATIVADO",
            Duration = 1.5,
            Type = "Error"
        })
    end
end, false)

-- Slider de FOV
TabMain:CreateSlider("FOV", 50, 300, 150, function(Value)
    _G.FOV = math.floor(Value)
    Circle.Radius = _G.FOV
end)

-- Slider de Predição
TabMain:CreateSlider("Predição", 0, 0.5, 0.165, function(Value)
    _G.Prediction = tonumber(string.format("%.3f", Value))
end)

-- Slider de Hit Chance
TabMain:CreateSlider("Hit Chance", 0, 100, 95, function(Value)
    _G.HitChance = math.floor(Value)
end)

-- Slider de Update Rate
TabMain:CreateSlider("Taxa de Atualização", 0.05, 0.5, 0.2, function(Value)
    _G.UpdateRate = tonumber(string.format("%.2f", Value))
end)

--// ABA CONFIGURAÇÕES
TabConfig:CreateLabel("=== Configurações Gerais ===")

-- Dropdown de Modo de Alvo
TabConfig:CreateDropdown("Modo de Alvo", {"NPCs", "Players", "Both"}, function(Value)
    _G.TargetMode = Value
end)

-- Dropdown de Parte para Mirar
TabConfig:CreateDropdown("Parte do Corpo", {"Head", "Torso", "Both", "Random"}, function(Value)
    _G.AimPart = Value
end)

-- Toggle de Wall Check
TabConfig:CreateToggle("Wall Check", function(Value)
    _G.VisibleCheck = Value
end, true)

-- Toggle de Bullet Teleport
TabConfig:CreateToggle("Bullet Teleport", function(Value)
    _G.BulletTeleport = Value
end, false)

-- Toggle de Show Target
TabConfig:CreateToggle("Mostrar Alvo", function(Value)
    _G.ShowTarget = Value
    if not Value and TargetInfo then
        TargetInfo.Visible = false
        TargetInfo.Text = ""
    end
end, true)

--// ABA MIRA
TabAim:CreateLabel("=== Configurações de Mira ===")

-- Informações sobre partes do corpo
TabAim:CreateLabel("Cabeça: Dano crítico")
TabAim:CreateLabel("Torso: Dano médio")
TabAim:CreateLabel("Ambos: Alterna entre ambos")
TabAim:CreateLabel("Aleatório: Partes aleatórias")

-- Color Picker para Círculo FOV
TabAim:CreateColorPicker("Cor do Círculo FOV", Color3.fromRGB(0, 255, 0), function(Color)
    Circle.Color = Color
end)

--// ABA TIME
TabTeam:CreateLabel("=== Configurações de Time ===")

-- Toggle de Team Check para Players
TabTeam:CreateToggle("Team Check (Players)", function(Value)
    _G.TeamCheck = Value
end, true)

-- Toggle de Team Check para NPCs
TabTeam:CreateToggle("Team Check (NPCs)", function(Value)
    _G.TeamCheckForNPCs = Value
end, false)

-- Informações sobre Team Check
TabTeam:CreateLabel("Team Check NPCs: Verifica StringValue 'Team' no NPC.")
TabTeam:CreateLabel("Team Check Players: Verifica time do jogador.")

--// ABA EXTRA
TabExtra:CreateLabel("=== Configurações Extras ===")

-- Toggle de Highlight
TabExtra:CreateToggle("Highlight no Alvo", function(Value)
    _G.HighlightTarget = Value
    if not Value and TargetHighlight then
        TargetHighlight:Destroy()
        TargetHighlight = nil
    end
end, false)

-- Color Picker para Highlight
TabExtra:CreateColorPicker("Cor do Highlight NPC", Color3.fromRGB(255, 50, 50), function(Color)
    -- A cor será aplicada na função UpdateHighlight
end)

TabExtra:CreateColorPicker("Cor do Highlight Player", Color3.fromRGB(50, 150, 255), function(Color)
    -- A cor será aplicada na função UpdateHighlight
end)

-- TextBox para Cache Update Interval
TabExtra:CreateTextBox("Intervalo de Cache (segundos)", "2", function(Text)
    local num = tonumber(Text)
    if num and num > 0 then
        CacheUpdateInterval = num
    end
end)

--// ABA NPC
TabNPC:CreateLabel("=== Configurações de NPC ===")

-- Toggle de Modo Agressivo
TabNPC:CreateToggle("Modo Agressivo", function(Value)
    _G.AggressiveNPCDetection = Value
    LastCacheUpdate = 0
    UpdateCaches()
    
    if Value then
        Library:Notification({
            Title = "⚠️ MODO AGRESSIVO",
            Text = "ATIVADO - Detectando TODOS como NPCs",
            Duration = 2,
            Type = "Warning"
        })
    end
end, false)

-- Toggle de Debug NPCs
TabNPC:CreateToggle("Debug NPCs", function(Value)
    _G.DebugNPCs = Value
    if Value then
        print("[DEBUG NPCs] Ativado - Ver console para detalhes")
    else
        print("[DEBUG NPCs] Desativado")
    end
end, false)

-- Botão para Forçar Atualização de Cache
TabNPC:CreateButton("Forçar Atualização de Cache", function()
    LastCacheUpdate = 0
    UpdateCaches()
    Library:Notification({
        Title = "🔄 CACHE",
        Text = "Cache atualizado com sucesso!",
        Duration = 1.5,
        Type = "Info"
    })
end)

-- Botão para Listar NPCs Detectados
TabNPC:CreateButton("Listar NPCs Detectados", function()
    local npcCount = 0
    for _ in pairs(NPCCache) do
        npcCount = npcCount + 1
    end
    
    local playerCount = 0
    for _ in pairs(PlayerCache) do
        playerCount = playerCount + 1
    end
    
    print("[DETECÇÃO] NPCs:", npcCount)
    print("[DETECÇÃO] Players:", playerCount)
    
    Library:Notification({
        Title = "📊 DETECÇÃO",
        Text = string.format("NPCs: %d | Players: %d", npcCount, playerCount),
        Duration = 2,
        Type = "Info"
    })
end)

--// ABA INFORMAÇÕES
TabInfo:CreateLabel("=== Controles de Informações ===")

-- Toggles individuais para informações do alvo
TabInfo:CreateToggle("Mostrar Nome/Tipo", function(Value)
    _G.ShowTargetName = Value
    if _G.SilentAim and CurrentTarget then
        UpdateTargetInfo()
    end
end, true)

TabInfo:CreateToggle("Mostrar HP", function(Value)
    _G.ShowTargetHP = Value
    if _G.SilentAim and CurrentTarget then
        UpdateTargetInfo()
    end
end, true)

TabInfo:CreateToggle("Mostrar Distância", function(Value)
    _G.ShowTargetDistance = Value
    if _G.SilentAim and CurrentTarget then
        UpdateTargetInfo()
    end
end, true)

TabInfo:CreateToggle("Mostrar Chance de Acerto", function(Value)
    _G.ShowHitChance = Value
    if _G.SilentAim and CurrentTarget then
        UpdateTargetInfo()
    end
end, true)

-- Informações do Script
TabInfo:CreateLabel("=== Informações do Script ===")
TabInfo:CreateLabel("Versão: 2.9")
TabInfo:CreateLabel("Feito com Mano Gustavo UI Library")
TabInfo:CreateLabel("NPC Detection System v2.0")

-- Botão de Status
TabInfo:CreateButton("Ver Status", function()
    local statusText = string.format(
        "Silent Aim: %s\nFOV: %d\nTarget Mode: %s\nAlvo Atual: %s\nCache NPCs: %d\nCache Players: %d",
        _G.SilentAim and "ON" or "OFF",
        _G.FOV,
        _G.TargetMode,
        CurrentTarget and CurrentTarget.Name or "Nenhum",
        #NPCCache,
        #PlayerCache
    )
    
    Library:Notification({
        Title = "📊 STATUS",
        Text = statusText,
        Duration = 3,
        Type = "Info"
    })
end)

-- Botão de Limpar UI
TabInfo:CreateButton("Limpar UI", function()
    CleanupUIOnly()
    Library:Notification({
        Title = "🧹 LIMPEZA",
        Text = "UI limpa com sucesso!",
        Duration = 1.5,
        Type = "Success"
    })
end)

--// INICIALIZAÇÃO
task.wait(0.5)
CleanupUIOnly()

--// NOTIFICAÇÃO INICIAL
task.spawn(function()
    task.wait(1)
    
    Library:Notification({
        Title = "🎯 SILENT AIM v2.9",
        Text = "Menu atualizado com Mano Gustavo UI Library!\nNova aba 'NPC' adicionada.",
        Duration = 3,
        Type = "Success"
    })
    
    print([[
╔══════════════════════════════════════════════╗
║        SILENT AIM - COMPACT EDITION          ║
║                 VERSION 2.9                  ║
║                                              ║
║  ✓ MENU ATUALIZADO COM MANO GUSTAVO UI       ║
║     • Interface moderna                      ║
║     • Sistema de abas organizado             ║
║     • Notificações integradas                ║
║                                              ║
║  ✓ NOVA ABA "NPC" NO MENU                    ║
║     • Modo Agressivo                         ║
║     • Debug NPCs                            ║
║     • Controles de cache                     ║
║                                              ║
║  ✓ BUG DO HIT CHANCE CORRIGIDO               ║
║     • Texto desaparece quando desligado      ║
║     • Mostra apenas se ShowHitChance = true  ║
║     • E HitChance > 0                        ║
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