shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.15, 0.75, 0.2);
uniform float wobble_speed = 2.0;
uniform float wobble_strength = 0.08;

void vertex() {
	float t = TIME * wobble_speed;
	float wave = sin(VERTEX.x * 4.0 + t) * cos(VERTEX.z * 3.5 + t * 0.7)
			   + sin(VERTEX.y * 5.0 - t * 1.3) * 0.5;
	VERTEX += NORMAL * wave * wobble_strength;
}

void fragment() {
	float fresnel = 1.0 - dot(NORMAL, VIEW);
	float rim = pow(fresnel, 3.0);

	ALBEDO = base_color;
	ROUGHNESS = 0.35;
	SPECULAR = 0.6;
	METALLIC = 0.0;
	EMISSION = base_color * rim * 0.8;
}
