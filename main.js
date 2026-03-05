const canvas = document.getElementById('glCanvas');
const gl = canvas.getContext('webgl2');

if (!gl) {
    document.body.innerHTML = "<h2 style='color:white; text-align:center; margin-top:20vh;'>WebGL2 not supported.</h2>";
} else {
    // Tweakpane UI Setup
    const PARAMS = {
        power: 8.0,
        iterations: 10,
        autoRotate: true,
        shadowSoftness: 16.0,
        fogDensity: 0.02,
        colorA: {r: 1.0, g: 1.0, b: 1.0},
        colorB: {r: 0.0, g: 0.33, b: 0.67},
    };

    const pane = new Tweakpane.Pane({ container: document.getElementById('ui-container') });
    pane.addInput(PARAMS, 'power', { min: 2.0, max: 16.0, step: 0.1 });
    pane.addInput(PARAMS, 'iterations', { min: 2, max: 20, step: 1 });
    pane.addInput(PARAMS, 'autoRotate');
    
    const renderFolder = pane.addFolder({ title: 'Rendering' });
    renderFolder.addInput(PARAMS, 'shadowSoftness', { min: 2.0, max: 64.0 });
    renderFolder.addInput(PARAMS, 'fogDensity', { min: 0.0, max: 0.1, step: 0.001 });
    
    const colorFolder = pane.addFolder({ title: 'Colors' });
    colorFolder.addInput(PARAMS, 'colorA', {color: {type: 'float'}});
    colorFolder.addInput(PARAMS, 'colorB', {color: {type: 'float'}});

    async function init() {
        // Fetch shaders
        const [vsSource, fsSource] = await Promise.all([
            fetch('vertex.glsl').then(r => r.text()),
            fetch('fragment.glsl').then(r => r.text())
        ]);
        
        function createShader(gl, type, source) {
            const s = gl.createShader(type);
            gl.shaderSource(s, source);
            gl.compileShader(s);
            if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
                console.error(gl.getShaderInfoLog(s));
            }
            return s;
        }

        const program = gl.createProgram();
        gl.attachShader(program, createShader(gl, gl.VERTEX_SHADER, vsSource));
        gl.attachShader(program, createShader(gl, gl.FRAGMENT_SHADER, fsSource));
        gl.linkProgram(program);
        gl.useProgram(program);

        const buffer = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1,-1, 1,-1, -1,1, -1,1, 1,-1, 1,1]), gl.STATIC_DRAW);
        const posLoc = gl.getAttribLocation(program, "position");
        gl.enableVertexAttribArray(posLoc);
        gl.vertexAttribPointer(posLoc, 2, gl.FLOAT, false, 0, 0);

        // Uniform Locations
        const locs = {
            res: gl.getUniformLocation(program, "u_resolution"),
            camPos: gl.getUniformLocation(program, "u_camPos"),
            camTarget: gl.getUniformLocation(program, "u_camTarget"),
            time: gl.getUniformLocation(program, "u_time"),
            power: gl.getUniformLocation(program, "u_power"),
            maxIter: gl.getUniformLocation(program, "u_max_iter"),
            shadows: gl.getUniformLocation(program, "u_shadow_softness"),
            fog: gl.getUniformLocation(program, "u_fog_density"),
            colA: gl.getUniformLocation(program, "u_color_a"),
            colB: gl.getUniformLocation(program, "u_color_b")
        };

        // Camera State
        let yaw = 0.5, pitch = 0.3, distance = 2.8;
        let isDragging = false;
        let lastX = 0, lastY = 0;
        let startTime = Date.now();

        function render() {
            const width = window.innerWidth;
            const height = window.innerHeight;
            if (canvas.width !== width || canvas.height !== height) {
                canvas.width = width; canvas.height = height;
                gl.viewport(0, 0, width, height);
            }

            if (PARAMS.autoRotate && !isDragging) yaw += 0.003;

            const cx = distance * Math.cos(yaw) * Math.cos(pitch);
            const cy = distance * Math.sin(pitch);
            const cz = distance * Math.sin(yaw) * Math.cos(pitch);

            // Update Uniforms
            gl.uniform2f(locs.res, width, height);
            gl.uniform3f(locs.camPos, cx, cy, cz);
            gl.uniform3f(locs.camTarget, 0, 0, 0);
            gl.uniform1f(locs.time, (Date.now() - startTime) * 0.001);
            
            gl.uniform1f(locs.power, PARAMS.power);
            gl.uniform1f(locs.maxIter, PARAMS.iterations);
            gl.uniform1f(locs.shadows, PARAMS.shadowSoftness);
            gl.uniform1f(locs.fog, PARAMS.fogDensity);
            gl.uniform3f(locs.colA, PARAMS.colorA.r, PARAMS.colorA.g, PARAMS.colorA.b);
            gl.uniform3f(locs.colB, PARAMS.colorB.r, PARAMS.colorB.g, PARAMS.colorB.b);

            gl.drawArrays(gl.TRIANGLES, 0, 6);
            requestAnimationFrame(render);
        }

        // Input
        window.addEventListener('mousedown', e => { 
            if(e.target.tagName !== 'CANVAS') return; // Ignore clicks on UI
            isDragging = true; lastX = e.clientX; lastY = e.clientY; 
        });
        window.addEventListener('mouseup', () => isDragging = false);
        window.addEventListener('mousemove', e => {
            if (!isDragging) return;
            yaw += (e.clientX - lastX) * 0.01;
            pitch += (e.clientY - lastY) * 0.01;
            pitch = Math.max(-Math.PI/2 + 0.1, Math.min(Math.PI/2 - 0.1, pitch));
            lastX = e.clientX; lastY = e.clientY;
        });
        window.addEventListener('wheel', e => {
            distance += e.deltaY * 0.002;
            distance = Math.max(1.0, Math.min(10.0, distance));
            e.preventDefault();
        }, { passive: false });

        requestAnimationFrame(render);
    }

    init();
}