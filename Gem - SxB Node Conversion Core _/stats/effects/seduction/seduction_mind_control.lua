require "/scripts/messageutil.lua"

function init()
  local targetId = entity.id()

  local watcherTimeout = effect.getParameter("timeout", 60)
  local nodeTimeout = effect.getParameter("nodeTimeout", 3600)
  local sourceId = effect.sourceEntity()
  local sourceType = sourceId and world.entityType(sourceId) or nil

  local key = "seduction:" .. targetId
  local existing = world.getProperty(key)
  if existing then
    -- Prevent duplicate transform requests from repeated whip hits.
    effect.expire()
    return
  end

  local data = {
    targetId = targetId,
    targetUniqueId = world.entityUniqueId(targetId),
    entityType = world.entityType(targetId),
    species = world.entitySpecies(targetId),
    startTime = world.time(),
    timeout = watcherTimeout,
    nodeTimeout = nodeTimeout,
    seducedById = sourceId,
    seducedByType = sourceType,
    seducedByUuid = sourceId and world.entityUniqueId(sourceId) or nil,
    transformPending = true
  }

  if data.entityType == "npc" then
    data.npcType = world.npcType(targetId)
    data.identity = world.callScriptedEntity(targetId, "npcIdentity")
  elseif data.entityType == "monster" then
    data.monsterType = world.monsterType(targetId)
  end

  world.setProperty(key, data)

  self._pk = PromiseKeeper.new()
  self._pk:add(
    world.sendEntityMessage(targetId, "Sexbound:Transform", {
      responseRequired = true,
      timeout = nodeTimeout,
      applyStatusEffects = { "sexbound_invisible", "sexbound_stun" }
    }),
    function(result)
      local current = world.getProperty(key)
      if current and result and result.uniqueId then
        current.sexNodeId = result.uniqueId
        current.transformPending = false
        world.setProperty(key, current)
      else
        world.setProperty(key, nil)
      end
      effect.expire()
    end,
    function()
      world.setProperty(key, nil)
      effect.expire()
    end
  )
end

function update(dt)
  if self._pk then self._pk:update() end
end
