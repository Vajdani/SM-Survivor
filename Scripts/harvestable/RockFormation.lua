---@class RockFormation : HarvestableClass
---@field dropData? { uuid: Uuid, amount: fun():number }
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

function RockFormation:server_onExplosion(center, destructionLevel)
    self:sv_onHit(self.sv.health)
end

function RockFormation:sv_onHit(damage)
    if not sm.exists(self.harvestable) or self.sv.type == ROCKTYPE.BORDER then return end

    self.sv.health = self.sv.health - (damage or 1)
    if self.sv.health <= 0 then
        local worldPos = self.harvestable.worldPosition
        sm.effect.playEffect(
            "RockFormation - Break", worldPos,
            nil, self.harvestable.worldRotation, nil,
            { size = self.harvestable:getMass() / AUDIO_MASS_DIVIDE_RATIO }
        )

        if self.dropData then
            local drop = sm.harvestable.create(self.dropData.uuid, vec3(worldPos.x, worldPos.y, 0.1), angleAxis(math.rad(math.random(1, 360)), VEC3_UP))
            drop:setParams({ type = self.sv.type, amount = self.dropData.amount() })
        end

        self.harvestable:destroy()
    else
        self.storage:save(self.sv)
        sm.event.sendToGame("sv_onRockHit", self.harvestable)
    end
end



---@class MineralFormation : RockFormation
MineralFormation = class(RockFormation)
MineralFormation.poseWeightCount = 2
MineralFormation.dropData = {
    uuid = hvs_mineralDrop,
    amount = function() return math.random(1, 4) end
}

function MineralFormation:server_onCreate()
    RockFormation.server_onCreate(self)

    self.network:sendToClients("cl_colour", self.sv.type)
end



function MineralFormation:cl_colour(_type)
    self.harvestable:setColor(MINERALCOLOURS[_type])
end



---@class MorkiteFormation : MineralFormation
MorkiteFormation = class(MineralFormation)
MorkiteFormation.dropData = {
    uuid = hvs_mineralDrop,
    amount = function() return math.random(1, 2) end
}