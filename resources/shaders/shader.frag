#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(push_constant) uniform _PushConstant {
    uint ticks;
} PushConstant;

//layout(binding = 0) uniform sampler2D texSampler;

layout(location = 0) in vec4 fragColor;
layout(location = 1) in vec2 uv;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 finalColour = fragColor;
         finalColour = finalColour + vec4(PushConstant.ticks % 255);

    outColor = (finalColour / vec4(255));
}