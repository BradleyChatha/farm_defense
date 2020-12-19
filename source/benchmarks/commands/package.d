module benchmarks.commands;

import std.meta : AliasSeq;
public import 
    benchmarks.commands.logging;

// A limitation of D: We can't gain access to publically imported modules, so we need to forward them for JCLI.
alias ALL_BENCHMARKING_COMMANDS = AliasSeq!(
    benchmarks.commands.logging
);