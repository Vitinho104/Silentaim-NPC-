[file content begin]
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

--// NOVAS CONFIGURAÇÕES SUPER AIMBOT
_G.SuperAimbot = false -- Ativa todas as funções apelões
_G.InstantAim = false -- Mira instantânea para o alvo
_G.InstantHit = false -- Dano instantâneo sem delay
_G.IgnoreAllWalls = false -- Ignora todas as paredes/obstáculos
_G.AutoTrigger = false -- Atira automaticamente quando o alvo está no FOV
_G.MultiTarget = false -- Atira em múltiplos alvos simultaneamente
_G.InstantKill = false -- Mata com um tiro
_G.AutoSwitchTarget = false -- Troca automaticamente de alvo quando morre
_G.MaxTargets = 5 -- Máximo de alvos simultâneos
_G.TriggerDelay = 0.1 -- Delay entre tiros automáticos
_G.AimbotStrength = 1.0 -- Força do aimbot (1.0 = instantâneo, 0.1 = suave)

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
local FloatButton = nil
local MainUI = nil
local PulseConnection = nil

--// VARIÁVEIS SUPER AIMBOT
local SuperTargets = {} -- Tabela de alvos para multi-target
local LastTriggerTime = 0 -- Último tempo de trigger
local OriginalHooks = {} -- Armazena hooks originais
local IsAiming = false -- Se está mirando ativamente
local AutoShootConnection = nil -- Conexão para auto-tiro

--// VARIÁVEIS PARA HOOKS (não limpar)
local oldNamecall = nil
local oldIndex = nil

--// FUNÇÃO: ATIVAR SUPER AIMBOT (APELÃO)
local function ActivateSuperAimbot()
    if _G.SuperAimbot then
        -- Ativar todas as configurações apelões
        _G.InstantAim = true
        _G.InstantHit = true
        _G.IgnoreAllWalls = true
        _G.AutoTrigger = true
        _G.MultiTarget = true
        _G.InstantKill = true
        _G.AutoSwitchTarget = true
        _G.HitChance = 100
        _G.BulletTeleport = true
        _G.VisibleCheck = false
        _G.Prediction = 0.2
        _G.FOV = 250
        
        print("[SUPER AIMBOT] Ativado - Modo APELÃO!")
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "💀 SUPER AIMBOT",
            Text = "MODO APELÃO ATIVADO!\nTodas as vantagens ligadas!",
            Duration = 3,
            Icon = "rbxassetid://4483345998"
        })
    else
        -- Desativar todas as configurações apelões
        _G.InstantAim = false
        _G.InstantHit = false
        _G.IgnoreAllWalls = false
        _G.AutoTrigger = false
        _G.MultiTarget = false
        _G.InstantKill = false
        _G.AutoSwitchTarget = false
        _G.HitChance = 95
        _G.BulletTeleport = false
        _G.VisibleCheck = true
        _G.Prediction = 0.165
        _G.FOV = 150
        
        print("[SUPER AIMBOT] Desativado")
    end
end

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

--// FUNÇÃO: AUTO SHOOT (ATIRA AUTOMATICAMENTE)
local function AutoShoot()
    if not _G.AutoTrigger or not _G.SilentAim then return end
    
    local currentTime = tick()
    if currentTime - LastTriggerTime < _G.TriggerDelay then return end
    
    if CurrentTarget and TargetPart then
        -- Simular clique do mouse para atirar
        LastTriggerTime = currentTime
        
        -- Tentar encontrar a arma atual do jogador
        local character = LocalPlayer.Character
        if character then
            -- Procurar por ferramentas/armas
            for _, tool in pairs(character:GetChildren()) do
                if tool:IsA("Tool") then
                    -- Encontrar eventos de tiro
                    local shootEvent = tool:FindFirstChild("RemoteEvent") or tool:FindFirstChild("RemoteFunction")
                    if shootEvent then
                        -- Tentar atirar
                        pcall(function()
                            if shootEvent:IsA("RemoteEvent") then
                                shootEvent:FireServer()
                            elseif shootEvent:IsA("RemoteFunction") then
                                shootEvent:InvokeServer()
                            end
                        end)
                    end
                end
            end
        end
    end
end

--// FUNÇÃO: INSTANT AIM (MIRA INSTANTÂNEA)
local function UpdateInstantAim()
    if not _G.InstantAim or not _G.SilentAim or not CurrentTarget or not TargetPart then return end
    
    -- Mira instantânea para o alvo (apenas visual)
    if Mouse and Camera then
        local targetPosition = TargetPart.Position
        if _G.Prediction > 0 then
            local hrp = CurrentTarget:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.Velocity.Magnitude > 1 then
                targetPosition = targetPosition + (hrp.Velocity * _G.Prediction)
            end
        end
        
        -- Calcular posição na tela
        local screenPosition, onScreen = Camera:WorldToScreenPoint(targetPosition)
        if onScreen then
            -- Mover mouse para a posição do alvo (visual apenas)
            Mouse.Target = TargetPart
        end
    end
end

--// FUNÇÃO: GET MULTIPLE TARGETS (MULTI-TARGET)
local function GetMultipleTargets()
    if not _G.MultiTarget or not _G.SilentAim then return {} end
    
    local targets = {}
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    -- Limitar número de alvos
    local maxTargets = math.min(_G.MaxTargets, 10)
    
    -- Coletar NPCs
    if _G.TargetMode == "NPCs" or _G.TargetMode == "Both" then
        for _, data in pairs(NPCCache) do
            if #targets >= maxTargets then break end
            
            local hrp = data.HRP
            local humanoid = data.Humanoid
            
            if hrp and humanoid and humanoid.Health > 0 then
                if not IsEnemyNPC(data.Model) then continue end
                
                local targetPart = GetTargetPart(data.Model) or hrp
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                
                if onScreen then
                    local screenPoint = Vector2.new(screenPos.X, screenPos.Y)
                    local dist = (screenPoint - screenCenter).Magnitude
                    
                    if dist <= _G.FOV then
                        table.insert(targets, {
                            Model = data.Model,
                            Part = targetPart,
                            Distance = dist,
                            IsNPC = true
                        })
                    end
                end
            end
        end
    end
    
    -- Coletar Players
    if _G.TargetMode == "Players" or _G.TargetMode == "Both" then
        for _, data in pairs(PlayerCache) do
            if #targets >= maxTargets then break end
            
            local hrp = data.HRP
            local humanoid = data.Humanoid
            
            if hrp and humanoid and humanoid.Health > 0 then
                if not IsEnemyPlayer(data.Player) then continue end
                
                local targetPart = GetTargetPart(data.Model) or hrp
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                
                if onScreen then
                    local screenPoint = Vector2.new(screenPos.X, screenPos.Y)
                    local dist = (screenPoint - screenCenter).Magnitude
                    
                    if dist <= _G.FOV then
                        table.insert(targets, {
                            Model = data.Model,
                            Part = targetPart,
                            Distance = dist,
                            IsNPC = false,
                            Player = data.Player
                        })
                    end
                end
            end
        end
    end
    
    -- Ordenar por distância
    table.sort(targets, function(a, b)
        return a.Distance < b.Distance
    end)
    
    return targets
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
    SuperTargets = {}
    
    -- Parar auto shoot
    if AutoShootConnection then
        AutoShootConnection:Disconnect()
        AutoShootConnection = nil
    end
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
                    
                    -- WALL CHECK CORRIGIDO (ignorar se IgnoreAllWalls estiver ativo)
                    if _G.VisibleCheck and not _G.IgnoreAllWalls then
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
                    if isVisible or not _G.VisibleCheck or _G.IgnoreAllWalls then
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
            
            -- Atualizar multi-targets
            if _G.MultiTarget then
                SuperTargets = GetMultipleTargets()
            else
                SuperTargets = {}
            end
            
            -- Auto switch target
            if _G.AutoSwitchTarget and CurrentTarget then
                local humanoid = CurrentTarget:FindFirstChildOfClass("Humanoid")
                if not humanoid or humanoid.Health <= 0 then
                    CurrentTarget = GetTarget() -- Buscar novo alvo
                end
            end
        else
            CurrentTarget = nil
            TargetInRange = false
            TargetPart = nil
            SuperTargets = {}
        end
    end
end)

--// FUNÇÃO: TELEPORTAR BALLET PARA O ALVO
local function TeleportBulletToTarget(origin, direction, bulletName)
    if not _G.BulletTeleport or (not TargetPart and #SuperTargets == 0) then
        return origin, direction
    end
    
    -- Verificar se é realmente uma bala (baseado no nome)
    local bulletNames = {"bullet", "ammo", "shot", "projectile", "missile", "rocket"}
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
    
    -- MULTI-TARGET: Selecionar alvo mais próximo
    local targetToUse = TargetPart
    if _G.MultiTarget and #SuperTargets > 0 then
        -- Usar primeiro alvo da lista (mais próximo)
        targetToUse = SuperTargets[1].Part
    end
    
    if not targetToUse then
        return origin, direction
    end
    
    -- Calcular nova direção para o alvo
    local targetPosition = targetToUse.Position
    if _G.Prediction > 0 and targetToUse.Parent:FindFirstChild("HumanoidRootPart") then
        local hrp = targetToUse.Parent:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.Velocity.Magnitude > 1 then
            targetPosition = targetPosition + (hrp.Velocity * _G.Prediction)
        end
    end
    
    -- Calcular direção para o alvo
    local newDirection = (targetPosition - origin).Unit * direction.Magnitude
    
    return origin, newDirection
end

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
            
            -- Informações do Super Aimbot
            if _G.SuperAimbot then
                table.insert(infoLines, "💀 SUPER MODE")
            elseif _G.MultiTarget and #SuperTargets > 0 then
                table.insert(infoLines, string.format("🎯 %d alvos", #SuperTargets))
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
    if not _G.BulletTeleport or (not TargetPart and #SuperTargets == 0) then
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
    
    -- MULTI-TARGET: Selecionar alvo mais próximo
    local targetToUse = TargetPart
    local targetModel = CurrentTarget
    
    if _G.MultiTarget and #SuperTargets > 0 then
        -- Usar primeiro alvo da lista (mais próximo)
        targetToUse = SuperTargets[1].Part
        targetModel = SuperTargets[1].Model
    end
    
    if not targetToUse then
        return origin, direction
    end
    
    -- Calcular nova direção para o alvo
    local targetPosition = targetToUse.Position
    
    -- Aplicar predição se estiver habilitada
    if _G.Prediction > 0 and targetModel:FindFirstChild("HumanoidRootPart") then
        local hrp = targetModel:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.Velocity.Magnitude > 1 then
            targetPosition = targetPosition + (hrp.Velocity * _G.Prediction)
        end
    end
    
    -- INSTANT KILL: Mirar sempre na cabeça
    if _G.InstantKill then
        local head = targetModel:FindFirstChild("Head")
        if head then
            targetPosition = head.Position
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

--// HOOKS ATUALIZADOS COM SUPER AIMBOT
if not oldNamecall then
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if not _G.SilentAim or (not TargetPart and #SuperTargets == 0) then
            return oldNamecall(self, ...)
        end
        
        local method = getnamecallmethod()
        local args = {...}
        
        -- INSTANT HIT: Ignorar delay
        if _G.InstantHit and (method == "FireServer" or method == "InvokeServer") then
            -- Remover argumentos de delay se existirem
            for i, arg in pairs(args) do
                if type(arg) == "number" and arg > 0.1 then
                    args[i] = 0.01  -- Delay mínimo
                end
            end
        end
        
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
        
        -- HOOK ORIGINAL COM SUPER AIMBOT
        if (method == "FireServer" or method == "InvokeServer") and typeof(self) == "Instance" then
            local selfName = self.Name:lower()
            if string.find(selfName, "fire") or string.find(selfName, "hit") or string.find(selfName, "attack") or string.find(selfName, "damage") then
                -- Verificar Hit Chance ANTES de modificar
                if not ShouldHit() then
                    return oldNamecall(self, ...)  -- Retornar normal se não passar no hit chance
                end
                
                local newArgs = {}
                local modified = false
                
                -- MULTI-TARGET: Processar múltiplos alvos
                local targetsToHit = {TargetPart}
                if _G.MultiTarget and #SuperTargets > 0 then
                    targetsToHit = {}
                    for _, targetData in pairs(SuperTargets) do
                        table.insert(targetsToHit, targetData.Part)
                    end
                end
                
                for i, arg in pairs(args) do
                    if typeof(arg) == "Vector3" then
                        -- Para multi-target, usar o primeiro alvo
                        newArgs[i] = targetsToHit[1] and targetsToHit[1].Position or arg
                        modified = true
                    elseif typeof(arg) == "CFrame" then
                        newArgs[i] = targetsToHit[1] and CFrame.new(targetsToHit[1].Position) or arg
                        modified = true
                    elseif typeof(arg) == "Ray" then
                        local origin = arg.Origin
                        newArgs[i] = targetsToHit[1] and Ray.new(origin, (targetsToHit[1].Position - origin).Unit * 100) or arg
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
            
            if origin and (TargetPart or #SuperTargets > 0) then
                -- Verificar Hit Chance ANTES de modificar
                if not ShouldHit() then
                    return oldNamecall(self, ...)  -- Retornar normal se não passar no hit chance
                end
                
                local targetToUse = TargetPart
                if _G.MultiTarget and #SuperTargets > 0 then
                    targetToUse = SuperTargets[1].Part
                end
                
                if targetToUse then
                    local newDir = (targetToUse.Position - origin).Unit * direction.Magnitude
                    return oldNamecall(self, origin, newDir, args[3], args[4])
                end
            end
        end
        
        return oldNamecall(self, ...)
    end)
end

if not oldIndex then
    oldIndex = hookmetamethod(game, "__index", function(self, key)
        if self == Mouse and _G.SilentAim and (TargetPart or #SuperTargets > 0) then
            local keyLower = string.lower(key)
            if keyLower == "hit" then
                -- Verificar Hit Chance ANTES de modificar
                if not ShouldHit() then
                    return oldIndex(self, key)  -- Retornar normal se não passar no hit chance
                end
                
                local targetToUse = TargetPart
                if _G.MultiTarget and #SuperTargets > 0 then
                    targetToUse = SuperTargets[1].Part
                end
                
                if targetToUse then
                    return CFrame.new(targetToUse.Position)
                end
            elseif keyLower == "target" then
                return TargetPart or (_G.MultiTarget and #SuperTargets > 0 and SuperTargets[1].Part or nil)
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
        
        -- Super Aimbot: Mostrar cor especial
        if _G.SuperAimbot then
            Circle.Color = Color3.fromRGB(255, 50, 150)  -- Rosa/vermelho
            Circle.Thickness = 3
        elseif _G.MultiTarget and #SuperTargets > 0 then
            Circle.Color = Color3.fromRGB(255, 150, 0)  -- Laranja para multi-target
            Circle.Thickness = 3
        end
    else
        Circle.Visible = false
    end
    
    -- Atualizar informações do alvo (CORREÇÃO DO BUG DO HIT CHANCE)
    UpdateTargetInfo()
    
    -- Atualizar highlight
    UpdateHighlight()
    
    -- Atualizar Instant Aim
    UpdateInstantAim()
    
    -- Auto Shoot
    AutoShoot()
end)

--// SISTEMA DE AUTO SHOOT CONECTADO
task.spawn(function()
    while task.wait(0.05) do
        if _G.AutoTrigger and _G.SilentAim then
            AutoShoot()
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
                    Size = UDim2.new(0, 320, 0, 450)  -- Aumentado para 450
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

--// INTERFACE COMPACTA ATUALIZADA (COM NOVA ABA SUPER AIMBOT)
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
        Super = Color3.fromRGB(255, 50, 150),  -- Nova cor para Super Aimbot
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
    MainFrame.Size = UDim2.new(0, 320, 0, 450)  -- Aumentado para 450
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
    HeaderText.Text = "🎯 SILENT AIM v3.0"
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
    
    local Tabs = {"Geral", "Config", "Aim", "Team", "Extra", "NPC", "Super", "Info"}  -- Adicionada aba "Super"
    local CurrentTab = "Geral"
    local TabButtons = {}
    local TabContents = {}
    
    -- Criar botões de abas
    for i, tabName in ipairs(Tabs) do
        local TabButton = Instance.new("TextButton")
        TabButton.Name = tabName .. "Tab"
        TabButton.Size = UDim2.new(0.11, 0, 1, 0)  -- Ajustado para 0.11 para caber mais abas
        TabButton.Position = UDim2.new((i-1) * 0.115, 0, 0, 0)
        TabButton.Text = tabName
        TabButton.TextColor3 = Theme.TextSecondary
        TabButton.BackgroundColor3 = Theme.Secondary
        TabButton.BackgroundTransparency = 0.7
        TabButton.Font = Enum.Font.GothamBold
        TabButton.TextSize = 8  -- Texto menor para caber
        TabButton.Parent = TabContainer
        
        local TabCorner = Instance.new("UICorner")
        TabCorner.CornerRadius = UDim.new(0, 6)
        TabCorner.Parent = TabButton
        
        TabButtons[tabName] = TabButton
        
        -- Conteúdo da aba
        local TabContent = Instance.new("ScrollingFrame")
        TabContent.Name = tabName .. "Content"
        TabContent.Size = UDim2.new(1, -20, 0, 270)
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
                    local bgColor = Theme.Accent
                    if name == "Super" then
                        bgColor = Theme.Super  -- Cor especial para aba Super
                    end
                    
                    TweenService:Create(btn, TweenInfo.new(0.2), {
                        BackgroundTransparency = 0.3,
                        TextColor3 = Theme.Text,
                        BackgroundColor3 = bgColor
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
    ToggleStatus.BackgroundColor3 = _G.SilentAim and Theme.Success or Theme.Danger
    ToggleStatus.Parent = ToggleContainer
    
    local StatusCorner = Instance.new("UICorner")
    StatusCorner.CornerRadius = UDim.new(1, 0)
    StatusCorner.Parent = ToggleStatus
    
    local StatusText = Instance.new("TextLabel")
    StatusText.Name = "StatusText"
    StatusText.Size = UDim2.new(1, 0, 1, 0)
    StatusText.Text = _G.SilentAim and "ON" or "OFF"
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
    FOVText.Text = "FOV: " .. _G.FOV
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
    PredText.Text = "Predição: " .. string.format("%.3f", _G.Prediction)
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
    ModeText.Text = "Modo: " .. _G.TargetMode
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
    WallCheckIcon.TextColor3 = _G.VisibleCheck and Theme.Success or Theme.Danger
    WallCheckIcon.BackgroundTransparency = 1
    WallCheckIcon.Font = Enum.Font.GothamBold
    WallCheckIcon.TextSize = 24
    WallCheckIcon.Parent = WallCheckCard
    
    local WallCheckText = Instance.new("TextLabel")
    WallCheckText.Name = "WallCheckText"
    WallCheckText.Size = UDim2.new(0.6, 0, 0.4, 0)
    WallCheckText.Position = UDim2.new(0.2, 0, 0.2, 0)
    WallCheckText.Text = "Wall Check: " .. (_G.VisibleCheck and "ON" or "OFF")
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
    AimPartText.Text = "Parte: " .. _G.AimPart
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
    
    --// CONTEÚDO DA ABA EXTRA
    local ExtraContent = TabContents["Extra"]
    
    -- Botão de Show Target (Toggle principal)
    local ShowTargetCard = Instance.new("Frame")
    ShowTargetCard.Name = "ShowTargetCard"
    ShowTargetCard.Size = UDim2.new(1, 0, 0, 60)
    ShowTargetCard.Position = UDim2.new(0, 0, 0, 0)
    ShowTargetCard.BackgroundColor3 = Theme.Secondary
    ShowTargetCard.Parent = ExtraContent
    
    local ShowTargetCorner = Instance.new("UICorner")
    ShowTargetCorner.CornerRadius = UDim.new(0, 10)
    ShowTargetCorner.Parent = ShowTargetCard
    
    local ShowTargetBtn = Instance.new("TextButton")
    ShowTargetBtn.Name = "ShowTargetBtn"
    ShowTargetBtn.Size = UDim2.new(1, 0, 1, 0)
    ShowTargetBtn.BackgroundTransparency = 1
    ShowTargetBtn.Text = ""
    ShowTargetBtn.Parent = ShowTargetCard
    
    local ShowTargetIcon = Instance.new("TextLabel")
    ShowTargetIcon.Name = "ShowTargetIcon"
    ShowTargetIcon.Size = UDim2.new(0, 35, 0, 35)
    ShowTargetIcon.Position = UDim2.new(0.05, 0, 0.2, 0)
    ShowTargetIcon.Text = "📋"
    ShowTargetIcon.TextColor3 = Theme.Info
    ShowTargetIcon.BackgroundTransparency = 1
    ShowTargetIcon.Font = Enum.Font.GothamBold
    ShowTargetIcon.TextSize = 24
    ShowTargetIcon.Parent = ShowTargetCard
    
    local ShowTargetText = Instance.new("TextLabel")
    ShowTargetText.Name = "ShowTargetText"
    ShowTargetText.Size = UDim2.new(0.6, 0, 0.4, 0)
    ShowTargetText.Position = UDim2.new(0.2, 0, 0.2, 0)
    ShowTargetText.Text = "Mostrar Alvo: " .. (_G.ShowTarget and "ON" or "OFF")
    ShowTargetText.TextColor3 = Theme.Text
    ShowTargetText.BackgroundTransparency = 1
    ShowTargetText.Font = Enum.Font.GothamBold
    ShowTargetText.TextSize = 12
    ShowTargetText.TextXAlignment = Enum.TextXAlignment.Left
    ShowTargetText.Parent = ShowTargetCard
    
    local ShowTargetLabel = Instance.new("TextLabel")
    ShowTargetLabel.Name = "ShowTargetLabel"
    ShowTargetLabel.Size = UDim2.new(0.6, 0, 0.3, 0)
    ShowTargetLabel.Position = UDim2.new(0.2, 0, 0.6, 0)
    ShowTargetLabel.Text = "Mostrar informações do alvo"
    ShowTargetLabel.TextColor3 = Theme.TextSecondary
    ShowTargetLabel.BackgroundTransparency = 1
    ShowTargetLabel.Font = Enum.Font.Gotham
    ShowTargetLabel.TextSize = 9
    ShowTargetLabel.TextXAlignment = Enum.TextXAlignment.Left
    ShowTargetLabel.Parent = ShowTargetCard
    
    local ShowTargetStatus = Instance.new("Frame")
    ShowTargetStatus.Name = "ShowTargetStatus"
    ShowTargetStatus.Size = UDim2.new(0, 40, 0, 20)
    ShowTargetStatus.Position = UDim2.new(0.8, -20, 0.4, -10)
    ShowTargetStatus.BackgroundColor3 = _G.ShowTarget and Theme.Success or Theme.Danger
    ShowTargetStatus.Parent = ShowTargetCard
    
    local ShowTargetStatusCorner = Instance.new("UICorner")
    ShowTargetStatusCorner.CornerRadius = UDim.new(1, 0)
    ShowTargetStatusCorner.Parent = ShowTargetStatus
    
    local ShowTargetStatusText = Instance.new("TextLabel")
    ShowTargetStatusText.Name = "ShowTargetStatusText"
    ShowTargetStatusText.Size = UDim2.new(1, 0, 1, 0)
    ShowTargetStatusText.Text = _G.ShowTarget and "ON" or "OFF"
    ShowTargetStatusText.TextColor3 = Theme.Text
    ShowTargetStatusText.BackgroundTransparency = 1
    ShowTargetStatusText.Font = Enum.Font.GothamBold
    ShowTargetStatusText.TextSize = 10
    ShowTargetStatusText.Parent = ShowTargetStatus
    
    -- Slider de Hit Chance
    local HitChanceCard = Instance.new("Frame")
    HitChanceCard.Name = "HitChanceCard"
    HitChanceCard.Size = UDim2.new(1, 0, 0, 60)
    HitChanceCard.Position = UDim2.new(0, 0, 0, 70)
    HitChanceCard.BackgroundColor3 = Theme.Secondary
    HitChanceCard.Parent = ExtraContent
    
    local HitChanceCorner = Instance.new("UICorner")
    HitChanceCorner.CornerRadius = UDim.new(0, 10)
    HitChanceCorner.Parent = HitChanceCard
    
    local HitChanceIcon = Instance.new("TextLabel")
    HitChanceIcon.Name = "HitChanceIcon"
    HitChanceIcon.Size = UDim2.new(0, 30, 0, 30)
    HitChanceIcon.Position = UDim2.new(0.05, 0, 0.25, 0)
    HitChanceIcon.Text = "🎯"
    HitChanceIcon.TextColor3 = Theme.Warning
    HitChanceIcon.BackgroundTransparency = 1
    HitChanceIcon.Font = Enum.Font.GothamBold
    HitChanceIcon.TextSize = 20
    HitChanceIcon.Parent = HitChanceCard
    
    local HitChanceText = Instance.new("TextLabel")
    HitChanceText.Name = "HitChanceText"
    HitChanceText.Size = UDim2.new(0.5, 0, 0.4, 0)
    HitChanceText.Position = UDim2.new(0.2, 0, 0.15, 0)
    HitChanceText.Text = "Hit Chance: " .. _G.HitChance .. "%"
    HitChanceText.TextColor3 = Theme.Text
    HitChanceText.BackgroundTransparency = 1
    HitChanceText.Font = Enum.Font.GothamBold
    HitChanceText.TextSize = 12
    HitChanceText.TextXAlignment = Enum.TextXAlignment.Left
    HitChanceText.Parent = HitChanceCard
    
    local HitChanceSlider = Instance.new("Frame")
    HitChanceSlider.Name = "HitChanceSlider"
    HitChanceSlider.Size = UDim2.new(0.7, 0, 0, 5)
    HitChanceSlider.Position = UDim2.new(0.15, 0, 0.7, 0)
    HitChanceSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    HitChanceSlider.Parent = HitChanceCard
    
    local HitChanceSliderCorner = Instance.new("UICorner")
    HitChanceSliderCorner.CornerRadius = UDim.new(1, 0)
    HitChanceSliderCorner.Parent = HitChanceSlider
    
    local HitChanceSliderFill = Instance.new("Frame")
    HitChanceSliderFill.Name = "HitChanceSliderFill"
    HitChanceSliderFill.Size = UDim2.new(_G.HitChance / 100, 0, 1, 0)
    HitChanceSliderFill.Position = UDim2.new(0, 0, 0, 0)
    HitChanceSliderFill.BackgroundColor3 = Theme.Warning
    HitChanceSliderFill.Parent = HitChanceSlider
    
    local HitChanceSliderFillCorner = Instance.new("UICorner")
    HitChanceSliderFillCorner.CornerRadius = UDim.new(1, 0)
    HitChanceSliderFillCorner.Parent = HitChanceSliderFill
    
    -- Botão de Bullet Teleport
    local BulletTeleportCard = Instance.new("Frame")
    BulletTeleportCard.Name = "BulletTeleportCard"
    BulletTeleportCard.Size = UDim2.new(1, 0, 0, 60)
    BulletTeleportCard.Position = UDim2.new(0, 0, 0, 140)
    BulletTeleportCard.BackgroundColor3 = Theme.Secondary
    BulletTeleportCard.Parent = ExtraContent
    
    local BulletTeleportCorner = Instance.new("UICorner")
    BulletTeleportCorner.CornerRadius = UDim.new(0, 10)
    BulletTeleportCorner.Parent = BulletTeleportCard
    
    local BulletTeleportBtn = Instance.new("TextButton")
    BulletTeleportBtn.Name = "BulletTeleportBtn"
    BulletTeleportBtn.Size = UDim2.new(1, 0, 1, 0)
    BulletTeleportBtn.BackgroundTransparency = 1
    BulletTeleportBtn.Text = ""
    BulletTeleportBtn.Parent = BulletTeleportCard
    
    local BulletTeleportIcon = Instance.new("TextLabel")
    BulletTeleportIcon.Name = "BulletTeleportIcon"
    BulletTeleportIcon.Size = UDim2.new(0, 35, 0, 35)
    BulletTeleportIcon.Position = UDim2.new(0.05, 0, 0.2, 0)
    BulletTeleportIcon.Text = "🔫"
    BulletTeleportIcon.TextColor3 = Theme.Info
    BulletTeleportIcon.BackgroundTransparency = 1
    BulletTeleportIcon.Font = Enum.Font.GothamBold
    BulletTeleportIcon.TextSize = 24
    BulletTeleportIcon.Parent = BulletTeleportCard
    
    local BulletTeleportText = Instance.new("TextLabel")
    BulletTeleportText.Name = "BulletTeleportText"
    BulletTeleportText.Size = UDim2.new(0.6, 0, 0.4, 0)
    BulletTeleportText.Position = UDim2.new(0.2, 0, 0.2, 0)
    BulletTeleportText.Text = "Bullet Teleport: " .. (_G.BulletTeleport and "ON" or "OFF")
    BulletTeleportText.TextColor3 = Theme.Text
    BulletTeleportText.BackgroundTransparency = 1
    BulletTeleportText.Font = Enum.Font.GothamBold
    BulletTeleportText.TextSize = 12
    BulletTeleportText.TextXAlignment = Enum.TextXAlignment.Left
    BulletTeleportText.Parent = BulletTeleportCard
    
    local BulletTeleportLabel = Instance.new("TextLabel")
    BulletTeleportLabel.Name = "BulletTeleportLabel"
    BulletTeleportLabel.Size = UDim2.new(0.6, 0, 0.3, 0)
    BulletTeleportLabel.Position = UDim2.new(0.2, 0, 0.6, 0)
    BulletTeleportLabel.Text = "Teleportar balas para o alvo"
    BulletTeleportLabel.TextColor3 = Theme.TextSecondary
    BulletTeleportLabel.BackgroundTransparency = 1
    BulletTeleportLabel.Font = Enum.Font.Gotham
    BulletTeleportLabel.TextSize = 9
    BulletTeleportLabel.TextXAlignment = Enum.TextXAlignment.Left
    BulletTeleportLabel.Parent = BulletTeleportCard
    
    local BulletTeleportStatus = Instance.new("Frame")
    BulletTeleportStatus.Name = "BulletTeleportStatus"
    BulletTeleportStatus.Size = UDim2.new(0, 40, 0, 20)
    BulletTeleportStatus.Position = UDim2.new(0.8, -20, 0.4, -10)
    BulletTeleportStatus.BackgroundColor3 = _G.BulletTeleport and Theme.Success or Theme.Danger
    BulletTeleportStatus.Parent = BulletTeleportCard
    
    local BulletTeleportStatusCorner = Instance.new("UICorner")
    BulletTeleportStatusCorner.CornerRadius = UDim.new(1, 0)
    BulletTeleportStatusCorner.Parent = BulletTeleportStatus
    
    local BulletTeleportStatusText = Instance.new("TextLabel")
    BulletTeleportStatusText.Name = "BulletTeleportStatusText"
    BulletTeleportStatusText.Size = UDim2.new(1, 0, 1, 0)
    BulletTeleportStatusText.Text = _G.BulletTeleport and "ON" or "OFF"
    BulletTeleportStatusText.TextColor3 = Theme.Text
    BulletTeleportStatusText.BackgroundTransparency = 1
    BulletTeleportStatusText.Font = Enum.Font.GothamBold
    BulletTeleportStatusText.TextSize = 10
    BulletTeleportStatusText.Parent = BulletTeleportStatus
    
    ExtraContent.CanvasSize = UDim2.new(0, 0, 0, 210)
    
    --// CONTEÚDO DA ABA NPC
    local NPCContent = TabContents["NPC"]
    
    -- Botão de Modo Agressivo
    local AggressiveCard = Instance.new("Frame")
    AggressiveCard.Name = "AggressiveCard"
    AggressiveCard.Size = UDim2.new(1, 0, 0, 60)
    AggressiveCard.Position = UDim2.new(0, 0, 0, 0)
    AggressiveCard.BackgroundColor3 = Theme.Secondary
    AggressiveCard.Parent = NPCContent
    
    local AggressiveCorner = Instance.new("UICorner")
    AggressiveCorner.CornerRadius = UDim.new(0, 10)
    AggressiveCorner.Parent = AggressiveCard
    
    local AggressiveBtn = Instance.new("TextButton")
    AggressiveBtn.Name = "AggressiveBtn"
    AggressiveBtn.Size = UDim2.new(1, 0, 1, 0)
    AggressiveBtn.BackgroundTransparency = 1
    AggressiveBtn.Text = ""
    AggressiveBtn.Parent = AggressiveCard
    
    local AggressiveIcon = Instance.new("TextLabel")
    AggressiveIcon.Name = "AggressiveIcon"
    AggressiveIcon.Size = UDim2.new(0, 35, 0, 35)
    AggressiveIcon.Position = UDim2.new(0.05, 0, 0.2, 0)
    AggressiveIcon.Text = "⚠️"
    AggressiveIcon.TextColor3 = _G.AggressiveNPCDetection and Theme.Warning or Theme.TextSecondary
    AggressiveIcon.BackgroundTransparency = 1
    AggressiveIcon.Font = Enum.Font.GothamBold
    AggressiveIcon.TextSize = 24
    AggressiveIcon.Parent = AggressiveCard
    
    local AggressiveText = Instance.new("TextLabel")
    AggressiveText.Name = "AggressiveText"
    AggressiveText.Size = UDim2.new(0.6, 0, 0.4, 0)
    AggressiveText.Position = UDim2.new(0.2, 0, 0.2, 0)
    AggressiveText.Text = "Modo Agressivo: " .. (_G.AggressiveNPCDetection and "ON" or "OFF")
    AggressiveText.TextColor3 = Theme.Text
    AggressiveText.BackgroundTransparency = 1
    AggressiveText.Font = Enum.Font.GothamBold
    AggressiveText.TextSize = 12
    AggressiveText.TextXAlignment = Enum.TextXAlignment.Left
    AggressiveText.Parent = AggressiveCard
    
    local AggressiveLabel = Instance.new("TextLabel")
    AggressiveLabel.Name = "AggressiveLabel"
    AggressiveLabel.Size = UDim2.new(0.6, 0, 0.3, 0)
    AggressiveLabel.Position = UDim2.new(0.2, 0, 0.6, 0)
    AggressiveLabel.Text = "Detectar TODOS como NPCs"
    AggressiveLabel.TextColor3 = Theme.TextSecondary
    AggressiveLabel.BackgroundTransparency = 1
    AggressiveLabel.Font = Enum.Font.Gotham
    AggressiveLabel.TextSize = 9
    AggressiveLabel.TextXAlignment = Enum.TextXAlignment.Left
    AggressiveLabel.Parent = AggressiveCard
    
    local AggressiveStatus = Instance.new("Frame")
    AggressiveStatus.Name = "AggressiveStatus"
    AggressiveStatus.Size = UDim2.new(0, 40, 0, 20)
    AggressiveStatus.Position = UDim2.new(0.8, -20, 0.4, -10)
    AggressiveStatus.BackgroundColor3 = _G.AggressiveNPCDetection and Theme.Warning or Theme.Danger
    AggressiveStatus.Parent = AggressiveCard
    
    local AggressiveStatusCorner = Instance.new("UICorner")
    AggressiveStatusCorner.CornerRadius = UDim.new(1, 0)
    AggressiveStatusCorner.Parent = AggressiveStatus
    
    local AggressiveStatusText = Instance.new("TextLabel")
    AggressiveStatusText.Name = "AggressiveStatusText"
    AggressiveStatusText.Size = UDim2.new(1, 0, 1, 0)
    AggressiveStatusText.Text = _G.AggressiveNPCDetection and "ON" or "OFF"
    AggressiveStatusText.TextColor3 = Theme.Text
    AggressiveStatusText.BackgroundTransparency = 1
    AggressiveStatusText.Font = Enum.Font.GothamBold
    AggressiveStatusText.TextSize = 10
    AggressiveStatusText.Parent = AggressiveStatus
    
    -- Botão de Debug NPCs
    local DebugCard = Instance.new("Frame")
    DebugCard.Name = "DebugCard"
    DebugCard.Size = UDim2.new(1, 0, 0, 60)
    DebugCard.Position = UDim2.new(0, 0, 0, 70)
    DebugCard.BackgroundColor3 = Theme.Secondary
    DebugCard.Parent = NPCContent
    
    local DebugCorner = Instance.new("UICorner")
    DebugCorner.CornerRadius = UDim.new(0, 10)
    DebugCorner.Parent = DebugCard
    
    local DebugBtn = Instance.new("TextButton")
    DebugBtn.Name = "DebugBtn"
    DebugBtn.Size = UDim2.new(1, 0, 1, 0)
    DebugBtn.BackgroundTransparency = 1
    DebugBtn.Text = ""
    DebugBtn.Parent = DebugCard
    
    local DebugIcon = Instance.new("TextLabel")
    DebugIcon.Name = "DebugIcon"
    DebugIcon.Size = UDim2.new(0, 35, 0, 35)
    DebugIcon.Position = UDim2.new(0.05, 0, 0.2, 0)
    DebugIcon.Text = "🐛"
    DebugIcon.TextColor3 = _G.DebugNPCs and Theme.Info or Theme.TextSecondary
    DebugIcon.BackgroundTransparency = 1
    DebugIcon.Font = Enum.Font.GothamBold
    DebugIcon.TextSize = 24
    DebugIcon.Parent = DebugCard
    
    local DebugText = Instance.new("TextLabel")
    DebugText.Name = "DebugText"
    DebugText.Size = UDim2.new(0.6, 0, 0.4, 0)
    DebugText.Position = UDim2.new(0.2, 0, 0.2, 0)
    DebugText.Text = "Debug NPCs: " .. (_G.DebugNPCs and "ON" or "OFF")
    DebugText.TextColor3 = Theme.Text
    DebugText.BackgroundTransparency = 1
    DebugText.Font = Enum.Font.GothamBold
    DebugText.TextSize = 12
    DebugText.TextXAlignment = Enum.TextXAlignment.Left
    DebugText.Parent = DebugCard
    
    local DebugLabel = Instance.new("TextLabel")
    DebugLabel.Name = "DebugLabel"
    DebugLabel.Size = UDim2.new(0.6, 0, 0.3, 0)
    DebugLabel.Position = UDim2.new(0.2, 0, 0.6, 0)
    DebugLabel.Text = "Mostrar detecção no console"
    DebugLabel.TextColor3 = Theme.TextSecondary
    DebugLabel.BackgroundTransparency = 1
    DebugLabel.Font = Enum.Font.Gotham
    DebugLabel.TextSize = 9
    DebugLabel.TextXAlignment = Enum.TextXAlignment.Left
    DebugLabel.Parent = DebugCard
    
    local DebugStatus = Instance.new("Frame")
    DebugStatus.Name = "DebugStatus"
    DebugStatus.Size = UDim2.new(0, 40, 0, 20)
    DebugStatus.Position = UDim2.new(0.8, -20, 0.4, -10)
    DebugStatus.BackgroundColor3 = _G.DebugNPCs and Theme.Info or Theme.Danger
    DebugStatus.Parent = DebugCard
    
    local DebugStatusCorner = Instance.new("UICorner")
    DebugStatusCorner.CornerRadius = UDim.new(1, 0)
    DebugStatusCorner.Parent = DebugStatus
    
    local DebugStatusText = Instance.new("TextLabel")
    DebugStatusText.Name = "DebugStatusText"
    DebugStatusText.Size = UDim2.new(1, 0, 1, 0)
    DebugStatusText.Text = _G.DebugNPCs and "ON" or "OFF"
    DebugStatusText.TextColor3 = Theme.Text
    DebugStatusText.BackgroundTransparency = 1
    DebugStatusText.Font = Enum.Font.GothamBold
    DebugStatusText.TextSize = 10
    DebugStatusText.Parent = DebugStatus
    
    -- Informações sobre detecção de NPCs
    local NPCInfoCard = Instance.new("Frame")
    NPCInfoCard.Name = "NPCInfoCard"
    NPCInfoCard.Size = UDim2.new(1, 0, 0, 90)
    NPCInfoCard.Position = UDim2.new(0, 0, 0, 140)
    NPCInfoCard.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    NPCInfoCard.BackgroundTransparency = 0.3
    NPCInfoCard.Parent = NPCContent
    
    local NPCInfoCorner = Instance.new("UICorner")
    NPCInfoCorner.CornerRadius = UDim.new(0, 8)
    NPCInfoCorner.Parent = NPCInfoCard
    
    local NPCInfoText = Instance.new("TextLabel")
    NPCInfoText.Name = "NPCInfoText"
    NPCInfoText.Size = UDim2.new(0.9, 0, 0.9, 0)
    NPCInfoText.Position = UDim2.new(0.05, 0, 0.05, 0)
    NPCInfoText.Text = "Modo Agressivo: Detecta QUALQUER humanoid como NPC.\nDebug: Mostra no console todos os NPCs detectados."
    NPCInfoText.TextColor3 = Theme.TextSecondary
    NPCInfoText.BackgroundTransparency = 1
    NPCInfoText.Font = Enum.Font.Gotham
    NPCInfoText.TextSize = 9
    NPCInfoText.TextXAlignment = Enum.TextXAlignment.Left
    NPCInfoText.TextYAlignment = Enum.TextYAlignment.Top
    NPCInfoText.TextWrapped = true
    NPCInfoText.Parent = NPCInfoCard
    
    NPCContent.CanvasSize = UDim2.new(0, 0, 0, 240)
    
    --// CONTEÚDO DA ABA SUPER (NOVA ABA)
    local SuperContent = TabContents["Super"]
    
    -- Botão SUPER AIMBOT (Toggle principal)
    local SuperAimbotCard = Instance.new("Frame")
    SuperAimbotCard.Name = "SuperAimbotCard"
    SuperAimbotCard.Size = UDim2.new(1, 0, 0, 60)
    SuperAimbotCard.Position = UDim2.new(0, 0, 0, 0)
    SuperAimbotCard.BackgroundColor3 = Theme.Super
    SuperAimbotCard.BackgroundTransparency = 0.3
    SuperAimbotCard.Parent = SuperContent
    
    local SuperCorner = Instance.new("UICorner")
    SuperCorner.CornerRadius = UDim.new(0, 10)
    SuperCorner.Parent = SuperAimbotCard
    
    local SuperBtn = Instance.new("TextButton")
    SuperBtn.Name = "SuperBtn"
    SuperBtn.Size = UDim2.new(1, 0, 1, 0)
    SuperBtn.BackgroundTransparency = 1
    SuperBtn.Text = ""
    SuperBtn.Parent = SuperAimbotCard
    
    local SuperIcon = Instance.new("TextLabel")
    SuperIcon.Name = "SuperIcon"
    SuperIcon.Size = UDim2.new(0, 35, 0, 35)
    SuperIcon.Position = UDim2.new(0.05, 0, 0.2, 0)
    SuperIcon.Text = "💀"
    SuperIcon.TextColor3 = _G.SuperAimbot and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
    SuperIcon.BackgroundTransparency = 1
    SuperIcon.Font = Enum.Font.GothamBold
    SuperIcon.TextSize = 24
    SuperIcon.Parent = SuperAimbotCard
    
    local SuperText = Instance.new("TextLabel")
    SuperText.Name = "SuperText"
    SuperText.Size = UDim2.new(0.6, 0, 0.4, 0)
    SuperText.Position = UDim2.new(0.2, 0, 0.2, 0)
    SuperText.Text = "SUPER AIMBOT: " .. (_G.SuperAimbot and "ON" or "OFF")
    SuperText.TextColor3 = Theme.Text
    SuperText.BackgroundTransparency = 1
    SuperText.Font = Enum.Font.GothamBold
    SuperText.TextSize = 12
    SuperText.TextXAlignment = Enum.TextXAlignment.Left
    SuperText.Parent = SuperAimbotCard
    
    local SuperLabel = Instance.new("TextLabel")
    SuperLabel.Name = "SuperLabel"
    SuperLabel.Size = UDim2.new(0.6, 0, 0.3, 0)
    SuperLabel.Position = UDim2.new(0.2, 0, 0.6, 0)
    SuperLabel.Text = "Ativar MODO APELÃO (tudo ligado)"
    SuperLabel.TextColor3 = Theme.TextSecondary
    SuperLabel.BackgroundTransparency = 1
    SuperLabel.Font = Enum.Font.Gotham
    SuperLabel.TextSize = 9
    SuperLabel.TextXAlignment = Enum.TextXAlignment.Left
    SuperLabel.Parent = SuperAimbotCard
    
    local SuperStatus = Instance.new("Frame")
    SuperStatus.Name = "SuperStatus"
    SuperStatus.Size = UDim2.new(0, 40, 0, 20)
    SuperStatus.Position = UDim2.new(0.8, -20, 0.4, -10)
    SuperStatus.BackgroundColor3 = _G.SuperAimbot and Color3.fromRGB(255, 50, 50) or Theme.Danger
    SuperStatus.Parent = SuperAimbotCard
    
    local SuperStatusCorner = Instance.new("UICorner")
    SuperStatusCorner.CornerRadius = UDim.new(1, 0)
    SuperStatusCorner.Parent = SuperStatus
    
    local SuperStatusText = Instance.new("TextLabel")
    SuperStatusText.Name = "SuperStatusText"
    SuperStatusText.Size = UDim2.new(1, 0, 1, 0)
    SuperStatusText.Text = _G.SuperAimbot and "ON" or "OFF"
    SuperStatusText.TextColor3 = Theme.Text
    SuperStatusText.BackgroundTransparency = 1
    SuperStatusText.Font = Enum.Font.GothamBold
    SuperStatusText.TextSize = 10
    SuperStatusText.Parent = SuperStatus
    
    -- Multi-Target
    local MultiTargetCard = Instance.new("Frame")
    MultiTargetCard.Name = "MultiTargetCard"
    MultiTargetCard.Size = UDim2.new(1, 0, 0, 60)
    MultiTargetCard.Position = UDim2.new(0, 0, 0, 70)
    MultiTargetCard.BackgroundColor3 = Theme.Secondary
    MultiTargetCard.Parent = SuperContent
    
    local MultiTargetCorner = Instance.new("UICorner")
    MultiTargetCorner.CornerRadius = UDim.new(0, 10)
    MultiTargetCorner.Parent = MultiTargetCard
    
    local MultiTargetBtn = Instance.new("TextButton")
    MultiTargetBtn.Name = "MultiTargetBtn"
    MultiTargetBtn.Size = UDim2.new(1, 0, 1, 0)
    MultiTargetBtn.BackgroundTransparency = 1
    MultiTargetBtn.Text = ""
    MultiTargetBtn.Parent = MultiTargetCard
    
    local MultiTargetIcon = Instance.new("TextLabel")
    MultiTargetIcon.Name = "MultiTargetIcon"
    MultiTargetIcon.Size = UDim2.new(0, 35, 0, 35)
    MultiTargetIcon.Position = UDim2.new(0.05, 0, 0.2, 0)
    MultiTargetIcon.Text = "🎯"
    MultiTargetIcon.TextColor3 = _G.MultiTarget and Theme.Success or Theme.TextSecondary
    MultiTargetIcon.BackgroundTransparency = 1
    MultiTargetIcon.Font = Enum.Font.GothamBold
    MultiTargetIcon.TextSize = 24
    MultiTargetIcon.Parent = MultiTargetCard
    
    local MultiTargetText = Instance.new("TextLabel")
    MultiTargetText.Name = "MultiTargetText"
    MultiTargetText.Size = UDim2.new(0.6, 0, 0.4, 0)
    MultiTargetText.Position = UDim2.new(0.2, 0, 0.2, 0)
    MultiTargetText.Text = "Multi-Target: " .. (_G.MultiTarget and "ON" or "OFF")
    MultiTargetText.TextColor3 = Theme.Text
    MultiTargetText.BackgroundTransparency = 1
    MultiTargetText.Font = Enum.Font.GothamBold
    MultiTargetText.TextSize = 12
    MultiTargetText.TextXAlignment = Enum.TextXAlignment.Left
    MultiTargetText.Parent = MultiTargetCard
    
    local MultiTargetLabel = Instance.new("TextLabel")
    MultiTargetLabel.Name = "MultiTargetLabel"
    MultiTargetLabel.Size = UDim2.new(0.6, 0, 0.3, 0)
    MultiTargetLabel.Position = UDim2.new(0.2, 0, 0.6, 0)
    MultiTargetLabel.Text = "Atirar em múltiplos alvos"
    MultiTargetLabel.TextColor3 = Theme.TextSecondary
    MultiTargetLabel.BackgroundTransparency = 1
    MultiTargetLabel.Font = Enum.Font.Gotham
    MultiTargetLabel.TextSize = 9
    MultiTargetLabel.TextXAlignment = Enum.TextXAlignment.Left
    MultiTargetLabel.Parent = MultiTargetCard
    
    local MultiTargetStatus = Instance.new("Frame")
    MultiTargetStatus.Name = "MultiTargetStatus"
    MultiTargetStatus.Size = UDim2.new(0, 40, 0, 20)
    MultiTargetStatus.Position = UDim2.new(0.8, -20, 0.4, -10)
    MultiTargetStatus.BackgroundColor3 = _G.MultiTarget and Theme.Success or Theme.Danger
    MultiTargetStatus.Parent = MultiTargetCard
    
    local MultiTargetStatusCorner = Instance.new("UICorner")
    MultiTargetStatusCorner.CornerRadius = UDim.new(1, 0)
    MultiTargetStatusCorner.Parent = MultiTargetStatus
    
    local MultiTargetStatusText = Instance.new("TextLabel")
    MultiTargetStatusText.Name = "MultiTargetStatusText"
    MultiTargetStatusText.Size = UDim2.new(1, 0, 1, 0)
    MultiTargetStatusText.Text = _G.MultiTarget and "ON" or "OFF"
    MultiTargetStatusText.TextColor3 = Theme.Text
    MultiTargetStatusText.BackgroundTransparency = 1
    MultiTargetStatusText.Font = Enum.Font.GothamBold
    MultiTargetStatusText.TextSize = 10
    MultiTargetStatusText.Parent = MultiTargetStatus
    
    -- Auto Trigger
    local AutoTriggerCard = Instance.new("Frame")
    AutoTriggerCard.Name = "AutoTriggerCard"
    AutoTriggerCard.Size = UDim2.new(1, 0, 0, 60)
    AutoTriggerCard.Position = UDim2.new(0, 0, 0, 140)
    AutoTriggerCard.BackgroundColor3 = Theme.Secondary
    AutoTriggerCard.Parent = SuperContent
    
    local AutoTriggerCorner = Instance.new("UICorner")
    AutoTriggerCorner.CornerRadius = UDim.new(0, 10)
    AutoTriggerCorner.Parent = AutoTriggerCard
    
    local AutoTriggerBtn = Instance.new("TextButton")
    AutoTriggerBtn.Name = "AutoTriggerBtn"
    AutoTriggerBtn.Size = UDim2.new(1, 0, 1, 0)
    AutoTriggerBtn.BackgroundTransparency = 1
    AutoTriggerBtn.Text = ""
    AutoTriggerBtn.Parent = AutoTriggerCard
    
    local AutoTriggerIcon = Instance.new("TextLabel")
    AutoTriggerIcon.Name = "AutoTriggerIcon"
    AutoTriggerIcon.Size = UDim2.new(0, 35, 0, 35)
    AutoTriggerIcon.Position = UDim2.new(0.05, 0, 0.2, 0)
    AutoTriggerIcon.Text = "🔫"
    AutoTriggerIcon.TextColor3 = _G.AutoTrigger and Theme.Success or Theme.TextSecondary
    AutoTriggerIcon.BackgroundTransparency = 1
    AutoTriggerIcon.Font = Enum.Font.GothamBold
    AutoTriggerIcon.TextSize = 24
    AutoTriggerIcon.Parent = AutoTriggerCard
    
    local AutoTriggerText = Instance.new("TextLabel")
    AutoTriggerText.Name = "AutoTriggerText"
    AutoTriggerText.Size = UDim2.new(0.6, 0, 0.4, 0)
    AutoTriggerText.Position = UDim2.new(0.2, 0, 0.2, 0)
    AutoTriggerText.Text = "Auto Trigger: " .. (_G.AutoTrigger and "ON" or "OFF")
    AutoTriggerText.TextColor3 = Theme.Text
    AutoTriggerText.BackgroundTransparency = 1
    AutoTriggerText.Font = Enum.Font.GothamBold
    AutoTriggerText.TextSize = 12
    AutoTriggerText.TextXAlignment = Enum.TextXAlignment.Left
    AutoTriggerText.Parent = AutoTriggerCard
    
    local AutoTriggerLabel = Instance.new("TextLabel")
    AutoTriggerLabel.Name = "AutoTriggerLabel"
    AutoTriggerLabel.Size = UDim2.new(0.6, 0, 0.3, 0)
    AutoTriggerLabel.Position = UDim2.new(0.2, 0, 0.6, 0)
    AutoTriggerLabel.Text = "Atirar automaticamente"
    AutoTriggerLabel.TextColor3 = Theme.TextSecondary
    AutoTriggerLabel.BackgroundTransparency = 1
    AutoTriggerLabel.Font = Enum.Font.Gotham
    AutoTriggerLabel.TextSize = 9
    AutoTriggerLabel.TextXAlignment = Enum.TextXAlignment.Left
    AutoTriggerLabel.Parent = AutoTriggerCard
    
    local AutoTriggerStatus = Instance.new("Frame")
    AutoTriggerStatus.Name = "AutoTriggerStatus"
    AutoTriggerStatus.Size = UDim2.new(0, 40, 0, 20)
    AutoTriggerStatus.Position = UDim2.new(0.8, -20, 0.4, -10)
    AutoTriggerStatus.BackgroundColor3 = _G.AutoTrigger and Theme.Success or Theme.Danger
    AutoTriggerStatus.Parent = AutoTriggerCard
    
    local AutoTriggerStatusCorner = Instance.new("UICorner")
    AutoTriggerStatusCorner.CornerRadius = UDim.new(1, 0)
    AutoTriggerStatusCorner.Parent = AutoTriggerStatus
    
    local AutoTriggerStatusText = Instance.new("TextLabel")
    AutoTriggerStatusText.Name = "AutoTriggerStatusText"
    AutoTriggerStatusText.Size = UDim2.new(1, 0, 1, 0)
    AutoTriggerStatusText.Text = _G.AutoTrigger and "ON" or "OFF"
    AutoTriggerStatusText.TextColor3 = Theme.Text
    AutoTriggerStatusText.BackgroundTransparency = 1
    AutoTriggerStatusText.Font = Enum.Font.GothamBold
    AutoTriggerStatusText.TextSize = 10
    AutoTriggerStatusText.Parent = AutoTriggerStatus
    
    SuperContent.CanvasSize = UDim2.new(0, 0, 0, 210)
    
    --// CONTEÚDO DA ABA INFO
    local InfoContent = TabContents["Info"]
    
    -- Botão de Highlight Target
    local HighlightCard = Instance.new("Frame")
    HighlightCard.Name = "HighlightCard"
    HighlightCard.Size = UDim2.new(1, 0, 0, 60)
    HighlightCard.Position = UDim2.new(0, 0, 0, 0)
    HighlightCard.BackgroundColor3 = Theme.Secondary
    HighlightCard.Parent = InfoContent
    
    local HighlightCorner = Instance.new("UICorner")
    HighlightCorner.CornerRadius = UDim.new(0, 10)
    HighlightCorner.Parent = HighlightCard
    
    local HighlightBtn = Instance.new("TextButton")
    HighlightBtn.Name = "HighlightBtn"
    HighlightBtn.Size = UDim2.new(1, 0, 1, 0)
    HighlightBtn.BackgroundTransparency = 1
    HighlightBtn.Text = ""
    HighlightBtn.Parent = HighlightCard
    
    local HighlightIcon = Instance.new("TextLabel")
    HighlightIcon.Name = "HighlightIcon"
    HighlightIcon.Size = UDim2.new(0, 35, 0, 35)
    HighlightIcon.Position = UDim2.new(0.05, 0, 0.2, 0)
    HighlightIcon.Text = "✨"
    HighlightIcon.TextColor3 = Theme.Warning
    HighlightIcon.BackgroundTransparency = 1
    HighlightIcon.Font = Enum.Font.GothamBold
    HighlightIcon.TextSize = 24
    HighlightIcon.Parent = HighlightCard
    
    local HighlightText = Instance.new("TextLabel")
    HighlightText.Name = "HighlightText"
    HighlightText.Size = UDim2.new(0.6, 0, 0.4, 0)
    HighlightText.Position = UDim2.new(0.2, 0, 0.2, 0)
    HighlightText.Text = "Highlight: " .. (_G.HighlightTarget and "ON" or "OFF")
    HighlightText.TextColor3 = Theme.Text
    HighlightText.BackgroundTransparency = 1
    HighlightText.Font = Enum.Font.GothamBold
    HighlightText.TextSize = 12
    HighlightText.TextXAlignment = Enum.TextXAlignment.Left
    HighlightText.Parent = HighlightCard
    
    local HighlightLabel = Instance.new("TextLabel")
    HighlightLabel.Name = "HighlightLabel"
    HighlightLabel.Size = UDim2.new(0.6, 0, 0.3, 0)
    HighlightLabel.Position = UDim2.new(0.2, 0, 0.6, 0)
    HighlightLabel.Text = "Destacar alvo com brilho"
    HighlightLabel.TextColor3 = Theme.TextSecondary
    HighlightLabel.BackgroundTransparency = 1
    HighlightLabel.Font = Enum.Font.Gotham
    HighlightLabel.TextSize = 9
    HighlightLabel.TextXAlignment = Enum.TextXAlignment.Left
    HighlightLabel.Parent = HighlightCard
    
    local HighlightStatus = Instance.new("Frame")
    HighlightStatus.Name = "HighlightStatus"
    HighlightStatus.Size = UDim2.new(0, 40, 0, 20)
    HighlightStatus.Position = UDim2.new(0.8, -20, 0.4, -10)
    HighlightStatus.BackgroundColor3 = _G.HighlightTarget and Theme.Success or Theme.Danger
    HighlightStatus.Parent = HighlightCard
    
    local HighlightStatusCorner = Instance.new("UICorner")
    HighlightStatusCorner.CornerRadius = UDim.new(1, 0)
    HighlightStatusCorner.Parent = HighlightStatus
    
    local HighlightStatusText = Instance.new("TextLabel")
    HighlightStatusText.Name = "HighlightStatusText"
    HighlightStatusText.Size = UDim2.new(1, 0, 1, 0)
    HighlightStatusText.Text = _G.HighlightTarget and "ON" or "OFF"
    HighlightStatusText.TextColor3 = Theme.Text
    HighlightStatusText.BackgroundTransparency = 1
    HighlightStatusText.Font = Enum.Font.GothamBold
    HighlightStatusText.TextSize = 10
    HighlightStatusText.Parent = HighlightStatus
    
    -- Controles individuais de informações
    local InfoControlsCard = Instance.new("Frame")
    InfoControlsCard.Name = "InfoControlsCard"
    InfoControlsCard.Size = UDim2.new(1, 0, 0, 130)
    InfoControlsCard.Position = UDim2.new(0, 0, 0, 70)
    InfoControlsCard.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    InfoControlsCard.BackgroundTransparency = 0.3
    InfoControlsCard.Parent = InfoContent
    
    local InfoControlsCorner = Instance.new("UICorner")
    InfoControlsCorner.CornerRadius = UDim.new(0, 8)
    InfoControlsCorner.Parent = InfoControlsCard
    
    local InfoControlsTitle = Instance.new("TextLabel")
    InfoControlsTitle.Name = "InfoControlsTitle"
    InfoControlsTitle.Size = UDim2.new(1, 0, 0, 20)
    InfoControlsTitle.Position = UDim2.new(0, 0, 0, 5)
    InfoControlsTitle.Text = "Controles de Informações:"
    InfoControlsTitle.TextColor3 = Theme.Text
    InfoControlsTitle.BackgroundTransparency = 1
    InfoControlsTitle.Font = Enum.Font.GothamBold
    InfoControlsTitle.TextSize = 11
    InfoControlsTitle.TextXAlignment = Enum.TextXAlignment.Center
    InfoControlsTitle.Parent = InfoControlsCard
    
    -- Função para criar botões de controle
    local function CreateInfoToggle(name, yPosition, defaultValue, icon, description)
        local container = Instance.new("Frame")
        container.Name = name .. "Container"
        container.Size = UDim2.new(0.9, 0, 0, 25)
        container.Position = UDim2.new(0.05, 0, 0, yPosition)
        container.BackgroundTransparency = 1
        container.Parent = InfoControlsCard
        
        local iconLabel = Instance.new("TextLabel")
        iconLabel.Name = name .. "Icon"
        iconLabel.Size = UDim2.new(0, 20, 0, 20)
        iconLabel.Position = UDim2.new(0, 0, 0, 2)
        iconLabel.Text = icon
        iconLabel.TextColor3 = Theme.Text
        iconLabel.BackgroundTransparency = 1
        iconLabel.Font = Enum.Font.GothamBold
        iconLabel.TextSize = 14
        iconLabel.Parent = container
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Name = name .. "Text"
        textLabel.Size = UDim2.new(0.5, 0, 1, 0)
        textLabel.Position = UDim2.new(0.1, 0, 0, 0)
        textLabel.Text = description
        textLabel.TextColor3 = Theme.TextSecondary
        textLabel.BackgroundTransparency = 1
        textLabel.Font = Enum.Font.Gotham
        textLabel.TextSize = 9
        textLabel.TextXAlignment = Enum.TextXAlignment.Left
        textLabel.Parent = container
        
        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Name = name .. "Btn"
        toggleBtn.Size = UDim2.new(0, 40, 0, 20)
        toggleBtn.Position = UDim2.new(0.8, 0, 0.1, 0)
        toggleBtn.Text = ""
        toggleBtn.BackgroundColor3 = defaultValue and Theme.Success or Theme.Danger
        toggleBtn.Parent = container
        
        local toggleCorner = Instance.new("UICorner")
        toggleCorner.CornerRadius = UDim.new(1, 0)
        toggleCorner.Parent = toggleBtn
        
        local toggleText = Instance.new("TextLabel")
        toggleText.Name = name .. "Status"
        toggleText.Size = UDim2.new(1, 0, 1, 0)
        toggleText.Text = defaultValue and "ON" or "OFF"
        toggleText.TextColor3 = Theme.Text
        toggleText.BackgroundTransparency = 1
        toggleText.Font = Enum.Font.GothamBold
        toggleText.TextSize = 8
        toggleText.Parent = toggleBtn
        
        toggleBtn.MouseButton1Click:Connect(function()
            local newValue = not _G["ShowTarget" .. name]
            _G["ShowTarget" .. name] = newValue
            
            TweenService:Create(toggleBtn, TweenInfo.new(0.2), {
                BackgroundColor3 = newValue and Theme.Success or Theme.Danger
            }):Play()
            
            toggleText.Text = newValue and "ON" or "OFF"
            
            -- Atualizar imediatamente as informações do alvo (CORREÇÃO DO BUG)
            if _G.SilentAim and CurrentTarget then
                UpdateTargetInfo()
            elseif not _G.SilentAim then
                -- Se o SilentAim estiver desligado, garantir que o texto desapareça
                if TargetInfo then
                    TargetInfo.Visible = false
                    TargetInfo.Text = ""
                end
            end
        end)
        
        return container
    end
    
    -- Criar controles individuais
    CreateInfoToggle("Name", 30, _G.ShowTargetName, "👤", "Nome/Tipo")
    CreateInfoToggle("HP", 60, _G.ShowTargetHP, "❤️", "Vida do alvo")
    CreateInfoToggle("Distance", 90, _G.ShowTargetDistance, "📏", "Distância")
    CreateInfoToggle("HitChance", 120, _G.ShowHitChance, "🎯", "Chance de acerto")
    
    InfoContent.CanvasSize = UDim2.new(0, 0, 0, 210)
    
    --// Barra de Status
    local StatusBar = Instance.new("Frame")
    StatusBar.Name = "StatusBar"
    StatusBar.Size = UDim2.new(1, -20, 0, 40)
    StatusBar.Position = UDim2.new(0, 10, 0, 395)  -- Ajustado para 395
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
    
    --// FUNÇÕES DOS SLIDERS CORRIGIDAS
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
    
    local function UpdateHitChance(value)
        _G.HitChance = math.clamp(value, 0, 100)
        HitChanceText.Text = "Hit Chance: " .. math.floor(_G.HitChance) .. "%"
        HitChanceSliderFill.Size = UDim2.new(_G.HitChance / 100, 0, 1, 0)
    end
    
    --// SLIDER DO FOV CORRIGIDO
    local fovConnection = nil
    FOVContainer.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            if fovConnection then
                fovConnection:Disconnect()
                fovConnection = nil
            end
            
            local function onInputChanged(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
                    local relativeX = (input.Position.X - FOVContainer.AbsolutePosition.X) / FOVContainer.AbsoluteSize.X
                    relativeX = math.clamp(relativeX, 0, 1)
                    local value = 50 + (relativeX * (300 - 50))
                    UpdateFOV(value)
                end
            end
            
            local function onInputEnded(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                    if fovConnection then
                        fovConnection:Disconnect()
                        fovConnection = nil
                    end
                    PulseEffect(FOVContainer)
                end
            end
            
            local relativeX = (input.Position.X - FOVContainer.AbsolutePosition.X) / FOVContainer.AbsoluteSize.X
            relativeX = math.clamp(relativeX, 0, 1)
            local value = 50 + (relativeX * (300 - 50))
            UpdateFOV(value)
            
            fovConnection = UserInputService.InputChanged:Connect(onInputChanged)
            
            local endConnection
            endConnection = UserInputService.InputEnded:Connect(function(input)
                onInputEnded(input)
                endConnection:Disconnect()
            end)
        end
    end)
    
    --// SLIDER DA PREDIÇÃO CORRIGIDO
    local predConnection = nil
    PredContainer.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            if predConnection then
                predConnection:Disconnect()
                predConnection = nil
            end
            
            local function onInputChanged(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
                    local relativeX = (input.Position.X - PredContainer.AbsolutePosition.X) / PredContainer.AbsoluteSize.X
                    relativeX = math.clamp(relativeX, 0, 1)
                    local value = relativeX * 0.5
                    UpdatePrediction(value)
                end
            end
            
            local function onInputEnded(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                    if predConnection then
                        predConnection:Disconnect()
                        predConnection = nil
                    end
                    PulseEffect(PredContainer)
                end
            end
            
            local relativeX = (input.Position.X - PredContainer.AbsolutePosition.X) / PredContainer.AbsoluteSize.X
            relativeX = math.clamp(relativeX, 0, 1)
            local value = relativeX * 0.5
            UpdatePrediction(value)
            
            predConnection = UserInputService.InputChanged:Connect(onInputChanged)
            
            local endConnection
            endConnection = UserInputService.InputEnded:Connect(function(input)
                onInputEnded(input)
                endConnection:Disconnect()
            end)
        end
    end)
    
    --// SLIDER DE HIT CHANCE
    local hitChanceConnection = nil
    HitChanceCard.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            if hitChanceConnection then
                hitChanceConnection:Disconnect()
                hitChanceConnection = nil
            end
            
            local function onInputChanged(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
                    local relativeX = (input.Position.X - HitChanceCard.AbsolutePosition.X) / HitChanceCard.AbsoluteSize.X
                    relativeX = math.clamp(relativeX, 0, 1)
                    local value = relativeX * 100
                    UpdateHitChance(value)
                end
            end
            
            local function onInputEnded(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                    if hitChanceConnection then
                        hitChanceConnection:Disconnect()
                        hitChanceConnection = nil
                    end
                    PulseEffect(HitChanceCard)
                end
            end
            
            local relativeX = (input.Position.X - HitChanceCard.AbsolutePosition.X) / HitChanceCard.AbsoluteSize.X
            relativeX = math.clamp(relativeX, 0, 1)
            local value = relativeX * 100
            UpdateHitChance(value)
            
            hitChanceConnection = UserInputService.InputChanged:Connect(onInputChanged)
            
            local endConnection
            endConnection = UserInputService.InputEnded:Connect(function(input)
                onInputEnded(input)
                endConnection:Disconnect()
            end)
        end
    end)
    
    --// FUNÇÕES DOS BOTÕES CORRIGIDAS
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
            
            -- CORREÇÃO DO BUG: Garantir que o texto desapareça quando desativado
            if TargetInfo then
                TargetInfo.Visible = false
                TargetInfo.Text = ""
            end
            
            -- Limpar highlight
            if TargetHighlight then
                TargetHighlight:Destroy()
                TargetHighlight = nil
            end
            
            -- Desativar Super Aimbot se estiver ativo
            if _G.SuperAimbot then
                _G.SuperAimbot = false
                ActivateSuperAimbot()
            end
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
    
    ShowTargetBtn.MouseButton1Click:Connect(function()
        _G.ShowTarget = not _G.ShowTarget
        PulseEffect(ShowTargetCard)
        
        if _G.ShowTarget then
            TweenService:Create(ShowTargetStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Success
            }):Play()
            ShowTargetStatusText.Text = "ON"
            ShowTargetText.Text = "Mostrar Alvo: ON"
            ShowTargetIcon.TextColor3 = Theme.Success
            
            -- Atualizar imediatamente
            if _G.SilentAim and CurrentTarget then
                UpdateTargetInfo()
            end
        else
            TweenService:Create(ShowTargetStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Danger
            }):Play()
            ShowTargetStatusText.Text = "OFF"
            ShowTargetText.Text = "Mostrar Alvo: OFF"
            ShowTargetIcon.TextColor3 = Theme.Danger
            
            -- CORREÇÃO DO BUG: Garantir que o texto desapareça
            if TargetInfo then
                TargetInfo.Visible = false
                TargetInfo.Text = ""
            end
        end
    end)
    
    BulletTeleportBtn.MouseButton1Click:Connect(function()
        _G.BulletTeleport = not _G.BulletTeleport
        PulseEffect(BulletTeleportCard)
        
        if _G.BulletTeleport then
            TweenService:Create(BulletTeleportStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Success
            }):Play()
            BulletTeleportStatusText.Text = "ON"
            BulletTeleportText.Text = "Bullet Teleport: ON"
            BulletTeleportIcon.TextColor3 = Theme.Success
        else
            TweenService:Create(BulletTeleportStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Danger
            }):Play()
            BulletTeleportStatusText.Text = "OFF"
            BulletTeleportText.Text = "Bullet Teleport: OFF"
            BulletTeleportIcon.TextColor3 = Theme.Danger
        end
    end)
    
    HighlightBtn.MouseButton1Click:Connect(function()
        _G.HighlightTarget = not _G.HighlightTarget
        PulseEffect(HighlightCard)
        
        if _G.HighlightTarget then
            TweenService:Create(HighlightStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Success
            }):Play()
            HighlightStatusText.Text = "ON"
            HighlightText.Text = "Highlight: ON"
            HighlightIcon.TextColor3 = Theme.Success
        else
            TweenService:Create(HighlightStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Danger
            }):Play()
            HighlightStatusText.Text = "OFF"
            HighlightText.Text = "Highlight: OFF"
            HighlightIcon.TextColor3 = Theme.Danger
            
            -- Remover highlight se estiver ativo
            if TargetHighlight then
                TargetHighlight:Destroy()
                TargetHighlight = nil
            end
        end
    end)
    
    -- BOTÕES DA ABA NPC
    AggressiveBtn.MouseButton1Click:Connect(function()
        _G.AggressiveNPCDetection = not _G.AggressiveNPCDetection
        PulseEffect(AggressiveCard)
        
        if _G.AggressiveNPCDetection then
            TweenService:Create(AggressiveStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Warning
            }):Play()
            AggressiveStatusText.Text = "ON"
            AggressiveText.Text = "Modo Agressivo: ON"
            AggressiveIcon.TextColor3 = Theme.Warning
            
            -- Forçar atualização do cache
            LastCacheUpdate = 0
            UpdateCaches()
            
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "🎯 MODO AGRESSIVO",
                Text = "ATIVADO - Detectando TODOS como NPCs",
                Duration = 2,
                Icon = "rbxassetid://4483345998"
            })
        else
            TweenService:Create(AggressiveStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Danger
            }):Play()
            AggressiveStatusText.Text = "OFF"
            AggressiveText.Text = "Modo Agressivo: OFF"
            AggressiveIcon.TextColor3 = Theme.TextSecondary
            
            -- Forçar atualização do cache
            LastCacheUpdate = 0
            UpdateCaches()
        end
    end)
    
    DebugBtn.MouseButton1Click:Connect(function()
        _G.DebugNPCs = not _G.DebugNPCs
        PulseEffect(DebugCard)
        
        if _G.DebugNPCs then
            TweenService:Create(DebugStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Info
            }):Play()
            DebugStatusText.Text = "ON"
            DebugText.Text = "Debug NPCs: ON"
            DebugIcon.TextColor3 = Theme.Info
            
            print("[DEBUG NPCs] Ativado - Ver console para detalhes")
        else
            TweenService:Create(DebugStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Danger
            }):Play()
            DebugStatusText.Text = "OFF"
            DebugText.Text = "Debug NPCs: OFF"
            DebugIcon.TextColor3 = Theme.TextSecondary
            
            print("[DEBUG NPCs] Desativado")
        end
    end)
    
    -- BOTÕES DA NOVA ABA SUPER AIMBOT
    SuperBtn.MouseButton1Click:Connect(function()
        _G.SuperAimbot = not _G.SuperAimbot
        PulseEffect(SuperAimbotCard)
        
        ActivateSuperAimbot()  -- Ativar/desativar todas as funções
        
        if _G.SuperAimbot then
            TweenService:Create(SuperStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(255, 50, 50)
            }):Play()
            SuperStatusText.Text = "ON"
            SuperText.Text = "SUPER AIMBOT: ON"
            SuperIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
            
            -- Atualizar outros botões da aba Super
            MultiTargetText.Text = "Multi-Target: ON"
            MultiTargetIcon.TextColor3 = Theme.Success
            TweenService:Create(MultiTargetStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Success
            }):Play()
            MultiTargetStatusText.Text = "ON"
            
            AutoTriggerText.Text = "Auto Trigger: ON"
            AutoTriggerIcon.TextColor3 = Theme.Success
            TweenService:Create(AutoTriggerStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Success
            }):Play()
            AutoTriggerStatusText.Text = "ON"
            
            -- Atualizar configurações na aba Geral
            FOVText.Text = "FOV: 250"
            HitChanceText.Text = "Hit Chance: 100%"
            WallCheckText.Text = "Wall Check: OFF"
            BulletTeleportText.Text = "Bullet Teleport: ON"
            
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "💀 SUPER AIMBOT",
                Text = "MODO APELÃO ATIVADO!\nTodas as vantagens ligadas!",
                Duration = 3,
                Icon = "rbxassetid://4483345998"
            })
        else
            TweenService:Create(SuperStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Danger
            }):Play()
            SuperStatusText.Text = "OFF"
            SuperText.Text = "SUPER AIMBOT: OFF"
            SuperIcon.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end)
    
    MultiTargetBtn.MouseButton1Click:Connect(function()
        _G.MultiTarget = not _G.MultiTarget
        PulseEffect(MultiTargetCard)
        
        if _G.MultiTarget then
            TweenService:Create(MultiTargetStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Success
            }):Play()
            MultiTargetStatusText.Text = "ON"
            MultiTargetText.Text = "Multi-Target: ON"
            MultiTargetIcon.TextColor3 = Theme.Success
        else
            TweenService:Create(MultiTargetStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Danger
            }):Play()
            MultiTargetStatusText.Text = "OFF"
            MultiTargetText.Text = "Multi-Target: OFF"
            MultiTargetIcon.TextColor3 = Theme.TextSecondary
        end
    end)
    
    AutoTriggerBtn.MouseButton1Click:Connect(function()
        _G.AutoTrigger = not _G.AutoTrigger
        PulseEffect(AutoTriggerCard)
        
        if _G.AutoTrigger then
            TweenService:Create(AutoTriggerStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Success
            }):Play()
            AutoTriggerStatusText.Text = "ON"
            AutoTriggerText.Text = "Auto Trigger: ON"
            AutoTriggerIcon.TextColor3 = Theme.Success
            
            -- Iniciar auto shoot
            if not AutoShootConnection and _G.SilentAim then
                task.spawn(function()
                    while _G.AutoTrigger and _G.SilentAim do
                        AutoShoot()
                        task.wait(_G.TriggerDelay)
                    end
                end)
            end
        else
            TweenService:Create(AutoTriggerStatus, TweenInfo.new(0.2), {
                BackgroundColor3 = Theme.Danger
            }):Play()
            AutoTriggerStatusText.Text = "OFF"
            AutoTriggerText.Text = "Auto Trigger: OFF"
            AutoTriggerIcon.TextColor3 = Theme.TextSecondary
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
        MainFrame.Size = UDim2.new(0, 320, 0, 450)
        
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
                    
                    -- Multi-target info
                    if _G.MultiTarget and #SuperTargets > 0 then
                        StatusText.Text = StatusText.Text .. " (" .. #SuperTargets .. " alvos)"
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
                
                -- Super Aimbot indicator
                if _G.SuperAimbot then
                    StatusIcon.Text = "💀"
                    StatusIcon.TextColor3 = Color3.fromRGB(255, 50, 150)
                    StatusText.Text = "SUPER MODE"
                end
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
        Size = UDim2.new(0, 320, 0, 450)
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
        Title = "🎯 SILENT AIM v3.0",
        Text = "NOVA ABA 'SUPER' ADICIONADA!\n• Super Aimbot APELÃO\n• Multi-Target\n• Auto Trigger\n• Instant Kill",
        Duration = 3,
        Icon = "rbxassetid://4483345998"
    })
    
    print([[
╔══════════════════════════════════════════════╗
║        SILENT AIM - SUPER EDITION            ║
║                 VERSION 3.0                  ║
║                                              ║
║  ✓ NOVA ABA "SUPER" NO MENU                  ║
║     • Super Aimbot (tudo ligado)             ║
║     • Multi-Target (até 5 alvos)             ║
║     • Auto Trigger (tiro automático)         ║
║     • Instant Kill (morte instantânea)       ║
║     • Ignore All Walls (atravessa tudo)      ║
║     • Instant Aim (mira instantânea)         ║
║                                              ║
║  Sistema carregado com sucesso!              ║
╚══════════════════════════════════════════════╝]])
    
    -- Exibir ajuda de comandos
    print("\n[COMANDOS SUPER AIMBOT]")
    print("1. Super Aimbot: " .. tostring(_G.SuperAimbot))
    print("2. Multi-Target: " .. tostring(_G.MultiTarget))
    print("3. Auto Trigger: " .. tostring(_G.AutoTrigger))
    print("4. Instant Kill: " .. tostring(_G.InstantKill))
    print("5. Ignore All Walls: " .. tostring(_G.IgnoreAllWalls))
end)

--// LIMPEZA
game:GetService("Players").PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        CleanupUIOnly()
    end
end)
[file content end]