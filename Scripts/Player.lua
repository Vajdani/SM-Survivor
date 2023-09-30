---@class Player : PlayerClass
Player = class( nil )

local verticalOffset = sm.vec3.new(0,0,10)
local moveDirs = {
	[1] = sm.vec3.new(-1,0,0),
    [2] = sm.vec3.new(1,0,0),
    [3] = sm.vec3.new(0,1,0),
    [4] = sm.vec3.new(0,-1,0),
}

function Player:server_onCreate()
	print("Player.server_onCreate")
	self.moveDir = sm.vec3.zero()
end

function Player:server_onFixedUpdate()
	local char = self.player.character
	if not self.input or not sm.exists(self.input) then
		if char and sm.exists(char) then
			local worldPos = char.worldPosition

			if not self.controlled then
				self.controlled = sm.unit.createUnit(sm.uuid.new("eb3d1c56-e2c0-4711-9c8d-218b36d5380b"), worldPos)
			end

			self.input = sm.harvestable.create(
				sm.uuid.new("7ebb9c69-3e14-4b4a-83b4-2a8e0b2e8952"),
				worldPos - verticalOffset
			)
		end

		return
	end

	if not self.input:getSeatCharacter() then
		self.input:setSeatCharacter(char)
	end
	self.input:setPosition(self.controlled.character.worldPosition - verticalOffset)
	self.controlled:setMovementDirection(self.moveDir)

	local moving = self.moveDir:length2() > 0
	if moving then
		self.controlled:setFacingDirection(self.moveDir)
	end

	self.controlled:setMovementType(moving and "walk" or "stand")
end

function Player:sv_onMove(data)
	local dir = moveDirs[data.key]
	if data.state then
		self.moveDir = self.moveDir + dir
	else
		self.moveDir = self.moveDir - dir
	end
end



function Player:client_onCreate()
	self.isLocal = self.player == sm.localPlayer.getPlayer()
	if not self.isLocal then return end

	self:cl_cam()
end

function Player:client_onReload()
	return true
end

function Player:client_onInteract()
	return true
end

local camOffset = sm.vec3.new(-0.75,-1.25,1) * 10
function Player:client_onUpdate(dt)
	local char = self.player.character
	if not self.isLocal or not char then return end

	if self.cam ~= 3 then return end
	local charPos = char.worldPosition + verticalOffset
	local newPos = charPos + camOffset
	sm.camera.setPosition(sm.vec3.lerp(sm.camera.getPosition(), newPos, dt * 15))
	sm.camera.setDirection(charPos - newPos)
end

function Player:cl_cam()
	self.cam = self.cam == 3 and 0 or 3
	sm.camera.setCameraState(self.cam)
	sm.camera.setFov(45)
end