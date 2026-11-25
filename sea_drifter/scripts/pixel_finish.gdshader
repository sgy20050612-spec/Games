shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
void fragment() {
	vec2 size = vec2(1.0) / SCREEN_PIXEL_SIZE;
	vec2 sample_uv = (floor(SCREEN_UV * size) + vec2(0.5)) / size;
	vec3 color = texture(screen_texture, sample_uv).rgb;
	// One consistent five-bit color ramp per channel across sprites, UI and sky.
	color = floor(color * 31.0 + vec3(0.5)) / 31.0;
	COLOR = vec4(color, 1.0);
}
