-- Shields Block Spitters
-- Prevents spitter slowdown when player has active shields (>0 HP)
-- Also works for vehicles with shield equipment (e.g. Spidertron)
-- If shields break (reach 0), slowdown persists for its normal duration even if shields recharge

local SHIELD_THRESHOLD = 0

-- Track entities that had their shields broken and when stickers were applied
-- Format: {entity_unit_number = {sticker_name = game_tick_when_applied}}
local broken_shield_stickers = {}

-- Check if player has shields above threshold
local function has_active_shield(player)
  if not player or not player.valid then return false end

  local armor = player.get_inventory(defines.inventory.character_armor)
  if not armor or armor.is_empty() then return false end

  local armor_item = armor[1]
  if not armor_item or not armor_item.valid_for_read then return false end

  local grid = armor_item.grid
  if not grid then return false end

  local total_shield = 0
  local equipment = grid.equipment

  for _, equip in pairs(equipment) do
    if equip.valid and equip.type == "energy-shield-equipment" then
      total_shield = total_shield + equip.shield
    end
  end

  return total_shield > SHIELD_THRESHOLD
end

-- Check if vehicle has shields above threshold
local function vehicle_has_active_shield(vehicle)
  if not vehicle or not vehicle.valid then return false end

  local grid = vehicle.grid
  if not grid then return false end

  local total_shield = 0
  local equipment = grid.equipment

  for _, equip in pairs(equipment) do
    if equip.valid and equip.type == "energy-shield-equipment" then
      total_shield = total_shield + equip.shield
    end
  end

  return total_shield > SHIELD_THRESHOLD
end

-- Check if a sticker is an acid sticker (from spitters)
local function is_acid_sticker(name)
  return name and (string.find(name, "acid%-sticker%-small") or
                   string.find(name, "acid%-sticker%-medium") or
                   string.find(name, "acid%-sticker%-big") or
                   string.find(name, "acid%-sticker%-behemoth"))
end

-- Remove acid stickers from an entity, respecting broken shield rules
local function process_acid_stickers(entity, has_shields)
  if not entity or not entity.valid then return end

  local stickers = entity.stickers
  if not stickers then return end

  local unit_number = entity.unit_number
  if not unit_number then return end

  local current_tick = game.tick

  -- Initialize tracking table for this entity if needed
  if not broken_shield_stickers[unit_number] then
    broken_shield_stickers[unit_number] = {}
  end

  for _, sticker in pairs(stickers) do
    if sticker.valid and is_acid_sticker(sticker.name) then
      local sticker_name = sticker.name

      if has_shields then
        -- Shields are active
        if broken_shield_stickers[unit_number][sticker_name] then
          -- This sticker was applied when shields were broken - let it persist
          -- Don't remove it
        else
          -- This sticker is being applied while shields are up - block it
          sticker.destroy()
        end
      else
        -- Shields are broken/depleted - mark this sticker and let it stay
        broken_shield_stickers[unit_number][sticker_name] = current_tick
      end
    end
  end

  -- Clean up old entries for stickers that no longer exist
  local current_sticker_names = {}
  for _, sticker in pairs(stickers) do
    if sticker.valid then
      current_sticker_names[sticker.name] = true
    end
  end

  for sticker_name, _ in pairs(broken_shield_stickers[unit_number]) do
    if not current_sticker_names[sticker_name] then
      -- Sticker has expired naturally, remove from tracking
      broken_shield_stickers[unit_number][sticker_name] = nil
    end
  end
end

-- Main tick handler
local function on_tick(event)
  for _, player in pairs(game.connected_players) do
    if not player.valid then goto continue end

    -- Check if player is in a vehicle
    local vehicle = player.vehicle
    if vehicle and vehicle.valid then
      -- Vehicle protection
      local has_shields = vehicle_has_active_shield(vehicle)
      process_acid_stickers(vehicle, has_shields)
    elseif player.character then
      -- Player on foot protection
      local has_shields = has_active_shield(player)
      process_acid_stickers(player.character, has_shields)
    end

    ::continue::
  end
end

script.on_event(defines.events.on_tick, on_tick)
