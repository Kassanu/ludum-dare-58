shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform sampler2D top_tex    : source_color;
uniform sampler2D bottom_tex : source_color;
uniform float top_rotation   = 0.0;
uniform float bottom_rotation= 0.0;

uniform vec3  rim_color = vec3(0.82, 0.82, 0.82);
uniform float metallic  = 0.9;
uniform float roughness = 0.35;

// Pass local-space normal.y so "top vs bottom" is robust no matter how the coin rotates
varying float v_local_ny;

vec2 rotate_uv(vec2 uv, float a) {
    float s = sin(a), c = cos(a);
    // Godot expects mat2(vec2, vec2) (column-major)
    mat2 R = mat2(vec2(c, -s), vec2(s, c));
    return R * (uv - 0.5) + 0.5;
}

void vertex() {
    v_local_ny = NORMAL.y; // object-space normal
}

void fragment() {
    METALLIC = metallic;
    ROUGHNESS = roughness;

    if (abs(v_local_ny) > 0.7071) { // cap region
        bool is_top = v_local_ny > 0.0;
        vec2 uv = rotate_uv(UV, is_top ? top_rotation : bottom_rotation);
        vec4 face = texture(is_top ? top_tex : bottom_tex, uv);
        ALBEDO = face.rgb;
        ALPHA  = face.a;
    } else { // rim
        ALBEDO = rim_color;
    }
}
