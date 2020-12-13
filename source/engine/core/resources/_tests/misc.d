module engine.core.resources._tests.misc;

import fluent.asserts : should;
import engine.core.resources, engine.util;

final class BasicResource : IResource
{
    mixin IResourceBoilerplate;

    string name;

    this(string name)
    {
        this.name = name;
        this.resourceName = name;
    }
}

struct BasicLoadInfo
{
    string name;
}

struct WithDependencyLoadInfo
{
    string myName;
    string depName;
}

final class BasicLoadInfoLoader : IResourceLoader
{
    mixin IResourceLoaderBoilerplate!BasicLoadInfo;

    override Result!IResource loadFromLoadInfo(ResourceLoadInfo loadInfo, ref PackageLoadContext context)
    {
        auto info = loadInfo.as!BasicLoadInfo;
        return Result!IResource.ok(new BasicResource(info.name));
    }
}

final class WithDependencyLoadInfoLoader : IResourceLoader
{
    mixin IResourceLoaderBoilerplate!WithDependencyLoadInfo;

    override Result!IResource loadFromLoadInfo(ResourceLoadInfo loadInfo, ref PackageLoadContext context)
    {
        auto info       = loadInfo.as!WithDependencyLoadInfo;
        auto dependency = context.require!BasicResource(info.depName);

        return Result!IResource.ok(new BasicResource(info.myName~"->"~dependency.name));
    }
}

final class BasicPackageLoader : IPackageLoader
{
    ResourceLoadInfo[] loadInfo;

    this(ResourceLoadInfo[] loadInfo)
    {
        this.loadInfo = loadInfo;
    }
    
    override Result!(ResourceLoadInfo[]) loadFromFile(string absolutePath)
    {
        return typeof(return).ok(this.loadInfo);
    }
}

@("Resources - Basic test")
unittest
{
    static final class DummyResource : IResource { mixin IResourceBoilerplate; }

    auto manager = new PackageManager();
    manager.register(new BasicLoadInfoLoader());
    manager.register("basic", new BasicPackageLoader([
        ResourceLoadInfo(BasicLoadInfo("hello")),
        ResourceLoadInfo(BasicLoadInfo("world"))
    ]));
    auto loadResult = manager.loadFromFile("UNITTEST", "basic"); // "UNITTEST" bypasses the file check.
    assert(loadResult.isOk, loadResult.error);

    // Existing (Right type)
    auto r = manager.getOrNull!BasicResource("hello");
    r.should.not.beNull;
    r.name.should.equal("hello");

    r = manager.getOrNull!BasicResource("world");
    r.should.not.beNull;
    r.name.should.equal("world");

    // Existing (Wrong type)
    manager.getOrNull!DummyResource("hello").should.beNull;

    // Non-existing
    manager.getOrNull("nasdnasdnasdn").should.beNull;
}

@("Resources - Dependency test")
unittest
{
    auto manager = new PackageManager();
    manager.register(new BasicLoadInfoLoader());
    manager.register(new WithDependencyLoadInfoLoader());
    manager.register("basic", new BasicPackageLoader([
        ResourceLoadInfo(WithDependencyLoadInfo("a", "b")), // Depends on non-loaded value
        ResourceLoadInfo(BasicLoadInfo("b")),
        ResourceLoadInfo(WithDependencyLoadInfo("c", "b")) // Depends on loaded value
    ]));
    auto loadResult = manager.loadFromFile("UNITTEST", "basic"); // "UNITTEST" bypasses the file check.
    assert(loadResult.isOk, loadResult.error);

    manager.getOrNull!BasicResource("a->b").should.not.beNull;
    manager.getOrNull!BasicResource("b").should.not.beNull;
    manager.getOrNull!BasicResource("c->b").should.not.beNull;
}

@("Resources - Infinite loop detection")
unittest
{
    auto manager = new PackageManager();
    manager.register(new WithDependencyLoadInfoLoader());
    manager.register("basic", new BasicPackageLoader([
        ResourceLoadInfo(WithDependencyLoadInfo("a", "b"))
    ]));
    manager.loadFromFile("UNITTEST", "basic").isOk.should.not.equal(true);
}