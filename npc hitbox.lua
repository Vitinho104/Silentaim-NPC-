--[[
Script Original por: !vcsk0#1516
Portado para Obsidian UI por: Gemini
Modificado para suporte a NPCs + Head/Body Hitbox + Melee Support
Otimizado para redução de lag por: Claude
Integração Client Pull por: DeepSeek
ATUALIZADO: Adicionado modos Stepped e Simulation no Pull Mode
MODIFICADO: Client Pull agora puxa TODOS os NPCs para o MESMO ponto (distante do jogador)
ATUALIZADO v7: Client Pull em modo agressivo para QUALQUER NPC (inclusive sem tags)
OTIMIZADO v8: Redução drástica de lag no Client Pull com cache, throttle e limite de NPCs

CORREÇÕES v6 (AUTO-RESPAWN & ANTI-DESYNC FIX):
  - Vigilância Ativa: Se o jogo restaurar o tamanho do player/npc no respawn, o script força a hitbox automaticamente.
  - Deep Scan: Detecta NPCs que renascem dentro de sub-pastas profundas no Workspace.
  - Health Check: Não tenta aplicar hitbox em cadáveres/modelos mortos.
  - Memory Garbage Collector: Limpa memória de NPCs mortos a cada 10s para zero lag.
]]

-- ==========================================
-- [[ 1. SERVIÇOS ]]
-- ==========================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local function isNumber(str)
    return tonumber(str) ~= nil or str == 'inf'
end

-- ==========================================
-- [[ 2. VARIÁVEIS GLOBAIS ]]
-- ==========================================
getgenv().HitboxSize             = 15
getgenv().HeadHitboxSize         = 10
getgenv().HitboxTransparency     = 0.9
getgenv().HitboxStatus           = false
getgenv().HeadHitbox             = false
getgenv().BodyHitbox             = false
getgenv().TeamCheck              = false
getgenv().NPCHitbox              = false
getgenv().MeleeHitbox            = false
getgenv().MeleeSize              = 5
getgenv().AggressiveNPCDetection = false
getgenv().PlayerHitbox           = true

getgenv().Walkspeed = 16
getgenv().Jumppower = 50
getgenv().loopW     = false
getgenv().loopJ     = false

getgenv().TPSpeed = 3
getgenv().TPWalk  = false
getgenv().Noclip  = false
getgenv().InfJ    = false

-- CLIENT PULL VARIABLES (OTIMIZADAS)
getgenv().ClientPullEnabled = false
getgenv().ClientPullDistance = 10
getgenv().ClientPullMode = "Heartbeat" -- Mudado para Heartbeat por padrão (mais eficiente)
getgenv().ClientPullAggressive = false
getgenv().PullThrottleTime = 0.15 -- Tempo entre pulls (maior = menos lag)
getgenv().MaxNPCsToPull = 30 -- Máximo de NPCs puxados por frame
getgenv().PullOnlyNear = false -- Puxar apenas NPCs próximos

-- ==========================================
-- [[ 3. CARREGANDO OBSIDIAN ]]
-- ==========================================
local repo        = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library     = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title = 'Hitbox Expander | Obsidian',
    Center = true,
    AutoShow = true,
    TabPadding = 8
})

-- ==========================================
-- [[ 4. ABAS ]]
-- ==========================================
local Tabs = {
    Home    = Window:AddTab('Home'),
    Players = Window:AddTab('Players'),
    Visuals = Window:AddTab('Visuals'),
    Pull    = Window:AddTab('Client Pull') -- NOVA ABA
}
if game.PlaceId == 3082002798 then
    Tabs.Games = Window:AddTab('Games')
end
Tabs.Settings = Window:AddTab('UI Settings')

-- ==========================================
-- [[ 5. UI — ABA HOME ]]
-- ==========================================
local HitboxSettings = Tabs.Home:AddLeftGroupbox('Settings')
local HitboxMain     = Tabs.Home:AddRightGroupbox('Main')
local HitboxNPC      = Tabs.Home:AddLeftGroupbox('NPC Detection')

HitboxSettings:AddSlider('HBSize', {
    Text = 'Body Size', Default = 15, Min = 1, Max = 100, Rounding = 1, Compact = false,
    Callback = function(v) getgenv().HitboxSize = v end
})
HitboxSettings:AddSlider('HBHeadSize', {
    Text = 'Head Size', Default = 10, Min = 1, Max = 100, Rounding = 1, Compact = false,
    Callback = function(v) getgenv().HeadHitboxSize = v end
})
HitboxSettings:AddSlider('HBTrans', {
    Text = 'Transparency', Default = 0.9, Min = 0, Max = 1, Rounding = 2, Compact = false,
    Callback = function(v) getgenv().HitboxTransparency = v end
})
HitboxSettings:AddSlider('MeleeSize', {
    Text = 'Melee Hitbox Size', Default = 5, Min = 1, Max = 50, Rounding = 1, Compact = false,
    Callback = function(v) getgenv().MeleeSize = v end
})

HitboxMain:AddToggle('HBStatus', {
    Text = 'Status', Default = false, Tooltip = 'Liga/Desliga a Hitbox geral',
    Callback = function(v) getgenv().HitboxStatus = v end
})
HitboxMain:AddToggle('HBTeam', {
    Text = 'Team Check', Default = false,
    Callback = function(v) getgenv().TeamCheck = v end
})
HitboxMain:AddToggle('HBNpc', {
    Text = 'NPC Hitbox', Default = false, Tooltip = 'Liga/Desliga hitbox em NPCs',
    Callback = function(v)
        getgenv().NPCHitbox = v
        if v then npcCache = {}; npcCacheDirty = true; task.spawn(scanNPCs) end
    end
})
HitboxMain:AddToggle('HBPlayers', {
    Text = 'Player Hitbox', Default = true, Tooltip = 'Liga/Desliga hitbox em players',
    Callback = function(v) getgenv().PlayerHitbox = v end
})
HitboxMain:AddToggle('HBHead', {
    Text = 'Head Hitbox', Default = false, Tooltip = 'Expande a cabeça',
    Callback = function(v) getgenv().HeadHitbox = v end
})
HitboxMain:AddToggle('HBBody', {
    Text = 'Body Hitbox', Default = false, Tooltip = 'Expande o corpo',
    Callback = function(v) getgenv().BodyHitbox = v end
})
HitboxMain:AddToggle('HBMelee', {
    Text = 'Melee Hitbox', Default = false, Tooltip = 'Expande todas as partes para melee',
    Callback = function(v) getgenv().MeleeHitbox = v end
})

HitboxNPC:AddToggle('HBNpcAgressivo', {
    Text = 'Modo Agressivo Extremo',
    Default = false,
    Tooltip = 'Detecta qualquer Model com Humanoid ou estrutura básica, garantindo 100% de detecção.',
    Callback = function(v)
        getgenv().AggressiveNPCDetection = v
        npcCache = {}; npcCacheDirty = true
        if getgenv().NPCHitbox then task.spawn(scanNPCs) end
        Library:Notify(v and '⚠️ MODO AGRESSIVO EXTREMO ATIVADO' or 'Modo normal de NPC ativado', 2)
    end
})
HitboxNPC:AddButton({
    Text = 'Forçar Rescan de NPCs',
    Func = function()
        npcCache = {}; npcCacheDirty = true
        task.spawn(scanNPCs)
        Library:Notify('Cache de NPC atualizado!', 1)
    end
})
HitboxNPC:AddLabel('Normal: tags/pastas/CollectionService')
HitboxNPC:AddLabel('Agressivo: Qualquer Model+Humanoid')

-- ==========================================
-- [[ 6. UI — ABA CLIENT PULL (COM OPÇÕES DE LAG) ]]
-- ==========================================
local PullGroup = Tabs.Pull:AddLeftGroupbox('Client Pull Settings')
local PullOptimization = Tabs.Pull:AddRightGroupbox('Otimizações Anti-Lag')

PullGroup:AddToggle('ClientPullToggle', {
    Text = 'Enable Client Pull', Default = false,
    Callback = function(v) getgenv().ClientPullEnabled = v end
})
PullGroup:AddSlider('ClientPullDist', {
    Text = 'Pull Distance', Default = 10, Min = 1, Max = 50, Rounding = 1,
    Callback = function(v) getgenv().ClientPullDistance = v end
})
PullGroup:AddDropdown('ClientPullMode', {
    Text = 'Pull Mode',
    Default = 'Heartbeat',
    Options = {'RenderStepped', 'Heartbeat', 'Stepped', 'Simulation'},
    Callback = function(v) getgenv().ClientPullMode = v end
})
PullGroup:AddToggle('ClientPullAggressive', {
    Text = '🔴 Modo Agressivo (QUALQUER NPC)',
    Default = false,
    Tooltip = 'Puxa QUALQUER modelo que pareça ser um NPC, mesmo sem tags ou identificadores',
    Callback = function(v) 
        getgenv().ClientPullAggressive = v
        Library:Notify(v and '⚠️ CLIENT PULL AGRESSIVO ATIVADO' or 'Client Pull normal ativado', 2)
    end
})

-- OTIMIZAÇÕES ANTI-LAG
PullOptimization:AddSlider('PullThrottle', {
    Text = 'Throttle (s) (↑ = ↓ Lag)', 
    Default = 0.15, Min = 0.05, Max = 0.5, Rounding = 2,
    Tooltip = 'Intervalo entre pulls. Maior = menos lag, menor = mais suave',
    Callback = function(v) getgenv().PullThrottleTime = v end
})
PullOptimization:AddSlider('MaxNPCs', {
    Text = 'Max NPCs por frame', 
    Default = 30, Min = 5, Max = 100, Rounding = 0,
    Tooltip = 'Máximo de NPCs puxados em cada frame',
    Callback = function(v) getgenv().MaxNPCsToPull = v end
})
PullOptimization:AddToggle('PullOnlyNear', {
    Text = 'Puxar só NPCs próximos (< 50 studs)',
    Default = false,
    Tooltip = 'Só puxa NPCs a menos de 50 studs do jogador',
    Callback = function(v) getgenv().PullOnlyNear = v end
})
PullOptimization:AddToggle('PullLowPerf', {
    Text = 'Modo Baixa Performance',
    Default = false,
    Tooltip = 'Reduz ainda mais o lag (throttle 0.3s, max 15 NPCs)',
    Callback = function(v)
        if v then
            getgenv().PullThrottleTime = 0.3
            getgenv().MaxNPCsToPull = 15
            Library:Notify('🟡 Modo baixa performance ativado', 2)
        else
            getgenv().PullThrottleTime = 0.15
            getgenv().MaxNPCsToPull = 30
            Library:Notify('🟢 Performance normal restaurada', 2)
        end
    end
})
PullOptimization:AddLabel('⚡ Dica: Use Throttle 0.15 e Max 30 para melhor equilíbrio')

-- ==========================================
-- [[ 7. SISTEMA DE HITBOX (ANTI-DESYNC) ]]
-- ==========================================
local partData  = {}   
local charState = {}   
local npcCache      = {}
local npcCacheDirty = true

local function savePart(part)
    if part and not partData[part] then
        partData[part] = {
            size         = part.Size,
            transparency = part.Transparency,
            material     = part.Material,
            brickColor   = part.BrickColor,
            canCollide   = part.CanCollide,
            massless     = part.Massless,
        }
    end
end

local function restorePart(part)
    if not part then return end
    local d = partData[part]
    if not d then return end
    part.Size         = d.size
    part.Transparency = d.transparency
    part.Material     = d.material
    part.BrickColor   = d.brickColor
    part.CanCollide   = d.canCollide
    part.Massless     = d.massless
end

local function makeSnapshot(active, color)
    local g = getgenv()
    return {
        active    = active,
        color     = color or "",
        body      = g.BodyHitbox,
        head      = g.HeadHitbox,
        melee     = g.MeleeHitbox,
        bodySize  = g.HitboxSize,
        headSize  = g.HeadHitboxSize,
        meleeSize = g.MeleeSize,
        trans     = g.HitboxTransparency,
    }
end

local function getRootPart(character)
    return character:FindFirstChild("HumanoidRootPart") 
        or character.PrimaryPart 
        or character:FindFirstChild("Torso") 
        or character:FindFirstChild("UpperTorso")
end

-- VIGILÂNCIA ATIVA: Checa se o tamanho da peça no jogo está igual ao do menu
local function isStateDesynced(character, active, color)
    local s = charState[character]
    if not s then return true end -- Personagem novo (Respawn)
    
    local g = getgenv()
    -- Checa se as configs do UI mudaram
    if s.active ~= active or s.color ~= (color or "") or s.body ~= g.BodyHitbox or s.head ~= g.HeadHitbox or s.melee ~= g.MeleeHitbox or s.bodySize ~= g.HitboxSize or s.headSize ~= g.HeadHitboxSize or s.meleeSize ~= g.MeleeSize or s.trans ~= g.HitboxTransparency then
        return true
    end
    
    -- Checa se O JOGO tentou reduzir a hitbox depois do respawn/auto-scale
    if active then
        local hrp = getRootPart(character)
        if g.BodyHitbox and hrp and hrp:IsA("BasePart") then
            if math.abs(hrp.Size.X - g.HitboxSize) > 0.1 or math.abs(hrp.Transparency - g.HitboxTransparency) > 0.05 then return true end
        end
        
        local head = character:FindFirstChild("Head")
        if g.HeadHitbox and head and head:IsA("BasePart") then
            if math.abs(head.Size.X - g.HeadHitboxSize) > 0.1 or math.abs(head.Transparency - g.HitboxTransparency) > 0.05 then return true end
        end
    end
    
    return false
end

local function applyHitbox(character, color)
    local g    = getgenv()
    local hrp  = getRootPart(character)
    local head = character:FindFirstChild("Head")

    local missingParts = false
    if g.BodyHitbox and not hrp then missingParts = true end
    if g.HeadHitbox and not head then missingParts = true end
    if missingParts then return end

    if not isStateDesynced(character, true, color) then return end

    -- Body Hitbox
    if hrp and hrp:IsA("BasePart") then
        savePart(hrp)
        if g.BodyHitbox then
            local s = g.HitboxSize
            hrp.Size         = Vector3.new(s, s, s)
            hrp.Transparency = g.HitboxTransparency
            hrp.BrickColor   = BrickColor.new(color)
            hrp.Material     = Enum.Material.Neon
            hrp.CanCollide   = false
        else
            restorePart(hrp)
        end
    end

    -- Head Hitbox
    if head and head:IsA("BasePart") then
        savePart(head)
        if g.HeadHitbox then
            local s = g.HeadHitboxSize
            head.Size         = Vector3.new(s, s, s)
            head.Transparency = g.HitboxTransparency
            head.BrickColor   = BrickColor.new(color)
            head.Material     = Enum.Material.Neon
            head.CanCollide   = false
            head.Massless     = true
        else
            restorePart(head)
        end
    end

    -- Melee Hitbox
    for _, part in next, character:GetChildren() do
        if part:IsA("BasePart") and part.Name ~= (hrp and hrp.Name or "") and part.Name ~= "Head" then
            pcall(function()
                savePart(part)
                if g.MeleeHitbox then
                    local s = g.MeleeSize
                    part.Size         = partData[part].size + Vector3.new(s, s, s)
                    part.Transparency = g.HitboxTransparency
                    part.CanCollide   = false
                    part.Massless     = true
                else
                    restorePart(part)
                end
            end)
        end
    end

    charState[character] = makeSnapshot(true, color)
end

local function resetHitbox(character)
    if not isStateDesynced(character, false, "") then return end

    local hrp  = getRootPart(character)
    local head = character:FindFirstChild("Head")

    if hrp  then restorePart(hrp)  end
    if head then restorePart(head) end

    for _, part in next, character:GetChildren() do
        if part:IsA("BasePart") and part.Name ~= (hrp and hrp.Name or "") and part.Name ~= "Head" then
            pcall(function() restorePart(part) end)
        end
    end

    charState[character] = makeSnapshot(false, "")
end

local function cleanupCharacter(character)
    charState[character] = nil
    for _, part in next, character:GetDescendants() do
        if part:IsA("BasePart") then
            partData[part] = nil
        end
    end
end

local function hookCleanup(player)
    player.CharacterAdded:Connect(function(chr)
        chr.AncestryChanged:Connect(function(_, p) if not p then cleanupCharacter(chr) end end)
    end)
    if player.Character then
        player.Character.AncestryChanged:Connect(function(_, p)
            if not p then cleanupCharacter(player.Character) end
        end)
    end
end
for _, p in next, Players:GetPlayers() do hookCleanup(p) end
Players.PlayerAdded:Connect(hookCleanup)

-- ==========================================
-- [[ 8. DETECÇÃO DE NPC (DEEP SCAN) ]]
-- ==========================================
local NPCTags = {
    "NPC","Npc","npc","Enemy","enemy","Enemies","enemies","Hostile","hostile","Bad","bad",
    "BadGuy","badguy","Foe","foe","Opponent","opponent","Bot","bot","Bots","bots","Mob",
    "mob","Mobs","mobs","Monster","monster","Monsters","monsters","Zombie","zombie",
    "Zombies","zombies","Creature","creature","Animal","animal","Beast","beast","Villain",
    "villain","Boss","boss","MiniBoss","miniboss","Guard","guard","Guardian","guardian",
    "Soldier","soldier","Warrior","warrior","Fighter","fighter","Target","target","Dummy",
    "dummy","Dummies","dummies","Training","training","Skeleton","skeleton","Orc","orc",
    "Goblin","goblin","Troll","troll","Ogre","ogre","Demon","demon","Devil","devil",
    "Ghost","ghost","Spirit","spirit","Vampire","vampire","Werewolf","werewolf","Dragon",
    "dragon","Gang","gang","Thug","thug","Bandit","bandit","Raider","raider","Pirate",
    "pirate","Agent","agent","Assassin","assassin","Mercenary","mercenary","Hunter",
    "hunter","Robot","robot","Drone","drone","Android","android","Cyborg","cyborg",
    "Minion","minion","Pawn","pawn","AI","ai","Char","char","Character","character","Model",
    "model","Event","event","Special","special","Holiday","holiday","Seasonal","seasonal"
}

local NPCFolders = {
    "NPCs","Enemies","Bots","Mobs","Targets","Enemy","Hostile",
    "Monsters","Zombies","Creatures","Characters","Spawns",
    "EnemySpawns","NPCSpawns","Bosses","Minions"
}

local function IsPlayerCharacter(model)
    if not model or not model:IsA("Model") then return false end
    if model == Players.LocalPlayer.Character then return true end
    return Players:GetPlayerFromCharacter(model) ~= nil
end

local function IsNPC(model)
    if not model or not model:IsA("Model") then return false end
    if IsPlayerCharacter(model) then return false end
    
    local hasHumanoid = model:FindFirstChildWhichIsA("Humanoid")
    
    if getgenv().AggressiveNPCDetection then
        if hasHumanoid then return true end
        if model:FindFirstChild("Head") and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")) then
            return true
        end
        return false
    end

    if not hasHumanoid then return false end
    if not model:FindFirstChild("Head") then return false end
    if not getRootPart(model) then return false end

    local name = model.Name:lower()
    for _, tag in next, NPCTags do
        if name:find(tag:lower(), 1, true) then return true end
    end
    for _, fn in next, NPCFolders do
        local f = workspace:FindFirstChild(fn)
        if f and model:IsDescendantOf(f) then return true end
    end
    for _, ind in next, {"NPC","IsNPC","IsEnemy","Hostile","Enemy","IsBot","IsMob","IsMonster"} do
        local val = model:FindFirstChild(ind)
        if val then
            if val:IsA("BoolValue") and val.Value == true then return true end
            if val:IsA("StringValue") and (val.Value:lower() == "enemy" or val.Value:lower() == "hostile" or val.Value:lower() == "npc" or val.Value:lower() == "bot") then return true end
        end
    end
    for _, tag in next, CollectionService:GetTags(model) do
        local tl = tag:lower()
        for _, nt in next, NPCTags do
            if tl:find(nt:lower(), 1, true) then return true end
        end
    end

    return true
end

-- ==========================================
-- [[ 8.1 FUNÇÃO PARA DETECTAR NPC DE FORMA AGRESSIVA (PARA O PULL) ]]
-- ==========================================
local function IsAnyNPC(model)
    if not model or not model:IsA("Model") then return false end
    if IsPlayerCharacter(model) then return false end
    
    -- Verifica se tem Humanoid (mais comum)
    if model:FindFirstChildWhichIsA("Humanoid") then
        return true
    end
    
    -- Verifica se tem estrutura de personagem (cabeça + tronco ou root)
    if model:FindFirstChild("Head") then
        if model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso") then
            return true
        end
    end
    
    -- Verifica se tem partes básicas que indicam um NPC
    local parts = 0
    for _, child in pairs(model:GetChildren()) do
        if child:IsA("BasePart") then
            parts = parts + 1
            if parts >= 3 then -- Se tiver pelo menos 3 partes, provavelmente é um NPC
                return true
            end
        end
    end
    
    return false
end

local function FindNPCsRecursive(parent, results)
    for _, child in next, parent:GetChildren() do
        if child:IsA("Model") and IsNPC(child) then
            table.insert(results, child)
        end
        if child:IsA("Folder") or child:IsA("Model") then
            FindNPCsRecursive(child, results)
        end
    end
end

function scanNPCs()
    local found = {}
    if getgenv().AggressiveNPCDetection then
        local counter = 0
        for _, desc in next, workspace:GetDescendants() do
            if desc:IsA("Model") and IsNPC(desc) then
                table.insert(found, desc)
            end
            counter = counter + 1
            if counter % 150 == 0 then task.wait() end
        end
    else
        for _, model in next, workspace:GetChildren() do
            if model:IsA("Model") and IsNPC(model) then
                table.insert(found, model)
            end
            if model:IsA("Folder") or model:IsA("Model") then
                for _, fn in next, NPCFolders do
                    if model.Name == fn then
                        FindNPCsRecursive(model, found)
                        break
                    end
                end
            end
        end
    end
    npcCache = found
    npcCacheDirty = false
end

-- DEEP SCAN: Detecta NPCs renascendo no fundo de pastas, com anti-lag throttle
local scanTick = 0
workspace.DescendantAdded:Connect(function(c)
    if c:IsA("Model") or c:IsA("Humanoid") then
        if tick() - scanTick > 1 then
            scanTick = tick()
            npcCacheDirty = true
        end
    end
end)

task.spawn(function() task.wait(1); scanNPCs() end)

-- ==========================================
-- [[ 9. FUNÇÃO CLIENT PULL OTIMIZADA (ANTI-LAG) ]]
-- ==========================================
local pullCache = {}
local pullCacheTime = 0
local NPCsToPull = {}

local function shouldPullNPC(npc)
    if not npc or not npc.Parent then return false end
    local hrp = npc:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    return true
end

local function getNPCRoot(npc)
    return npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso") or npc:FindFirstChild("UpperTorso")
end

local function pullNPCs()
    if not getgenv().ClientPullEnabled then return end

    local player = Players.LocalPlayer
    local char = player.Character
    if not char then return end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local pullDist = getgenv().ClientPullDistance or 10
    local targetPoint = rootPart.Position + rootPart.CFrame.LookVector * pullDist
    
    -- SÓ ATUALIZA O CACHE A CADA 2 SEGUNDOS (REDUZ LAG)
    local currentTime = tick()
    if currentTime - pullCacheTime > 2 then
        pullCacheTime = currentTime
        NPCsToPull = {}
        
        local aggressive = getgenv().ClientPullAggressive or false
        
        if aggressive then
            -- Modo agressivo: varre tudo (mas só a cada 2s)
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("Model") and obj:FindFirstChild("HumanoidRootPart") then
                    if not IsPlayerCharacter(obj) and IsAnyNPC(obj) then
                        table.insert(NPCsToPull, obj)
                    end
                end
                -- Limite de iterações por frame para não travar
                if #NPCsToPull > 200 then break end
            end
        else
            -- Modo normal: usa cache de NPCs existente
            for _, npc in pairs(npcCache) do
                if shouldPullNPC(npc) then
                    table.insert(NPCsToPull, npc)
                end
            end
        end
    end

    -- PUXA APENAS NPCs PRÓXIMOS (FILTRO DE DISTÂNCIA)
    local maxPullRange = getgenv().PullOnlyNear and 50 or 150 -- 50 se modo only near, 150 normal
    local rootPos = rootPart.Position
    
    local maxNPCs = getgenv().MaxNPCsToPull or 30
    
    for i = 1, math.min(#NPCsToPull, maxNPCs) do -- LIMITE MÁXIMO DE NPCs POR FRAME
        local npc = NPCsToPull[i]
        if npc and npc.Parent then
            local npcRoot = getNPCRoot(npc)
            if npcRoot then
                -- Verifica distância antes de puxar
                local distance = (npcRoot.Position - rootPos).Magnitude
                if distance < maxPullRange then
                    npcRoot.CFrame = CFrame.new(targetPoint)
                end
            end
        end
    end
end

-- ==========================================
-- [[ 10. LOOP ÚNICO UNIFICADO (COM THROTTLE) ]]
-- ==========================================
local localPlayer    = Players.LocalPlayer
local hitboxThrottle = 0
local movThrottle    = 0
local noclipThrottle = 0
local lastGC         = tick()
local pullThrottle   = 0

-- LOOP PRINCIPAL (Heartbeat)
RunService.Heartbeat:Connect(function(dt)
    -- CLIENT PULL COM THROTTLE (EXECUTA A CADA X SEGUNDOS)
    local mode = getgenv().ClientPullMode or "Heartbeat"
    local throttleTime = getgenv().PullThrottleTime or 0.15
    
    -- SÓ EXECUTA O PULL SE O MODO FOR Heartbeat OU Simulation
    if mode == "Heartbeat" or mode == "Simulation" then
        if getgenv().ClientPullEnabled then
            pullThrottle = pullThrottle + dt
            if pullThrottle >= throttleTime then
                pullThrottle = 0
                pcall(pullNPCs)
            end
        end
    end
    
    -- Garbage Collector (Limpa memória de quem já morreu)
    if tick() - lastGC > 10 then
        lastGC = tick()
        for char, _ in pairs(charState) do
            if not char.Parent then cleanupCharacter(char) end
        end
    end

    -- MOVIMENTO (WalkSpeed e JumpPower)
    movThrottle = movThrottle + dt
    if movThrottle >= 0.05 then
        movThrottle = 0
        if getgenv().loopW then
            pcall(function() localPlayer.Character.Humanoid.WalkSpeed = getgenv().Walkspeed end)
        end
        if getgenv().loopJ then
            pcall(function() localPlayer.Character.Humanoid.JumpPower = getgenv().Jumppower end)
        end
    end

    -- NOCLIP
    noclipThrottle = noclipThrottle + dt
    if noclipThrottle >= 0.1 then
        noclipThrottle = 0
        if getgenv().Noclip then
            pcall(function()
                localPlayer.Character.Head.CanCollide  = false
                localPlayer.Character.Torso.CanCollide = false
            end)
        end
    end

    -- HITBOX
    hitboxThrottle = hitboxThrottle + dt
    if hitboxThrottle < 0.1 then return end
    hitboxThrottle = 0

    local anyOn = getgenv().HeadHitbox or getgenv().BodyHitbox or getgenv().MeleeHitbox

    if getgenv().PlayerHitbox then
        for _, v in next, Players:GetPlayers() do
            if v ~= localPlayer then
                pcall(function()
                    local char = v.Character
                    if char and char.Parent then
                        local hum = char:FindFirstChildWhichIsA("Humanoid")
                        -- HEALTH CHECK: Ignora cadáveres
                        if hum and hum.Health > 0 then
                            local teamOk = not getgenv().TeamCheck or (localPlayer.Team ~= v.Team)
                            if getgenv().HitboxStatus and anyOn and teamOk then
                                applyHitbox(char, "Really black")
                            else
                                resetHitbox(char)
                            end
                        end
                    end
                end)
            end
        end
    end

    if getgenv().NPCHitbox then
        if npcCacheDirty then task.spawn(scanNPCs) end
        for _, model in next, npcCache do
            pcall(function()
                if model and model.Parent then
                    local hum = model:FindFirstChildWhichIsA("Humanoid")
                    -- HEALTH CHECK: Ignora cadáveres
                    if (not hum) or (hum and hum.Health > 0) then
                        if getgenv().HitboxStatus and anyOn then
                            applyHitbox(model, "Really red")
                        else
                            resetHitbox(model)
                        end
                    end
                end
            end)
        end
    end
end)

-- ==========================================
-- [[ 10.1 LOOPS ADICIONAIS (RenderStepped e Stepped) ]]
-- ==========================================
RunService.RenderStepped:Connect(function()
    local mode = getgenv().ClientPullMode or "Heartbeat"
    if mode == "RenderStepped" and getgenv().ClientPullEnabled then
        -- Throttle também no RenderStepped
        local throttleTime = getgenv().PullThrottleTime or 0.15
        pullThrottle = pullThrottle + 0.016 -- Aproximadamente 1 frame
        if pullThrottle >= throttleTime then
            pullThrottle = 0
            pcall(pullNPCs)
        end
    end
end)

RunService.Stepped:Connect(function()
    local mode = getgenv().ClientPullMode or "Heartbeat"
    if mode == "Stepped" and getgenv().ClientPullEnabled then
        -- Throttle também no Stepped
        local throttleTime = getgenv().PullThrottleTime or 0.15
        pullThrottle = pullThrottle + 0.016
        if pullThrottle >= throttleTime then
            pullThrottle = 0
            pcall(pullNPCs)
        end
    end
end)

-- ==========================================
-- [[ 11. ABA PLAYERS ]]
-- ==========================================
local PlayerMovement = Tabs.Players:AddLeftGroupbox('Movement')
local PlayerMods     = Tabs.Players:AddRightGroupbox('Modifiers')

PlayerMovement:AddInput('WSInput', {
    Default = '16', Numeric = true, Finished = true, Text = 'WalkSpeed',
    Callback = function(v)
        getgenv().Walkspeed = tonumber(v)
        pcall(function() localPlayer.Character.Humanoid.WalkSpeed = tonumber(v) end)
    end
})
PlayerMovement:AddToggle('WSLoop', {
    Text = 'Loop WalkSpeed', Default = false,
    Callback = function(v) getgenv().loopW = v end
})
PlayerMovement:AddInput('JPInput', {
    Default = '50', Numeric = true, Finished = true, Text = 'JumpPower',
    Callback = function(v)
        getgenv().Jumppower = tonumber(v)
        pcall(function() localPlayer.Character.Humanoid.JumpPower = tonumber(v) end)
    end
})
PlayerMovement:AddToggle('JPLoop', {
    Text = 'Loop JumpPower', Default = false,
    Callback = function(v) getgenv().loopJ = v end
})
PlayerMovement:AddInput('TPInput', {
    Default = '3', Numeric = true, Finished = true, Text = 'TP Speed',
    Callback = function(v) getgenv().TPSpeed = tonumber(v) end
})
PlayerMovement:AddToggle('TPWalkToggle', {
    Text = 'TP Walk', Default = false,
    Callback = function(v)
        getgenv().TPWalk = v
        local hb = RunService.Heartbeat
        while getgenv().TPWalk and hb:Wait() do
            local chr = localPlayer.Character
            local hum = chr and chr:FindFirstChildWhichIsA("Humanoid")
            if chr and hum and hum.Parent and hum.MoveDirection.Magnitude > 0 then
                chr:TranslateBy(hum.MoveDirection * (isNumber(getgenv().TPSpeed) and tonumber(getgenv().TPSpeed) or 1))
            end
        end
    end
})

PlayerMods:AddSlider('FovSlider', {
    Text = 'FOV', Default = workspace.CurrentCamera.FieldOfView, Min = 70, Max = 120, Rounding = 0, Compact = false,
    Callback = function(v) workspace.CurrentCamera.FieldOfView = v end
})
PlayerMods:AddToggle('NoclipToggle', {
    Text = 'Noclip', Default = false,
    Callback = function(v) getgenv().Noclip = v end
})
PlayerMods:AddToggle('InfJumpToggle', {
    Text = 'Infinite Jump', Default = false,
    Callback = function(v) getgenv().InfJ = v end
})

game:GetService("UserInputService").JumpRequest:Connect(function()
    if getgenv().InfJ then
        pcall(function() localPlayer.Character:FindFirstChildOfClass('Humanoid'):ChangeState("Jumping") end)
    end
end)

PlayerMods:AddButton({
    Text = 'Rejoin Server',
    Func = function() game:GetService("TeleportService"):Teleport(game.PlaceId, localPlayer) end
})

-- ==========================================
-- [[ 12. ABA VISUALS ]]
-- ==========================================
local VisualsGroup = Tabs.Visuals:AddLeftGroupbox('ESP Settings')
VisualsGroup:AddLabel('Wait 3-10 seconds to load ESP')
VisualsGroup:AddToggle('ESPToggle', {
    Text = 'Character Highlight', Default = false,
    Callback = function(state)
        getgenv().enabled             = state
        getgenv().filluseteamcolor    = true
        getgenv().outlineuseteamcolor = true
        getgenv().fillcolor           = Color3.new(0, 0, 0)
        getgenv().outlinecolor        = Color3.new(1, 1, 1)
        getgenv().filltrans           = 0.5
        getgenv().outlinetrans        = 0.5
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Vcsk/RobloxScripts/main/Highlight-ESP.lua"))()
    end
})

-- ==========================================
-- [[ 13. ABA GAMES ]]
-- ==========================================
if game.PlaceId == 3082002798 then
    local GamesGroup = Tabs.Games:AddLeftGroupbox('Game Mods')
    GamesGroup:AddLabel("Game: " .. game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name)
    GamesGroup:AddButton({
        Text = 'No Cooldown',
        Func = function()
            for _, v in pairs(game:GetService('ReplicatedStorage')['Shared_Modules'].Tools:GetDescendants()) do
                if v:IsA('ModuleScript') then require(v).DEBOUNCE = 0 end
            end
        end
    })
end

-- ==========================================
-- [[ 14. CONFIGURAÇÕES DA LIBRARY ]]
-- ==========================================
Library:SetWatermark('Hitbox Expander')
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({'MenuKeybind'})
ThemeManager:SetFolder('HitboxExpander')
SaveManager:SetFolder('HitboxExpander/main')
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:BuildThemeManager(Tabs.Settings)

Library:Notify('Hitbox Expander v8 (Anti-Lag) carregado com sucesso!', 5)