#version 450
#extension GL_GOOGLE_include_directive: enable

#include <quad_renderer.vert>

layout(location = 0) out vec4 fragColour;
layout(location = 1) out vec2 fragUv;
layout(location = 2) out int fragTextureIndex;

// Instead of fucking about with vertex and index buffers, we can actually generate the vert positions we need on the GPU.
// We just need to know the start position and size of each quad, which we store inside of the SSBO defined in quad_renderer.vert
const ivec2[6] INDICIES_TO_USE_PER_VERT_INDEX = 
{
    ivec2(0, 1),
    ivec2(2, 1),
    ivec2(2, 3),
    ivec2(2, 3),
    ivec2(0, 3),
    ivec2(0, 1)
};

void main() 
{
    const int       quadIndex       = gl_VertexIndex / 6;
    const int       indiciesIndex   = gl_VertexIndex % 6;
    const Quad      quad            = quads[quadIndex];
    const ivec2     indicies        = INDICIES_TO_USE_PER_VERT_INDEX[indiciesIndex];
    const float[4]  pos             = {quad.topLeft.x, quad.topLeft.y, quad.botRight.x, quad.botRight.y};
    const float[4]  uv              = {quad.uvTopLeft.x, quad.uvTopLeft.y, quad.uvBotRight.x, quad.uvBotRight.y};

    gl_Position         = projection * view * quad.model * vec4(pos[indicies.x], pos[indicies.y], 0, 1);
    fragColour          = quad.colour;
    fragUv              = vec2(uv[indicies.x], uv[indicies.y]);
    fragTextureIndex    = quad.textureIndex;
}