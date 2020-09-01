module game.common.task;

import std.experimental.logger;
import std.traits;
import core.thread;
import game.common;

private enum OBJECTS_PER_REGION     = 512;
private enum INITIAL_FIBER_CAPACITY = 512;

private MemoryPool!(TaskFiber, OBJECTS_PER_REGION) g_taskFiberPool;
private TaskGroup[TaskGroupIndex.max+1]            g_taskGroups;

private enum TaskGroupIndex
{
    Future
}

private struct TaskGroup
{
    private PooledObject!TaskFiber[] _tasks;
    private TaskGroupIndex           _index;
            string                   statName;

    this(string statName, TaskGroupIndex index)
    {
        this.statName = statName;
        this._index   = index;
        this.resize(INITIAL_FIBER_CAPACITY);
    }

    void resize(size_t taskCount)
    {
        this._tasks.length = taskCount;
    }

    size_t enqueue(PooledObject!TaskFiber task)
    {
        assert(task.value !is null,                  "Task is null");
        assert(task.value.state == Fiber.State.HOLD, "Task is not in HOLD state");
        assert(this._tasks.length != 0,              "I wasn't initialised :(");

        auto index = size_t.max;
        foreach(i, t; this._tasks)
        {
            if(t == PooledObject!TaskFiber.init)
            {
                index = i;
                break;
            }
        }

        if(index == size_t.max)
        {
            index = this._tasks.length;
            this.resize(this._tasks.length * 2);
        }

        task.value.index   = index;
        task.value.group   = this._index;
        this._tasks[index] = task;
        return index;
    }

    void unqueue(TaskFiber task)
    {
        const index = task.index;
        this._tasks[index] = PooledObject!TaskFiber.init;
        g_taskFiberPool.free(this._tasks[index]);
    }

    void process()
    {
        foreach(task; this._tasks)
        {
            if(task.value is null)
                continue;
            
            if(task.value.state == Fiber.State.HOLD)
                task.value.call(Fiber.Rethrow.yes);
        }
    }
}

class TaskFiber : Fiber
{
    void delegate() func;
    size_t          index;
    TaskGroupIndex  group;

    this(void delegate() func)
    {
        this.func = func;
        super(&this.run);
    }

    void run()
    {
        func();
        taskFinaliseImpl(this);
    }
}

struct Future(T)
{
    private T    value;
    private bool finished;
    private void function(ref PooledObject!(typeof(this))) destroyFunc;
}

bool observe(T)(ref PooledObject!(Future!T) task, ref T value)
{
    if(!task.value.finished)
        return false;

    value = task.value.value;
    task.value.destroyFunc(Ref(task));
    return true;
}

alias FutureFor(T) = PooledObject!(Future!T);

FutureFor!ValueT taskCreateFuture(ValueT)(ValueT delegate() func)
{
    static MemoryPool!(Future!ValueT, 32) futurePool;

    auto future = futurePool.makeSingle();
    future.value.destroyFunc = (ref task){ futurePool.free(task); };
    taskCreateImpl(TaskGroupIndex.Future, ()
    { 
        future.value.value    = func();
        future.value.finished = true;
    });

    return future;
}

private void taskCreateImpl(TaskGroupIndex group, void delegate() task)
{
    g_taskGroups[cast(size_t)group].enqueue(g_taskFiberPool.makeSingle(task));
}

private void taskFinaliseImpl(TaskFiber task)
{
    g_taskGroups[cast(size_t)task.group].unqueue(task);
}

void taskProcessFutures()
{
    g_taskGroups[cast(size_t)TaskGroupIndex.Future].process();
}

void taskProcessAll()
{
    foreach(group; g_taskGroups)
        group.process();
}

void taskInit()
{
    info("Initialising task system.");

    import std.conv : to;
    foreach(group; [TaskGroupIndex.Future])
        g_taskGroups[cast(size_t)group] = TaskGroup("task.group."~group.to!string, group);
}

@("Please for the love of fuck work first time")
unittest
{
    taskInit();

    int intValue;
    auto future = taskCreateFuture(() { Fiber.yield(); return 69; });
    assert(!future.finished);
    assert(!future.observe(Ref(intValue)));
    assert(g_taskGroups[cast(size_t)TaskGroupIndex.Future]._tasks[0].value !is null);

    taskProcessAll();
    assert(!future.finished);
    assert(!future.observe(Ref(intValue)));
    assert(g_taskGroups[cast(size_t)TaskGroupIndex.Future]._tasks[0].value !is null);

    taskProcessAll();
    assert(future.finished);
    assert(future.value.value == 69);
    assert(future.observe(Ref(intValue)));
    assert(intValue == 69);
    assert(!future.isValid);

    assert(g_taskGroups[cast(size_t)TaskGroupIndex.Future]._tasks[0].value is null);

    // Just seeing if we magically crash.
    taskProcessAll();
    taskProcessAll();
    taskProcessAll();
}