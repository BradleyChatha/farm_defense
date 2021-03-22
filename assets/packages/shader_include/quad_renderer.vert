struct Quad {
    vec2 topLeft;
    vec2 botRight;
    int textureIndex;
    vec2 uvTopLeft;
    vec2 uvBotRight;
    vec4 colour;
    mat4 model;
};

layout(binding = 0, set = 0) readonly buffer RenderData {
    mat4 view;
    mat4 projection;
    Quad[] quads;
};