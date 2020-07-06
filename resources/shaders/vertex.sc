$input a_position, a_color0, a_texcoord0
$output v_color0, v_texcoord0

#include "bgfx_shader.h"

void main()
{
	// Apply model directly to the vert position, as that allows the model matrix to use world-space coordinates.
	vec4 coord = mul(vec4(a_position, 1.0), u_model[0]);
	
	// *Then* apply the viewProjection to it.
	gl_Position = mul(coord, u_viewProj);
	v_color0    = a_color0;
	v_texcoord0 = a_texcoord0;
}