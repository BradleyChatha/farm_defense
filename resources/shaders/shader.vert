#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(push_constant) uniform _PushConstant
{
    layout(row_major) mat4 view;
                      mat4 projection; // Don't ask me why this one works fine, even though it's also supposed to be row_major (unless mat4f.orthographic is different here).
} PushConstant;

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inUv;
layout(location = 2) in uvec4 inColour;

layout(location = 0) out vec4 fragColour;
layout(location = 1) out vec2 uv;

void main()
{
    // We floor the view * model calculation, as inaccuracies can cause random gaps between verts.
    //
    // By flooring across the board, we ensure everything looks consistent to eachother, even if it means other slight oddities down the line.
    gl_Position = vec4((PushConstant.projection * floor(PushConstant.view * vec4(inPosition, 1.0))).xyz, 1.0) - vec4(1, 1, 0, 0);
    fragColour  = inColour;
    uv          = inUv;
}