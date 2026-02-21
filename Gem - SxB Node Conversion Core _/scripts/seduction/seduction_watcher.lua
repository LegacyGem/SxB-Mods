require "/scripts/messageutil.lua"

local DEBUG = true

local function log(msg, ...)
  if DEBUG then sb.logInfo("[Seduction] " .. msg, ...) end
end

local FRIENDLY_TEAM = { type = "friendly" }

local function getPregnancies(sexboundData)
  if type(sexboundData) ~= "table" then return {} end
  if type(sexboundData.pregnant) == "table" then return sexboundData.pregnant end
  if type(sexboundData.sexbound) == "table" and type(sexboundData.sexbound.pregnant) == "table" then
    return sexboundData.sexbound.pregnant
  end
  return {}
end

local function getNodePregnancies(sexNodeId)
  if not sexNodeId then return {} end

  local ok, nodeStorage = pcall(world.callScriptedEntity, sexNodeId, "Sexbound.API.getStorage")
  if not ok or type(nodeStorage) ~= "table" then
    return {}
  end

  local actorStorage = nodeStorage.actor and nodeStorage.actor.storage or nil
  if type(actorStorage) ~= "table" then
    return {}
  end

  local sexboundData = actorStorage.sexbound or actorStorage
  return getPregnancies(sexboundData)
end

local function hasAnyPregnancyInList(pregnancies)
  if type(pregnancies) ~= "table" then return false end
  for _, pregnancy in pairs(pregnancies) do
    if type(pregnancy) == "table" then
      return true
    end
  end
  return false
end

local function hasAnyPregnancyInNode(data)
  if not data then return false end
  return hasAnyPregnancyInList(getNodePregnancies(data.sexNodeId))
end

local function hasPregnantStatus(targetId)
  if not targetId or not world.entityExists(targetId) then
    return false
  end

  local ok, result = pcall(world.callScriptedEntity, targetId, "status.statusProperty", "sexbound_pregnant")
  return ok and result == true
end

local function hasAnyPregnancy(data, sexboundData)
  if hasAnyPregnancyInList(getPregnancies(sexboundData)) then
    return true
  end

  if hasAnyPregnancyInNode(data) then
    return true
  end

  if data and hasPregnantStatus(data.targetId) then
    return true
  end

  return false
end

local function shouldConvertFriendly(data, sexboundData)
  if data and data.markedFriendly then
    return true
  end

  return hasAnyPregnancy(data, sexboundData)
end

local function setFriendlyOnLiveEntity(data)
  if not data then
    return false
  end

  local targetRef = nil
  if data.targetId and world.entityExists(data.targetId) then
    targetRef = data.targetId
  elseif data.targetUniqueId then
    targetRef = data.targetUniqueId
  else
    return false
  end

  -- Sync storage in a shape Sexbound NPC/monster handlers can merge safely.
  world.sendEntityMessage(targetRef, "Sexbound:Storage:Sync", {
    sexbound = {},
    previousDamageTeam = FRIENDLY_TEAM
  })

  -- Use Sexbound restore paths so team restore is applied by the override scripts.
  world.sendEntityMessage(targetRef, "Sexbound:Actor:Restore", {
    previousDamageTeam = FRIENDLY_TEAM
  })
  world.sendEntityMessage(targetRef, "Sexbound:Actor:Respawn", {
    previousDamageTeam = FRIENDLY_TEAM
  })

  -- Fallback direct team set in case hostile AI reapplies enemy aggressively.
  pcall(world.callScriptedEntity, targetRef, "npc.setDamageTeam", FRIENDLY_TEAM)
  pcall(world.callScriptedEntity, targetRef, "monster.setDamageTeam", FRIENDLY_TEAM)

  -- Marker used by Gem conversion to wait until node has actually ended.
  pcall(world.callScriptedEntity, targetRef, "status.setStatusProperty", "nodeReleasedForConversion", true)

  return true
end

local function clearSeductionKey(key)
  world.setProperty(key, nil)
end

local function queuePendingFriendly(key, data)
  if not data then
    clearSeductionKey(key)
    return
  end

  data.markedFriendly = true
  setFriendlyOnLiveEntity(data)
  clearSeductionKey(key)
end

local function processPendingFriendly(key, data)
  if not data or data.pendingFriendly ~= true then
    return false
  end

  -- Keep forcing friendly for a while in case hostile AI scripts try to set enemy again.
  setFriendlyOnLiveEntity(data)

  if world.time() > (data.pendingFriendlyUntil or 0) then
    clearSeductionKey(key)
  end

  return true
end

local function smashNode(key, data, makeFriendly)
  local storage = {}
  if makeFriendly then
    storage.previousDamageTeam = FRIENDLY_TEAM
    log("Friendly conversion set for targetId=%s", tostring(data.targetId))
  end

  if data.sexNodeId then
    world.sendEntityMessage(data.sexNodeId, "Sexbound:Smash", { storage = storage })
  end

  if makeFriendly then
    queuePendingFriendly(key, data)
  else
    clearSeductionKey(key)
  end
end

local function markFriendlyIfQualified(key, data)
  if not data or data.markedFriendly then
    return
  end

  if hasAnyPregnancyInNode(data) then
    data.markedFriendly = true
    world.setProperty(key, data)
    return
  end

  if not data.targetId or not world.entityExists(data.targetId) or self._pending[key] then
    return
  end

  self._pending[key] = true
  self._pk:add(
    world.sendEntityMessage(data.targetId, "Sexbound:Storage:Retrieve", { name = "sexbound" }),
    function(sexboundData)
      if hasAnyPregnancy(data, sexboundData) then
        data.markedFriendly = true
        world.setProperty(key, data)
      end
      self._pending[key] = nil
    end,
    function()
      if hasAnyPregnancyInNode(data) or hasPregnantStatus(data.targetId) then
        data.markedFriendly = true
        world.setProperty(key, data)
      end
      self._pending[key] = nil
    end
  )
end

function init()
  self._tick = 0
  self._pk = PromiseKeeper.new()
  self._pending = {}
end

function update(dt)
  if self._pk then self._pk:update() end

  self._tick = self._tick + dt
  if self._tick < 1 then return end
  self._tick = 0

  for _, key in ipairs(world.propertyKeys()) do
    if string.sub(key, 1, 10) == "seduction:" then
      local data = world.getProperty(key)
      if not data then
        clearSeductionKey(key)
        self._pending[key] = nil
      else
        if processPendingFriendly(key, data) then
          self._pending[key] = nil
        elseif data.transformPending and (world.time() - (data.startTime or world.time())) > 10 then
          clearSeductionKey(key)
          self._pending[key] = nil
        else
          markFriendlyIfQualified(key, data)

          local elapsed = world.time() - (data.startTime or world.time())
          if not self._pending[key] then
            if elapsed >= (data.timeout or 60) then
              handleTimeout(key, data)
            else
              checkEarlyNodeBreak(key, data)
            end
          end
        end
      end
    end
  end
end

function fetchSexboundDataAndFinalize(key, data, onDecision)
  if data and (not data.targetId or not world.entityExists(data.targetId)) then
    onDecision(shouldConvertFriendly(data, nil))
    return
  end

  self._pending[key] = true

  self._pk:add(
    world.sendEntityMessage(data.targetId, "Sexbound:Storage:Retrieve", { name = "sexbound" }),
    function(sexboundData)
      local shouldConvert = shouldConvertFriendly(data, sexboundData)
      onDecision(shouldConvert)
      self._pending[key] = nil
    end,
    function()
      local shouldConvert = shouldConvertFriendly(data, nil)
      onDecision(shouldConvert)
      self._pending[key] = nil
    end
  )
end

function handleTimeout(key, data)
  if not data or not data.sexNodeId then
    clearSeductionKey(key)
    return
  end

  log("Timeout reached for %s, forcing smash + friendly", tostring(key))
  smashNode(key, data, true)
end

function checkEarlyNodeBreak(key, data)
  if not data or not data.sexNodeId then
    return
  end

  self._pending[key] = true
  self._pk:add(
    world.sendEntityMessage(data.sexNodeId, "Sexbound:Retrieve:ControllerId"),
    function(_)
      self._pending[key] = nil
    end,
    function()
      -- Node already broke before watcher timeout; force a post-break friendly restore.
      log("Node break detected early for %s, applying friendly restore", tostring(key))
      setFriendlyOnLiveEntity(data)
      clearSeductionKey(key)
      self._pending[key] = nil
    end
  )
end


