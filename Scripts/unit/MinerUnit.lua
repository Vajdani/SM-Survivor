---@class MinerUit : UnitClass
MinerUnit = class()

local mineTimer = 25

function MinerUnit:server_onCreate()
    self.mineBox =  sm.areaTrigger.createBox(sm.vec3.new(1.125,0.75,1), sm.vec3.zero(), sm.quat.identity(), sm.areaTrigger.filter.harvestable)
    self.timer = mineTimer
    self.swinging = false
end

function MinerUnit:server_onFixedUpdate()
    local char = self.unit.character
    if not char or not sm.exists(char) then return end

    local pos = char.worldPosition
    local dir = char.direction
    self.mineBox:setWorldPosition(pos + dir)
	self.mineBox:setWorldRotation(sm.vec3.getRotation(VEC3_Y, dir))

    local oldSwinging = self.swinging
    local contents = self.mineBox:getContents()
    if #contents > 0 and sm.physics.spherecast(pos, pos + char.direction * 2, 0.1) then
        self.swinging = true
        self.timer = self.timer - 1
        if self.timer <= 0 then
            for k, rock in pairs(contents) do
                if sm.exists(rock) then
                    local hit, result = sm.physics.raycast(pos, rock.worldPosition)
                    sm.effect.playEffect(
                        "Sledgehammer - Hit", result.pointWorld, nil, nil, nil,
                        { Material = rock.materialId }
                    )

                    sm.event.sendToHarvestable(rock, "sv_onHit")
                end
            end

            self.timer = mineTimer
        end
    elseif self.swinging then
        self.timer = mineTimer
        self.swinging = false
    end

    if self.swinging ~= oldSwinging then
        self.unit:sendCharacterEvent( "swing"..(self.swinging and "_start" or "_end") )
    end
end