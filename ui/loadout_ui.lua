-- loadout_ui.lua

LoadoutUI = LoadoutUI or {}
local ModHelper = LoadoutUI.ModHelper

-- vanilla UI order for added UI sorting
LoadoutUI.vanillaSectionOrder = {
  [ReadText(1001, 9409)] = 10, -- Weapon Configuration
  [ReadText(1001, 8612)] = 20, -- Turret Behaviour
  [ReadText(1001, 8619)] = 30, -- Units
  [ReadText(1001, 2800)] = 40, -- Ammunition
  [ReadText(1001, 1332)] = 50, -- Deployables
  [ReadText(1001, 9413)] = 60, -- Loadout
  [ReadText(1001, 8031)] = 70, -- Storage
}


-- returns the modified Loadout panel function
local function BuildWrapper(menu, originalSetupLoadoutInfoSubmenuRows)
  return function(mode, inputtable, inputobject, instance)
    local context = {
      menu = menu,
      mode = mode,
      inputtable = inputtable,
      inputobject = inputobject,
      instance = instance,
    }
    local uimod = {}
    for _, uipackage in ipairs(LoadoutUI.registeredUI) do
      local builddata = nil
      if uipackage.builddata then
        builddata = uipackage.builddata(context)
      else
        builddata = {}
      end
      if builddata then
        table.insert(uimod, {
          uipackage = uipackage,
          builddata = builddata,
          matched = false,
        })
      end
    end

    -- if no UI mod, recall the original UI
    if #uimod == 0 then
      return originalSetupLoadoutInfoSubmenuRows(mode, inputtable, inputobject, instance)
    end

    local originalAddRow = inputtable.addRow
    local originalAddRowGroup = inputtable.addRowGroup
    local currentsection = nil
    local building = 0

    local function RunBuild(entry, target)
      building = building + 1
      local ok, result = pcall(entry.uipackage.buildfunction, context, entry.builddata, target)
      building = building - 1
      if not ok then
        error(result)
      end
      return result
    end

    local function HeaderEntries(header)
      local entries = {}
      for _, entry in ipairs(uimod) do
        if entry.uipackage.targetname == header then
          table.insert(entries, entry)
        end
      end
      return entries
    end

    local function CloseSection()
      if currentsection then
        for _, entry in ipairs(currentsection.after) do
          RunBuild(entry, {
            matched = true,
            newname = entry.uipackage.newname,
            targetname = currentsection.header,
            inputtable = inputtable,
          })
        end
      end
      currentsection = nil
    end

    local function AddMissingSectionsBefore(nextHeader)
      local nextOrder = LoadoutUI.vanillaSectionOrder[nextHeader]
      if not nextOrder then
        return
      end

      local missing = {}
      for _, entry in ipairs(uimod) do
        local targetname = entry.uipackage.targetname
        local targetOrder = LoadoutUI.vanillaSectionOrder[targetname]
        if not entry.matched and targetOrder and targetOrder < nextOrder then
          table.insert(missing, entry)
        end
      end
      table.sort(missing, function(a, b)
        return LoadoutUI.vanillaSectionOrder[a.uipackage.targetname] < LoadoutUI.vanillaSectionOrder[b.uipackage.targetname]
      end)

      for _, entry in ipairs(missing) do
        entry.matched = true
        RunBuild(entry, {
          matched = false,
          newname = entry.uipackage.newname,
          targetname = entry.uipackage.targetname,
          inputtable = inputtable,
        })
      end
    end

    local function HandleHeader(rowargs, cellops, text, properties)
      CloseSection()
      AddMissingSectionsBefore(text)

      local entries = HeaderEntries(text)
      local replacement = nil
      local after = {}
      for _, entry in ipairs(entries) do
        entry.matched = true
        if entry.uipackage.packageType == "add" then
          table.insert(after, entry)
        else
          replacement = entry
        end
      end

      if replacement then
        RunBuild(replacement, {
          matched = true,
          newname = replacement.uipackage.newname,
          targetname = text,
          inputtable = inputtable,
        })
        currentsection = {
          header = text,
          rowgroup = nil,
          after = after,
          suppressed = true,
        }
        return ModHelper.CreateBlankNode()
      end

      local row = originalAddRow(inputtable, unpack(rowargs, 1, rowargs.n))
      local cell = row[1]
      for _, operation in ipairs(cellops) do
        cell = cell[operation.name](cell, unpack(operation.args, 1, operation.args.n)) or cell
      end
      local result = cell:createText(text, properties)
      currentsection = {
        header = text,
        rowgroup = nil,
        after = after,
        suppressed = false,
      }
      return result
    end

    local function CreateHeaderRowProxy(rowargs)
      local row = {}
      local cells = {}
      setmetatable(row, {
        __index = function(_, index)
          if cells[index] then
            return cells[index]
          end
          local cellops = {}
          local realized = nil
          local cell = { handlers = {} }
          setmetatable(cell, {
            __index = function(_, key)
              if realized then
                return realized[key]
              end
              if key == "createText" and index == 1 then
                return function(_, text, properties)
                  realized = HandleHeader(rowargs, cellops, text, properties)
                  return realized
                end
              end
              return function(_, ...)
                table.insert(cellops, { name = key, args = ModHelper.Pack(...) })
                return cell
              end
            end,
            __newindex = function(_, key, value)
              if realized then
                realized[key] = value
              else
                rawset(cell, key, value)
              end
            end,
          })
          cells[index] = cell
          return cell
        end,
      })
      return row
    end

    inputtable.addRow = function(tableobj, ...)
      if building > 0 then
        return originalAddRow(tableobj, ...)
      end
      local args = ModHelper.Pack(...)
      if args[2] == Helper.headerRowProperties then
        return CreateHeaderRowProxy(args)
      end
      return originalAddRow(tableobj, ...)
    end

    inputtable.addRowGroup = function(tableobj, ...)
      if building > 0 then
        return originalAddRowGroup(tableobj, ...)
      end
      if currentsection and not currentsection.rowgroup then
        if currentsection.suppressed then
          currentsection.rowgroup = ModHelper.CreateBlankRowGroup()
        else
          currentsection.rowgroup = originalAddRowGroup(tableobj, ...)
        end
        return currentsection.rowgroup
      end
      return originalAddRowGroup(tableobj, ...)
    end

    local ok, result = pcall(originalSetupLoadoutInfoSubmenuRows, mode, inputtable, inputobject, instance)
    if ok then
      CloseSection()
    end
    inputtable.addRow = originalAddRow
    inputtable.addRowGroup = originalAddRowGroup
    if not ok then
      error(result)
    end

    local mapped = {}
    local unmapped = {}
    for _, entry in ipairs(uimod) do
      if not entry.matched and LoadoutUI.vanillaSectionOrder[entry.uipackage.targetname] then
        table.insert(mapped, entry)
      elseif not entry.matched then
        table.insert(unmapped, entry)
      end
    end
    table.sort(mapped, function(a, b)
      return LoadoutUI.vanillaSectionOrder[a.uipackage.targetname] < LoadoutUI.vanillaSectionOrder[b.uipackage.targetname]
    end)

    for _, entry in ipairs(mapped) do
      RunBuild(entry, {
        matched = false,
        newname = entry.uipackage.newname,
        targetname = entry.uipackage.targetname,
        inputtable = inputtable,
      })
    end
    for _, entry in ipairs(unmapped) do
      RunBuild(entry, {
        matched = false,
        newname = entry.uipackage.newname,
        targetname = entry.uipackage.targetname,
        inputtable = inputtable,
      })
    end
    return result
  end
end

-- hook is on event and runs everytime the menu is open
local function HookMapMenu()
  local menu = LoadoutUI.ModHelper.FindMapMenu()
  if not menu then
    LoadoutUI.ModHelper.Debug("[Hook] failed", {
      "reason=", "MapMenu missing",
    })
    return false
  end
  if ModHelper.IsInstalled(menu) then
    return true
  end
  if not menu.setupLoadoutInfoSubmenuRows then
    LoadoutUI.ModHelper.Debug("[Hook] failed", {
      "menu=", menu.name,
      "reason=", "setupLoadoutInfoSubmenuRows missing",
    })
    return false
  end

  -- replace the vanilla menu with wrapper
  LoadoutUI.wrapper = BuildWrapper(menu, menu.setupLoadoutInfoSubmenuRows)
  menu.setupLoadoutInfoSubmenuRows = LoadoutUI.wrapper

  LoadoutUI.ModHelper.Debug("[Hook] installed", {
    "menu=", menu.name,
    "installed=", ModHelper.IsInstalled(menu),
  })
  return ModHelper.IsInstalled(menu)
end

local function Init()
  if LoadoutUI.initialized then
    return
  end
  RegisterEvent("menu_opened", HookMapMenu)
  RegisterEvent("showMapMenu", HookMapMenu)
  HookMapMenu()
  LoadoutUI.initialized = true
end

Init()
