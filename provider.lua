local maxDbSize = 81
local interfaceSize = 9
local component = require("component")

---------------------------------------------------------------------
local function getDatabases()
  local addresses = component.list()
  
  local dbs = {}
  for k,v in pairs(addresses) do
    if v == "database" then
      table.insert(dbs, component.proxy(k))
    end
  end

  return dbs
end

---------------------------------------------------------------------
local function getStoredItems(dbs)
  local items = { n = 0 }
  local hashes = {}
  local duplicate = nil
  local function fillItems(db)
    for i=1,maxDbSize do
      local hash = db.computeHash(i)
      if (hash ~= nil) then
        if hashes[hash] then
          duplicate = 'found duplicated item ' .. db.get(i).label
          return
        end
        hashes[hash] = true
        items.n = items.n + 1
        items[items.n] = { dbAddress = db.address, dbEntry = i }
      end
    end
  end
  
  for i,db in pairs(dbs) do
    pcall(fillItems, db)
    if duplicate then
      error(duplicate)
    end
  end

  return items
end


---------------------------------------------------------------------
local dbs = getDatabases()
local itemsToProvide = getStoredItems(dbs)
if (itemsToProvide.n == 0) then
  error('no items found')
end
local itemIdx = 1
local interface = component.me_interface

local function configureInterface(slot)
  local item = itemsToProvide[itemIdx]
  interface.setInterfaceConfiguration(slot, item.dbAddress, item.dbEntry)
  itemIdx = itemIdx + 1
  if (itemIdx > itemsToProvide.n) then
    itemIdx = 1
  end
  os.sleep(1)
end

local slotIdx = 1
while true do
  local currentConfig = interface.getInterfaceConfiguration(slotIdx)
  if (currentConfig == nil) then
    configureInterface(slotIdx)
  else
    local filter = { label = currentConfig.label, name = currentConfig.name }
    local sameItemsInNetwork = interface.getItemsInNetwork(filter)
    if (sameItemsInNetwork.n == 0) then
      configureInterface(slotIdx)
    else
      slotIdx = slotIdx + 1
      if (slotIdx > interfaceSize) then
        slotIdx = 1
        os.sleep(60)
      end
    end
  end
end