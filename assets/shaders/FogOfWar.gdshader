shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled;

// Inputs
uniform sampler2D noise_texture;
uniform sampler2D mask_texture; // Viewport Texture (Red = Visible/Visited)

uniform vec4 fog_color : source_color = vec4(0.2, 0.1, 0.3, 0.8); // Deep Purple
uniform float time_speed = 0.05;
uniform float density = 1.0;

void fragment() {
	// Scrolling UVs for Noise
	vec2 uv_scrolled = UV + vec2(TIME * time_speed * 0.5, TIME * time_speed * 0.2);
	vec2 uv_scrolled_2 = UV + vec2(-TIME * time_speed * 0.3, TIME * time_speed * 0.6);
	
	// Sample Noise Layers
	float noise_1 = texture(noise_texture, uv_scrolled).r;
	float noise_2 = texture(noise_texture, uv_scrolled_2 * 1.5).r;
	
	// Combine Noise
	float cloud = (noise_1 + noise_2) * 0.5;
	
	// Sample Mask
	// Mask is White (1.0) where visited, Black (0.0) where hidden.
	// We want FOG where HIDDEN.
	float visited = texture(mask_texture, UV).r;
	
	// Logic: If visited (1.0), Alpha -> 0.0.
	// If unvisited (0.0), Alpha -> cloud * density.
	
	float mask_factor = 1.0 - visited;
	
	// Edge fade for mask to avoid sharp pixelated edges?
	// The Viewport drawing circles should use smooth textures for soft edges.
	
	// Final Alpha
	float final_alpha = cloud * mask_factor * density * fog_color.a;
	
	ALBEDO = fog_color.rgb;
	ALPHA = clamp(final_alpha, 0.0, 1.0);
}
