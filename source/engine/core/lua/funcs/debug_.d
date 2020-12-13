module engine.core.lua.funcs.debug_;

import core.stdc.stdio;
import engine.core.lua.funcs._import;

// Taken from StackOverflow since I was lazy.
void printStack (ref LuaState state) {
    auto L = state.handle;
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