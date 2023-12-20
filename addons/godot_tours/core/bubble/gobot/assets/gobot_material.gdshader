shader_type canvas_item;

const vec2 OFFSETS[12] = { vec2(-1, 0), vec2(0, -1), vec2(0, 1), vec2(1, 0), vec2(-0.85, 0.5), vec2(-0.5, 0.85), vec2(0.85, 0.5), vec2(0.5, 0.85), vec2(-0.85, -0.5), vec2(-0.5, -0.85), vec2(0.85, -0.5), vec2(0.5, -0.85)
};

uniform float line_thickness : hint_range(0, 100) = 1.0;

float outline(vec2 size, vec2 uv, sampler2D color){
	float outline = 0.0;
	for(int i = 0; i < OFFSETS.length(); i++){
		outline += texture(color, uv + size * OFFSETS[i]).a;
	}
	return min(outline, 1.0);
}

void fragment(){
	float black_outline_mask = outline(TEXTURE_PIXEL_SIZE * line_thickness, UV, TEXTURE);
	float white_outline_mask = outline(1.6 * TEXTURE_PIXEL_SIZE * line_thickness, UV, TEXTURE);
	vec3 border_color = mix(vec3(1.0), vec3(0.0), black_outline_mask);
	COLOR.rgb = mix(border_color, COLOR.rgb, COLOR.a);
	COLOR.a = white_outline_mask;
}