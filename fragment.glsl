#version 300 es
precision highp float;
out vec4 outColor;

// Uniforms
uniform vec2 u_resolution;
uniform vec3 u_camPos;
uniform vec3 u_camTarget;
uniform float u_time;

// UI Parameters
uniform float u_power;
uniform float u_max_iter;
uniform float u_shadow_softness;
uniform float u_fog_density;
uniform vec3 u_color_a;
uniform vec3 u_color_b;

const float BAILOUT = 2.0;
const int MAX_STEPS = 150;
const float MAX_DIST = 12.0;
const float SURF_DIST = 0.0015;

// Dynamic Palette based on UI colors
vec3 get_palette(float t) {
    vec3 a = vec3(0.5);
    vec3 b = vec3(0.5);
    return a + b * cos(6.28318 * (u_color_a * t + u_color_b + u_time * 0.05));
}

// Returns vec2(distance, orbit_trap)
vec2 mandelbulb_de(vec3 pos) {
    vec3 z = pos;
    float dr = 1.0;
    float r = 0.0;
    float trap = 1e20; // Used for coloring
    
    // WebGL2 requires constant loop bounds
    for (int i = 0; i < 30; i++) {
        if (float(i) >= u_max_iter) break;
        
        r = length(z);
        if (r > BAILOUT) break;
        
        // Orbit trap (closest distance to origin)
        trap = min(trap, r);
        
        float theta = acos(clamp(z.z / r, -1.0, 1.0));
        float phi = atan(z.y, z.x);
        
        dr = pow(r, u_power - 1.0) * u_power * dr + 1.0;
        
        float zr = pow(r, u_power);
        theta *= u_power;
        phi *= u_power;
        
        z = zr * vec3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta)) + pos;
    }
    return vec2(0.5 * log(r) * r / dr, trap);
}

vec3 calc_normal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        mandelbulb_de(p + e.xyy).x - mandelbulb_de(p - e.xyy).x,
        mandelbulb_de(p + e.yxy).x - mandelbulb_de(p - e.yxy).x,
        mandelbulb_de(p + e.yyx).x - mandelbulb_de(p - e.yyx).x
    ));
}

// Raymarched Soft Shadows
float calc_shadow(vec3 ro, vec3 rd, float mint, float tmax, float k) {
    float res = 1.0;
    float t = mint;
    for(int i = 0; i < 48; i++) {
        float h = mandelbulb_de(ro + rd * t).x;
        res = min(res, k * h / t);
        t += clamp(h, 0.02, 0.2);
        if(h < 0.001 || t > tmax) break;
    }
    return clamp(res, 0.0, 1.0);
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;
    
    vec3 ro = u_camPos;
    vec3 target = u_camTarget;
    vec3 ww = normalize(target - ro);
    vec3 uu = normalize(cross(ww, vec3(0, 1, 0)));
    vec3 vv = normalize(cross(uu, ww));
    vec3 rd = normalize(uv.x * uu + uv.y * vv + 1.2 * ww); // 1.2 is FOV

    float t = 0.0;
    float steps = 0.0;
    float trap_val = 0.0;
    bool hit = false;
    
    for (int i = 0; i < MAX_STEPS; i++) {
        vec2 result = mandelbulb_de(ro + rd * t);
        float d = result.x;
        trap_val = result.y;
        
        if (d < SURF_DIST) { hit = true; break; }
        t += d;
        steps += 1.0;
        if (t > MAX_DIST) break;
    }

    vec3 bg_color = vec3(0.02, 0.02, 0.04);
    vec3 color = bg_color;

    if (hit) {
        vec3 p = ro + rd * t;
        vec3 n = calc_normal(p);
        vec3 light_dir = normalize(vec3(1.2, 1.0, -1.0));
        
        // Lighting
        float diff = max(dot(n, light_dir), 0.0);
        float sky_diff = max(dot(n, vec3(0.0, 1.0, 0.0)), 0.0);
        
        // Shadows & AO
        float shadow = calc_shadow(p, light_dir, 0.02, 5.0, u_shadow_softness);
        float ao = clamp(1.0 - (steps / float(MAX_STEPS)), 0.0, 1.0);
        
        // Orbit Trap Coloring
        vec3 mat_color = get_palette(trap_val * 1.5 + length(p) * 0.2);
        
        // Combine
        vec3 ambient = vec3(0.05, 0.08, 0.1) * sky_diff;
        vec3 diffuse = mat_color * diff * shadow;
        color = (ambient + diffuse) * ao;

        // Specular highlight
        vec3 view_dir = normalize(ro - p);
        vec3 refl_dir = reflect(-light_dir, n);
        float spec = pow(max(dot(view_dir, refl_dir), 0.0), 32.0);
        color += vec3(0.8) * spec * shadow * ao;
    }

    // Distance Fog
    float fog_factor = 1.0 - exp(-u_fog_density * t * t);
    color = mix(color, bg_color, clamp(fog_factor, 0.0, 1.0));

    // Gamma correction
    outColor = vec4(pow(color, vec3(1.0/2.2)), 1.0);
}