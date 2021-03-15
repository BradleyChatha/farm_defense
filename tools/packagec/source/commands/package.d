module commands;

import std.meta : AliasSeq;

import
    commands.test;

alias COMMANDS = AliasSeq!(
    commands.test
);