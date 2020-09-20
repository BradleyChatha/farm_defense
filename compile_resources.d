#!/usr/bin/env dub
/+ dub.sdl:
	name "compile"
    dependency "jcli" version="0.7.0"
    dependency "jioc" version="0.2.0"
    dependency "asdf" version="0.5.7"
    dependency "sdlang-d" version="0.10.6"
+/
module compile;

import std, sdlang;
import jaster.cli, jaster.ioc;

int main(string[] args)
{
    auto cli = new CommandLineInterface!compile(new ServiceProvider(
    [
        addFileConfig!(Config, AsdfConfigAdapter)(".compile_config.json")
    ]));

    return cli.parseAndExecute(args);
}

/++ COMMANDS ++/

@Command(null, "Compiles everything")
struct DefaultCommand
{
    IConfig!Config config;

    @CommandNamedArg("force", "Forces all files to be compiled.")
    Nullable!bool force;

    this(IConfig!Config config)
    {
        this.config = config;
        UserIO.configure().useVerboseLogging(true);
    }

    void onExecute()
    {
        auto conf   = this.config.value;
        auto assets = parseFile("./resources/assets.sdl");
        scope(exit)
        {
            this.config.value = conf;
            this.config.save();
        }

        // Shaders are specially handled since their usage is always hard coded into the game.
        this.iterateFilePairs("resources/shaders/", "spv", conf, (pair)
        {
            pair.destinationFile ~= pair.sourceFile.extension;

            UserIO.logInfof("[SHADER      ] %s", pair);
            Shell.executeEnforceStatusZero(
                "\"glslc.exe\" %s -o %s".format(
                    pair.sourceFile,
                    pair.destinationFile
                )
            );
        });

        this.copyFile("./resources/assets.sdl", "ASSET LIST", conf);
        foreach(tag; assets.tags)
        {
            switch(tag.name)
            {
                case "font":
                case "texture": this.copyFile(tag.values[1].get!string, tag.name, conf); break;

                default: throw new Exception("Don't know how to handle tag: "~tag.name);
            }
        }
    }

    void copyFile(string source, string typeName, ref Config conf)
    {
        this.handleFilePair(this.createPair(source, null), conf, (pair)
        {
            UserIO.logInfof("[%s] %s", typeName, pair);
            copy(pair.sourceFile, pair.destinationFile);
        });
    }

    void handleFilePair(FilePair pair, ref Config conf, void delegate(FilePair) action)
    {
        if(!pair.sourceIsNewer(conf) && !this.force.get(false))
        {
            UserIO.logInfof("[NOT MODIFIED] %s", pair);
            return;
        }

        mkdirRecurse(pair.destinationFile.dirName);
        action(pair);
    }

    void iterateFilePairs(string sourceDir, string destExt, ref Config conf, void delegate(FilePair) action)
    {
        if(!sourceDir.exists)
            return;

        foreach(file; dirEntries(sourceDir, SpanMode.depth))
        {
            if(file.isDir)
                continue;

            auto pair = this.createPair(file, destExt);
            this.handleFilePair(pair, conf, action);
        }
    }
    
    FilePair createPair(string source, string newExtension)
    {
        const absolute    = source.asNormalizedPath
                                  .array
                                  .asRelativePath(getcwd())
                                  .array
                                  .idup;
        const destination = absolute
                            .asNormalizedPath
                            .array
                            .asRelativePath(getcwd())
                            .substitute!("resources", "bin\\resources")
                            .byChar
                            .array
                            .idup
                            .setExtension(newExtension is null ? source.extension : newExtension);

        return FilePair(absolute, destination);
    }
}

/++ DATA TYPES ++/

struct Config
{
    long[string] lastModified;
}

struct FilePair
{
    string sourceFile;
    string destinationFile;

    bool sourceIsNewer(ref Config config)
    {
        auto ptr    = (this.sourceFile in config.lastModified);
        auto result = ptr is null || *ptr != timeLastModified(this.sourceFile).stdTime || !this.destinationFile.exists;

        if(result)
           config.lastModified[this.sourceFile] = timeLastModified(this.sourceFile).stdTime;

        return result;
    }
}