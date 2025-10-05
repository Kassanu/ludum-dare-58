shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

// ---------------- MATERIAL ----------------
uniform vec3  rim_color = vec3(0.82, 0.82, 0.82);
uniform float metallic  = 0.9;
uniform float roughness = 0.35;
uniform float wear      = 0.35; // 0..1

uniform vec3  face_color = vec3(0.82, 0.82, 0.82);
uniform bool  faces_use_rim_color = false;

// NEW: independent face material controls (defaults match rim)
uniform bool  faces_use_rim_material = true; // if true, faces use metallic/roughness/wear above
uniform float face_metallic  = 0.9;
uniform float face_roughness = 0.35;
uniform float face_wear      = 0.35;

// NEW: make printed ink change material response (recommended)
uniform bool  face_ink_affects_material = true;
uniform float face_ink_roughness_boost  = 0.20; // add to roughness under ink
uniform float face_ink_metallic_scale   = 0.85; // multiply metallic under ink

// ---------------- FACE TEXTURES ----------------
uniform sampler2D top_tex    : source_color;
uniform sampler2D bottom_tex : source_color;
uniform bool top_tex_enabled = false;
uniform bool bottom_tex_enabled = false;

// Cap geometry in OBJECT SPACE (XZ plane)
uniform vec2  cap_center_top_os = vec2(0.0, 0.0);
uniform float cap_radius_top_os = 0.5;
uniform vec2  cap_center_bot_os = vec2(0.0, 0.0);
uniform float cap_radius_bot_os = 0.5;

// If your bottom appears mirrored, flip here:
uniform bool bottom_flip_u = false;
uniform bool bottom_flip_v = false;

// Tiny artistic tweaks (optional)
uniform vec2  face_tex_scale_top  = vec2(1.0, 1.0);
uniform vec2  face_tex_scale_bot  = vec2(1.0, 1.0);
uniform vec2  face_tex_offset_top = vec2(0.0);
uniform vec2  face_tex_offset_bot = vec2(0.0);


// --------- YEAR OVERLAY (SDF) ----------
uniform sampler2D digits_sdf;
uniform vec4  year_digits = vec4(2.0, 0.0, 0.0, 4.0);

uniform bool  overlay_enabled         = true;
uniform bool  overlay_on_top          = true;
uniform bool  overlay_on_bottom       = false;
// keep upright by default (does NOT follow face rotation — but we removed face rotation anyway)
uniform bool  overlay_follows_face_rotation = false;
uniform bool  overlay_align_tangent   = true;

// UV ellipse—used only by overlay placement/guides. Defaults are safe.
uniform vec2  face_center_uv          = vec2(0.5, 0.5);
uniform vec2  face_radius_uv          = vec2(0.485, 0.485);

// Overlay placement (UV-space)
uniform vec2  overlay_center_uv       = vec2(0.5, 0.74);
uniform vec2  overlay_size_uv         = vec2(0.26, 0.10);
uniform float overlay_rotation        = 0.0;
uniform bool  overlay_mirror_x        = false;
uniform bool  overlay_rtl             = false;
uniform float overlay_radial_margin   = 0.05;

uniform vec3  overlay_color           = vec3(0.10, 0.10, 0.10);
uniform float overlay_opacity         = 1.0;
uniform float digit_spacing           = 0.10;
uniform float digits_softness         = 0.08;

// drive overlay position by cap geometry (object space)
uniform float overlay_angle = 1.57079632679; // angle around rim in radians; 0=+X, pi/2=+Z
uniform float overlay_inset_norm = 0.08;     // inward from rim in *normalized* cap radius units
uniform bool  overlay_use_cap_space = true;  // switch to cap-space overlay

// ---------- DEBUG ----------
uniform bool  debug_face_circle = false;
uniform bool  debug_overlay_box = false;
uniform bool  debug_overlay_fill= false;
uniform int  debug_face_view = 0; // 0=off, 1=alpha, 2=luma, 3=rgb, 4=coverage(alpha), 5=premult test
uniform bool debug_face_only = true; // if true, only affects caps (not rim)

// ---------------- INTERNAL ----------------
varying float v_local_ny;
varying vec2  v_cap_local; // cap-local coords in [-1..1] from object-space XZ
varying float v_is_top;    // 1.0 for top, 0.0 for bottom

// --------- HELPERS ----------
mat2 rot2(float a) {
    float s = sin(a), c = cos(a);
    return mat2(vec2(c, -s), vec2(s, c));
}
vec2 rotate_uv_pivot(vec2 uv, float angle, vec2 pivot) {
    return rot2(angle) * (uv - pivot) + pivot;
}
float sample_digit(vec2 uv01, float idx) {
    float cell = 1.0 / 10.0;
    uv01.x = uv01.x * cell + floor(clamp(idx, 0.0, 9.0)) * cell;
    uv01 = clamp(uv01, vec2(0.0), vec2(1.0));
    float d = texture(digits_sdf, uv01).r;
    return smoothstep(0.5 - digits_softness, 0.5 + digits_softness, d);
}
float ellipse_boundary_len(vec2 dir, vec2 radius) {
    float a = dir.x / max(radius.x, 1e-6);
    float b = dir.y / max(radius.y, 1e-6);
    return 1.0 / sqrt(a*a + b*b);
}

void vertex() {
    v_local_ny = NORMAL.y;
    v_is_top   = (NORMAL.y > 0.0) ? 1.0 : 0.0;

    // Project object-space position onto cap plane (XZ)
    vec2 p_xz = VERTEX.xz;

    // Compute top/bottom cap-local coords in [-1..1] using *real* centers/radii
    vec2 local_top = (p_xz - cap_center_top_os) / max(cap_radius_top_os, 1e-6);
    vec2 local_bot = (p_xz - cap_center_bot_os) / max(cap_radius_bot_os, 1e-6);

    // Choose based on face
    v_cap_local = mix(local_bot, local_top, v_is_top);
}
void fragment() {
    bool is_cap = abs(v_local_ny) > 0.7071; // +/- 45°

    if (is_cap) {
        // ----- FACES (caps) -----
        float m = faces_use_rim_material ? metallic  : face_metallic;
        float r = faces_use_rim_material ? roughness : face_roughness;
        float w = faces_use_rim_material ? wear      : face_wear;

        // Base face material before “ink” adjustments
        float face_metal  = m;
        float face_rough  = mix(r, 0.6, clamp(w, 0.0, 1.0)); // keep your “wear” nudge
        bool is_top = (v_is_top > 0.5);

        // ---- FACE: opaque base + centered planar mapping from object space ----
        vec3 base_rgb = faces_use_rim_color ? rim_color : face_color;
        vec3 out_rgb  = base_rgb;
        float out_a   = 1.0;

        vec2 local = v_cap_local; // [-1..1] circle == face edge

        if (!is_top) {
            if (bottom_flip_u) local.x = -local.x;
            if (bottom_flip_v) local.y = -local.y;
        }

        vec2 fscale = is_top ? face_tex_scale_top : face_tex_scale_bot;
        vec2 foffs  = is_top ? face_tex_offset_top : face_tex_offset_bot;

        local = local * fscale + foffs;

        // Map to [0..1], clamp for safety
        vec2 tex_uv = clamp(local * 0.5 + 0.5, 0.0, 1.0);

        vec4 face_samp = is_top ? texture(top_tex, tex_uv) : texture(bottom_tex, tex_uv);

        // ---- Diagnostics (visualize what's in the texture) ----
        if (debug_face_view != 0 && (debug_face_only ? true : true)) {
            float a    = clamp(face_samp.a, 0.0, 1.0);
            vec3  rgb  = face_samp.rgb;
            float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
            float cov_alpha = a;
            vec3  ink_est   = rgb / max(a, 1e-4); // “un-premultiply” for inspection

            vec3 dbg = vec3(0.0);
            if (debug_face_view == 1) {          // alpha channel visualized
                dbg = vec3(a);
            } else if (debug_face_view == 2) {   // luma of RGB
                dbg = vec3(luma);
            } else if (debug_face_view == 3) {   // raw RGB
                dbg = rgb;
            } else if (debug_face_view == 4) {   // what mix(..., alpha) uses as coverage
                dbg = vec3(cov_alpha);
            } else if (debug_face_view == 5) {   // premultiplied ink estimate
                dbg = ink_est;
            }

            // Make it clearly visible regardless of lighting
            ALBEDO   = dbg;
            EMISSION = dbg;
            ALPHA    = 1.0;
        } else {
            // --- Blend coverage gated by 'texture assigned' flags ---
            bool tex_enabled = is_top ? top_tex_enabled : bottom_tex_enabled;
            float cov = tex_enabled ? clamp(face_samp.a, 0.0, 1.0) : 0.0;

            // (Optional) If some of your real textures have messy alpha, you can
            // derive extra coverage from luma. Uncomment to use min(alpha, luma):
            // float luma     = dot(face_samp.rgb, vec3(0.299, 0.587, 0.114));
            // float cov_luma = smoothstep(0.05, 0.10, luma);
            // cov = tex_enabled ? min(cov, cov_luma) : 0.0;

            // Composite face ink over the opaque metal base
            out_rgb = mix(out_rgb, face_samp.rgb, cov);

            // --- Make ink affect material so changes are visible ---
            float ink_cov = cov; // 0..1 coverage from face texture alpha
            float final_metal   = face_metal;
            float final_rough   = face_rough;

            if (face_ink_affects_material) {
                final_rough = clamp(final_rough + face_ink_roughness_boost * ink_cov, 0.0, 1.0);
                final_metal = clamp(final_metal * mix(1.0, face_ink_metallic_scale, ink_cov), 0.0, 1.0);
            }

            ALBEDO    = out_rgb;
            ALPHA     = 1.0;
            METALLIC  = final_metal;
            ROUGHNESS = final_rough;

            // ---- DEBUG: UV ellipse ring (for overlay tuning only) ----
            if (debug_face_circle) {
                vec2 d = (UV - face_center_uv) / face_radius_uv;
                float r = length(d);
                float band = smoothstep(1.0 - 0.003, 1.0, r) - smoothstep(1.0, 1.0 + 0.003, r);
                ALBEDO = mix(ALBEDO, vec3(1.0, 0.2, 0.2), band);
            }

            // --------- YEAR OVERLAY (unchanged) ----------
            if (overlay_enabled && ((is_top && overlay_on_top) || (!is_top && overlay_on_bottom))) {

                if (overlay_use_cap_space) {
                    // Use the same cap-local coords we used for face mapping:
                    // local in [-1..1], where 1.0 = rim
                    // We only need to build a parametric center point along the rim direction.
                    // --- Choose the rim point by angle 'overlay_angle' ---
                    float a = overlay_angle;

                    // Radial (outward) and Tangent (parallel to rim) unit vectors in cap-local space
                    vec2 n_rad = vec2(cos(a), sin(a));      // radial  (+1 points outward)
                    vec2 t_tan = vec2(-sin(a), cos(a));     // tangent (counter-clockwise from +X)

                    // Pick current fragment in cap-local space [-1..1]
                    vec2 p_local = v_cap_local;
                    if (!is_top) {
                        if (bottom_flip_u) p_local.x = -p_local.x;
                        if (bottom_flip_v) p_local.y = -p_local.y;
                    }

                    // Box size (unchanged API: overlay_size_uv is in *cap-local* units now)
                    float half_w = overlay_size_uv.x * 0.5;
                    float half_h = overlay_size_uv.y * 0.5;

                    // How far to move inward from the rim (0..1 where 1 = center)
                    float inward = clamp(overlay_inset_norm, 0.0, 0.95);

                    // Center of the overlay box in cap-local coords: start at rim (1.0) and go inward
                    // We also subtract half_h so the *outer edge* clears the rim.
                    vec2 center_local = n_rad * (1.0 - inward - half_h);

                    // Build a local 2D coordinate in the (tangent, radial) basis.
                    // Because t_tan and n_rad are orthonormal, the coordinates are just dot products.
                    vec2 q; // q.x = tangent coord, q.y = radial coord
                    vec2 delta = p_local - center_local;
                    q.x = dot(delta, t_tan);
                    q.y = dot(delta, n_rad);

                    // Optional extra rotation around the box's center (keeps tangent as the natural "X")
                    float angle_final = overlay_rotation; // small tweak only
                    vec2 q_rot = rot2(angle_final) * q;

                    // Map to 0..1 box space
                    vec2 minb = vec2(-half_w, -half_h);
                    vec2 local_box = (q_rot - minb) / overlay_size_uv;

                    if (overlay_mirror_x) {
                        local_box.x = 1.0 - local_box.x;
                    }

                    if (debug_overlay_box || debug_overlay_fill) {
                        bool inside = all(greaterThanEqual(local_box, vec2(0.0))) && all(lessThanEqual(local_box, vec2(1.0)));
                        float edge = max(max(abs(local_box.x - 0.0), abs(local_box.x - 1.0)),
                                        max(abs(local_box.y - 0.0), abs(local_box.y - 1.0)));
                        float border = smoothstep(0.01, 0.0, abs(edge) - 0.0);
                        if (debug_overlay_fill && inside) {
                            ALBEDO = mix(ALBEDO, vec3(0.2, 0.6, 1.0), 0.35);
                        }
                        ALBEDO = mix(ALBEDO, vec3(0.0, 0.5, 1.0), border);
                    }

                    float date_mask = 0.0;
                    if (all(greaterThanEqual(local_box, vec2(0.0))) && all(lessThanEqual(local_box, vec2(1.0)))) {
                        float sp = clamp(digit_spacing, 0.0, 0.5);
                        float w  = (1.0 - 3.0 * sp) / 4.0;
                        for (int i = 0; i < 4; i++) {
                            float left = float(i) * (w + sp);
                            vec2 d_uv = (local_box - vec2(left, 0.0)) / vec2(w, 1.0);
                            if (d_uv.x >= 0.0 && d_uv.x <= 1.0 && d_uv.y >= 0.0 && d_uv.y <= 1.0) {
                                int j = overlay_rtl ? (3 - i) : i;
                                float d_idx = (j == 0) ? year_digits.x :
                                            (j == 1) ? year_digits.y :
                                            (j == 2) ? year_digits.z : year_digits.w;
                                date_mask = max(date_mask, sample_digit(d_uv, d_idx));
                            }
                        }
                    }

                    a = date_mask * overlay_opacity;
                    ALBEDO    = mix(ALBEDO, overlay_color, a);
                    ROUGHNESS = mix(ROUGHNESS, max(0.05, ROUGHNESS * 0.7), a);
                }
            }
        }
    } else {
        ALBEDO    = rim_color;
        METALLIC  = metallic;
        ROUGHNESS = mix(roughness, 0.6, clamp(wear, 0.0, 1.0));
    }
}
