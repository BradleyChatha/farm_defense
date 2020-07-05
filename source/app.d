import std.stdio;
import game.thirdparty, game.window, game.engine;

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

    ThirdParty.onInit();
    Window.onInit();
    ThirdParty.onPostInit();

    auto engine = new Engine();
    engine.onInit();
    engine.loop();
}
