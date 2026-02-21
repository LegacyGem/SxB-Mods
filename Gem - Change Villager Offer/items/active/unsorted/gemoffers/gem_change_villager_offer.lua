require "/scripts/messageutil.lua"

function init()
  self.offerType = config.getParameter("offerType")
end

local actionLock = false

function update(dt, fireMode, shiftHeld)
  promises:update()
  if fireMode ~= "none" then
    if not actionLock then
      fire()
      actionLock = true
    end
  else
    actionLock = false
  end
end

function fire()
  local npcs = world.entityQuery(activeItem.ownerAimPosition(), 3, {includedTypes = {"npc"}, order = "nearest"})
  if npcs[1] then
    local promise = world.sendEntityMessage(npcs[1], "gemForceTypeChange", { offerType = self.offerType })
    promises:add(promise, onSuccess, onFailure)
  end
end

function onSuccess(newEntityId)
  if newEntityId and world.entityExists(newEntityId) then
    item.setCount(0)
  end
end

function onFailure(error)
  sb.logInfo("[GemVillagerOffer] conversion failed: %s", tostring(error))
end

