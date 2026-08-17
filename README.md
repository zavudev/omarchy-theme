# Zavu

> One API. Every message.

Tema oscuro de Omarchy derivado de **Zavu Brand System V1.1**
(`zavu-brand.md`). Infraestructura de comunicación con precisión científica
y minimalismo editorial, aplicada al escritorio.

Bifurcado de [Last Horizon](https://github.com/HANCORE-linux/omarchy-lasthorizon-theme)
(MIT), recoloreado y regeometrizado por completo.

## Paleta

| Token | Hex | Nombre | Papel |
|---|---|---|---|
| `background` | `#000000` | Void Black | Sustrato del sistema |
| `foreground` | `#FFFFFF` | Pure White | Tipografía primaria |
| superficie | `#18181B` | Surface | Popups, menús, tarjetas |
| elevada | `#27272A` | Surface Elevated | Bordes hairline, hover |
| `muted` | `#A1A1AA` | Muted Gray | Metadatos, texto secundario |
| `accent` | `#615FFF` | Signal Violet | Foco, selección, estado activo |

Colores de sistema (§5.3, solo para comunicar estado):
`#4DF688` operativo · `#FFDA5E` atención · `#FF5E5E` fallo · `#6EFAFF` actividad

## Decisiones

- **Un solo acento.** El violeta aparece en el borde de la ventana enfocada,
  la fila seleccionada y el foco de los controles. En ningún otro sitio.
  El presupuesto es ~3% de la composición (§5.5).
- **Geometría editorial.** Esquinas rectas, borde de 1px, sin sombras ni
  bloom. Precisión de dibujo técnico, no de tarjeta SaaS.
- **Movimiento de instrumento.** Una sola curva, `cubic-bezier(0.22, 1,
  0.36, 1)` — la de `ZAVU.motion.defaultEasing`. Sin overshoot ni física de
  muelle, que el brand system prohíbe explícitamente (§8.3, §12).
- **Seis hues en la terminal.** La marca define cuatro colores de sistema
  más el acento; un resaltado de sintaxis necesita separarlos. El naranja
  (`#FF9C5E`) es la mezcla al 50% de `warning` y `error` — no hay ningún
  hue fuera de la familia.

## Fondos

Los dos primeros son el shader **Strands** que corre en el hero de
`zavu.dev` — `apps/web/components/reactbits/Strands.tsx`, montado por
`V3Journey`. `tools/strands.c` es un port CPU literal de su `FRAG`,
evaluado en el estado de reposo del hero (sin pulso, sin fan, sin ratón,
sin strand activo) con los uniformes que le pasa `V3Journey`:
`count=5 · scale=1.5 · amplitude=1.05 · glow=2.6 · speed=0.18`.

- `01-strands.png` — la paleta de canales del hero
  (`#06B6D4 #EAB308 #FF4242 #1877F2 #7C3AED`). Es lo que se ve en la web.
- `02-strands-signal.png` — misma geometría, un solo acento en la familia
  Signal Violet. Cumple la regla de un acento por composición (§5.5).
- `03-void.png` — negro puro. El vacío como sustrato.

### Cualquier resolución

El shader depende del aspecto, no sólo de la escala: `uv` se normaliza por
la altura y la envolvente `env` se mide sobre `uv.x`, así que estirar un
render de 16:9 a 21:9 no da la misma imagen que renderizarlo a 21:9.
Por eso se renderiza por resolución, no se escala:

```bash
tools/render 3440 1440              # paleta de canales
tools/render 2560 1600 signal       # paleta de marca
tools/render 3840 2160 channels mi-fondo.png
```

Hay un juego ya renderizado (16 resoluciones × 2 paletas, de 1366×768 a
5120×1440, incluyendo verticales) en `~/Pictures/zavu-wallpapers/`. Vive
fuera del tema a propósito: `omarchy theme set` copia el directorio del
tema entero en cada cambio.

## Instalación

```bash
omarchy theme install https://github.com/zavudev/omarchy-theme.git
omarchy theme set Zavu
```

## Licencia

MIT, heredada del tema base. La identidad de marca Zavu (logotipo, isotipo,
wordmark) no está cubierta por esa licencia.
