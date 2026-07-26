--[[
Script Original por: !vcsk0#1516
Portado para Obsidian UI por: Gemini
Modificado para suporte a NPCs + Head/Body Hitbox + Melee Support
Otimizado para redução de lag por: Claude
Integração Client Pull por: DeepSeek
REACH INTEGRATION FIX: Dropdowns corrigidos (Values) + Adição de Modo Agressivo e Expansão Física de Arma (100% PC)
]]

-- ==========================================
-- [[ 1. SERVIÇOS ]]
-- ==========================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Stats             = game:GetService("Stats")

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

-- CLIENT PULL VARIABLES
getgenv().ClientPullEnabled = false
getgenv().ClientPullDistance = 10
getgenv().ClientPullRadius = 250
getgenv().ClientPullMode = "RenderStepped"
getgenv().ClientPullAggressive = false
getgenv().ClientPullMaxNPCs = 10

-- REACH VARIABLES
getgenv().ReachEnabled = false
getgenv().ReachDistance = 15
getgenv().ReachAggressive = false -- NOVO: MODO AGRESSIVO
getgenv().ReachExpandWeapon = false -- NOVO: EXPANSAO FISICA PARA PC
getgenv().ReachRandom = false
getgenv().ReachRandomStrength = 2.0
getgenv().ReachBacktrack = false
getgenv().ReachBacktrackWindow = 0.5
getgenv().ReachPredictive = true
getgenv().ReachWallCheck = false
getgenv().ReachTeamCheck = false
getgenv().ReachHitboxShape = "Sphere"
getgenv().ReachShowVisualizer = true
getgenv().ReachVisualizerTransparency = 0.85
getgenv().ReachCombatProfile = "Standard" 
getgenv().ReachAutoClick = false
getgenv().ReachHitDelay = 0.08
getgenv().ReachAlwaysActive = false
getgenv().ReachTargetPlayers = true
getgenv().ReachTargetNPCs = true

-- ==========================================
-- [[ 3. CARREGANDO OBSIDIAN ]]
-- ==========================================
local repo        = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library     = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title = 'Hitbox + Reach | Obsidian',
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
    Pull    = Window:AddTab('Client Pull'),
    Reach   = Window:AddTab('Reach')
}
if game.PlaceId == 3082002798 then
    Tabs.Games = Window:AddTab('Games')
end
Tabs.Settings = Window:AddTab('UI Settings')

-- ==========================================
-- [[ 5. UI — ABA HOME (Hitbox) ]]
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
    Tooltip = 'Detecta qualquer Model com Humanoid ou estrutura básica.',
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

-- ==========================================
-- [[ 6. UI — ABA REACH ]]
-- ==========================================
local ReachMain = Tabs.Reach:AddLeftGroupbox('Reach Settings')
local ReachAdvanced = Tabs.Reach:AddRightGroupbox('Advanced')
local ReachVisuals = Tabs.Reach:AddLeftGroupbox('Visuals')

ReachMain:AddToggle('ReachEnabled', {
    Text = 'Enable Reach', Default = false,
    Tooltip = 'Ativa o sistema de alcance estendido',
    Callback = function(v) getgenv().ReachEnabled = v end
})

ReachMain:AddToggle('ReachAggressive', {
    Text = '🔥 MODO AGRESSIVO', Default = false,
    Tooltip = 'Ignora colisões, ataca múltiplas partes do NPC/Player sem delay.',
    Callback = function(v) getgenv().ReachAggressive = v end
})

-- CORREÇÃO: Mudado de 'Options' para 'Values'
ReachMain:AddDropdown('ReachCombatProfile', {
    Text = 'Combat Mode',
    Default = 2, -- 2 equivale a Standard
    Values = {'Legit', 'Standard', 'Extreme', 'Deadly'}, 
    Callback = function(v) getgenv().ReachCombatProfile = v end
})

ReachMain:AddToggle('ReachTargetPlayers', {
    Text = 'Target Players', Default = true,
    Callback = function(v) getgenv().ReachTargetPlayers = v end
})

ReachMain:AddToggle('ReachTargetNPCs', {
    Text = 'Target NPCs', Default = true,
    Callback = function(v) getgenv().ReachTargetNPCs = v end
})

ReachMain:AddToggle('ReachRandom', {
    Text = 'Randomize Reach', Default = false,
    Callback = function(v) getgenv().ReachRandom = v end
})

ReachMain:AddToggle('ReachAutoClick', {
    Text = 'Auto Clicker', Default = false,
    Callback = function(v) getgenv().ReachAutoClick = v end
})

ReachMain:AddSlider('ReachDistance', {
    Text = 'Reach Studs', Default = 15, Min = 5, Max = 100, Rounding = 1,
    Callback = function(v) getgenv().ReachDistance = v end
})

ReachMain:AddSlider('ReachRandomStrength', {
    Text = 'Random Strength', Default = 2.0, Min = 0.1, Max = 10.0, Rounding = 1,
    Callback = function(v) getgenv().ReachRandomStrength = v end
})

ReachMain:AddSlider('ReachHitDelay', {
    Text = 'Hit Delay', Default = 0.08, Min = 0.0, Max = 0.5, Rounding = 2,
    Callback = function(v) getgenv().ReachHitDelay = v end
})

ReachAdvanced:AddToggle('ReachExpandWeapon', {
    Text = 'Expand Weapon Hitbox', Default = false,
    Tooltip = 'Expande o tamanho físico da sua ferramenta (Perfeito para PC)',
    Callback = function(v) getgenv().ReachExpandWeapon = v end
})

ReachAdvanced:AddToggle('ReachBacktrack', {
    Text = 'Backtrack', Default = false,
    Callback = function(v) getgenv().ReachBacktrack = v end
})

ReachAdvanced:AddToggle('ReachPredictive', {
    Text = 'Predictive Aim', Default = true,
    Callback = function(v) getgenv().ReachPredictive = v end
})

ReachAdvanced:AddToggle('ReachWallCheck', {
    Text = 'Wall Check', Default = false,
    Callback = function(v) getgenv().ReachWallCheck = v end
})

ReachAdvanced:AddToggle('ReachTeamCheck', {
    Text = 'Team Check (Players)', Default = false,
    Callback = function(v) getgenv().ReachTeamCheck = v end
})

ReachAdvanced:AddSlider('ReachBacktrackWindow', {
    Text = 'Backtrack Window', Default = 0.5, Min = 0.1, Max = 1.0, Rounding = 1,
    Callback = function(v) getgenv().ReachBacktrackWindow = v end
})

-- CORREÇÃO: Mudado de 'Options' para 'Values'
ReachAdvanced:AddDropdown('ReachHitboxShape', {
    Text = 'Hitbox Shape',
    Default = 1, -- 1 equivale a Sphere
    Values = {'Sphere', 'Square', 'Line', 'Sector'},
    Callback = function(v) getgenv().ReachHitboxShape = v end
})

ReachVisuals:AddToggle('ReachShowVisualizer', {
    Text = 'Show Visualizer', Default = true,
    Callback = function(v) getgenv().ReachShowVisualizer = v end
})

ReachVisuals:AddSlider('ReachVisualizerTransparency', {
    Text = 'Visualizer Transparency', Default = 0.85, Min = 0, Max = 1, Rounding = 2,
    Callback = function(v) getgenv().ReachVisualizerTransparency = v end
})

-- ==========================================
-- [[ 7. UI — ABA CLIENT PULL ]]
-- ==========================================
local PullGroup = Tabs.Pull:AddLeftGroupbox('Client Pull Settings')
local PullInfo  = Tabs.Pull:AddRightGroupbox('Info')

PullGroup:AddToggle('ClientPullToggle', {
    Text = 'Enable Client Pull', Default = false,
    Callback = function(v) getgenv().ClientPullEnabled = v end
})
PullGroup:AddSlider('ClientPullDist', {
    Text = 'Offset (Distância)', Default = 10, Min = 1, Max = 100, Rounding = 1,
    Callback = function(v) getgenv().ClientPullDistance = v end
})
PullGroup:AddSlider('ClientPullRadius', {
    Text = 'Max Pull Radius (Alcance)', Default = 250, Min = 1, Max = 1000, Rounding = 0,
    Callback = function(v) getgenv().ClientPullRadius = v end
})

-- CORREÇÃO: Mudado de 'Options' para 'Values'
PullGroup:AddDropdown('ClientPullMode', {
    Text = 'Pull Mode',
    Default = 1,
    Values = {'RenderStepped', 'Heartbeat', 'Stepped', 'Simulation'},
    Callback = function(v) getgenv().ClientPullMode = v end
})
PullGroup:AddSlider('ClientPullMaxNPCs', {
    Text = 'Max NPCs per frame',
    Default = 10, Min = 1, Max = 100, Rounding = 0,
    Callback = function(v) getgenv().ClientPullMaxNPCs = v end
})
PullGroup:AddToggle('ClientPullAggressive', {
    Text = '🔴 Modo Agressivo (QUALQUER NPC)',
    Default = false,
    Callback = function(v) 
        getgenv().ClientPullAggressive = v
        aggressiveCacheDirty = true
        Library:Notify(v and '⚠️ CLIENT PULL AGRESSIVO ATIVADO' or 'Client Pull normal ativado', 2)
    end
})
PullInfo:AddLabel('O Raio limita a distância máxima para puxar NPCs.')
PullInfo:AddLabel('Offset é a posição final onde eles ficam na sua tela.')

-- ==========================================
-- [[ 8. SISTEMA DE HITBOX (ANTI-DESYNC) ]]
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

local function isStateDesynced(character, active, color)
    local s = charState[character]
    if not s then return true end
    
    local g = getgenv()
    if s.active ~= active or s.color ~= (color or "") or s.body ~= g.BodyHitbox or s.head ~= g.HeadHitbox or s.melee ~= g.MeleeHitbox or s.bodySize ~= g.HitboxSize or s.headSize ~= g.HeadHitboxSize or s.meleeSize ~= g.MeleeSize or s.trans ~= g.HitboxTransparency then
        return true
    end
    
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

    if g.MeleeHitbox then
        for _, part in next, character:GetChildren() do
            if part:IsA("BasePart") and part.Name ~= (hrp and hrp.Name or "") and part.Name ~= "Head" then
                pcall(function()
                    savePart(part)
                    local s = g.MeleeSize
                    part.Size         = partData[part].size + Vector3.new(s, s, s)
                    part.Transparency = g.HitboxTransparency
                    part.CanCollide   = false
                    part.Massless     = true
                end)
            end
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
-- [[ 9. DETECÇÃO DE NPC (DEEP SCAN) ]]
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

local function IsAnyNPC(model)
    if not model or not model:IsA("Model") then return false end
    if IsPlayerCharacter(model) then return false end
    
    if model:FindFirstChildWhichIsA("Humanoid") then return true end
    
    if model:FindFirstChild("Head") then
        if model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso") then
            return true
        end
    end
    
    local parts = 0
    for _, child in pairs(model:GetChildren()) do
        if child:IsA("BasePart") then
            parts = parts + 1
            if parts >= 3 then return true end
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
-- [[ 10. SISTEMA DE REACH (COM MODO AGRESSIVO) ]]
-- ==========================================
local reachVisualizer = nil
local reachSectorParts = {}
local reachBacktrackBuffer = {}
local reachCooldowns = {}
local reachIsSwinging = false
local reachCachedRoot = nil
local originalToolSizes = {}

local function getPing()
    local ok, val = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return (ok and type(val) == "number") and val or 0
end

local function isWallBetween(p1, p2)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {Players.LocalPlayer.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(p1, (p2 - p1), params)
    if result then
        local hit = result.Instance
        return hit and hit.CanCollide and hit.Anchored and not hit:IsDescendantOf(Players.LocalPlayer.Character)
    end
    return false
end

local function isInReachHitbox(origin, targetPos, rootCF)
    local relPos = rootCF:PointToObjectSpace(targetPos)
    local reach = getgenv().ReachDistance
    if getgenv().ReachRandom then
        reach = reach + (math.random(-100, 100) / 100 * getgenv().ReachRandomStrength)
    end

    local dirToEnemy = targetPos - origin
    local dist = dirToEnemy.Magnitude
    
    if getgenv().ReachAggressive then
        return dist <= reach
    end

    local fwd = rootCF.LookVector
    local flatFwd = Vector3.new(fwd.X, 0, fwd.Z)
    local flatDir = Vector3.new(dirToEnemy.X, 0, dirToEnemy.Z)
    local flatFwdMag = flatFwd.Magnitude
    local flatDirMag = flatDir.Magnitude
    local horizontalDot = (flatFwdMag > 0.001 and flatDirMag > 0.001)
        and (flatFwd / flatFwdMag):Dot(flatDir / flatDirMag)
        or 1.0

    if getgenv().ReachCombatProfile == "Legit" then
        if horizontalDot < 0.707 then return false end
    end

    if getgenv().ReachHitboxShape == "Sphere" then
        return dist <= reach
    elseif getgenv().ReachHitboxShape == "Square" then
        return math.abs(relPos.X) <= reach and math.abs(relPos.Y) <= reach and math.abs(relPos.Z) <= reach
    elseif getgenv().ReachHitboxShape == "Line" then
        if getgenv().ReachCombatProfile == "Legit" then
            return math.abs(relPos.X) <= 2 and math.abs(relPos.Y) <= 3.5 and relPos.Z <= 0 and relPos.Z >= -reach
        else
            return math.abs(relPos.X) <= 2 and math.abs(relPos.Y) <= 3.5 and math.abs(relPos.Z) <= reach
        end
    elseif getgenv().ReachHitboxShape == "Sector" then
        if dist > reach then return false end
        if math.abs(relPos.Y) > 3.5 then return false end
        return horizontalDot >= 0.6428
    end
    return false
end

RunService.Heartbeat:Connect(function()
    if not getgenv().ReachEnabled then return end
    
    if getgenv().ReachTargetPlayers then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= Players.LocalPlayer and player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    if not reachBacktrackBuffer[player.UserId] then reachBacktrackBuffer[player.UserId] = {} end
                    local buffer = reachBacktrackBuffer[player.UserId]
                    table.insert(buffer, 1, {pos = root.Position, time = os.clock()})
                    local maxTime = getgenv().ReachBacktrackWindow
                    while #buffer > 0 and (os.clock() - buffer[#buffer].time) > maxTime do table.remove(buffer) end
                end
            end
        end
    end
    
    if getgenv().ReachTargetNPCs then
        for _, npc in ipairs(npcCache) do
            if npc and npc.Parent then
                local root = npc:FindFirstChild("HumanoidRootPart")
                if root then
                    local npcId = "npc_" .. tostring(npc)
                    if not reachBacktrackBuffer[npcId] then reachBacktrackBuffer[npcId] = {} end
                    local buffer = reachBacktrackBuffer[npcId]
                    table.insert(buffer, 1, {pos = root.Position, time = os.clock()})
                    local maxTime = getgenv().ReachBacktrackWindow
                    while #buffer > 0 and (os.clock() - buffer[#buffer].time) > maxTime do table.remove(buffer) end
                end
            end
        end
    end
end)

local function updateReachVisualizer()
    if not (getgenv().ReachEnabled and getgenv().ReachShowVisualizer) then
        if reachVisualizer then reachVisualizer.Parent = nil end
        for _, p in ipairs(reachSectorParts) do pcall(function() p:Destroy() end) end
        reachSectorParts = {}
        return
    end

    local char = Players.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        if reachVisualizer then reachVisualizer.Parent = nil end
        return
    end

    local reach = getgenv().ReachDistance
    local cam = workspace:FindFirstChildOfClass("Camera") or workspace

    if getgenv().ReachHitboxShape == "Sector" and not getgenv().ReachAggressive then
        if reachVisualizer then reachVisualizer.Parent = nil end
        
        local HALF_ANG = math.rad(50)
        local NUM_SPOKES = 30
        local ARC_SEGS = 18
        local TOTAL = NUM_SPOKES + ARC_SEGS
        local SPOKE_H = 3.5
        local TRANSP = getgenv().ReachVisualizerTransparency

        local angStep = (2 * HALF_ANG) / math.max(NUM_SPOKES - 1, 1)
        local SPOKE_W = math.max(1.0, reach * angStep * 1.25)
        local ARC_W = SPOKE_W

        while #reachSectorParts < TOTAL do
            local p = Instance.new("Part")
            p.Material = Enum.Material.ForceField
            p.CanCollide = false
            p.CastShadow = false
            p.Anchored = true
            p.Archivable = false
            p.Parent = cam
            table.insert(reachSectorParts, p)
        end
        
        while #reachSectorParts > TOTAL do
            pcall(function() table.remove(reachSectorParts):Destroy() end)
        end

        for i = 1, NUM_SPOKES do
            local p = reachSectorParts[i]
            p.Color = Color3.fromRGB(0, 255, 255)
            p.Transparency = TRANSP
            p.Parent = cam
            local t = (i - 1) / (NUM_SPOKES - 1)
            local angle = -HALF_ANG + t * (2 * HALF_ANG)
            p.Size = Vector3.new(SPOKE_W, SPOKE_H, reach)
            local rot = root.CFrame * CFrame.Angles(0, angle, 0)
            p.CFrame = rot * CFrame.new(0, 0, -reach / 2)
        end

        for j = 1, ARC_SEGS do
            local p = reachSectorParts[NUM_SPOKES + j]
            p.Color = Color3.fromRGB(0, 255, 255)
            p.Transparency = TRANSP
            p.Parent = cam
            local t = (j - 1) / (ARC_SEGS - 1)
            local angle = -HALF_ANG + t * (2 * HALF_ANG)
            local tipX = math.sin(angle) * reach
            local tipZ = -math.cos(angle) * reach
            p.Size = Vector3.new(ARC_W, SPOKE_H, ARC_W)
            p.CFrame = root.CFrame * CFrame.new(tipX, 0, tipZ)
        end
        return
    end

    for _, p in ipairs(reachSectorParts) do pcall(function() p:Destroy() end) end
    reachSectorParts = {}

    if not reachVisualizer or not reachVisualizer.Parent then
        if reachVisualizer then pcall(function() reachVisualizer:Destroy() end) end
        reachVisualizer = Instance.new("Part")
        reachVisualizer.Name = "ReachVisualizer"
        reachVisualizer.Material = Enum.Material.ForceField
        reachVisualizer.CanCollide = false
        reachVisualizer.CastShadow = false
        reachVisualizer.Anchored = true
        reachVisualizer.Archivable = false
    end

    reachVisualizer.Parent = cam
    reachVisualizer.Transparency = getgenv().ReachVisualizerTransparency
    
    if getgenv().ReachAggressive then
        reachVisualizer.Color = Color3.fromRGB(255, 0, 0) -- Fica vermelho no modo agressivo
    else
        reachVisualizer.Color = Color3.fromRGB(0, 255, 255)
    end

    if getgenv().ReachHitboxShape == "Sphere" or getgenv().ReachAggressive then
        reachVisualizer.Shape = Enum.PartType.Ball
        reachVisualizer.Size = Vector3.new(reach*2, reach*2, reach*2)
        reachVisualizer.CFrame = root.CFrame
    elseif getgenv().ReachHitboxShape == "Square" then
        reachVisualizer.Shape = Enum.PartType.Block
        reachVisualizer.Size = Vector3.new(reach*2, reach*2, reach*2)
        reachVisualizer.CFrame = root.CFrame
    elseif getgenv().ReachHitboxShape == "Line" then
        reachVisualizer.Shape = Enum.PartType.Block
        reachVisualizer.Size = Vector3.new(4, 4, reach)
        reachVisualizer.CFrame = root.CFrame * CFrame.new(0, 0, -reach/2)
    end
end
RunService.RenderStepped:Connect(updateReachVisualizer)

local function performReach()
    if not (getgenv().ReachEnabled and (getgenv().ReachTargetPlayers or getgenv().ReachTargetNPCs)) then return end
    
    local char = Players.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local tool = char and char:FindFirstChildOfClass("Tool")
    local handle = tool and (tool:FindFirstChild("Handle") or tool:FindFirstChildOfClass("Part"))
    
    if not (root and handle) then return end
    
    -- EXPANSAO FISICA DA ARMA (Safe para PC)
    if getgenv().ReachExpandWeapon then
        if not originalToolSizes[handle] then originalToolSizes[handle] = handle.Size end
        handle.Size = Vector3.new(getgenv().ReachDistance, getgenv().ReachDistance, getgenv().ReachDistance)
        handle.Massless = true
        handle.CanCollide = false
        handle.Transparency = 1 
    else
        if originalToolSizes[handle] then
            handle.Size = originalToolSizes[handle]
            handle.Transparency = 0
            originalToolSizes[handle] = nil
        end
    end
    
    if getgenv().ReachAutoClick and tool.Parent == char and tool.Enabled and os.clock() - (reachCooldowns["autoclick"] or 0) > 0.05 then
        reachCooldowns["autoclick"] = os.clock()
        pcall(function() tool:Activate() end)
    end

    if not (reachIsSwinging or getgenv().ReachAlwaysActive) then return end
    
    local ping = getPing()
    
    local function processTarget(targetRoot, targetId, isPlayer)
        if not targetRoot or not targetRoot.Parent then return end
        
        local hum = targetRoot.Parent:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        
        if isPlayer and getgenv().ReachTeamCheck then
            local player = Players:GetPlayerFromCharacter(targetRoot.Parent)
            if player and player.Team == Players.LocalPlayer.Team then return end
        end
        
        local targetPos = targetRoot.Position
        
        if getgenv().ReachPredictive and not getgenv().ReachAggressive then
            targetPos = targetPos + (targetRoot.Velocity * (ping / 1000))
        end
        
        if not isInReachHitbox(root.Position, targetPos, root.CFrame) then
            if getgenv().ReachBacktrack and reachBacktrackBuffer[targetId] then
                local found = false
                for _, entry in ipairs(reachBacktrackBuffer[targetId]) do
                    if isInReachHitbox(root.Position, entry.pos, root.CFrame) then
                        if getgenv().ReachAggressive or not (getgenv().ReachWallCheck and isWallBetween(root.Position, entry.pos)) then
                            targetPos = entry.pos
                            found = true
                            break
                        end
                    end
                end
                if not found then return end
            else
                return
            end
        end
        
        if not getgenv().ReachAggressive and getgenv().ReachWallCheck and isWallBetween(root.Position, targetPos) then return end
        
        local delay = getgenv().ReachHitDelay
        local multihit = 1
        
        if getgenv().ReachCombatProfile == "Legit" then
            delay = 0.2
        elseif getgenv().ReachCombatProfile == "Standard" then
            delay = getgenv().ReachHitDelay * 0.8
            multihit = 2
        elseif getgenv().ReachCombatProfile == "Extreme" then
            delay = 0.0
            multihit = 25
        elseif getgenv().ReachCombatProfile == "Deadly" then
            delay = 0.0
            multihit = 40
        end

        if getgenv().ReachAggressive then
            delay = 0.0 
            multihit = multihit * 2
        end

        if os.clock() - (reachCooldowns[targetId] or 0) < delay then return end
        reachCooldowns[targetId] = os.clock()

        for i = 1, multihit do
            local bodyParts = {}
            
            -- Lógica agressiva: Pega todas as partes do modelo do NPC ou Player para garantir o hit
            if getgenv().ReachAggressive then
                for _, part in ipairs(targetRoot.Parent:GetChildren()) do
                    if part:IsA("BasePart") then
                        table.insert(bodyParts, part)
                    end
                end
            else
                table.insert(bodyParts, targetRoot)
                local torso = targetRoot.Parent:FindFirstChild("UpperTorso") or targetRoot.Parent:FindFirstChild("Torso")
                local head = targetRoot.Parent:FindFirstChild("Head")
                
                if torso then table.insert(bodyParts, torso) end
                if getgenv().ReachCombatProfile == "Deadly" and head then table.insert(bodyParts, head) end
            end
            
            for _, part in ipairs(bodyParts) do
                pcall(function()
                    firetouchinterest(handle, part, 0)
                    firetouchinterest(handle, part, 1)
                end)
            end
        end
    end

    if getgenv().ReachTargetPlayers then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= Players.LocalPlayer and player.Character then
                local eRoot = player.Character:FindFirstChild("HumanoidRootPart")
                if eRoot then
                    processTarget(eRoot, player.UserId, true)
                end
            end
        end
    end

    if getgenv().ReachTargetNPCs then
        for _, npc in ipairs(npcCache) do
            if npc and npc.Parent then
                local eRoot = npc:FindFirstChild("HumanoidRootPart")
                if eRoot then
                    local npcId = "npc_" .. tostring(npc)
                    processTarget(eRoot, npcId, false)
                end
            end
        end
    end
end

RunService.Heartbeat:Connect(performReach)

local function setupReachTool(t)
    if not t:IsA("Tool") then return end
    t.Equipped:Connect(function() reachIsSwinging = false end)
    t.Activated:Connect(function() reachIsSwinging = true end)
    t.Deactivated:Connect(function() reachIsSwinging = false end)
    t.Unequipped:Connect(function() 
        reachIsSwinging = false 
        local handle = t:FindFirstChild("Handle") or t:FindFirstChildOfClass("Part")
        if handle and originalToolSizes[handle] then
            handle.Size = originalToolSizes[handle]
            handle.Transparency = 0
            originalToolSizes[handle] = nil
        end
    end)
end

local function setupReachCharacter(c)
    reachCachedRoot = c:WaitForChild("HumanoidRootPart", 5)
    c.ChildAdded:Connect(function(child)
        if child.Name == "HumanoidRootPart" then reachCachedRoot = child end
        setupReachTool(child)
    end)
    for _, v in pairs(c:GetChildren()) do setupReachTool(v) end
end

Players.LocalPlayer.CharacterAdded:Connect(setupReachCharacter)
if Players.LocalPlayer.Character then setupReachCharacter(Players.LocalPlayer.Character) end

-- ==========================================
-- [[ 11. CLIENT PULL OTIMIZADO ]]
-- ==========================================
local aggressiveNPCCache = {}
local aggressiveCacheDirty = true
local aggressiveScanTick = 0

local function scanAggressiveNPCs()
    if not getgenv().ClientPullAggressive then return end
    
    local player = Players.LocalPlayer
    local char = player.Character
    if not char then return end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local newCache = {}
    local rootPos = rootPart.Position
    local maxRadius = getgenv().ClientPullRadius or 250
    local count = 0
    
    for _, obj in pairs(workspace:GetDescendants()) do
        count = count + 1
        if count % 150 == 0 then task.wait() end 
        
        if obj:IsA("Model") and obj:FindFirstChild("HumanoidRootPart") then
            if not IsPlayerCharacter(obj) and IsAnyNPC(obj) then
                local npcRoot = obj:FindFirstChild("HumanoidRootPart")
                if npcRoot then
                    local dist = (npcRoot.Position - rootPos).Magnitude
                    if dist <= maxRadius then
                        table.insert(newCache, {npc = obj, root = npcRoot, dist = dist})
                    end
                end
            end
        end
    end
    
    table.sort(newCache, function(a, b) return a.dist < b.dist end)
    aggressiveNPCCache = newCache
    aggressiveCacheDirty = false
end

workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Model") then
        aggressiveCacheDirty = true
    end
end)

workspace.DescendantRemoving:Connect(function(obj)
    if obj:IsA("Model") then
        aggressiveCacheDirty = true
    end
end)

local function pullNPCs()
    if not getgenv().ClientPullEnabled then return end

    local player = Players.LocalPlayer
    local char = player.Character
    if not char then return end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local pullDist = getgenv().ClientPullDistance or 10
    local targetPoint = rootPart.Position + rootPart.CFrame.LookVector * pullDist
    local aggressive = getgenv().ClientPullAggressive or false
    local maxNPCs = getgenv().ClientPullMaxNPCs or 10
    local maxRadius = getgenv().ClientPullRadius or 250
    
    if aggressive then
        if aggressiveCacheDirty or tick() - aggressiveScanTick > 2.5 then
            aggressiveScanTick = tick()
            task.spawn(scanAggressiveNPCs) 
        end
        
        local count = 0
        for _, data in ipairs(aggressiveNPCCache) do
            if count >= maxNPCs then break end
            if data.npc and data.npc.Parent and data.root and data.root.Parent then
                data.root.CFrame = CFrame.new(targetPoint)
                count = count + 1
            end
        end
    else
        local count = 0
        for _, npc in pairs(npcCache) do
            if count >= maxNPCs then break end
            if npc and npc.Parent then
                local npcRoot = npc:FindFirstChild("HumanoidRootPart")
                if npcRoot then
                    local dist = (npcRoot.Position - rootPart.Position).Magnitude
                    if dist <= maxRadius then
                        npcRoot.CFrame = CFrame.new(targetPoint)
                        count = count + 1
                    end
                end
            end
        end
    end
end

RunService.RenderStepped:Connect(function()
    local mode = getgenv().ClientPullMode or "RenderStepped"
    if mode == "RenderStepped" and getgenv().ClientPullEnabled then
        pcall(pullNPCs)
    end
end)

RunService.Stepped:Connect(function()
    local mode = getgenv().ClientPullMode or "RenderStepped"
    if mode == "Stepped" and getgenv().ClientPullEnabled then
        pcall(pullNPCs)
    end
end)

RunService.Heartbeat:Connect(function(dt)
    local mode = getgenv().ClientPullMode or "RenderStepped"
    
    if mode == "Heartbeat" and getgenv().ClientPullEnabled then
        pcall(pullNPCs)
    end
    
    if mode == "Simulation" and getgenv().ClientPullEnabled then
        pcall(pullNPCs)
    end
end)

-- ==========================================
-- [[ 12. LOOP ÚNICO UNIFICADO (HITBOX EXPANDER) ]]
-- ==========================================
local localPlayer = Players.LocalPlayer
local hitboxThrottle = 0
local movThrottle = 0
local noclipThrottle = 0
local lastGC = tick()

RunService.Heartbeat:Connect(function(dt)
    if tick() - lastGC > 10 then
        lastGC = tick()
        for char, _ in pairs(charState) do
            if not char.Parent then cleanupCharacter(char) end
        end
    end

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

    noclipThrottle = noclipThrottle + dt
    if noclipThrottle >= 0.1 then
        noclipThrottle = 0
        if getgenv().Noclip then
            pcall(function()
                localPlayer.Character.Head.CanCollide = false
                localPlayer.Character.Torso.CanCollide = false
            end)
        end
    end

    hitboxThrottle = hitboxThrottle + dt
    if hitboxThrottle < 0.05 then return end
    hitboxThrottle = 0

    local anyOn = getgenv().HeadHitbox or getgenv().BodyHitbox or getgenv().MeleeHitbox

    if getgenv().PlayerHitbox then
        for _, v in next, Players:GetPlayers() do
            if v ~= localPlayer then
                pcall(function()
                    local char = v.Character
                    if char and char.Parent then
                        local hum = char:FindFirstChildWhichIsA("Humanoid")
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
-- [[ 13. ABA PLAYERS ]]
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
-- [[ 14. ABA VISUALS ]]
-- ==========================================
local VisualsGroup = Tabs.Visuals:AddLeftGroupbox('ESP Settings')
VisualsGroup:AddLabel('Wait 3-10 seconds to load ESP')
VisualsGroup:AddToggle('ESPToggle', {
    Text = 'Character Highlight', Default = false,
    Callback = function(state)
        getgenv().enabled = state
        getgenv().filluseteamcolor = true
        getgenv().outlineuseteamcolor = true
        getgenv().fillcolor = Color3.new(0, 0, 0)
        getgenv().outlinecolor = Color3.new(1, 1, 1)
        getgenv().filltrans = 0.5
        getgenv().outlinetrans = 0.5
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Vcsk/RobloxScripts/main/Highlight-ESP.lua"))()
    end
})

-- ==========================================
-- [[ 15. ABA GAMES ]]
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
-- [[ 16. CONFIGURAÇÕES DA LIBRARY ]]
-- ==========================================
Library:SetWatermark('Hitbox + Reach Expander (PC Fixed)')
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({'MenuKeybind'})
ThemeManager:SetFolder('HitboxReachExpander')
SaveManager:SetFolder('HitboxReachExpander/main')
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:BuildThemeManager(Tabs.Settings)

Library:Notify('Hitbox + Reach v9.2 (Agressivo + UI Fix) carregado!', 5)
