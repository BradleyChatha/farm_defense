import std.stdio, std.experimental.logger;
import bindbc.sdl, erupted;

void main()
{
    import std.file : exists, chdir;

    // Support running the game from "dub run"
    bool goBack = false;
    if("dub.sdl".exists)
    {
        chdir("bin");
        goBack = true;
    }    
    scope(exit)
    {
        if(goBack)
            chdir("..");
    }
}
