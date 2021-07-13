local modname = minetest.get_current_modname()
local register_craftitem = minetest.register_tool
local register_entity = minetest.register_entity
local add_entity = minetest.add_entity

local mudsling = {}
mudsling.players = {}
mudsling.GRAVITY_BASE = 0.987
mudsling.POWER_MAX = 12

mudsling.checkPlayer = function(name)
    return mudsling.players[name]
end

mudsling.addPlayer = function(name)
    if(name and type(name) == "string")then
        mudsling.players[name] = {active = false, hud = 0, power = 1}
    end
end

mudsling.activate = function(name)
    mudsling.players[name].active = true
end

mudsling.deactivate = function(name)
    mudsling.players[name].active = false
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


local function invertPlayerPhysics(name, state)
    -- removes gravity and jump if [state] is falsy and returns them if truthy
    local player = minetest.get_player_by_name(name)
    if(name and type(name) == "string" and player)then
        local val = state and 1 or 0
        local physics_params = player:get_physics_override()
        physics_params.gravity = val
        physics_params.jump = val
        -- speed-removal removed to allow some degree of motion in-flight
        player:set_physics_override(physics_params)
    end
end

mudsling.invertPlayerPhysics = invertPlayerPhysics


local function generateAngularVel(name,vec)
    if(name and type(name) == "string")then
        local player = minetest.get_player_by_name(name)
        local pos = player:get_pos()
        vec = vec or player:get_look_dir()
        local sdata = minetest.serialize({name = name, vel = vec})
        minetest.add_entity(pos, modname .. ":entity", sdata)
    end
end
mudsling.generateAngularVel = generateAngularVel


local function enforceGravity(obj)
    -- draws down the object by subtracting from y-component of velocity vector.
    local vel = obj:get_velocity()
    vel.y = vel.y - mudsling.GRAVITY_BASE
    obj:set_velocity(vel)
end
mudsling.enforceGravity = enforceGravity


local function attenuateVel(obj)
    -- reduces all components of velocity vector; wannabe air resistance.
    local vel = obj:get_velocity()
    vel = vector.divide(vel,1.0005)
    obj:set_velocity(vel)
end
mudsling.attenuateVel = attenuateVel


local function setProps(obj,propdef)
    -- performs set_properties on as many key-value pairs as present in propdef.
    if(obj and obj:get_properties())then
        local props = obj:get_properties()
        
        for k,v in pairs(propdef)do
            if(props[k])then
                props[k] = v
            end
        end
        
        obj:set_properties(props)
    end
end

mudsling.setProps = setProps


local function getProp(obj, label)
    -- returns the value of the property with the key [label] if it exists.
    if(obj and obj:get_properties())then
        local props = obj:get_properties()
        return props[label]
    end
end

mudsling.getProp = getProp

local function activateSling(name)
    -- Intended to kick-start the functions required for launching to work.
    if(not (mudsling.checkPlayer(name) and mudsling.checkPlayer(name).active))then

        mudsling.activate(name)
        local power = mudsling.players[name].power*10 or 40
        local vec = vector.multiply(minetest.get_player_by_name(name):get_look_dir(),-power)
        minetest.sound_play({name = "thwang_muddy"}, {to_player = name, gain = 0.25, pitch = 1})
        mudsling.generateAngularVel(name,vec)
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
        mudsling.activateSling(name)
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        local name = user:get_player_name()
        mudsling.activateSling(name)
    end
})




-- ENTITYDEF

local entdef = {
    physical = true,
    collide_with_objects = false,
    pointable = false,
    is_visible = false,
    static_save = false,
    weight = 5,
    collisionbox = {-0.5, 0.0, -0.5, 0.5, 1.0, 0.5},
    selectionbox = {-0.5, 0.0, -0.5, 0.5, 1.0, 0.5},

    on_activate = function(self, staticdata)
        
        self.object:set_armor_groups({immortal = 1}) -- become immortal, it deserves it anyway.
        local data = minetest.deserialize(staticdata)

        -- player stuff
        mudsling.setProps(self.object,{infotext = data.name})
        mudsling.invertPlayerPhysics(data.name)

        -- set starting velocity
        self.object:set_velocity(data.vel)

    end,
    on_step = function(self)
        local obj = self.object
        local name = mudsling.getProp(obj,"infotext") -- change
        local player = minetest.get_player_by_name(name)
        local pos = obj:get_pos()
        local is_shift_key_pressed = player:get_player_control().sneak

        if(obj:get_velocity().y == 0 or is_shift_key_pressed)then        
            
            mudsling.deactivate(name)
            mudsling.invertPlayerPhysics(name,true)
            obj:remove()

        else

            obj:set_velocity(vector.add(obj:get_velocity(),vector.divide(player:get_velocity(),10)))
            
            mudsling.attenuateVel(obj)
            mudsling.enforceGravity(obj)

            player:move_to(pos)
            
        end
        
    end
}
register_entity(modname .. ":entity", entdef)

minetest.register_on_joinplayer(function(obj)
    local name = obj:get_player_name()
    mudsling.addPlayer(name)
end)
minetest.register_craft({
    output = modname .. ":sling",
    recipe = {
        {"default:dirt_with_grass","bucket:bucket_water","default:dirt_with_grass"},
        {"default:dirt_with_grass","default:dirt_with_grass","default:dirt_with_grass"},
        {"","default:dirt_with_grass",""}
    },
})