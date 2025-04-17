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
        sm.event.sendToGame("sv_onRockHit", self.harvestable)
    end
end



---@class MineralFormation : RockFormation
MineralFormation = class(RockFormation)
MineralFormation.poseWeightCount = 2

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

        local drop = sm.harvestable.create(hvs_mineralDrop, vec3(worldPos.x, worldPos.y, 0.1), angleAxis(math.rad(math.random(1, 360)), VEC3_UP))
        drop:setParams({ type = self.sv.type, amount = math.random(1, 4) })

        self.harvestable:destroy()
    else
        self.storage:save(self.sv)
        sm.event.sendToGame("sv_onRockHit", self.harvestable)
    end
end



function MineralFormation:cl_colour(_type)
    self.harvestable:setColor(MINERALCOLOURS[_type])
end