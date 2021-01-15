module app;

version(Engine_Library){}
else version(Engine_Benchmark)
{
    import jaster.cli, benchmarks.commands;
    int main(string[] args)
    {
        auto cli = new CommandLineInterface!ALL_BENCHMARKING_COMMANDS();
        return cli.parseAndExecute(args);
    }
}
else
{
    import engine.core, engine.init, engine.gameplay;

    int main(string[] args)
    {
        scope(exit)
        {
            // Specific condition that likely means this thread has thrown an uncaught error, but we can do a quick log flush first.
            if(!g_shouldThreadsStop && g_threadLogging !is null)
                logForceFlush(); 
            g_shouldThreadsStop = true;
        }
        threadMainResetKeepAlive();
        init_00_init_globals();
        init_01_init_thirdparty();
        init_03_load_config();
        init_06_init_resources();
        init_09_init_graphics();
        profileFlush();
        logForceFlush();
        loopStart();
        uninit_all();
        return 0;
    }
}