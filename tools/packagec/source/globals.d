module globals;

import common, interfaces, implementations;

private PackagecCore g_core;

PackagecCore getCore()
{
    if(g_core is null)
    {
        auto builder = new PackagecCoreBuilder();

        builder.withLoader(".sdl", new SdlPackageLoader())
               .withImporter("file", new RawFileAssetImporter())
               .withExporter("texture", new TextureExporter())
               .withAction("to:texture", new ToTextureAction())
               .withAction("texture:stitch", new TextureStitchAction());

        g_core = builder.build();
    }

    return g_core;
}