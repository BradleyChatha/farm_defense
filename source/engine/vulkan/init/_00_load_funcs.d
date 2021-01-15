module engine.vulkan.init._00_load_funcs;

import erupted.vulkan_lib_loader;
import engine.core.logging, engine.vulkan;

package void _00_load_funcs()
{
    logfTrace("00. Loading global functions via erupted.");
    loadGlobalLevelFunctions();
}