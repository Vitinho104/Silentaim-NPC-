--[[
Script Original por: !vcsk0#1516
Portado para Obsidian UI por: Gemini
Modificado para suporte a NPCs + Head/Body Hitbox + Melee Support
Otimizado para redução de lag por: Claude
Detecção Agressiva de NPC portada de: Universal Pro v3.7

CORREÇÕES v3:
  - State tracking: só escreve propriedades quando algo MUDA (elimina lag + frozen)
  - Salva tamanho/props ORIGINAIS do HRP e Head antes de modificar
  - Restaura os tamanhos REAIS ao desativar (não mais hardcoded)
  - Massless = true nas parts expandidas (personagens param de ficar travados)
  - Cleanup de memória ao personagem sair
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
getgenv().PlayerHitbox           = true   -- NOVO: permite desativar hitbox em players

getgenv().Walkspeed = 16
getgenv().Jumppower = 50
getgenv().loopW     = false
getgenv().loopJ     = false

getgenv().TPSpeed = 3
getgenv().TPWalk  = false
getgenv().Noclip  = false
getgenv().InfJ    = false

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
    Visuals = Window:AddTab('Visuals')
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
    Text = 'Modo Agressivo',
    Default = false,
    Tooltip = 'Detecta qualquer Model com Humanoid, independente do nome ou pasta.',
    Callback = function(v)
        getgenv().AggressiveNPCDetection = v
        npcCache = {}; npcCacheDirty = true
        if getgenv().NPCHitbox then task.spawn(scanNPCs) end
        Library:Notify(v and '⚠️ MODO AGRESSIVO ATIVADO' or 'Modo normal de NPC ativado', 2)
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
HitboxNPC:AddLabel('Agressivo: qualquer Model+Humanoid')

-- ==========================================
-- [[ 6. SISTEMA DE HITBOX — VERSÃO CORRIGIDA ]]
-- ==========================================

--[[
  partData[part]      = propriedades ORIGINAIS do part (salvas antes de qualquer mudança)
  charState[char]     = snapshot das configs quando foi aplicada pela última vez
  Se o snapshot bater com o estado atual → pula, não escreve nada no part.
  Isso elimina o lag E o efeito "frozen" (causado por escrever propriedades todo frame).
]]

local partData  = {}   -- { size, transparency, material, brickColor, canCollide, massless }
local charState = {}   -- snapshot por personagem
local npcCache      = {}
local npcCacheDirty = true

-- Salva props originais do part (apenas uma vez por part)
local function savePart(part)
    if not partData[part] then
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

-- Restaura props originais salvas
local function restorePart(part)
    local d = partData[part]
    if not d then return end
    part.Size         = d.size
    part.Transparency = d.transparency
    part.Material     = d.material
    part.BrickColor   = d.brickColor
    part.CanCollide   = d.canCollide
    part.Massless     = d.massless
end

-- Snapshot do estado atual para comparação
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

-- Retorna true se o estado mudou desde a última aplicação
local function stateChanged(character, active, color)
    local s = charState[character]
    if not s then return true end
    local g = getgenv()
    return s.active    ~= active
        or s.color     ~= (color or "")
        or s.body      ~= g.BodyHitbox
        or s.head      ~= g.HeadHitbox
        or s.melee     ~= g.MeleeHitbox
        or s.bodySize  ~= g.HitboxSize
        or s.headSize  ~= g.HeadHitboxSize
        or s.meleeSize ~= g.MeleeSize
        or s.trans     ~= g.HitboxTransparency
end

local function applyHitbox(character, color)
    -- SKIP: nada mudou, não escreve nada (elimina lag + frozen)
    if not stateChanged(character, true, color) then return end

    local g    = getgenv()
    local hrp  = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")

    -- Body Hitbox
    if hrp then
        savePart(hrp)
        if g.BodyHitbox then
            local s = g.HitboxSize
            hrp.Size         = Vector3.new(s, s, s)
            hrp.Transparency = g.HitboxTransparency
            hrp.BrickColor   = BrickColor.new(color)
            hrp.Material     = Enum.Material.Neon
            hrp.CanCollide   = false
            -- NÃO muda Massless no HRP: ele é a raiz da física do personagem
            -- Massless=true no HRP faz o char flutuar no ar
        else
            restorePart(hrp)          -- volta ao tamanho REAL original
        end
    end

    -- Head Hitbox
    if head then
        savePart(head)
        if g.HeadHitbox then
            local s = g.HeadHitboxSize
            head.Size         = Vector3.new(s, s, s)
            head.Transparency = g.HitboxTransparency
            head.BrickColor   = BrickColor.new(color)
            head.Material     = Enum.Material.Neon
            head.CanCollide   = false
            head.Massless     = true  -- evita travar o pescoço/animações
        else
            restorePart(head)         -- volta ao tamanho REAL original
        end
    end

    -- Melee Hitbox (demais parts)
    for _, part in next, character:GetChildren() do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "Head" then
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
    -- SKIP: já está resetado
    if not stateChanged(character, false, "") then return end

    local hrp  = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")

    if hrp  then restorePart(hrp)  end
    if head then restorePart(head) end

    for _, part in next, character:GetChildren() do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "Head" then
            pcall(function() restorePart(part) end)
        end
    end

    charState[character] = makeSnapshot(false, "")
end

-- Limpa memória quando personagem é removido
local function cleanupCharacter(character)
    charState[character] = nil
    for _, part in next, character:GetDescendants() do
        if part:IsA("BasePart") then
            partData[part] = nil
        end
    end
end

-- Registra cleanup para todos os players (atuais e futuros)
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
-- [[ 7. DETECÇÃO DE NPC (PORTADA DO SILENT AIM v3.7) ]]
-- ==========================================

local NPCTags = {
    "NPC","Npc","npc","Enemy","enemy","Enemies","enemies",
    "Hostile","hostile","Bad","bad","BadGuy","badguy","Foe","foe","Opponent","opponent",
    "Bot","bot","Bots","bots","Mob","mob","Mobs","mobs","Monster","monster","Monsters","monsters",
    "Zombie","zombie","Zombies","zombies","Creature","creature","Animal","animal","Beast","beast",
    "Villain","villain","Boss","boss","MiniBoss","miniboss",
    "Guard","guard","Guardian","guardian","Soldier","soldier","Warrior","warrior","Fighter","fighter",
    "Target","target","Dummy","dummy","Dummies","dummies","Training","training",
    "Skeleton","skeleton","Orc","orc","Goblin","goblin","Troll","troll","Ogre","ogre",
    "Demon","demon","Devil","devil","Ghost","ghost","Spirit","spirit","Vampire","vampire","Werewolf","werewolf",
    "Dragon","dragon","Gang","gang","Thug","thug","Bandit","bandit","Raider","raider",
    "Pirate","pirate","Agent","agent","Assassin","assassin",
    "Mercenary","mercenary","Hunter","hunter","Robot","robot","Drone","drone",
    "Android","android","Cyborg","cyborg","Minion","minion","Pawn","pawn",
    "AI","ai","Char","char","Character","character","Model","model",
    "Event","event","Special","special","Holiday","holiday","Seasonal","seasonal"
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
    if not model:FindFirstChildOfClass("Humanoid") then return false end
    if not model:FindFirstChild("Head") then return false end
    if not model:FindFirstChild("HumanoidRootPart") then return false end

    -- MODO AGRESSIVO: tem estrutura de personagem e não é player → é NPC
    if getgenv().AggressiveNPCDetection then return true end

    -- MODO NORMAL: heurísticas
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
            if val:IsA("StringValue") then
                local v = val.Value:lower()
                if v == "enemy" or v == "hostile" or v == "npc" or v == "bot" then return true end
            end
        end
    end

    for _, child in next, model:GetChildren() do
        if child:IsA("Script") or child:IsA("LocalScript") then
            local n = child.Name:lower()
            if n:find("ai") or n:find("behavior") or n:find("patrol") or n:find("attack") or n:find("combat") then
                return true
            end
        end
        for _, ab in next, {"Attack","Damage","Aggro","Patrol","AI","BehaviorTree"} do
            if child.Name == ab or child.Name == ab .. "Script" then return true end
        end
    end

    for _, tag in next, CollectionService:GetTags(model) do
        local tl = tag:lower()
        for _, nt in next, NPCTags do
            if tl:find(nt:lower(), 1, true) then return true end
        end
    end

    for _, pat in next, {"^npc_","^enemy_","^bot_","^mob_","_npc$","_enemy$","_bot$"} do
        if string.match(name, pat) then return true end
    end

    return true  -- fallback: tem humanoid e não é player
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

workspace.ChildAdded:Connect(function(c)
    if c:IsA("Model") or c:IsA("Folder") then task.wait(0.5); npcCacheDirty = true end
end)
workspace.ChildRemoved:Connect(function(c)
    if c:IsA("Model") or c:IsA("Folder") then npcCacheDirty = true end
end)

task.spawn(function() task.wait(1); scanNPCs() end)

-- ==========================================
-- [[ 8. LOOP ÚNICO UNIFICADO ]]
-- ==========================================
local localPlayer    = Players.LocalPlayer
local hitboxThrottle = 0
local movThrottle    = 0
local noclipThrottle = 0

RunService.Heartbeat:Connect(function(dt)

    -- WalkSpeed / JumpPower (0.05s)
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

    -- Noclip (0.1s)
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

    -- Hitbox (0.1s)
    hitboxThrottle = hitboxThrottle + dt
    if hitboxThrottle < 0.1 then return end
    hitboxThrottle = 0

    local anyOn = getgenv().HeadHitbox or getgenv().BodyHitbox or getgenv().MeleeHitbox

    -- Players
    for _, v in next, Players:GetPlayers() do
        if v ~= localPlayer then
            pcall(function()
                if v.Character then
                    local teamOk = not getgenv().TeamCheck or (localPlayer.Team ~= v.Team)
                    if getgenv().HitboxStatus and anyOn and teamOk then
                        applyHitbox(v.Character, "Really black")
                    else
                        resetHitbox(v.Character)
                    end
                end
            end)
        end
    end

    -- NPCs
    if getgenv().NPCHitbox then
        if npcCacheDirty then task.spawn(scanNPCs) end
        for _, model in next, npcCache do
            pcall(function()
                if model and model.Parent then
                    if getgenv().HitboxStatus and anyOn then
                        applyHitbox(model, "Really red")
                    else
                        resetHitbox(model)
                    end
                end
            end)
        end
    end
end)

-- ==========================================
-- [[ 9. ABA PLAYERS ]]
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
-- [[ 10. ABA VISUALS ]]
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
-- [[ 11. ABA GAMES (Condicional) ]]
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
-- [[ 12. CONFIGURAÇÕES DA LIBRARY ]]
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

Library:Notify('Hitbox Expander FINAL carregado! — v3 AntiLag + AntiFreeze', 4)
