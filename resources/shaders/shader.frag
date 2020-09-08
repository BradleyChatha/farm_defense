#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(push_constant) uniform _PushConstant {
    uint ticks;
} PushConstant;

layout(binding = 0) uniform sampler2D texSampler;

layout(location = 0) in vec4 fragColor;
layout(location = 1) in vec2 uv;

layout(location = 0) out vec4 outColor;

void main() {
    // Normalise UV coords
    vec2 finalUv = uv / textureSize(texSampler, 0);

    // Apply colour calcs
    vec4 finalColour = fragColor;
         //finalColour = finalColour + (vec4(PushConstant.ticks % 255) / vec4(1, 2, 4, 1));
         finalColour = finalColour / vec4(255);
         finalColour = finalColour * texture(texSampler, finalUv);

    outColor = finalColour;
}