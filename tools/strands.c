/*
 * Port CPU del shader Strands de Zavu.
 * Fuente: apps/web/components/reactbits/Strands.tsx (const FRAG).
 *
 * Port literal del fragment completo: mismas constantes, mismo orden de
 * operaciones, mismo tonemap. A diferencia del hero — que sólo llega al estado
 * de reposo y a lo que el scroll y el clic disparan — aquí cualquier uniforme
 * se fija por línea de comandos, así que se pueden congelar estados que en la
 * web sólo existen durante unas décimas: el abanico abierto, el pulso violeta
 * a mitad de recorrido, una hebra destacada.
 *
 * El único uniforme que no se expone es el ratón: no tiene sentido en un
 * fondo fijo, así que uMouseStrength se queda en 0 y sus dos términos salen
 * de la ecuación.
 *
 * Salida: PPM binario (P6) a stdout. Sobre fondo negro el canvas se compone
 * premultiplicado, así que el color visible es exactamente col*opacity.
 *
 *   gcc -O2 -o strands strands.c -lm
 *   ./strands 3440 1440 --time 43
 *   ./strands 3440 1440 --fan 0.22 --active 2
 */
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_STRANDS 12
#define MAX_COLORS 8
#define PI 3.14159265358979323846

typedef struct { double r, g, b; } vec3;

/* Defaults del componente, con los del hero (V3Journey) ya aplicados. */
static int    u_count        = 5;
static double u_time         = 43.0;
static double u_speed        = 0.18;
static double u_amplitude    = 1.05;
static double u_waviness     = 1.0;
static double u_thickness    = 0.7;
static double u_glow         = 2.6;
static double u_taper        = 3.0;
static double u_spread       = 1.0;
static double u_hue_shift    = 0.0;
static double u_intensity    = 0.6;
static double u_saturation   = 1.5;
static double u_opacity      = 1.0;
static double u_scale        = 1.5;
static double u_fan_spread   = 0.0;
static double u_pulse        = -1.0;   /* negativo = en reposo */
static double u_pulse_spread = 0.075;
static int    u_active       = -1;
static double u_focus        = 1.0;
static vec3   u_pulse_color  = { 0.3804, 0.3725, 1.0 }; /* #615FFF */

static vec3 palette[MAX_COLORS];
static int  palette_n = 0;

static double clampd(double v, double lo, double hi) {
  return v < lo ? lo : (v > hi ? hi : v);
}

static double mixd(double a, double b, double t) { return a + (b - a) * t; }

static double smoothstepd(double e0, double e1, double x) {
  double t = clampd((x - e0) / (e1 - e0), 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

static vec3 hex_to_vec3(const char *s) {
  while (*s == ' ' || *s == '#') s++;
  unsigned int v = (unsigned int)strtoul(s, NULL, 16);
  vec3 c = { ((v >> 16) & 0xFF) / 255.0, ((v >> 8) & 0xFF) / 255.0, (v & 0xFF) / 255.0 };
  return c;
}

/* samplePalette(): rampa cíclica entre los colores de uColors. */
static vec3 sample_palette(double t) {
  t = t - floor(t);
  double scaled = t * (double)palette_n;
  int idx = (int)floor(scaled);
  double blend = scaled - floor(scaled);
  if (idx >= palette_n) idx = palette_n - 1;
  int next = (idx + 1 >= palette_n) ? 0 : idx + 1;
  vec3 a = palette[idx], b = palette[next];
  vec3 o = { mixd(a.r, b.r, blend), mixd(a.g, b.g, blend), mixd(a.b, b.b, blend) };
  return o;
}

static void parse_palette(const char *spec) {
  char buf[512];
  strncpy(buf, spec, sizeof(buf) - 1);
  buf[sizeof(buf) - 1] = 0;
  palette_n = 0;
  for (char *tok = strtok(buf, ","); tok && palette_n < MAX_COLORS; tok = strtok(NULL, ",")) {
    palette[palette_n++] = hex_to_vec3(tok);
  }
}

int main(int argc, char **argv) {
  if (argc < 3) {
    fprintf(stderr,
      "uso: strands W H [opciones]\n"
      "  --time T           reloj del shader (default 43)\n"
      "  --palette \"#a,#b\"  colores de las hebras\n"
      "  --count N          n.º de hebras (default 5)\n"
      "  --fan F            uFanSpread: abre el abanico (0 = haz cerrado)\n"
      "  --pulse P          0..1 dentro del pulso de clic; <0 = en reposo\n"
      "  --pulse-spread S   cuánto separa el pulso (default 0.075)\n"
      "  --pulse-color #hex color al que colapsa el haz (default #615FFF)\n"
      "  --active I         hebra destacada; -1 = ninguna\n"
      "  --focus F          0..1, fuerza del destacado (default 1)\n"
      "  --glow G  --scale S  --amplitude A  --saturation S  --speed S\n");
    return 1;
  }
  int W = atoi(argv[1]);
  int H = atoi(argv[2]);
  parse_palette("#06B6D4,#EAB308,#FF4242,#1877F2,#7C3AED");

  for (int i = 3; i < argc - 1; i++) {
    const char *k = argv[i], *v = argv[i + 1];
    if      (!strcmp(k, "--time"))         { u_time = atof(v); i++; }
    else if (!strcmp(k, "--palette"))      { parse_palette(v); i++; }
    else if (!strcmp(k, "--count"))        { u_count = atoi(v); i++; }
    else if (!strcmp(k, "--fan"))          { u_fan_spread = atof(v); i++; }
    else if (!strcmp(k, "--pulse"))        { u_pulse = atof(v); i++; }
    else if (!strcmp(k, "--pulse-spread")) { u_pulse_spread = atof(v); i++; }
    else if (!strcmp(k, "--pulse-color"))  { u_pulse_color = hex_to_vec3(v); i++; }
    else if (!strcmp(k, "--active"))       { u_active = atoi(v); i++; }
    else if (!strcmp(k, "--focus"))        { u_focus = atof(v); i++; }
    else if (!strcmp(k, "--glow"))         { u_glow = atof(v); i++; }
    else if (!strcmp(k, "--scale"))        { u_scale = atof(v); i++; }
    else if (!strcmp(k, "--amplitude"))    { u_amplitude = atof(v); i++; }
    else if (!strcmp(k, "--saturation"))   { u_saturation = atof(v); i++; }
    else if (!strcmp(k, "--speed"))        { u_speed = atof(v); i++; }
  }
  if (u_count > MAX_STRANDS) u_count = MAX_STRANDS;

  double e = 0.06 + u_intensity * 0.94;
  double tt = u_time * u_speed;
  double scale = u_scale > 1e-4 ? u_scale : 1e-4;

  /* Envolvente del pulso: abre rápido, sostiene, cierra despacio. */
  double fan_pulse = (u_pulse >= 0.0)
    ? smoothstepd(0.0, 0.20, u_pulse) * (1.0 - smoothstepd(0.60, 1.0, u_pulse)) * u_pulse_spread
    : 0.0;
  double fan_amt = u_fan_spread + fan_pulse;
  double pulse_k = u_pulse_spread > 0.0001 ? clampd(fan_pulse / u_pulse_spread, 0.0, 1.0) : 0.0;
  double fan_t = smoothstepd(0.0, 0.05, fan_amt);
  double pulse_mix = (u_pulse >= 0.0)
    ? smoothstepd(0.0, 0.14, u_pulse) * (1.0 - smoothstepd(0.62, 1.0, u_pulse))
    : 0.0;

  /* Todo lo que sólo depende de x se calcula una vez. */
  double *env = malloc(sizeof(double) * W);
  double *thickx = malloc(sizeof(double) * W);
  double *vign = malloc(sizeof(double) * W);
  double *ylines = malloc(sizeof(double) * W * u_count);
  double *gmul = malloc(sizeof(double) * W * u_count);
  vec3   *scols = malloc(sizeof(vec3) * W * u_count);
  if (!env || !thickx || !vign || !ylines || !gmul || !scols) return 1;

  for (int x = 0; x < W; x++) {
    double fx = (double)x + 0.5;
    double uvx = ((fx - 0.5 * W) / (double)H) / scale;
    double nx = (fx / (double)W) * 2.0 - 1.0;

    /* env mezcla las dos envolventes: haz tapered vs abanico que converge
       a la izquierda y se abre a la derecha. */
    double c = cos(uvx * PI * 1.3);
    if (c < 0.0) c = 0.0;
    double bundle = pow(c, u_taper);
    double fan = smoothstepd(-1.0, -0.4, nx);
    env[x] = mixd(bundle, fan, fan_t);

    double fan_ramp = smoothstepd(-0.9, 0.9, nx);
    double amp = (0.1 + 0.02 * e) * env[x] * u_amplitude * mixd(1.0, 0.60, pulse_k);
    thickx[x] = (0.001 + 0.05 * e) * (0.35 + env[x]) * u_thickness * mixd(1.0, 0.20, pulse_k);

    /* El viñeteado sólo entra con el abanico abierto: evita que el haz
       parezca recortado por el borde del lienzo. */
    double vr = 1.0 - smoothstepd(0.82, 1.06, nx);
    vign[x] = vr;

    for (int i = 0; i < u_count; i++) {
      double fi = (double)i;
      double ph = fi * 1.7 * u_spread;
      double freq = (2.0 + fi * 0.35) * u_waviness;
      double spd = 1.4 + fi * 1.2;
      double w = sin(uvx * freq + tt * spd + ph) * 0.60
               + sin(uvx * freq * 1.1 - tt * spd * 0.7 + ph * 1.7) * 0.40;
      double y = w * amp;

      /* Con el abanico abierto cada hebra acaba a una altura distinta. */
      double target = (u_count > 1) ? mixd(fan_amt, -fan_amt, fi / (double)(u_count - 1)) : 0.0;
      y += target * fan_ramp;
      ylines[i * W + x] = y;

      /* Bead: una cuenta de luz recorriendo la hebra, retrasada por hebra
         para que el frente se lea como una ola y no como una barra. */
      double m = 1.0;
      if (u_pulse >= 0.0) {
        double pp = clampd(u_pulse * 1.25 - fi * 0.05, 0.0, 1.0);
        double pd = nx - mixd(-1.05, 1.05, pp);
        double bead = exp(-pd * pd * 70.0);
        m = 1.0 + bead * sin(pp * PI) * 1.15;
      }
      gmul[i * W + x] = m;

      /* Con el abanico abierto el tono se congela por hebra: la hebra i
         mantiene el color del canal i en vez de derivar con x y el tiempo. */
      double h = mixd(fi / (double)u_count + uvx * 0.30 + u_time * 0.04 + u_hue_shift,
                      fi / (double)u_count, fan_t);
      scols[i * W + x] = sample_palette(h);
    }
  }

  printf("P6\n%d %d\n255\n", W, H);
  unsigned char *row = malloc(3 * W);
  double ey = 0.5 / scale;

  for (int y = 0; y < H; y++) {
    double fy = (double)(H - 1 - y) + 0.5;   /* GL mira hacia arriba */
    double uvy = ((fy - 0.5 * H) / (double)H) / scale;
    double vy = 1.0 - smoothstepd(ey * 0.78, ey, fabs(uvy));

    for (int x = 0; x < W; x++) {
      vec3 col = { 0.0, 0.0, 0.0 };

      for (int i = 0; i < u_count; i++) {
        double d = fabs(uvy - ylines[i * W + x]);
        double th = thickx[x];
        double g = th / (d + th * 0.45);
        g = g * g;
        g *= gmul[i * W + x];

        double emph = 1.0;
        if (u_active >= 0) emph = (i == u_active) ? mixd(1.0, 1.6, u_focus) : mixd(1.0, 0.18, u_focus);

        double k = g * env[x] * emph;
        vec3 sc = scols[i * W + x];
        col.r += sc.r * k; col.g += sc.g * k; col.b += sc.b * k;
      }

      double m = (0.45 + 0.7 * e) * mixd(1.0, 0.82, pulse_k);
      col.r *= m; col.g *= m; col.b *= m;

      double v = mixd(1.0, vy * vign[x], fan_t);
      col.r *= v; col.g *= v; col.b *= v;

      col.r = 1.0 - exp(-col.r * u_glow);
      col.g = 1.0 - exp(-col.g * u_glow);
      col.b = 1.0 - exp(-col.b * u_glow);

      /* El colapso al acento va DESPUÉS del tonemap: antes, el núcleo ya
         está saturado a blanco y teñirlo sólo pintaría los bordes. */
      if (pulse_mix > 0.0) {
        double plum = fmax(fmax(col.r, col.g), col.b);
        col.r = mixd(col.r, u_pulse_color.r * plum, pulse_mix);
        col.g = mixd(col.g, u_pulse_color.g * plum, pulse_mix);
        col.b = mixd(col.b, u_pulse_color.b * plum, pulse_mix);
      }

      double gray = col.r * 0.2126 + col.g * 0.7152 + col.b * 0.0722;
      col.r = fmax(mixd(gray, col.r, u_saturation), 0.0);
      col.g = fmax(mixd(gray, col.g, u_saturation), 0.0);
      col.b = fmax(mixd(gray, col.b, u_saturation), 0.0);

      row[x * 3 + 0] = (unsigned char)(clampd(col.r * u_opacity, 0.0, 1.0) * 255.0 + 0.5);
      row[x * 3 + 1] = (unsigned char)(clampd(col.g * u_opacity, 0.0, 1.0) * 255.0 + 0.5);
      row[x * 3 + 2] = (unsigned char)(clampd(col.b * u_opacity, 0.0, 1.0) * 255.0 + 0.5);
    }
    fwrite(row, 1, 3 * W, stdout);
  }
  return 0;
}
