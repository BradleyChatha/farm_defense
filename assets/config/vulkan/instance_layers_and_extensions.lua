local value = {
    extensions = {},
    layers = {}
}

if Config.getBoolean(g_config, "isDebugBuild") then
    Logger.logTrace("This is a debug build, so I'm enabling debugging-related features.");
    table.insert(value.extensions, { name = "VK_EXT_debug_utils", isOptional = true })
    table.insert(value.layers, { name = "VK_LAYER_KHRONOS_validation", isOptional = true });
end

return value