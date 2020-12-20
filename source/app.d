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
    import engine.core;
    import engine.init;

    int main(string[] args)
    {
        init_00_init_globals();
        init_03_load_config();
        init_06_init_resources();
        scope(exit) g_shouldThreadsStop = true;
        return 0;
    }
}