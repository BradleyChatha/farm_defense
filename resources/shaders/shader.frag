#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(set = 0, binding = 0) uniform sampler2D texSampler;

layout(set = 1, binding = 0) uniform _LightingUniform 
{
    vec4 sunColour;
} LightingUniform;

layout(location = 0) in vec4 fragColor;
layout(location = 1) in vec2 uv;

layout(location = 0) out vec4 outColor;

void main() {
    // Normalise UV coords
    vec2 finalUv = uv / textureSize(texSampler, 0);

    // Normalise the fragColour; apply the texture's colour; apply lighting.
    vec4 finalColour = fragColor;
         finalColour = finalColour / vec4(255);
         finalColour = finalColour * texture(texSampler, finalUv);
         finalColour = finalColour * LightingUniform.sunColour;

    outColor = finalColour;
}