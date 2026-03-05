# WebGL-Mandelbulb

A real-time, interactive 3D Mandelbulb fractal renderer built entirely from scratch using WebGL2 and Raymarching (Sphere Tracing).

## Features

*   **Real-time Raymarching:** High-performance sphere tracing over a Signed Distance Field (SDF).
*   **Soft Shadows:** Raymarched contact shadows for realistic depth and lighting.
*   **Orbit Trap Coloring:** Dynamic, psychedelic color banding based on the fractal's internal iteration distance.
*   **Distance Fog:** Smooth fading into the deep-space background.
*   **Interactive Camera:** Orbit controls (drag to rotate) and zoom (scroll wheel).
*   **Live UI Controls:** Built with Tweakpane to adjust the fractal's Power, Iteration count, and colors in real-time.
*   **Zero Dependencies:** Just plain HTML, JS, and GLSL. (Uses Tweakpane via CDN for the UI).

## How to Run

Because this project loads external `.glsl` files via `fetch()`, you must run it through a local web server (opening the file directly via `file://` will cause CORS errors).

1. Clone the repository.
2. Start a local server:
   *   **Python 3:** `python3 -m http.server 8000`
   *   **Node.js:** `npx serve .`
3. Open `http://localhost:8000` in your browser.

## The Math

This renderer uses the **White and Nylander Power-8** formula to estimate the distance to the Mandelbulb surface:

$$z \mapsto z^n + c$$

Where $n$ is the "Power" parameter (adjustable in the UI) and $c$ is the constant position. The fractal is formed by converting Cartesian coordinates to spherical, applying the power, and converting back, iteratively until the length of $z$ escapes a defined bailout radius.

## License

MIT License - Feel free to use this code to learn raymarching or as a base for your own visual projects!
