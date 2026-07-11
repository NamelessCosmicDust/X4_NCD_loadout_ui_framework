-- loadout_api.lua

LoadoutUI = LoadoutUI or {}
local ModHelper = LoadoutUI.ModHelper

-- LoadoutUI.RegisterUI("mod_id", function()
--   UIX compatibility: use add for sections with UIX callbacks. Replacing Turret Behaviour
--   suppresses UIX's turret callback and can break UIX extensions.
--   return {
--     add = {
--       {
--         newname = "New Section",
--         targetname = ReadText(1001, 2800),
--         builddata = function(context) end,
--         buildfunction = function(context, builddata, section) end,
--       },
--     },
--     replace = {
--       {
--         newname = ReadText(1001, 2800),
--         targetname = ReadText(1001, 2800),
--         builddata = function(context) end,
--         buildfunction = function(context, builddata, section) end,
--       },
--     },
--   }
-- end)
function LoadoutUI.RegisterUI(caller, uiFunction)
  local uiPackages = uiFunction()
  for _, packageType in ipairs({ "add", "replace" }) do
    local packages = uiPackages[packageType]
    if packages then
      for _, uiPackage in ipairs(packages) do
        local targetname = uiPackage.targetname
        local sectionkey = "header:" .. type(targetname) .. ":" .. tostring(targetname)
        local targettext = "targetname=" .. tostring(targetname) .. " newname=" .. tostring(uiPackage.newname)

        uiPackage.caller = caller
        uiPackage.packageType = packageType
        uiPackage.sectionkey = sectionkey
        uiPackage.targettext = targettext
        table.insert(LoadoutUI.registeredUI, uiPackage)

        ModHelper.Debug("[RegisterUI]", {
          "caller=", caller,
          "type=", packageType,
          "target=", targettext,
        })

        local targetcallers = LoadoutUI.callersByTarget[sectionkey]
        if not targetcallers then
          targetcallers = { list = {}, set = {} }
          LoadoutUI.callersByTarget[sectionkey] = targetcallers
        end
        if not targetcallers.set[caller] then
          if #targetcallers.list > 0 then
            ModHelper.Debug("[RegisterUI] registration on the same UI", {
              "section=", tostring(targetname),
              "existing=", table.concat(targetcallers.list, ","),
              "incoming=", caller,
            })
          end
          targetcallers.set[caller] = true
          table.insert(targetcallers.list, caller)
        end
      end
    end
  end
end

-- local service = {
--   data = {},
--   GetData = function(...) end,
--   SetData = function(...) end,
-- }
-- LoadoutUI.RegisterService("mod_id", "service_id", service)
function LoadoutUI.RegisterService(caller, id, service)
  service.caller = caller
  LoadoutUI.registeredService[id] = service
  ModHelper.Debug("[RegisterService]", {
    "caller=", caller,
    "id=", id,
  })
end

-- local service = LoadoutUI.GetService("service_id")
-- service.GetData(...)
function LoadoutUI.GetService(id)
  return LoadoutUI.registeredService[id]
end
