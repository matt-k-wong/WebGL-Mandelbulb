@group(0) @binding(0) var output_tex: texture_storage_2d<rgba8unorm, write>;

// 1. Distance Estimator (DE): White and Nylander power-8 formula
fn mandelbulb_de(pos: vec3<f32>) -> f32 {
    var z: vec3<f32> = pos;
    var dr: f32 = 1.0;
    var r: f32 = 0.0;
    
    // Mathematical constraint: Power-8 Mandelbulb
    const POWER: f32 = 8.0; 
    const BAILOUT: f32 = 2.0;
    const MAX_ITER: u32 = 15u;
    
    for (var i: u32 = 0u; i < MAX_ITER; i++) {
        r = length(z);
        
        // Escape condition: Hubbard-Douady potential threshold
        if (r > BAILOUT) { break; } 
        if (r < 1e-6) { break; } // Prevent division by zero
        
        // Convert Cartesian coordinates to spherical coordinates
        // Clamp applied to acos domain to prevent NaN from floating point drift
        var theta: f32 = acos(clamp(z.z / r, -1.0, 1.0)); 
        var phi: f32 = atan2(z.y, z.x);
        
        // Scale the derivative for accurate distance estimation
        // Constraint: dz' = n * z^(n-1) * dz + 1
        dr = pow(r, POWER - 1.0) * POWER * dr + 1.0;
        
        // Apply the exponent to the spherical coordinates
        let zr: f32 = pow(r, POWER);
        theta = theta * POWER;
        phi = phi * POWER;
        
        // Convert back to Cartesian coordinates and add the positional constant
        z = zr * vec3<f32>(
            sin(theta) * cos(phi), 
            sin(theta) * sin(phi), 
            cos(theta)
        );
        z += pos;
    }
    
    // Distance estimation using the continuous potential formulation: 0.5 * ln(r) * r / |dz|
    return 0.5 * log(r) * r / dr;
}

// 3. Normal Calculation: Finite difference method on DE gradient
fn calc_normal(p: vec3<f32>) -> vec3<f32> {
    const EPSILON: vec2<f32> = vec2<f32>(0.001, 0.0);
    
    // Compute surface normals dynamically by sampling the gradient of the DE
    let n: vec3<f32> = vec3<f32>(
        mandelbulb_de(p + EPSILON.xyy) - mandelbulb_de(p - EPSILON.xyy),
        mandelbulb_de(p + EPSILON.yxy) - mandelbulb_de(p - EPSILON.yxy),
        mandelbulb_de(p + EPSILON.yyx) - mandelbulb_de(p - EPSILON.yyx)
    );
    return normalize(n);
}

@compute @workgroup_size(16, 16, 1)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let dimensions = textureDimensions(output_tex);
    if (global_id.x >= dimensions.x || global_id.y >= dimensions.y) {
        return;
    }

    let res = vec2<f32>(f32(dimensions.x), f32(dimensions.y));
    let coord = vec2<f32>(f32(global_id.x), f32(global_id.y));
    
    // UV mapped screen coordinate, centered and aspect-corrected
    let uv = (coord - 0.5 * res) / res.y;

    // Shoot rays from a virtual camera setup
    let ro = vec3<f32>(0.0, 0.0, -2.5); // Ray origin (camera position)
    // Flip Y to match standard Cartesian coordinates (Y goes up)
    let rd = normalize(vec3<f32>(uv.x, -uv.y, 1.0)); // Ray direction (looking down +Z)

    // 2. Raymarching Loop setup
    const MAX_STEPS: u32 = 128u; // Strict maximum iteration count
    const MAX_DIST: f32 = 10.0; // Distance boundary
    const SURF_DIST: f32 = 0.001; // Minimum distance threshold (epsilon) for surface intersection

    var t: f32 = 0.0;
    var steps: f32 = 0.0;
    var hit: bool = false;

    // Sphere tracing loop
    for (var i: u32 = 0u; i < MAX_STEPS; i++) {
        let p = ro + rd * t;
        let d = mandelbulb_de(p);
        
        // Ray intersects the surface bounding volume
        if (d < SURF_DIST) {
            hit = true;
            break;
        }
        
        t += d; // Advance ray safely
        steps += 1.0;
        
        // Ray has escaped the scene bounds
        if (t > MAX_DIST) {
            break;
        }
    }

    var final_color = vec3<f32>(0.02, 0.02, 0.05); // Background void color

    if (hit) {
        let p = ro + rd * t;
        let normal = calc_normal(p);

        // 4. Lighting Calculation
        let light_dir = normalize(vec3<f32>(1.0, 1.0, -1.0)); // Single directional light source
        let view_dir = normalize(ro - p);
        
        // Phong reflection direction
        let refl_dir = reflect(-light_dir, normal);

        // Basic Phong shading components
        let ambient = vec3<f32>(0.1, 0.1, 0.15);
        
        let diff_factor = max(dot(normal, light_dir), 0.0);
        let diffuse = vec3<f32>(0.8, 0.7, 0.6) * diff_factor;
        
        let spec_factor = pow(max(dot(view_dir, refl_dir), 0.0), 32.0);
        let specular = vec3<f32>(1.0, 1.0, 1.0) * spec_factor;

        // Ambient occlusion approximated by the raymarching step count
        // Fewer steps = exposed surface (bright), many steps = deep crevices (dark)
        let ao = clamp(1.0 - (steps / f32(MAX_STEPS)), 0.0, 1.0);
        
        // Composite the illumination model
        final_color = (ambient + diffuse + specular) * ao;
    }

    // Gamma correction (sRGB mapping)
    final_color = pow(final_color, vec3<f32>(1.0 / 2.2));

    // Write final pixel to full-screen quad texture storage
    textureStore(output_tex, global_id.xy, vec4<f32>(final_color, 1.0));
}
