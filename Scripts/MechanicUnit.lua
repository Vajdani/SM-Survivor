---@class MechanicUit : UnitClass
MechanicUnit = class()

local mineTimer = 10

function MechanicUnit:server_onCreate()
    self.mineBox =  sm.areaTrigger.createBox(sm.vec3.one(), sm.vec3.zero(), sm.quat.identity(), sm.areaTrigger.filter.harvestable)
    self.timer = mineTimer
end

local y = sm.vec3.new(0,1,0)
function MechanicUnit:server_onFixedUpdate()
    local char = self.unit.character
    if not char or not sm.exists(char) then return end

    local pos = char.worldPosition
    local dir = char.direction
    self.mineBox:setWorldPosition(pos + dir)
	self.mineBox:setWorldRotation(sm.vec3.getRotation(y, dir))

    local contents = self.mineBox:getContents()
    if #contents > 0 then
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
    else
        self.timer = mineTimer
    end
end