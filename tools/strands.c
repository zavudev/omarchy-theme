/*
 * Port CPU del shader Strands de Zavu.
 * Fuente: apps/web/components/reactbits/Strands.tsx (const FRAG).
 *
 * Evalúa el shader en el estado de reposo del hero de la home:
 *   uPulse < 0 (sin pulso), uFanSpread = 0, uActive = -1, uMouseStrength = 0.
 * Con esos valores fanT = 0, pulseK = 0, pulseMix = 0 y el viñeteado (que va
 * mezclado por fanT) desaparece, así que el fragment se reduce a la envolvente
 * "bundle" más el bucle de strands. Todo lo demás es literal: mismas
 * constantes, mismo orden de operaciones, mismo tonemap.
 *
 * Uniformes del hero (V3Journey): count=5, scale=1.5, amplitude=1.05,
 * glow=2.6, speed=0.18; el resto son los defaults del componente.
 *
 * Salida: PPM binario (P6) a stdout. Sobre fondo negro el canvas se compone
 * premultiplicado, así que el color visible es exactamente col*opacity.
 *
 *   gcc -O2 -o strands strands.c -lm
 *   ./strands W H TIME "#RRGGBB,#RRGGBB,..." > out.ppm
 */
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_STRANDS 12
#define MAX_COLORS 8
#define PI 3.14159265358979323846

typedef struct { double r, g, b; } vec3;

/* Uniformes: los defaults del componente, sobreescritos por los del hero. */
static int   u_count      = 5;
static double u_speed     = 0.18;
static double u_amplitude = 1.05;
static double u_waviness  = 1.0;
static double u_thickness = 0.7;
static double u_glow      = 2.6;
static double u_taper     = 3.0;
static double u_spread    = 1.0;
static double u_hue_shift = 0.0;
static double u_intensity = 0.6;
static double u_saturation= 1.5;
static double u_opacity   = 1.0;
static double u_scale     = 1.5;

static vec3 palette[MAX_COLORS];
static int  palette_n = 0;

static double clampd(double v, double lo, double hi) {
  return v < lo ? lo : (v > hi ? hi : v);
}

/* mix(colors[idx], colors[next], fract) sobre una rampa cíclica. */
static vec3 sample_palette(double t) {
  t = t - floor(t);
  double scaled = t * (double)palette_n;
  int idx = (int)floor(scaled);
  double blend = scaled - floor(scaled);
  if (idx >= palette_n) idx = palette_n - 1;
  int next = (idx + 1 >= palette_n) ? 0 : idx + 1;
  vec3 a = palette[idx], b = palette[next];
  vec3 o = { a.r + (b.r - a.r) * blend,
             a.g + (b.g - a.g) * blend,
             a.b + (b.b - a.b) * blend };
  return o;
}

static void parse_palette(const char *spec) {
  char buf[512];
  strncpy(buf, spec, sizeof(buf) - 1);
  buf[sizeof(buf) - 1] = 0;
  for (char *tok = strtok(buf, ","); tok && palette_n < MAX_COLORS; tok = strtok(NULL, ",")) {
    while (*tok == ' ' || *tok == '#') tok++;
    unsigned int v = (unsigned int)strtoul(tok, NULL, 16);
    palette[palette_n].r = ((v >> 16) & 0xFF) / 255.0;
    palette[palette_n].g = ((v >> 8) & 0xFF) / 255.0;
    palette[palette_n].b = (v & 0xFF) / 255.0;
    palette_n++;
  }
}

int main(int argc, char **argv) {
  if (argc < 5) {
    fprintf(stderr, "uso: strands W H TIME \"#RRGGBB,...\" [count]\n");
    return 1;
  }
  int W = atoi(argv[1]);
  int H = atoi(argv[2]);
  double time = atof(argv[3]);
  parse_palette(argv[4]);
  if (argc > 5) u_count = atoi(argv[5]);
  if (u_count > MAX_STRANDS) u_count = MAX_STRANDS;

  double e = 0.06 + u_intensity * 0.94;
  double tt = time * u_speed;

  /* Precalcular todo lo que sólo depende de x. */
  double *env    = malloc(sizeof(double) * W);
  double *thickx = malloc(sizeof(double) * W);
  double *ampx   = malloc(sizeof(double) * W);
  double *ylines = malloc(sizeof(double) * W * u_count);
  vec3   *scols  = malloc(sizeof(vec3)   * W * u_count);
  if (!env || !thickx || !ampx || !ylines || !scols) return 1;

  for (int x = 0; x < W; x++) {
    double fx = (double)x + 0.5;                       /* gl_FragCoord.x */
    double uvx = ((fx - 0.5 * W) / (double)H) / (u_scale > 1e-4 ? u_scale : 1e-4);

    /* env: envolvente bundle, cos^taper — se estrecha en ambos extremos. */
    double c = cos(uvx * PI * 1.3);
    if (c < 0.0) c = 0.0;
    env[x] = pow(c, u_taper);

    ampx[x]   = (0.1 + 0.02 * e) * env[x] * u_amplitude;
    thickx[x] = (0.001 + 0.05 * e) * (0.35 + env[x]) * u_thickness;

    for (int i = 0; i < u_count; i++) {
      double fi = (double)i;
      double ph = fi * 1.7 * u_spread;
      double freq = (2.0 + fi * 0.35) * u_waviness;
      double spd = 1.4 + fi * 1.2;
      double w = sin(uvx * freq + tt * spd + ph) * 0.60
               + sin(uvx * freq * 1.1 - tt * spd * 0.7 + ph * 1.7) * 0.40;
      ylines[i * W + x] = w * ampx[x];

      double h = fi / (double)u_count + uvx * 0.30 + time * 0.04 + u_hue_shift;
      scols[i * W + x] = sample_palette(h);
    }
  }

  printf("P6\n%d %d\n255\n", W, H);
  unsigned char *row = malloc(3 * W);

  for (int y = 0; y < H; y++) {
    /* La fila 0 de la imagen es la última del framebuffer: GL mira hacia arriba. */
    double fy = (double)(H - 1 - y) + 0.5;
    double uvy = ((fy - 0.5 * H) / (double)H) / (u_scale > 1e-4 ? u_scale : 1e-4);

    for (int x = 0; x < W; x++) {
      vec3 col = { 0.0, 0.0, 0.0 };

      for (int i = 0; i < u_count; i++) {
        double d = fabs(uvy - ylines[i * W + x]);
        double th = thickx[x];
        double g = th / (d + th * 0.45);
        g = g * g;
        double k = g * env[x];
        vec3 sc = scols[i * W + x];
        col.r += sc.r * k;
        col.g += sc.g * k;
        col.b += sc.b * k;
      }

      double m = 0.45 + 0.7 * e;
      col.r *= m; col.g *= m; col.b *= m;

      /* Tonemap: 1 - exp(-col * glow). */
      col.r = 1.0 - exp(-col.r * u_glow);
      col.g = 1.0 - exp(-col.g * u_glow);
      col.b = 1.0 - exp(-col.b * u_glow);

      /* Saturación alrededor de la luma, con clamp a 0 como en el shader. */
      double gray = col.r * 0.2126 + col.g * 0.7152 + col.b * 0.0722;
      col.r = fmax(gray + (col.r - gray) * u_saturation, 0.0);
      col.g = fmax(gray + (col.g - gray) * u_saturation, 0.0);
      col.b = fmax(gray + (col.b - gray) * u_saturation, 0.0);

      row[x * 3 + 0] = (unsigned char)(clampd(col.r * u_opacity, 0.0, 1.0) * 255.0 + 0.5);
      row[x * 3 + 1] = (unsigned char)(clampd(col.g * u_opacity, 0.0, 1.0) * 255.0 + 0.5);
      row[x * 3 + 2] = (unsigned char)(clampd(col.b * u_opacity, 0.0, 1.0) * 255.0 + 0.5);
    }
    fwrite(row, 1, 3 * W, stdout);
  }
  return 0;
}
