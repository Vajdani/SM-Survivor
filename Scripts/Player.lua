dofile "util.lua"

---@class Player : PlayerClass
---@field input Harvestable
---@field controlled Unit
Player = class( nil )

local verticalOffset = VEC3_UP * 10
local moveDirs = {
	[1] = -VEC3_X,
    [2] = VEC3_X,
    [3] = VEC3_Y,
    [4] = -VEC3_Y,
}

function Player:server_onCreate()
	print("Player.server_onCreate")
	self.moveDir = sm.vec3.zero()

	self:sv_initMaterials()
end

function Player:server_onFixedUpdate()
	local char = self.player.character
	if not char or not sm.exists(char) then return end

	if not self.input or not sm.exists(self.input) then return end

	self.input:setPosition(self.controlled.character.worldPosition - verticalOffset)
	self.controlled:setMovementDirection(self.moveDir)

	local moving = self.moveDir:length2() > 0
	if moving then
		self.controlled:setFacingDirection(self.moveDir)
	end

	self.controlled:setMovementType(moving and "walk" or "stand")
end

function Player:sv_createMiner(pos)
	--Thank Axolot for this mess
	if not sm.exists(self.player.character) then
		sm.event.sendToPlayer(self.player, "sv_createMiner", pos)
		return
	end

	self:sv_initMaterials()

	self.input = sm.harvestable.create(sm.uuid.new("7ebb9c69-3e14-4b4a-83b4-2a8e0b2e8952"), pos)
	self.controlled = sm.unit.createUnit(sm.uuid.new("eb3d1c56-e2c0-4711-9c8d-218b36d5380b"), pos + verticalOffset)
	self.controlled.publicData = { owner = self.player }
	self:sv_seat()
end

function Player:sv_seat()
	if not sm.exists(self.input) then
		sm.event.sendToPlayer(self.player, "sv_seat")
		return
	end

	self.input:setSeatCharacter(self.player.character)
end

function Player:sv_onMove(data)
	local dir = moveDirs[data.key]
	if data.state then
		self.moveDir = self.moveDir + dir
	else
		self.moveDir = self.moveDir - dir
	end
end

function Player:sv_initMaterials()
	self.minerals = {}
	for k, v in pairs(MINERALS) do
		self.minerals[v] = 0
	end
	self.network:sendToClient(self.player, "cl_updateMineralCount", self.minerals)
end

function Player:sv_collectMineral(data)
	self.minerals[data.type] = self.minerals[data.type] + data.amount
	self.network:sendToClient(self.player, "cl_updateMineralCount", self.minerals)
end


function Player:client_onCreate()
	self.isLocal = self.player == sm.localPlayer.getPlayer()
	if not self.isLocal then return end

	self.hud = sm.gui.createGuiFromLayout(
		"$CONTENT_DATA/Gui/hud.layout", false,
		{
			isHud = true,
			isInteractive = false,
			needsCursor = false,
			hidesHotbar = true,
			isOverlapped = false,
			backgroundAlpha = 0,
		}
	)
	for k, v in pairs(MINERALS) do
		self.hud:setImage("icon_"..v, string.format("$CONTENT_DATA/Gui/MineralIcons/%s.png",v))
	end
	self.hud:open()

	self:cl_cam()
end

function Player:client_onReload()
	return true
end

function Player:client_onInteract()
	return true
end

local camOffset = sm.vec3.new(-0.75,-1.25,1.25) * 10
function Player:client_onUpdate(dt)
	local char = self.player.character
	if not self.isLocal or not char then return end

	if self.cam ~= 3 then return end
	local charPos = char.worldPosition + verticalOffset
	local newPos = charPos + camOffset * self.zoom
	sm.camera.setPosition(sm.vec3.lerp(sm.camera.getPosition(), newPos, dt * 15))
	sm.camera.setDirection(charPos - newPos)
end

function Player:cl_cam()
	self.zoom = 1
	self.cam = self.cam == 3 and 0 or 3
	sm.camera.setCameraState(self.cam)
	sm.camera.setFov(45)
end

function Player:cl_increaseZoom()
	self.zoom = self.zoom > 1 and self.zoom - 1 or 1
end

function Player:cl_decreaseZoom()
	self.zoom = self.zoom < 10 and self.zoom + 1 or 10
end

function Player:cl_updateMineralCount(data)
	for k, v in pairs(data) do
		self.hud:setText("amount_"..k, tostring(v))
	end
end