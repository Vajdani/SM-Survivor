---@class MinerUit : UnitClass
MinerUnit = class()

local mineTimer = 25

function MinerUnit:server_onCreate()
    self.mineBox =  sm.areaTrigger.createBox(vec3(2,2,1) * 0.5, sm.vec3.zero(), sm.quat.identity(), sm.areaTrigger.filter.harvestable)
    self.collectArea = sm.areaTrigger.createSphere(2, sm.vec3.zero(), nil, sm.areaTrigger.filter.harvestable)
    self.collectArea:bindOnEnter("sv_collect")

    self.swinging = false
    self.miningEnabled = true

    local data = self.params or self.storage:load()
    if data then
        self.minerData = data
        self:sv_sendCharInit()
        self.storage:save(data)
    end
end

function MinerUnit:sv_sendCharInit()
    if not sm.exists(self.unit.character) then
        sm.event.sendToUnit(self.unit, "sv_sendCharInit")
        return
    end

    sm.event.sendToCharacter(self.unit.character, "sv_init", self.minerData)
end

function MinerUnit:server_onProjectile(position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid)
	sm.event.sendToPlayer(self.unit.publicData.owner, "sv_takeDamage", damage)
end

function MinerUnit:server_onExplosion(center, destructionLevel)
	sm.event.sendToPlayer(self.unit.publicData.owner, "sv_takeDamage", destructionLevel * 3)
end

function MinerUnit:server_onMelee(position, attacker, damage, power, direction, normal)
	sm.event.sendToPlayer(self.unit.publicData.owner, "sv_takeDamage", damage)
end

function MinerUnit:server_onFixedUpdate()
    local char = self.unit.character
    if not char or not sm.exists(char) then return end

    local minerData = self.unit.publicData.owner.publicData
    char.movementSpeedFraction = minerData.runSpeedMultiplier

    if not self.timer then
        self.timer = mineTimer * minerData.mineSpeedMultiplier
    end

    local pos = char.worldPosition
    local dir = char.direction
    self.mineBox:setWorldPosition(pos + dir)
	self.mineBox:setWorldRotation(sm.vec3.getRotation(VEC3_Y, dir))
    self.collectArea:setWorldPosition(pos)

    local oldSwinging = self.swinging
    local contents = self.mineBox:getContents()

    pos = pos + VEC3_UP * char:getHeight() * 0.25
    local _, colResult = sm.physics.spherecast(pos, pos + dir * 1.9, 0.1, char)
    if self.miningEnabled and colResult.type == "harvestable" then
        self.swinging = true
        self.timer = self.timer - 1
        if self.timer <= 0 then
            for k, rock in pairs(contents) do
                if sm.exists(rock) and MINERALDROPS[rock.id] == nil then
                    local hit, result = sm.physics.raycast(pos, rock.worldPosition)
                    if hit then
                        sm.effect.playEffect(
                            "Sledgehammer - Hit", result.pointWorld, nil, nil, nil,
                            { Material = rock.materialId }
                        )
                    end

                    sm.event.sendToHarvestable(rock, "sv_onHit", minerData.mineDamage)
                end
            end

            self.timer = mineTimer * minerData.mineSpeedMultiplier
        end
    elseif self.swinging then
        self.timer = 0--mineTimer * minerData.mineSpeedMultiplier
        self.swinging = false
    end

    if self.swinging ~= oldSwinging then
        self.unit:sendCharacterEvent( "swing"..(self.swinging and "_start" or "_end") )
    end
end

function MinerUnit:sv_collect(trigger, result)
    if not self.unit then return end

    local char = self.unit.character
    for k, v in pairs(result) do
        if MINERALDROPS[v.id] == true then
            sm.event.sendToHarvestable(v, "sv_onCollect", char)
        end
    end
end

function MinerUnit:sv_onDynamiteThrow()
    self:sv_setMiningEnabled(true)
end

function MinerUnit:sv_setMiningEnabled(state)
    self.miningEnabled = state
end