---@class RockFormation : HarvestableClass
RockFormation = class()
RockFormation.poseWeightCount = 2
RockFormation.colours = {
    gold = sm.color.new(1,1,0),
    nitra = sm.color.new(1,0,0),
}

local defaultRock = { type = "generic", health = 3 }
local mineralDrop = sm.uuid.new("f6cc2b7a-fa4c-42e5-b272-604549028149")

function RockFormation:server_onCreate()
    self.sv = {}

    local params = self.params
    if params then
        self.sv.type = params.type
        self.sv.health = params.health
        self.storage:save(self.sv)
    else
        local data = self.storage:load() or defaultRock
        self.sv.type = data.type
        self.sv.health = data.health

        if data.type ~= "generic" then
            self.network:sendToClients("cl_load", data)
        end
    end
end

function RockFormation:sv_onHit()
    if not sm.exists(self.harvestable) then return end

    self.sv.health = self.sv.health - 1
    if self.sv.health <= 0 then
        local worldPos = self.harvestable.worldPosition
        sm.effect.playEffect(
            "RockFormation - Break", worldPos,
            nil, self.harvestable.worldRotation, nil,
            { size = self.harvestable:getMass() / AUDIO_MASS_DIVIDE_RATIO }
        )

        if self.sv.type ~= "generic" then
            sm.projectile.harvestableCustomProjectileAttack(
                { type = self.sv.type, amount = math.random(1, 4) },
                mineralDrop, 0, worldPos, sm.noise.gunSpread(VEC3_UP * 2.5, 5),
                self.harvestable, 0
            )
        end

        self.harvestable:destroy()
    else
        self.storage:save(self.sv)
        self.network:sendToClients("cl_onHit")
    end
end



function RockFormation:client_onCreate()
    local params = self.params
    if params then
        self:cl_load(params)
    end

    self.animProgress = 0
end

function RockFormation:client_onFixedUpdate(dt)
    if self.animProgress <= 0 then return end

    self.animProgress = math.max(self.animProgress - dt * 5, 0)
    self.harvestable:setPoseWeight(0, self.animProgress)
end

local fxId = sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a")
local fxScale = sm.vec3.one() * 0.25
function RockFormation:cl_load(data)
    self.effects = {}

    local startPos = sm.vec3.new(-0.75,0.75,-0.75)
    for i = 1, 2 do
        for j = 1, 2 do
            local effect = sm.effect.createEffect("ShapeRenderable", self.harvestable)
            effect:setParameter("uuid", fxId)
            effect:setParameter("color", self.colours[data.type])
            effect:setScale(fxScale)
            effect:setOffsetPosition(startPos + sm.vec3.new(0.5 * i, 0, 0.5 * j))
            effect:start()

            self.effects[#self.effects+1] = effect
        end
    end
end

function RockFormation:cl_onHit()
    self.animProgress = math.random(50, 100) * 0.01
end