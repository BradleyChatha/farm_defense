#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(push_constant) uniform _PushConstant
{
    mat4 view;
    mat4 projection;
} PushConstant;

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inUv;
layout(location = 2) in uvec4 inColour;

layout(location = 0) out vec4 fragColour;
layout(location = 1) out vec2 uv;

void main()
{
    gl_Position = vec4((PushConstant.projection * PushConstant.view * vec4(floor(inPosition), 1.0)).xyz, 1.0) - vec4(1, 1, 0, 0);
    fragColour  = inColour;
    uv          = inUv;
}