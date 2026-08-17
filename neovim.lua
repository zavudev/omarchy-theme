-- Zavu — Neovim (aether.nvim).
--
-- Fondo Void Black sin transparencia: el vacío es el sustrato, no un hueco.
-- Los hues son los colores de sistema de la marca; Signal Violet es el acento
-- y marca cursor, selección y número de línea activa.

return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      transparent = false,
      colors = {
        bg         = "#000000",
        dark_bg    = "#000000",
        darker_bg  = "#000000",
        lighter_bg = "#18181B",

        fg         = "#FFFFFF",
        dark_fg    = "#52525B",
        light_fg   = "#E4E4E7",
        bright_fg  = "#FFFFFF",
        muted      = "#A1A1AA",

        red        = "#FF5E5E",
        orange     = "#FF9C5E",
        yellow     = "#FFDA5E",
        green      = "#4DF688",
        cyan       = "#6EFAFF",
        blue       = "#615FFF",
        magenta    = "#A5A3FF",
        purple     = "#A5A3FF",
        brown      = "#52525B",

        bright_red     = "#FF8181",
        bright_yellow  = "#FFE281",
        bright_green   = "#74F8A2",
        bright_cyan    = "#8EFBFF",
        bright_blue    = "#8482FF",
        bright_purple  = "#B9B7FF",
        bright_magenta = "#B9B7FF",

        accent               = "#615FFF",
        cursor               = "#615FFF",
        foreground           = "#FFFFFF",
        background           = "#000000",
        selection            = "#27272A",
        selection_foreground = "#FFFFFF",
        selection_background = "#615FFF",
      },
      on_highlights = function(hl, c)
        -- Superficies elevadas, no manchas de color.
        hl.CursorLine = { bg = c.lighter_bg }
        hl.CursorLineNr = { fg = c.blue, bold = true }
        hl.ColorColumn = { bg = c.lighter_bg }

        -- La selección es señal: violeta con texto blanco encima.
        hl.Visual = { bg = c.selection_background, fg = c.selection_foreground }
        hl.Search = { bg = c.selection, fg = c.bright_fg }
        hl.IncSearch = { bg = c.blue, fg = c.bright_fg }

        -- Separadores hairline, como el resto del sistema.
        hl.WinSeparator = { fg = "#27272A" }
        hl.VertSplit = { fg = "#27272A" }
        hl.FloatBorder = { fg = "#27272A", bg = c.lighter_bg }
        hl.NormalFloat = { bg = c.lighter_bg }

        -- Comentarios en el gris más apagado de la escala, nunca en cursiva.
        hl.Comment = { fg = c.dark_fg, italic = false }

        hl.LspReferenceText = { bg = c.selection, fg = c.bright_fg }
        hl.LspReferenceRead = hl.LspReferenceText
        hl.LspReferenceWrite = hl.LspReferenceText

        hl.SnacksPickerDir         = { fg = c.muted }
        hl.SnacksPickerPathHidden  = { fg = c.muted }
        hl.SnacksPickerPathIgnored = { fg = c.muted }
        hl.SnacksPickerListCursorLine = { bg = c.lighter_bg }
      end,
    },
    config = function(_, opts)
      require("aether").setup(opts)
      vim.cmd.colorscheme("aether")
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
