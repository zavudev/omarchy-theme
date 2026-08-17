#version 440

// Zavu Strands — el shader del hero de zavu.dev, adaptado al dialecto de Qt 6.
//
// Fuente: apps/web/components/reactbits/Strands.tsx (const FRAG). El cuerpo es
// el mismo, evaluado en el estado de reposo del hero: sin pulso, sin fan, sin
// ratón y sin strand activo. Con esos valores fanT, pulseK y pulseMix son 0,
// así que el fragment se reduce a la envolvente "bundle" y al bucle de hebras.
//
// Los uniformes que V3Journey le pasa son constantes aquí — no hay nada que
// animar salvo el tiempo — y así el UBO se queda en lo mínimo.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;     // 0
    float qt_Opacity;    // 64
    float uTime;         // 68
    vec2  uResolution;   // 72
};

const float PI = 3.14159265;

// Uniformes del hero (V3Journey) + defaults del componente.
const int   COUNT      = 5;
const float SPEED      = 0.18;
const float AMPLITUDE  = 1.05;
const float WAVINESS   = 1.0;
const float THICKNESS  = 0.7;
const float GLOW       = 2.6;
const float TAPER      = 3.0;
const float SPREAD     = 1.0;
const float INTENSITY  = 0.6;
const float SATURATION = 1.5;
const float SCALE      = 1.5;
// uFanSpread. 0 = haz cerrado (el reposo del hero). El script tools/build-shaders
// sustituye este valor para generar cada variante viva desde este mismo fuente.
const float FAN        = 0.0; // {{FAN}}

// <Strands colors={JOURNEY_COLORS}> — un color por canal.
const vec3 C0 = vec3(0.0235, 0.7137, 0.8314); // #06B6D4
const vec3 C1 = vec3(0.9176, 0.7020, 0.0314); // #EAB308
const vec3 C2 = vec3(1.0000, 0.2588, 0.2588); // #FF4242
const vec3 C3 = vec3(0.0941, 0.4667, 0.9490); // #1877F2
const vec3 C4 = vec3(0.4863, 0.2275, 0.9294); // #7C3AED

vec3 paletteAt(int i) {
    if (i == 0) return C0;
    if (i == 1) return C1;
    if (i == 2) return C2;
    if (i == 3) return C3;
    return C4;
}

// samplePalette(): rampa cíclica entre los colores de uColors.
vec3 samplePalette(float t) {
    t = fract(t);
    float scaled = t * float(COUNT);
    int idx = int(floor(scaled));
    float blend = fract(scaled);
    int nextIdx = idx + 1;
    if (nextIdx >= COUNT) nextIdx = 0;
    return mix(paletteAt(idx), paletteAt(nextIdx), blend);
}

void main() {
    // qt_TexCoord0 tiene el origen arriba a la izquierda; GL lo tiene abajo.
    vec2 fc = vec2(qt_TexCoord0.x, 1.0 - qt_TexCoord0.y) * uResolution;

    vec2 uv = (fc - 0.5 * uResolution) / uResolution.y;
    uv /= max(SCALE, 0.0001);

    float e = 0.06 + INTENSITY * 0.94;
    float nx = (fc.x / uResolution.x) * 2.0 - 1.0;

    // env mezcla las dos envolventes en vez de conmutar en un umbral: el haz
    // tapered en ambos extremos, y el abanico que converge a la izquierda y
    // se abre a la derecha. Con FAN = 0, fanT = 0 y sólo queda el haz.
    float fanT = smoothstep(0.0, 0.05, FAN);
    float env = mix(
      pow(max(cos(uv.x * PI * 1.3), 0.0), TAPER),
      smoothstep(-1.0, -0.4, nx),
      fanT
    );
    float fanRamp = smoothstep(-0.9, 0.9, nx);

    vec3 col = vec3(0.0);

    for (int i = 0; i < COUNT; i++) {
        float fi = float(i);
        float ph = fi * 1.7 * SPREAD;
        float freq = (2.0 + fi * 0.35) * WAVINESS;
        float spd = 1.4 + fi * 1.2;

        float tt = uTime * SPEED;
        float w = sin(uv.x * freq + tt * spd + ph) * 0.60
                + sin(uv.x * freq * 1.1 - tt * spd * 0.7 + ph * 1.7) * 0.40;

        float amp = (0.1 + 0.02 * e) * env * AMPLITUDE;
        float y = w * amp;

        // Con el abanico abierto cada hebra acaba a una altura distinta.
        float target = mix(FAN, -FAN, fi / float(COUNT - 1));
        y += target * fanRamp;

        float d = abs(uv.y - y);
        float thick = (0.001 + 0.05 * e) * (0.35 + env) * THICKNESS;
        float g = thick / (d + thick * 0.45);
        g = g * g;

        // Abanico abierto: el tono se congela por hebra, así la hebra i
        // mantiene el color del canal i en vez de derivar con x y el tiempo.
        float h = mix(fi / float(COUNT) + uv.x * 0.30 + uTime * 0.04,
                      fi / float(COUNT), fanT);

        col += samplePalette(h) * g * env;
    }

    col *= 0.45 + 0.7 * e;

    // Apaga el brillo antes de los bordes para que el haz no parezca
    // recortado por el lienzo. Sólo aplica con el abanico abierto.
    {
      float ey = 0.5 / max(SCALE, 0.0001);
      float vy = 1.0 - smoothstep(ey * 0.78, ey, abs(uv.y));
      float vr = 1.0 - smoothstep(0.82, 1.06, nx);
      col *= mix(1.0, vy * vr, fanT);
    }

    col = 1.0 - exp(-col * GLOW);

    float gray = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = max(mix(vec3(gray), col, SATURATION), 0.0);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
