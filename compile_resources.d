#!/usr/bin/env dub
/+ dub.sdl:
	name "compile"
    dependency "jcli" version="0.7.0"
    dependency "jioc" version="0.2.0"
    dependency "asdf" version="0.5.7"
+/
module compile;

import std;
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
        auto conf = this.config.value;
        scope(exit)
        {
            this.config.value = conf;
            this.config.save();
        }

        this.iterateFilePairs("resources/images/static/", "ktx", conf, (pair)
        {
            UserIO.logInfof("[STATIC IMAGE] %s", pair);
            Shell.executeEnforceStatusZero("\"./tools/win/texturec.exe\" -f \"%s\" -o \"%s\"".format(pair.sourceFile, pair.destinationFile));
        });

        this.iterateFilePairs("resources/images/dynamic/", null, conf, (pair)
        {
            UserIO.logInfof("[DYNAMC IMAGE] %s", pair);
            copy(pair.sourceFile, pair.destinationFile);
        });

        this.iterateFilePairs("resources/levels/", null, conf, (pair)
        {
            UserIO.logInfof("[LEVEL       ] %s", pair);
            copy(pair.sourceFile, pair.destinationFile);
        });

        //"./tools/win/shaderc.exe" -f ./resources/shaders/vertex.sc -o ./bin/resources/shaders/vertex.bin --type v --platform windows -p 130
        this.iterateFilePairs("resources/shaders/", "bin", conf, (pair)
        {
            if(pair.sourceFile.extension == ".h" || pair.sourceFile.canFind("varying.def.sc"))
                return;

            UserIO.logInfof("[SHADER      ] %s", pair);
            Shell.executeEnforceStatusZero(
                "\"./tools/win/shaderc.exe\" -f \"%s\" -o \"%s\" --type %s --platform windows -p 130".format(
                    pair.sourceFile,
                    pair.destinationFile,
                    pair.sourceFile.canFind("frag") ? "f" : "v"
                )
            );
        });
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
            if(!pair.sourceIsNewer(conf) && !this.force.get(false))
            {
                UserIO.logInfof("[NOT MODIFIED] %s", pair);
                continue;
            }

            mkdirRecurse(pair.destinationFile.dirName);
            action(pair);
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