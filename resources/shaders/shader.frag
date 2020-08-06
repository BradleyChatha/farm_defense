#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(push_constant) uniform _PushConstant {
    uint ticks;
} PushConstant;

layout(location = 0) in vec4 fragColor;

layout(location = 0) out vec4 outColor;

void main() {
    //outColor = (fragColor / vec4(255));
    const float scale = mod(PushConstant.ticks, 1000) / 1000;
    outColor = vec4(
        scale, 
        scale * 2, 
        scale * 0.5, 
        1.0
    );
}