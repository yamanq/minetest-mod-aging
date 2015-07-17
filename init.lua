local aging = {}
aging.agingSpeed = 1
local timers = {
                "speedTimer",
                "hotbarTimer",
                "cancerTimer",
                "ageTimer"
                }
aging.timersCurrent = {}
timerFunctions = {}
timersCalc = {}
aging.agingPeople = {}
local mainTimer = 0
local e = 2.7182818284590452353602874713527
math.randomseed(os.time())

local function SaveAgesToFile()
    local data = minetest.serialize(aging);
    local file = io.open(minetest.get_worldpath().."/aging.data", "w" );
    file:write(data);
    print("[Mod Aging] Recorded Ages.")
    file:close();
end

local function GetAges()
    local file = io.open(minetest.get_worldpath().."/aging.data", "r" );
    if file then
        local data = file:read("*all");
        aging = minetest.deserialize(data);
        print("[Mod Aging] Read Ages.")
        file:close();
    end
end

GetAges()

-- KEEP VALUES ON RESTART:
-- <VanessaE> for the first question, save your variable in a file on disk.

-- getAgeTimer()

minetest.register_globalstep(function(dtime)
    for _,timer in ipairs(timers) do
        aging.timersCurrent[timer] = aging.timersCurrent[timer] + dtime
        local temp = assert(loadstring('return timersCalc.'..timer..'(...)'))()
        if aging.timersCurrent[timer] >= temp then
            for _,player in ipairs(minetest.get_connected_players()) do
                if not aging.agingPeople[player:get_player_name()].immortality then
                    assert(loadstring('timerFunctions.'..timer..'(...)'))(player)
                end
            end
            aging.timersCurrent[timer] = 0
        end
    end
end)

-- Timer Current
aging.timersCurrent.speedTimer = 0
aging.timersCurrent.hotbarTimer = 0
aging.timersCurrent.cancerTimer = 0
aging.timersCurrent.ageTimer = 0

-- Aging Timer Calculations
function timersCalc.speedTimer()
    return 1
end

function timersCalc.hotbarTimer()
    return 6
end

function timersCalc.cancerTimer()
    return 10
end

function timersCalc.ageTimer()
    return aging.agingSpeed
end

-- Aging Updates
function timerFunctions.speedTimer(player)
    if aging.agingPeople[player:get_player_name()].slowMoveEnabled then
        if player:get_wielded_item():get_name() == "default:stick" then
            player:set_physics_override({
                speed = 1,
            })
        else
            player:set_physics_override({
                speed = 1.02 * math.pow(0.99, aging.agingPeople[player:get_player_name()].age),
            })
        end
    else
        player:set_physics_override({
            speed = 1,
        })
    end
end

function timerFunctions.hotbarTimer(player)
    local playerName = player:get_player_name()
    if aging.agingPeople[playerName].hotbarEnabled then
        local hotbar = 8 - math.floor(aging.agingPeople[playerName].hotbarMemory * 0.2) + aging.agingPeople[playerName].hotbarAntidote
        aging.agingPeople[playerName].hotbarMemory = aging.agingPeople[playerName].hotbarMemory + 1
        if hotbar > 0 then
            player:hud_set_hotbar_itemcount(hotbar)
        else
            player:hud_set_hotbar_itemcount(1)
        end
    end
end

function timerFunctions.cancerTimer(player)
    local playerName = player:get_player_name()
    if aging.agingPeople[playerName].cancerEnabled then                
        if aging.agingPeople[playerName].cancerTherapy and aging.agingPeople[playerName].cancerDuration > 0 then
            aging.agingPeople[playerName].cancerDuration = aging.agingPeople[playerName].cancerDuration - 5
        elseif aging.agingPeople[playerName].cancerTherapy and aging.agingPeople[playerName].cancerDuration <= 0 then
            aging.agingPeople[playerName].cancerDuration = 0
            aging.agingPeople[playerName].cancerTherapy = false
            aging.agingPeople[playerName].cancerEnabled = false
        elseif aging.agingPeople[playerName].cancerTherapy == false then
            aging.agingPeople[playerName].cancerDuration = aging.agingPeople[playerName].cancerDuration + 1
        end
        local damage = math.floor(18.47 / (1 + 66.3 * math.pow(e, -0.15 * aging.agingPeople[playerName].cancerDuration)))
        player:set_hp(player:get_hp() - damage)
    end
end

function timerFunctions.ageTimer(player)
    local playerName = player:get_player_name()
    aging.agingPeople[playerName].age = aging.agingPeople[playerName].age + 1
    local message = "Happy Birthday! You are now "..aging.agingPeople[playerName].age.." years old!"
    minetest.chat_send_player(playerName, message)
    ager(player, aging.agingPeople[playerName].age)
end


-- Set aging speed ingame
minetest.register_chatcommand("agespeed", {
    params = "<speed>",
    description = "Set number of seconds in one year",
    privs = {basic_privs = true},
    func = function(name, speed)
        speed = tonumber(speed)
        if type(speed) == "number" then
            if speed >= 0 then
                aging.agingSpeed = speed
                return true, "Aging speed has been set."
            elseif speed < 0 then
                return false, "Error: Value must be positive."
            end
        else
            return false, "Error: Enter a number"
        end
    end,
})

minetest.register_chatcommand("cure", {
    params = "<name>",
    description = "Cure yourself or another of all current diseases",
    privs = {basic_privs = true},
    func = function(name, param)
        if param == "" then
            cure(minetest.get_player_by_name(name))
            return true, "You have been cured"
        elseif minetest.get_player_by_name(param) then
            cure(minetest.get_player_by_name(param))
            return true, param.." has been cured"
        else
            return false, "Error: Could not find player"
        end
    end,
})

minetest.register_chatcommand("age", {
    description = "See current age",
    privs = {interact = true},
    func = function(name)
        if aging.agingPeople[name] ~= nil then
            local message = "You are currently "..aging.agingPeople[name].age.." years old."
            return true, message
        else
            return false, "Error, could not get age."
        end
    end,
})

minetest.register_chatcommand("setage", {
    params = "<name> <age/immortal>",
    description = "Set age of player",
    privs = {basic_privs = true},
    func = function(name, param)
        local playerName, ageToSet = string.match(param, "([^ ]+) (.+)")
        local numberAge = tonumber(ageToSet)
        if minetest.get_player_by_name(name) then
            if type(tonumber(ageToSet)) == "number" then
                if numberAge >= 0 then
                    aging.agingPeople[playerName].immortality = false
                    aging.agingPeople[playerName].age = numberAge
                    return true, "Age has been set."
                elseif numberAge < 0 then
                    return false, "Error: Age must be positive."
                end
            elseif ageToSet == "immortal" then
                aging.agingPeople[playerName].immortality = true
                local player = minetest.get_player_by_name(playerName)
                cure(player)
                player:set_physics_override({speed = 1,})
                return true, playerName.." is now immortal."
            end
        else
            return false, "Error: Could not find player."
        end
    end,
})

minetest.register_on_joinplayer(function(player)
    if not aging.agingPeople[player:get_player_name()] then
        create_age(player)
    else

    end
end)

minetest.register_on_shutdown(function()
    SaveAgesToFile()
end)

minetest.register_on_newplayer(function(player)
    create_age(player)
end)

function ager(player, age)
    local playerName = player:get_player_name()

    -- Chances
    local hotbarChance = 20 / (1 + 100 * math.pow(e, -0.09 * age))
    local cancerChance = 10 / (1 + 40 * math.pow(e,-0.05 * age))
    local slowMoveChance = 15 / (1 + 500 * math.pow(e,-0.1 * age))

    -- Hotbar Decreaser
    if math.random(100) <= hotbarChance and not aging.agingPeople[playerName].hotbarEnabled then
        minetest.chat_send_player(playerName, "You are starting to forget things.")
        aging.agingPeople[playerName].hotbarEnabled = true
    end

    -- Cancer
    if math.random(100) <= cancerChance and not aging.agingPeople[playerName].cancerEnabled then
        minetest.chat_send_player(playerName, "You have been diagnosed with cancer.")
        aging.agingPeople[playerName].cancerEnabled = true
    end

    -- Slower Movement
    if math.random(100) <= slowMoveChance and not aging.agingPeople[playerName].slowMoveEnabled then
        minetest.chat_send_player(playerName, "You can no longer run like you used to.")
        aging.agingPeople[playerName].slowMoveEnabled = true
    end
end

function create_age(player)
    local playerName = player:get_player_name()
    aging.agingPeople[playerName] = {}
    aging.agingPeople[playerName].name = playerName
    aging.agingPeople[playerName].age = 0
    aging.agingPeople[playerName].immortality = false
    cure(player)
end

function cure(player)
    local playerName = player:get_player_name()
    -- Hotbar
    aging.agingPeople[playerName].hotbarEnabled = false
    aging.agingPeople[playerName].hotbarMemory = 0
    aging.agingPeople[playerName].hotbarAntidote = 0

    -- Cancer
    aging.agingPeople[playerName].cancerEnabled = false
    aging.agingPeople[playerName].cancerDuration = 0
    aging.agingPeople[playerName].cancerTherapy = false

    -- Slow Move
    aging.agingPeople[playerName].slowMoveEnabled = false
end

minetest.override_item("default:dry_shrub", {
    description = "Herb to help Memory",
    on_use = function(itemstack, user, pointed_thing)
        itemstack:take_item()
        local playerName = user:get_player_name()
        if aging.agingPeople[user:get_player_name()].hotbarEnabled and (not aging.agingPeople[user:get_player_name()].immortality) then
            hotbar = 8 - math.floor(aging.agingPeople[playerName].hotbarMemory * 0.2) + aging.agingPeople[playerName].hotbarAntidote
            if hotbar < 8 and hotbar > 0 then
                aging.agingPeople[playerName].hotbarAntidote = aging.agingPeople[playerName].hotbarAntidote + 1
            elseif hotbar < 1 then
                aging.agingPeople[playerName].hotbarAntidote = 0
                aging.agingPeople[playerName].hotbarMemory = 30
            end
            timerFunctions.hotbarTimer(user)
        end
        return itemstack
    end
    })

minetest.register_craftitem("aging:fountain_of_youth", {
    description = "The Fountain of Youth",
    inventory_image = "aging_fountain_of_youth.png",
    on_use = function(itemstack, user, pointed_thing)
        itemstack:take_item()
        create_age(user)
        return itemstack
    end
})

-- Cancer Cure
minetest.register_craftitem("aging:cancer_cure", {
    description = "The Cure to Cancer",
    inventory_image = "aging_cancer_cure.png",
    on_use = function(itemstack, user, pointed_thing)
        itemstack:take_item()
        if pointed_thing.type == "object" then
            if pointed_thing.ref:is_player() then
                aging.agingPeople[pointed_thing.ref:get_player_name()].cancerTherapy = true
            end
        else
            aging.agingPeople[user:get_player_name()].cancerTherapy = true
        end
        return itemstack
    end,
 
    on_drop = function(itemstack, dropper, pos)
        itemstack:take_item()
        minetest.chat_send_player(dropper:get_player_name(), "The Great Cure has been Destroyed!")
        return itemstack
    end,
})

minetest.register_craftitem("aging:cancer_funding", {
    description = "Cancer Funding",
    inventory_image = "aging_cancer_funding.png",
})

minetest.register_craftitem("aging:cancer_research", {
    description = "Cancer Research",
    inventory_image = "aging_cancer_research.png",
})

minetest.register_craft({
    output = "aging:fountain_of_youth",
    recipe = {
        {"","bucket:bucket_water",""},
        {"bucket:bucket_lava", "default:nyancat", "bucket:bucket_lava"},
        {"", "vessels:glass_bottle", ""}
    },
})

-- Cancer Cure
minetest.register_craft({
    type = "shapeless",
    output = "aging:cancer_cure",
    recipe =
        {"aging:cancer_research",
         "aging:cancer_research",
         "aging:cancer_research",
         "aging:cancer_research",
         "aging:cancer_research",
         "aging:cancer_research",
         "aging:cancer_research",
         "aging:cancer_research",
         "aging:cancer_research"},
})

-- Various Cancer Funding
minetest.register_craft({
    type = "shapeless",
    output = "aging:cancer_funding",
    recipe =
        {"group:flower",
         "default:diamondblock",
         "default:diamondblock",
         "default:diamondblock",
         "default:diamondblock",
         "default:diamondblock",
         "default:diamondblock",
         "default:diamondblock",
         "default:diamondblock"},
})
minetest.register_craft({
    type = "shapeless",
    output = "aging:cancer_funding",
    recipe =
        {"group:flower",
         "default:mese",
         "default:mese",
         "default:mese",
         "default:mese",
         "default:mese",
         "default:mese",
         "default:mese",
         "default:mese"},
})
minetest.register_craft({
    type = "shapeless",
    output = "aging:cancer_funding",
    recipe =
        {"group:flower",
         "default:goldblock",
         "default:goldblock",
         "default:goldblock",
         "default:goldblock",
         "default:goldblock",
         "default:goldblock",
         "default:goldblock",
         "default:goldblock"},
})

-- Cancer Research
minetest.register_craft({
    output = "aging:cancer_research",
    recipe = {
        {"aging:cancer_funding", "aging:cancer_funding", "aging:cancer_funding"},
        {"aging:cancer_funding", "default:bookshelf", "aging:cancer_funding"},
        {"aging:cancer_funding", "aging:cancer_funding", "aging:cancer_funding"}
    }
})

