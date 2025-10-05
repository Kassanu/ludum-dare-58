shader_type spatial;

uniform float u_scale : hint_range(0.1, 50.0) = 4.0; // squares per meter
uniform vec3 color_a : source_color = vec3(0.85, 0.85, 0.90);
uniform vec3 color_b : source_color = vec3(0.55, 0.55, 0.60);

varying vec3 v_world_pos;

void vertex() {
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    float cx = floor(v_world_pos.x * u_scale);
    float cz = floor(v_world_pos.z * u_scale);
    float checker = mod(cx + cz, 2.0);
    ALBEDO = mix(color_a, color_b, checker);
}
