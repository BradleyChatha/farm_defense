import jcli;
import commands, common;

int main(string[] args)
{
    import engine.core, engine.init;

    scope(exit)
    {
        if(!g_shouldThreadsStop && g_threadLogging !is null)
            logForceFlush(); 

        profileFlush();
        uninit_all();
        g_shouldThreadsStop = true;
    }

    try
    {
        // A lot of data transformation is done via Vulkan, so we need to load up everything in the engine up until we can use Vulkan.
        ensureInGameRootDir();
        threadMainResetKeepAlive();
        init_00_init_globals();
        init_01_init_thirdparty();
        init_03_load_config();

        init_06_init_resources();
        init_09_init_graphics();

        import std.exception : enforce;
        import engine.vulkan;
        enforce(g_device.features.textureCompressionBC, "Vulkan support for BC compression must be enabled.");

        return (new CommandLineInterface!(commands.COMMANDS)).parseAndExecute(args);
    }
    catch(Exception ex)
    {
        logfFatal("%s\n%s", ex.msg, ex.info);
        logForceFlush();
        return -1;
    }
}
