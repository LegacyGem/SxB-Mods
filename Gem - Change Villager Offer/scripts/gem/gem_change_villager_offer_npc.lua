local ITEM_SLOTS = {
  "primary",
  "alt",
  "head",
  "headCosmetic",
  "chest",
  "chestCosmetic",
  "legs",
  "legsCosmetic",
  "back",
  "backCosmetic"
}

local function deepCopy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, val in pairs(v) do out[k] = deepCopy(val) end
  return out
end

local function captureItemSlots()
  local slots = {}
  if not npc or not npc.getItemSlot then return slots end

  for _, slot in ipairs(ITEM_SLOTS) do
    local ok, item = pcall(npc.getItemSlot, slot)
    if ok and item ~= nil then
      slots[slot] = deepCopy(item)
    end
  end

  return slots
end

local function applyItemSlots(entityId, slots)
  if not entityId or type(slots) ~= "table" then return end

  for _, slot in ipairs(ITEM_SLOTS) do
    local item = slots[slot]
    if item ~= nil then
      pcall(world.callScriptedEntity, entityId, "npc.setItemSlot", slot, item)
    end
  end
end

local function getIdentity()
  local ok, identity = pcall(npc.humanoidIdentity)
  if ok and type(identity) == "table" then
    return identity
  end

  local ok2, identity2 = pcall(npcIdentity)
  if ok2 and type(identity2) == "table" then
    return identity2
  end

  return nil
end

local function getInitialStorage()
  if type(preservedStorage) ~= "function" then
    return nil
  end

  local ok, data = pcall(preservedStorage)
  if ok and type(data) == "table" then
    return data
  end
  return nil
end

local function getPersonality()
  if type(personality) ~= "function" then
    return nil
  end

  local ok, p = pcall(personality)
  if ok and type(p) == "table" then
    return p
  end
  return nil
end

local function despawnSelf()
  if tenant and tenant.detachFromSpawner then
    pcall(tenant.detachFromSpawner)
  end
  if tenant and tenant.despawn then
    local ok = pcall(tenant.despawn)
    if ok then return end
  end

  if status and status.setResource then
    status.setResource("health", 0)
  end
end

local function forceTypeChange(params)
  params = params or {}
  local offerType = params.offerType
  if type(offerType) ~= "string" or offerType == "" then
    return false
  end

  local level = (npc and npc.level and npc.level()) or 1
  local seed = (npc and npc.seed and npc.seed()) or nil
  local species = (npc and npc.species and npc.species()) or "human"
  local slots = captureItemSlots()
  local identity = getIdentity()

  local scriptConfig = {
    uniqueId = sb.makeUuid()
  }

  local p = getPersonality()
  if p then scriptConfig.personality = p end

  local initialStorage = getInitialStorage()
  if initialStorage then scriptConfig.initialStorage = initialStorage end

  local spawnParams = {
    scriptConfig = scriptConfig
  }
  if identity then
    spawnParams.identity = identity
  end

  local ok, newEntityId = pcall(world.spawnNpc, entity.position(), species, offerType, level, seed, spawnParams)
  if not ok or not newEntityId or not world.entityExists(newEntityId) then
    return false
  end

  applyItemSlots(newEntityId, slots)
  despawnSelf()
  return newEntityId
end

local oldInit = init
function init(...)
  if oldInit then oldInit(...) end
  message.setHandler("gemForceTypeChange", function(_, _, params)
    return forceTypeChange(params)
  end)
end

