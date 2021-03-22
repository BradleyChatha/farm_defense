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
               .withExporter("material", new MaterialExporter())
               .withAction("to:texture", new ToTextureAction())
               .withAction("texture:stitch", new TextureStitchAction())
               .withAction("to:shader_module", new ToShaderModuleAction())
               .withAction("to:material", new ToMaterialAction());

        g_core = builder.build();
    }

    return g_core;
}