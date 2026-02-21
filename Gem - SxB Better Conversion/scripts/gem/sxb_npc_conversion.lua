local CONFIG_PATH = "/config/betterconversion.config"
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

local function loadConfig()
  local ok, cfg = pcall(root.assetJson, CONFIG_PATH)
  if ok and type(cfg) == "table" then
    return cfg
  end

  return {
    enabled = true,
    motherType = "motherexhostilevillager",
    afterBirthType = "afterbirthvillager",
    requirePlayerFather = true,
    logDebug = false
  }
end

local function debugLog(cfg, msg, ...)
  if cfg and cfg.logDebug then
    sb.logInfo("[GemSxBNpcConversion] " .. msg, ...)
  end
end

local function deepCopy(v)
  if type(v) ~= "table" then
    return v
  end

  local out = {}
  for k, item in pairs(v) do
    out[k] = deepCopy(item)
  end
  return out
end

local function captureItemSlots()
  local out = {}
  if not npc or not npc.getItemSlot then
    return out
  end

  for _, slot in ipairs(ITEM_SLOTS) do
    local ok, item = pcall(npc.getItemSlot, slot)
    if ok and item ~= nil then
      out[slot] = deepCopy(item)
    end
  end
  return out
end

local function applyItemSlots(entityId, equipment, cfg)
  if not entityId or type(equipment) ~= "table" then
    return
  end

  for _, slot in ipairs(ITEM_SLOTS) do
    local item = equipment[slot]
    if item ~= nil then
      local ok = pcall(world.callScriptedEntity, entityId, "npc.setItemSlot", slot, item)
      if not ok then
        debugLog(cfg, "Failed to apply slot %s on %s", slot, tostring(entityId))
      end
    end
  end
end

local function tryNpcIdentity()
  local ok, identity = pcall(npcIdentity)
  if ok and type(identity) == "table" then
    return identity
  end
  return nil
end

local function currentTeamType()
  local team = entity.damageTeam() or {}
  return team.type
end

local function getCurrentNpcType()
  local ok, t = pcall(world.npcType, entity.id())
  if ok and type(t) == "string" then
    return t
  end
  return ""
end

local function getPregnancies()
  if type(storage) ~= "table" then return {} end
  local sexboundData = storage.sexbound
  if type(sexboundData) ~= "table" then return {} end
  local pregnancies = sexboundData.pregnant
  if type(pregnancies) ~= "table" then return {} end
  return pregnancies
end

local function hasNodeReleaseMarker()
  if status and status.statusProperty then
    return status.statusProperty("nodeReleasedForConversion") == true or status.statusProperty("gemNodeReleasedForConversion") == true
  end
  return false
end

local function isInSexboundNodePhase()
  local team = entity.damageTeam() or {}
  if team.type == "ghostly" then
    return true
  end

  if status and status.statusProperty then
    if status.statusProperty("sexbound_sex") == true then
      return true
    end
    if status.statusProperty("sexbound_invisible") == true then
      return true
    end
    if status.statusProperty("sexbound_stun") == true and status.statusProperty("sexbound_pregnant") ~= true then
      return true
    end
  end

  if status and status.resource and (status.resource("stunned") or 0) > 0 then
    return true
  end

  if npc and npc.isLounging and npc.isLounging() then
    return true
  end

  return false
end

local function scanPregnancyInfo()
  local info = {
    hasPregnancy = false,
    hasPlayerFather = false,
    fatherUuid = nil,
    fatherName = nil
  }

  for _, p in pairs(getPregnancies()) do
    if type(p) == "table" then
      info.hasPregnancy = true

      if p.fatherType == "player" then
        info.hasPlayerFather = true
      end
      if type(p.fatherUuid) == "string" and p.fatherUuid ~= "" then
        info.fatherUuid = p.fatherUuid
      end
      if type(p.fatherName) == "string" and p.fatherName ~= "" then
        info.fatherName = p.fatherName
      end

      if type(p.babies) == "table" then
        for _, b in pairs(p.babies) do
          if type(b) == "table" then
            if b.fatherType == "player" then
              info.hasPlayerFather = true
            end
            if type(b.fatherUuid) == "string" and b.fatherUuid ~= "" then
              info.fatherUuid = b.fatherUuid
            end
            if type(b.fatherName) == "string" and b.fatherName ~= "" then
              info.fatherName = b.fatherName
            end
          end
        end
      end
    end
  end

  return info
end

local function normalizeIdentity(self, identity)
  identity = deepCopy(identity or {})

  local species = npc.species and npc.species() or nil
  local gender = npc.gender and npc.gender() or nil
  local name = self.conversionName or self.originalName or world.entityName(entity.id())

  if type(species) == "string" and species ~= "" then
    identity.species = identity.species or species
  end
  if type(gender) == "string" and gender ~= "" then
    identity.gender = identity.gender or gender
  end
  if type(name) == "string" and name ~= "" then
    identity.name = name
  end

  return identity
end

local function refreshConversionSnapshot(self)
  self.conversionIdentity = tryNpcIdentity()
  self.conversionName = world.entityName(entity.id())
  self.conversionSeed = npc.seed and npc.seed() or nil
  self.conversionSexboundStorage = deepCopy(storage and storage.sexbound or {})
  self.conversionEquipment = captureItemSlots()
end

local function buildSpawnParams(self)
  local friendlyTeam = { type = "friendly" }
  local params = {
    scriptConfig = {
      uniqueId = sb.makeUuid(),
      keepIdentity = true
    },
    statusControllerSettings = {
      statusProperties = {}
    }
  }

  local identity = self.conversionIdentity or self.originalIdentity or tryNpcIdentity()
  if identity then
    params.identity = normalizeIdentity(self, identity)
  end

  local sexboundStorage = deepCopy(self.conversionSexboundStorage or self.originalSexboundStorage or (storage and storage.sexbound) or {})
  params.statusControllerSettings.statusProperties.sexbound_previous_storage = {
    sexbound = sexboundStorage,
    previousDamageTeam = friendlyTeam
  }

  local subGender = sexboundStorage
    and sexboundStorage.identity
    and sexboundStorage.identity.sxbSubGender
    or nil
  if type(subGender) == "string" and subGender ~= "" then
    params.scriptConfig.subGender = subGender
  end

  if self.lastFatherUuid then
    params.statusControllerSettings.statusProperties.lastFatherUuid = self.lastFatherUuid
  end
  if self.lastFatherName then
    params.statusControllerSettings.statusProperties.lastFatherName = self.lastFatherName
  end
  if self.nodeReleased then
    params.statusControllerSettings.statusProperties.nodeReleasedForConversion = true
  end

  return params
end

local function spawnNpcType(npctype, level, seed, params)
  local ok, entityId = pcall(world.spawnNpc, entity.position(), npc.species(), npctype, level, seed, params)
  if ok and entityId and world.entityExists(entityId) then
    return entityId
  end
  return nil
end

local function replaceSelfWithType(self, targetType, cfg)
  local level = npc.level and npc.level() or 1
  local seed = self.conversionSeed or self.originalSeed or (npc.seed and npc.seed() or nil)
  local params = buildSpawnParams(self)
  local spawned = spawnNpcType(targetType, level, seed, params)

  if spawned then
    applyItemSlots(spawned, self.conversionEquipment or self.originalEquipment, cfg)
    self.converted = true
    self.pendingDespawnId = spawned
    self.pendingDespawnTimer = 2.0
    npc.setInteractive(false)
    debugLog(cfg, "Converted %s -> %s (id=%s)", getCurrentNpcType(), targetType, tostring(spawned))
    return true
  end

  debugLog(cfg, "Conversion failed to target %s", tostring(targetType))
  return false
end

local function convertIfNeeded(self, cfg)
  if self.converted then
    return
  end

  if isInSexboundNodePhase() then
    self.seenNodePhase = true
    return
  end

  if hasNodeReleaseMarker() then
    self.nodeReleased = true
  end

  if currentTeamType() == "enemy" then
    return
  end

  local currentType = getCurrentNpcType()
  local info = scanPregnancyInfo()

  if info.fatherUuid then self.lastFatherUuid = info.fatherUuid end
  if info.fatherName then self.lastFatherName = info.fatherName end

  if info.hasPregnancy then
    self.hadPregnancy = true

    if cfg.requirePlayerFather and not info.hasPlayerFather then
      return
    end

    if not (self.seenNodePhase or self.nodeReleased) then
      debugLog(cfg, "Pregnant but waiting for node release before conversion")
      return
    end

    if currentType ~= cfg.motherType and currentType ~= cfg.afterBirthType then
      refreshConversionSnapshot(self)
      replaceSelfWithType(self, cfg.motherType, cfg)
    end
    return
  end

  if self.hadPregnancy and currentType == cfg.motherType then
    refreshConversionSnapshot(self)
    replaceSelfWithType(self, cfg.afterBirthType, cfg)
  end
end

local oldInit = init
function init(...)
  if oldInit then oldInit(...) end

  local cfg = loadConfig()
  self.conversionCfg = cfg
  self.conversionTick = 0
  self.hadPregnancy = false
  self.converted = false
  self.lastFatherUuid = nil
  self.lastFatherName = nil
  self.seenNodePhase = false
  self.nodeReleased = hasNodeReleaseMarker()
  self.originalIdentity = tryNpcIdentity()
  self.originalName = world.entityName(entity.id())
  self.originalSeed = npc.seed and npc.seed() or nil
  self.originalSexboundStorage = deepCopy(storage and storage.sexbound or {})
  self.originalEquipment = captureItemSlots()
  self.pendingDespawnId = nil
  self.pendingDespawnTimer = 0

  local info = scanPregnancyInfo()
  self.hadPregnancy = info.hasPregnancy
  if info.fatherUuid then self.lastFatherUuid = info.fatherUuid end
  if info.fatherName then self.lastFatherName = info.fatherName end
end

local oldUpdate = update
function update(dt, ...)
  if oldUpdate then oldUpdate(dt, ...) end

  local cfg = self.conversionCfg or loadConfig()
  if not cfg.enabled then
    return
  end

  self.conversionTick = (self.conversionTick or 0) + (dt or 0)
  if self.conversionTick >= 1.0 then
    self.conversionTick = 0
    convertIfNeeded(self, cfg)
  end

  if self.pendingDespawnId then
    self.pendingDespawnTimer = (self.pendingDespawnTimer or 0) - (dt or 0)
    if self.pendingDespawnTimer <= 0 then
      if world.entityExists(self.pendingDespawnId) then
        status.setResource("health", 0)
      else
        self.converted = false
        npc.setInteractive(true)
      end
      self.pendingDespawnId = nil
      self.pendingDespawnTimer = 0
    end
  end
end

