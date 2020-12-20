module engine.core.lua.funcs.debug_;

import core.stdc.stdio;
import engine.core.lua.funcs._import;

// Taken from StackOverflow since I was lazy.
void printStack (ref LuaState state) {
    auto L = state.handle;

    printf("=====LUA STACK TRACE=====\n");

    int top=lua_gettop(L);
    for (int i=1; i <= top; i++) {
        printf("%d\t%s\t", i, luaL_typename(L,i));
        switch (lua_type(L, i)) {
        case LUA_TNUMBER:
            printf("%g\n",lua_tonumber(L,i));
            break;
        case LUA_TSTRING:
            printf("%s\n",lua_tostring(L,i));
            break;
        case LUA_TBOOLEAN:
            printf("%s\n", (lua_toboolean(L, i) ? "true".ptr : "false".ptr));
            break;
        case LUA_TNIL:
            printf("%s\n", "nil".ptr);
            break;
        default:
            printf("%p\n",lua_topointer(L,i));
            break;
        }
    }
}

Result!lua_Debug getDebugInfo(ref LuaState state, string what, int level = 1)
{
    auto guard = LuaStackGuard(state, 0);

    lua_Debug dbg;

    const result = lua_getstack(state.handle, level, &dbg);
    if(result != 1)
        return typeof(return).failure("lua_getstack returned non-1");

    lua_getinfo(state.handle, what.ptr, &dbg);

    return typeof(return).ok(dbg);
}