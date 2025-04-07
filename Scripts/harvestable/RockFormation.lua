---@class RockFormation : HarvestableClass
RockFormation = class()
RockFormation.poseWeightCount = 2

function RockFormation:server_onCreate()
    local params = self.params
    if params then
        self.sv = { type = params[1], health = params[2] }
        self.storage:save(self.sv)
    else
        local rockType = ROCKTYPES[ROCKTYPE.ROCK]
        self.sv = self.storage:load() or { type = rockType[1], health = rockType[2] }
    end
end

function RockFormation:sv_onHit()
    if not sm.exists(self.harvestable) or self.sv.type == ROCKTYPE.BORDER then return end

    self.sv.health = self.sv.health - 1
    if self.sv.health <= 0 then
        local worldPos = self.harvestable.worldPosition
        sm.effect.playEffect(
            "RockFormation - Break", worldPos,
            nil, self.harvestable.worldRotation, nil,
            { size = self.harvestable:getMass() / AUDIO_MASS_DIVIDE_RATIO }
        )

        self.harvestable:destroy()
    else
        self.storage:save(self.sv)
        self.network:sendToClients("cl_onHit")
    end
end



function RockFormation:client_onCreate()
    self.animProgress = 0
end

function RockFormation:client_onFixedUpdate(dt)
    if self.animProgress <= 0 then return end

    self.animProgress = math.max(self.animProgress - dt * 5, 0)
    self.harvestable:setPoseWeight(0, self.animProgress)
end

function RockFormation:cl_onHit()
    self.animProgress = math.random(50, 100) * 0.01
end



---@class MineralFormation : RockFormation
MineralFormation = class(RockFormation)
MineralFormation.poseWeightCount = 2
MineralFormation.colours = {
    [ROCKTYPE.GOLD]  = sm.color.new(1,1,0),
    [ROCKTYPE.NITRA] = sm.color.new(1,0,0),
}

function MineralFormation:server_onCreate()
    local params = self.params
    if params then
        self.sv = { type = params[1], health = params[2] }
        self.storage:save(self.sv)
    else
        local rockType = ROCKTYPES[ROCKTYPE.GOLD]
        self.sv = self.storage:load() or { type = rockType[1], health = rockType[2] }
    end

    self.network:sendToClients("cl_colour", self.sv.type)
end

local mineralDrop = sm.uuid.new("f6cc2b7a-fa4c-42e5-b272-604549028149")
function MineralFormation:sv_onHit()
    if not sm.exists(self.harvestable) then return end

    self.sv.health = self.sv.health - 1
    if self.sv.health <= 0 then
        local worldPos = self.harvestable.worldPosition
        sm.effect.playEffect(
            "RockFormation - Break", worldPos,
            nil, self.harvestable.worldRotation, nil,
            { size = self.harvestable:getMass() / AUDIO_MASS_DIVIDE_RATIO }
        )

        sm.projectile.harvestableCustomProjectileAttack(
            { type = self.sv.type, amount = math.random(1, 4) },
            mineralDrop, 0, worldPos, sm.noise.gunSpread(VEC3_UP * 2.5, 5),
            self.harvestable, 0
        )

        self.harvestable:destroy()
    else
        self.storage:save(self.sv)
        self.network:sendToClients("cl_onHit")
    end
end



function MineralFormation:cl_colour(_type)
    self.harvestable:setColor(self.colours[_type])
end