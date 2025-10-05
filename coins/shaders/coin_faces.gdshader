shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform sampler2D top_tex    : source_color;
uniform sampler2D bottom_tex : source_color;
uniform float top_rotation   = 0.0;
uniform float bottom_rotation= 0.0;

uniform vec3  rim_color = vec3(0.82, 0.82, 0.82);
uniform float metallic  = 0.9;
uniform float roughness = 0.35;
uniform float wear      = 0.35;     // 0..1, higher = duller

varying float v_local_ny;

vec2 rot2(vec2 uv, float a) {
    float s = sin(a), c = cos(a);
    mat2 R = mat2(vec2(c, -s), vec2(s, c));
    return R * (uv - 0.5) + 0.5;
}

void vertex() {
    v_local_ny = NORMAL.y;
}

void fragment() {
    METALLIC = metallic;
    ROUGHNESS = mix(roughness, 0.6, clamp(wear, 0.0, 1.0));

    if (abs(v_local_ny) > 0.7071) {
        bool is_top = v_local_ny > 0.0;
        vec2 uv = rot2(UV, is_top ? top_rotation : bottom_rotation);
        vec4 face = texture(is_top ? top_tex : bottom_tex, uv);
        ALBEDO = face.rgb;
        ALPHA  = face.a;
    } else {
        ALBEDO = rim_color;
    }
}
