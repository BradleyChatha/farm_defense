#version 450
#extension GL_GOOGLE_include_directive: enable

#include <quad_renderer.frag>

layout(location = 0) in vec4 fragColour;
layout(location = 1) in vec2 fragUv;
layout(location = 2) flat in int fragTextureIndex;

layout(location = 0) out vec4 outColour;

void main()
{
    // Assumes colours are in range 0-1
    const vec4 texColour = texture(textures[fragTextureIndex], fragUv);
    outColour = vec4(texColour.rgb * fragColour.rgb, texColour.a);
}