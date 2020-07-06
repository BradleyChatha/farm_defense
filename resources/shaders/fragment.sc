$input v_color0, v_texcoord0

#include "bgfx_shader.h"

SAMPLER2D(s_texColor, 0);

void main()
{
    // Size of the texture.
    ivec2 texSize = textureSize(s_texColor, 0).xy;

    // Fixup the UV. They're specified from the top-left but OpenGL wants the bottom-left.
    vec2 finalUV = v_texcoord0;
    finalUV.y    = texSize.y - finalUV.y;

    // Convert pixels to NDC
    vec2 onePixel = vec2(1.0, 1.0) / vec2(texSize);
    vec2 texel = onePixel * finalUV;

    //
    gl_FragColor = texture(s_texColor, texel) * v_color0;
	
	// I have actually 0 idea on how to properly enable alpha blending in BGFX, and any code I
	// find online doesn't really work, so.... we'll just do this.
	if(gl_FragColor.a == 0)
		discard;
}