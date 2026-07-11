-- loadout_helpers.lua

LoadoutUI = LoadoutUI or {}

LoadoutUI.registeredUI = LoadoutUI.registeredUI or {}
LoadoutUI.registeredService = LoadoutUI.registeredService or {}
LoadoutUI.callersByTarget = LoadoutUI.callersByTarget or {}
LoadoutUI.initialized = LoadoutUI.initialized or false
LoadoutUI.ModHelper = LoadoutUI.ModHelper or {}

local ModHelper = LoadoutUI.ModHelper

function ModHelper.Debug(text, values)
  if values and #values > 0 then
    local parts = {}
    for i = 1, #values, 2 do
      table.insert(parts, values[i] .. tostring(values[i + 1]))
    end
    text = text .. ": " .. table.concat(parts, " ")
  end
  DebugError("[Loadout UI]" .. text)
end


function ModHelper.Pack(...)
  return { n = select("#", ...), ... }
end

function ModHelper.CreateBlankNode()
  local node = { handlers = {} }
  setmetatable(node, {
    __index = function(t, key)
      local func = function()
        return t
      end
      rawset(t, key, func)
      return func
    end,
  })
  return node
end

function ModHelper.CreateBlankRow()
  local row = {}
  setmetatable(row, {
    __index = function(t, key)
      local cell = ModHelper.CreateBlankNode()
      rawset(t, key, cell)
      return cell
    end,
  })
  return row
end

function ModHelper.CreateBlankRowGroup()
  local rowgroup = ModHelper.CreateBlankNode()
  rowgroup.addRow = function()
    return ModHelper.CreateBlankRow()
  end
  rowgroup.addEmptyRow = function()
    return ModHelper.CreateBlankNode()
  end
  return rowgroup
end

function ModHelper.FindMapMenu()
  if not Menus then
    return nil
  end
  for _, menu in ipairs(Menus) do
    if menu.name == "MapMenu" then
      return menu
    end
  end
  return nil
end

function ModHelper.IsInstalled(menu)
  return menu and LoadoutUI.wrapper and menu.setupLoadoutInfoSubmenuRows == LoadoutUI.wrapper
end
