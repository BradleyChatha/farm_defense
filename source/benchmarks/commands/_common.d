module benchmarks.commands._common;

version(Engine_Benchmark):

public import std.datetime.stopwatch : benchmark;
import jaster.cli;

mixin template Benchmarker()
{
    import std.stdio : writefln;
    import std.conv : to;

    @CommandNamedArg("r|reps")
    Nullable!uint reps;

    void runBenchmark(alias Func)(string name)
    {
        const reps = this.reps.get(100);
        const result = benchmark!Func(reps)[0];

        writefln(
            "%s %s ran %s times averaging %s totalling %s.",
            "Test".ansi.fg(Ansi4BitColour.magenta),
            name.ansi.bold,
            reps.to!string.ansi.bold,
            (result / reps).to!string.ansi.bold,
            result.to!string.ansi.bold
        );
    }
}