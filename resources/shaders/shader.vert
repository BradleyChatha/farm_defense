#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(binding = 1) uniform _MandatoryUniforms
{
    mat4 view;
    mat4 projection;
} MandatoryUniforms;

layout(location = 0) in vec2 inPosition;
layout(location = 1) in vec2 inUv;
layout(location = 2) in uvec4 inColour;

layout(location = 0) out vec4 fragColour;
layout(location = 1) out vec2 uv;

void main()
{
    // I'm way too lazy to setup uniforms in Vulkan, just for a static camera, so we're doing this instead.
    const float WINDOW_WIDTH  = 832 / 2;
    const float WINDOW_HEIGHT = 832 / 2;

    vec2 finalPosition = vec2(
        (inPosition.x / WINDOW_WIDTH) - 1,
        (inPosition.y / WINDOW_HEIGHT) - 1
    );
    gl_Position = vec4(finalPosition, 0.0, 1.0);
    fragColour  = inColour;
    uv = inUv;
}