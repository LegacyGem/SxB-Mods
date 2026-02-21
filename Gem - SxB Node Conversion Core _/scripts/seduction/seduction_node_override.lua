local DEBUG = true

local FRIENDLY_TEAM = { type = "friendly" }

local function log(msg, ...)
  if DEBUG then sb.logInfo("[SeductionNode] " .. msg, ...) end
end

local function getPregnancies(actorStorage)
  if type(actorStorage) ~= "table" then return nil end

  if type(actorStorage.sexbound) == "table" and type(actorStorage.sexbound.pregnant) == "table" then
    return actorStorage.sexbound.pregnant
  end

  if type(actorStorage.pregnant) == "table" then
    return actorStorage.pregnant
  end

  return nil
end

local function hasPregnancy(actorStorage)
  local pregnancies = getPregnancies(actorStorage)
  if type(pregnancies) ~= "table" then return false end

  for _, pregnancy in pairs(pregnancies) do
    if type(pregnancy) == "table" then
      return true
    end
  end

  return false
end

local function enforceFriendlyOnStoredActor()
  if type(storage) ~= "table" or type(storage.actor) ~= "table" then
    return
  end

  storage.actor.storage = storage.actor.storage or {}
  local actorStorage = storage.actor.storage

  if hasPregnancy(actorStorage) then
    actorStorage.previousDamageTeam = FRIENDLY_TEAM
    log("Pregnancy detected on node die, forcing friendly restore for actor %s", tostring(storage.actor.uniqueId))
  end
end

local oldDie = die
function die()
  enforceFriendlyOnStoredActor()

  if type(oldDie) == "function" then
    return oldDie()
  end
end

