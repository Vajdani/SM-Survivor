---@class CollectItemMission : ScriptableObjectClass
CollectItemMission = class()

function CollectItemMission:server_onCreate()
    self.sv_missionId = self.params.id
    self.sv_mineralId = self.params.data.mineralId
    self.sv_targetAmount = self.params.data.goal
    self.sv_collectedAmount = 0

    EventManager.SubscribeToEvent(self.scriptableObject, "sv_collectItem", "CollectItem")
    self.network:setClientData({ self.sv_missionId, self.sv_mineralId, self.sv_targetAmount }, 1)
end

function CollectItemMission:server_onDestroy()
    EventManager.UnSubscribeFromEvent(self.scriptableObject, "CollectItem")
end

function CollectItemMission:sv_collectItem(args)
    if args.type ~= self.sv_mineralId then return end

    self.sv_collectedAmount = self.sv_collectedAmount + args.amount
    self.network:setClientData(self.sv_collectedAmount, 2)

    if self.sv_collectedAmount >= self.sv_targetAmount then
        print("mission completed")
    end
end



function CollectItemMission:client_onCreate()
    self.cl_missionId = 0
    self.cl_mineralId = -1
    self.cl_targetAmount = 0
    self.scriptableObject.clientPublicData = {}
end

function CollectItemMission:client_onClientDataUpdate(data, channel)
    if channel == 1 then
        self.cl_missionId = data[1]
        self.cl_mineralId = data[2]
        self.cl_targetAmount = data[3]

        local missionData = SIDEMISSIONDATA[self.cl_missionId]
        self.scriptableObject.clientPublicData = {
            title = missionData.title,
            icon = missionData.icon,
            progress = "0/"..self.cl_targetAmount
        }
    else
        self.scriptableObject.clientPublicData.progress = data.."/"..self.cl_targetAmount
    end
end