module engine.core.resources.packageloadcontext;

import core.thread : Fiber;
import engine.core.resources, engine.util;

struct PackageLoadContext
{
    @disable this(this){}

    private
    {
        struct Task
        {
            Fiber fiber;
            ResourceLoadInfo loadInfo;
            IResourceLoader loader;

            Result!IResource result;
        }

        PackageManager _manager;
        ResourceLoadInfo[] _loadInfo;
        Package _package;
        Task* _currentTask; // So tasks can access their data.
    }

    this(PackageManager manager, ResourceLoadInfo[] loadInfo)
    {
        this._manager = manager;
        this._loadInfo = loadInfo;
    }

    ResourceT require(ResourceT : IResource)(string resourceName)
    {
        import std.algorithm : countUntil;

        // Called from within a Fiber by the resource loader.
        assert(Fiber.getThis() !is null, "This function cannot be called outside of a Fiber.");

        ResourceT find()
        {
            auto result = this._manager.getOrNull!ResourceT(resourceName);
            if(result is null)
            {
                const index = this._package.resources.countUntil!((a, b) => a.resourceName == resourceName)(resourceName);
                if(index >= 0)
                    result = cast(ResourceT)this._package.resources[index];
            }

            return result;
        }

        auto result = find();
        while(result is null)
        {
            Fiber.yield();
            result = find();
        }

        return result;
    }

    package Result!Package process()
    {
        import std.algorithm : remove;

        // Not using .map since I need to be able to return early.
        auto tasks = new Task[this._loadInfo.length];
        foreach(i, loadInfo; this._loadInfo)
        {
            auto task = Task(new Fiber(&this.fiberMain), loadInfo);

            auto loader = this._manager.getLoaderForLoadInfoT(loadInfo._loadInfoT);
            if(!loader.isOk)
                return Result!Package.failure(loader.error);

            task.loader = loader.value;
            tasks[i] = task;
        }

        auto pkg = new Package();
        this._package = pkg;
        while(tasks.length > 0)
        {
            bool wasResolvedTask = false;
            for(size_t i = 0; i < tasks.length; i++)
            {
                auto task = &tasks[i];

                this._currentTask = task;
                task.fiber.call();

                if(task.fiber.state == Fiber.State.TERM)
                {
                    if(!task.result.isOk)
                        return Result!Package.failure(task.result.error);

                    pkg.resources ~= task.result.value;
                    wasResolvedTask = true;
                    tasks = tasks.remove(i--);
                }
            }

            if(!wasResolvedTask)
                return Result!Package.failure("No tasks resolved, preventing infinite loop.");
        }

        return Result!Package.ok(pkg);
    }

    private void fiberMain()
    {
        auto result = this._currentTask.loader.loadFromLoadInfo(this._currentTask.loadInfo, this);
        this._currentTask.result = result;
    }
}