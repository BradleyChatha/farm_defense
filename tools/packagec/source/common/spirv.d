module common.spirv;

import std.process, std.conv, std.traits, std.stdio, std.file, std.path, std.json, std.typecons;

enum SpirvShaderModuleType
{
    vert,
    frag
}

struct SpirvReflectMember
{
    string name;
    string type;
    Nullable!int offset;

    Nullable!int matrixStride;

    Nullable!int arrayLength;
    Nullable!bool arraySizeIsLiteral;
    Nullable!int arrayStride;

    Nullable!int set;
    Nullable!int binding;

    Nullable!int location;

    bool isArray()
    {
        return !this.arrayLength.isNull;
    }
}

struct SpirvReflectType
{
    string tag;
    string name;
    SpirvReflectMember[string] members;
}

struct SpirvReflectSsbo
{
    string name;
    string type;
    bool readOnly;
    int blockSize;
    int set;
    int binding;
}

struct SpirvReflection
{
    SpirvReflectType[string] types;
    SpirvReflectMember[string] outputs;
    SpirvReflectMember[string] inputs;
    SpirvReflectMember[string] textures;
    SpirvReflectSsbo[string] ssbos;
}

abstract static class Spirv
{
    public static
    {
        ubyte[] compile(string code, SpirvShaderModuleType type)
        {
            auto pipes = pipeShell(
                "glslc "~" -fshader-stage="~type.to!string~" - "~" -o- "~" -I assets/packages/shader_include/", 
                Redirect.stdin | Redirect.stdout | Redirect.stderrToStdout
            );
            scope(exit)
            {
                pipes.stdin.close();
                pipes.pid.wait();
            }

            pipes.stdin.write(code);
            pipes.stdin.close();

            ubyte[] data;
            foreach(slice; pipes.stdout.byChunk(4096))
                data ~= slice;

            auto statusCode = pipes.pid.wait();
            if(statusCode != 0)
                throw new Exception("Error when calling glslc: "~(cast(char[])data).idup);

            return data;
        }

        SpirvReflection reflect(ubyte[] rawSpirv)
        {
            SpirvReflection info;

            std.file.write("temp.spirv", rawSpirv);
            scope(exit) std.file.remove("temp.spirv");

            auto result = executeShell("spirv-cross temp.spirv --reflect");
            if(result.status != 0)
                throw new Exception("Error when calling spirv-cross: "~result.output);

            auto json = parseJSON(result.output).object;
            if(auto typesPtr = "types" in json)
            {
                auto types = typesPtr.object;
                foreach(key, value; types)
                {
                    SpirvReflectType type;
                    type.tag = key;
                    type.name = value["name"].get!string;

                    if(auto membersPtr = "members" in types)
                        type.members = readMemberArray(*membersPtr);
                    
                    info.types[key] = type;
                }
            }

            if(auto outputPtr = "outputs" in json)
                info.outputs = readMemberArray(*outputPtr);

            if(auto inputPtr = "inputs" in json)
                info.inputs = readMemberArray(*inputPtr);

            if(auto texturePtr = "textures" in json)
                info.textures = readMemberArray(*texturePtr);

            if(auto ssboPtr = "ssbos" in json)
            {
                auto ssboJson = ssboPtr.array;
                foreach(value; ssboJson)
                {
                    SpirvReflectSsbo ssbo;
                    ssbo.name = value["name"].get!string;
                    ssbo.type = value["type"].get!string;
                    ssbo.readOnly = value.getNullable!bool("readonly").get(false);
                    ssbo.blockSize = value["block_size"].get!int;
                    ssbo.set = value["set"].get!int;
                    ssbo.binding = value["binding"].get!int;

                    info.ssbos[ssbo.name] = ssbo;
                }
            }

            return info;
        }
    }
}

private SpirvReflectMember[string] readMemberArray(JSONValue array)
{
    typeof(return) aa;
    foreach(value; array.array)
    {
        auto member = readMember(value);
        aa[member.name] = member;
    }

    return aa;
}

private SpirvReflectMember readMember(JSONValue object)
{
    SpirvReflectMember member;
    member.name = object["name"].get!string;
    member.type = object["type"].get!string;
    member.offset = object.getNullable!int("offset");
    member.matrixStride = object.getNullable!int("matrix_stride");
    member.arrayLength = object.getNullableArrayWrappedValue!int("array");
    member.arraySizeIsLiteral = object.getNullableArrayWrappedValue!bool("array_size_is_literal");
    member.arrayStride = object.getNullable!int("array_stride");
    member.set = object.getNullable!int("set");
    member.binding = object.getNullable!int("binding");
    member.location = object.getNullable!int("location");

    return member;
}

private Nullable!T getNullable(T)(JSONValue value, string name)
{
    if(auto ptr = name in value.object)
        return typeof(return)(ptr.get!T);

    return typeof(return).init;
}

private Nullable!T getNullableArrayWrappedValue(T)(JSONValue value, string name)
{
    if(auto ptr = name in value.object)
    {
        if(ptr.type == JSONType.ARRAY)
            return typeof(return)(ptr.array[0].get!T);
    }

    return typeof(return).init;
}