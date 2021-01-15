local algs = require("assets/lua/std/algorithm")
local inspect = require("assets/lua/thirdparty/inspect")
local bit = require("bit")

--[[
    PARAMS
--]]
local queueFlags  = (...)[1]
local deviceTypes = (...)[2]

--[[
    INTERNAL FUNCTIONS
--]]

local function findEnabledExtensions(wanted, available)
    local enabled = {}
    local availableDisabled = {}
    local wantedDisabled = {}

    local comparer = function(a, b) return a.name == b.name end

    for _, value in ipairs(available) do
        if algs.contains(wanted, value, comparer) then
            table.insert(enabled, value)
        else
            table.insert(availableDisabled, value)
        end
    end

    for _, value in ipairs(wanted) do
        if not algs.contains(enabled, value, comparer) then
            table.insert(wantedDisabled, value)
        end
    end

    return {
        enabled = enabled,
        availableDisabled = availableDisabled,
        wantedDisabled = wantedDisabled
    }
end

local function getDeviceQueueFamiliesNonPresent(device)
    device.queueFamilyIndicies = {}

    for index, family in ipairs(device.queueFamilies) do
        if bit.band(family.queueFlags, queueFlags.VK_QUEUE_GRAPHICS_BIT) and not device.queueFamilyIndicies.graphics then
            device.queueFamilyIndicies.graphics = index
        elseif bit.band(family.queueFlags, queueFlags.VK_QUEUE_TRANSFER_BIT) and not device.queueFamilyIndicies.transfer then
            device.queueFamilyIndicies.transfer = index
        end
    end

    device.queueFamilyIndicies.transfer = device.queueFamilyIndicies.transfer and device.queueFamilyIndicies.transfer or device.queueFamilyIndicies.graphics
end

local function scoreDevice(device, wantedExtensions)
    device.score = 0
    device.extensionInfo = {}

    -- Score by GPU type
    if bit.band(device.props.deviceType, deviceTypes.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) then
        Logger.logDebug("Device is DISCRETE");
        device.score = device.score + 100
    elseif bit.band(device.props.deviceType, deviceTypes.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU) then
        Logger.logDebug("Device is INTEGRATED");
        device.score = device.score + 20
    else
        Logger.logDebug("Device is OTHER");
        device.score = device.score + 1
    end

    -- Score by available extensions
    local missingRequired = {}
    device.extensionInfo = findEnabledExtensions(wantedExtensions, device.extensions);
    algs.applyFiltered(
        device.extensionInfo.wantedDisabled,
        function(a) return not a.isOptional end,
        function(a) table.insert(missingRequired, a) end
    )
    if #missingRequired > 0 then
        device.extensionInfo.missingRequired = missingRequired
        device.score = -1
        Logger.logDebug("Device was missing required extensions: "..inspect({
            missing = device.extensionInfo.missingRequired,
            enabled = device.extensionInfo.enabled
        }));
        return
    end
    Logger.logDebug("Device has all required extensions.");
    device.score = device.score + #device.extensionInfo.enabled

    -- Score by existance of queue families
    getDeviceQueueFamiliesNonPresent(device);
    if not device.queueFamilyIndicies.graphics or not device.queueFamilyIndicies.transfer then
        device.score = -1
        Logger.logDebug("Device was missing either the graphics or transfer queue family.")
        return
    end
    if device.queueFamilyIndicies.graphics ~= device.queueFamilyIndicies.transfer then
        Logger.logDebug("Device has a seperate graphics and transfer family.");
        device.score = device.score + 2
    else
        Logger.logDebug("Device uses the graphics family as the transfer family.");
        device.score = device.score + 1
    end
end

--[[
    EXPORTED FUNCTIONS
--]]

local funcs = {}

function funcs.determineCoreVulkanDevice(devices, wantedExtensions)
    local highScore = 0
    local highScoreIndex = -1
    for index, device in ipairs(devices) do
        scoreDevice(device, wantedExtensions)
        Logger.logDebug("Device "..device.props.deviceName.." has a score of "..device.score);

        if device.score > highScore then
            highScore = device.score
            highScoreIndex = index
        end
    end

    if highScoreIndex == -1 then
        error("No valid device was found.")
    end

    local selectedDevice = devices[highScoreIndex]
    Logger.logTrace("Device "..selectedDevice.props.deviceName.." was selected a primary graphics device.");
    return {
        deviceIndex         = highScoreIndex - 1, -- This is going back to D, so make the index 0-based.
        enabledExtensions   = selectedDevice.extensionInfo.enabled,
        queueFamilyIndicies = selectedDevice.queueFamilyIndicies
    }
end

return funcs