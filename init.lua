local modname = minetest.get_current_modname()
local register_craftitem = minetest.register_tool
local register_entity = minetest.register_entity
local add_entity = minetest.add_entity

local mudsling = {}
mudsling.players = {}
mudsling.POWER_MAX = 12

minetest.after(4, function() end)

-- Player index functions
mudsling.checkPlayer = function(name)

    return mudsling.players[name]

end

mudsling.addPlayer = function(name)
    if(name and type(name) == "string")then

        mudsling.players[name] = {active = false, hud = 0, power = 1}

    end
end

mudsling.activate = function(name)
    if(mudsling.players[name])then

        mudsling.players[name].active = true

    end
end

mudsling.deactivate = function(name)
    if(mudsling.players[name])then

        mudsling.players[name].active = false

    end
end

mudsling.isOnGround = function(name) -- returns true if [name] is standing on a non-air node
    local player = name and minetest.get_player_by_name(name)
    
    if(player)then

        local pos_under = vector.add(player:get_pos(),{x = 0, y = -0.2, z = 0})
        local node_under = minetest.get_node(pos_under)

        return node_under.name ~= "air"

    end

end

mudsling.processFlight = function()
    -- periodic function for processing indexed players. Currently used for conferring fall-damage mitigation.
    local playerpool = mudsling.players

    for k,v in pairs(playerpool) do

        if(mudsling.isOnGround(k))then

            minetest.after(1, function()

            -- using minetest.after to account for walkable nodes on top of actually solid nodes (eg. shrubs on top of dirt in default mapgen or reposed leaf nodes in nodecore).
                
            mudsling.deactivate(k)
            end)

        end

    end
end

mudsling.incrementHud = function(name) -- increments player's power counter up by 1 and updates their HUD element accordingly.
    local player = minetest.get_player_by_name(name)
    local data = mudsling.players[name]
    local shift_key_is_pressed = player:get_player_control(player).sneak
    local power = data.power
    local id = data.hud
    player:hud_remove(id)
    if(shift_key_is_pressed)then
    else
        mudsling.players[name].power = (data.power + 1 <= mudsling.POWER_MAX) and data.power + 1 or 1
        power = mudsling.players[name].power
    end

    
    mudsling.players[name].id = player:hud_add({
        hud_elem_type = "image",
        position = {x = 0.55, y = 0.5},
        scale = {x = 2, y = 2},
        size = {x = 100, y = 100},
        text = "[combine:16x16:0,0=powerbar.png:4,"..(16 - 9 - power/2).."=mudball.png" -- 9 from -8 for full texture height plus 1 pixel for visible border
    })
    minetest.after(4, function() player:hud_remove(id)end) -- NB: poor patch, redo this
    
end


local function activateSling(name, itemstack)
    -- Intended to kick-start the functions required for launching to work.
    if(mudsling.players[name])then
        local player = minetest.get_player_by_name(name)

        minetest.after(1.2, function() mudsling.activate(name) end)
        -- activate the sling with delay

        local power = mudsling.players[name].power*10 or 40

        local vec = vector.multiply(minetest.get_player_by_name(name):get_look_dir(),-power)

        player:add_player_velocity(vec)

        itemstack:add_wear(power*110)
        
        minetest.sound_play({name = "thwang_muddy"}, {to_player = name, gain = 0.25, pitch = 1})
        

    end
end

mudsling.activateSling = activateSling

-- TOOLDEF
local iname = modname .. ":sling"
register_craftitem(iname,{
    description = iname,
    groups = {},
    inventory_image = "sling.png",
    range = 0,
    on_use = function(itemstack, user)
        local name = user:get_player_name()
        mudsling.incrementHud(name)
        -- leftclick will increment upwards and display HUD element unless shift (sneak) is held
        -- in which case it will only perform the latter action
    end,
    on_place = function(itemstack,placer)
        local name = placer:get_player_name()
        mudsling.activateSling(name, itemstack)
        return itemstack
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        local name = user:get_player_name()
        mudsling.activateSling(name, itemstack)
        return itemstack
    end
})


-- SERVERSTEPS

minetest.register_on_joinplayer(function(obj)
    local name = obj:get_player_name()
    mudsling.addPlayer(name)
end)
minetest.register_on_player_hpchange(function(player, hp_change, reason) -- fall damage mitigation
    local name = player:get_player_name()

    if(mudsling.checkPlayer(name) and mudsling.players[name].active and reason.type == 'fall')then
        -- player must be active, ie. in-flight to gain protection
        hp_change = 0
    end        
return hp_change
end, true)




-- CRAFTING


if(nodecore)then

    nodecore.interval(0.5, function() mudsling.processFlight() end)
    -- use nodecore's builtin periodic-action function in the presence of nodecore

    if(nodecore.register_craft)then
    nodecore.register_craft({
        action = "pummel",
        label = "Shape the most exquisite slingshot out of dirt, water and a sponge's polysaccharide-protein-matrix skeleton",
        toolgroups = {thumpy = 4},
        nodes = {
            {
            match = "nc_terrain:dirt",
            replace = "air"
            },
            {
                y = -1,
                match = "nc_sponge:sponge_living",
                replace = "air"
            }
        },
        items = {{name = modname .. ":sling", count = 1, scatter = 10}}
    })
    end
else
    
    
minetest.register_globalstep(function() -- use minetest builtin globalstep in absence of nodecore
    mudsling.processFlight()
end)

minetest.register_craft({
    output = modname .. ":sling",
    recipe = {
        {"default:dirt_with_grass","bucket:bucket_water","default:dirt_with_grass"},
        {"default:dirt_with_grass","default:dirt_with_grass","default:dirt_with_grass"},
        {"","default:dirt_with_grass",""}
    }
})
end