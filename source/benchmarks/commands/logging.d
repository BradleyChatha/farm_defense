module benchmarks.commands.logging;

version(Engine_Benchmark):

import core.thread;
import benchmarks.commands._common;
import engine.core;
import jaster.cli;

@Command("benchmark logging")
struct BenchmarkLoggingCommand
{
    mixin Benchmarker;

    @CommandNamedArg("n|logn")
    Nullable!size_t logN;

    @CommandNamedArg("f|flush-every")
    Nullable!size_t flushEvery;

    @CommandNamedArg("b|blocking")
    Nullable!bool blocking;

    void onExecute()
    {
        import std.stdio;
        //addLoggingSink(m => writeln(m.message));
        startLoggingThread();
        scope(exit) g_shouldThreadsStop = true;

        const n = this.logN.get(5_000);
        const f = this.flushEvery.get(500);
        const b = this.blocking.get(false);

        // This does also measure thread creation, starting, and waiting, buuuuuut meh.
        this.runBenchmark!((){
            auto t = [
                new Thread(() => loggingThread!("ONE")(n, f, b)),
                new Thread(() => loggingThread!("TWO")(n, f, b)),
                new Thread(() => loggingThread!("THREE")(n, f, b)),
                new Thread(() => loggingThread!("FOUR")(n, f, b)),
            ];

            foreach(thread; t)
                thread.start();

            foreach(thread; t)
                thread.join();
        })("4 THREADS");
    }
}

private void loggingThread(string message)(size_t reps, size_t flushEvery, bool block)
{
    foreach(i; 0..reps)
    {
        logInfo(message);
        if((i % flushEvery) == 0)
            while(!logFlush() && block){}
    }
    while(!logFlush() && block){}
}