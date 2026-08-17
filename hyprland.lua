-- Zavu — geometría y movimiento.
--
-- Registro editorial estricto (zavu-brand.md §8): esquinas rectas, borde
-- hairline de 1px, sin sombras. Signal Violet marca la ventana enfocada y
-- nada más; todo lo demás vive en la escala de grises de marca.
--
-- Movimiento: "calm, mechanical, instrument-like — not bouncy, not playful"
-- (§8.3). Una sola curva, la de marca (ZAVU.motion.defaultEasing), sin
-- overshoot y sin física de muelle.

local signal = "rgba(615fffff)"
local border = "rgba(27272aff)"

hl.config({
  general = {
    col = {
      active_border = signal,
      inactive_border = border,
    },
    gaps_in = 5,
    gaps_out = 10,
    border_size = 1,
  },
  group = {
    col = {
      border_active = signal,
      border_inactive = border,
    },
  },
  decoration = {
    -- Precisión científica: sin radio, sin sombra, sin bloom.
    rounding = 0,
    shadow = {
      enabled = false,
    },
  },
  animations = {
    enabled = true,
  },
})

-- ZAVU.motion.defaultEasing — cubic-bezier(0.22, 1, 0.36, 1).
hl.curve("zavuStandard", { type = "bezier", points = { { 0.22, 1.00 }, { 0.36, 1.00 } } })
-- Salida: acelera y desaparece. Sin rebote de vuelta.
hl.curve("zavuAccel", { type = "bezier", points = { { 0.40, 0.00 }, { 1.00, 1.00 } } })

-- Ventanas: disolución, no salto. El 97% deja el gesto casi imperceptible.
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, bezier = "zavuStandard", style = "popin 97%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "zavuAccel", style = "popin 97%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "zavuStandard" })

-- El borde es la señal: se mueve despacio para que el cambio de foco se lea.
hl.animation({ leaf = "border", enabled = true, speed = 8, bezier = "zavuStandard" })

-- Capas (barra, menús, notificaciones): fundidos limpios.
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "zavuStandard", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 3, bezier = "zavuAccel", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 3, bezier = "zavuStandard" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 3, bezier = "zavuAccel" })

-- Workspaces: barrido lateral, mecánico y constante.
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "zavuStandard", style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 4, bezier = "zavuStandard", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 3, bezier = "zavuAccel", style = "slidevert" })
