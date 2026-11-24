-- Nord overlay para el nvim del Core, sin editar el árbol vendorizado.
-- Se carga desde ~/.local/share/nvim/site/after/plugin, después de los plugins,
-- así que sustituye el colorscheme Everforest que aplica gerrrt.plugins.theme.

local palette = require("gerrrt.utils.palette")

local n = {
	nord0 = "#2e3440", -- base / bg
	nord1 = "#3b4252", -- superficie 1
	nord2 = "#434c5e", -- superficie 2
	nord3 = "#4c566a", -- superficie 3 / borde / comentario
	nord4 = "#d8dee9", -- texto
	nord5 = "#e5e9f0", -- texto intenso
	nord6 = "#eceff4", -- texto máximo
	nord7 = "#8fbcbb", -- teal
	nord8 = "#88c0d0", -- acento cyan
	nord9 = "#81a1c1", -- azul
	nord10 = "#5e81ac", -- azul oscuro
	nord11 = "#bf616a", -- rojo
	nord12 = "#d08770", -- naranja
	nord13 = "#ebcb8b", -- amarillo
	nord14 = "#a3be8c", -- verde
	nord15 = "#b48ead", -- morado
}

-- Mismos nombres de clave que expone palette.colors(): lualine, bufferline,
-- cheatsheet, fzf-lua y ui-highlights siguen funcionando sin cambios.
local nord_colors = {
	bg = n.nord0,
	bg_dark = n.nord0,
	bg_highlight = n.nord1,
	bg_visual = n.nord2,
	terminal_black = n.nord3,
	fg = n.nord5,
	fg_dark = n.nord4,
	fg_gutter = n.nord3,
	comment = n.nord3,
	border = n.nord3,
	border_highlight = n.nord8,
	red = n.nord11,
	green = n.nord14,
	blue = n.nord9,
	yellow = n.nord13,
	orange = n.nord12,
	purple = n.nord15,
	magenta = n.nord15,
	teal = n.nord7,
	cyan = n.nord8,
	bg0 = n.nord0,
	bg1 = n.nord1,
	bg2 = n.nord2,
	bg3 = n.nord3,
	bg4 = n.nord3,
	bg5 = n.nord3,
	aqua = n.nord8,
	grey0 = n.nord3,
	grey1 = n.nord9,
	grey2 = n.nord4,
}

local original_colors = palette.colors
palette.colors = function()
	return vim.tbl_deep_extend("force", original_colors(), nord_colors)
end
-- palette.nvchad() llama a M.colors() internamente, así que también sigue a Nord.

local hl = {
	Normal = { fg = n.nord4, bg = n.nord0 },
	NormalNC = { fg = n.nord4, bg = n.nord0 },
	Comment = { fg = n.nord3, italic = true },
	Constant = { fg = n.nord15 },
	String = { fg = n.nord14 },
	Number = { fg = n.nord15 },
	Boolean = { fg = n.nord15 },
	Float = { fg = n.nord15 },
	Identifier = { fg = n.nord4 },
	Function = { fg = n.nord9 },
	Keyword = { fg = n.nord9 },
	Statement = { fg = n.nord9 },
	Conditional = { fg = n.nord9 },
	Repeat = { fg = n.nord9 },
	Operator = { fg = n.nord8 },
	Exception = { fg = n.nord11 },
	PreProc = { fg = n.nord13 },
	Include = { fg = n.nord10 },
	Type = { fg = n.nord7 },
	StorageClass = { fg = n.nord13 },
	Structure = { fg = n.nord7 },
	Typedef = { fg = n.nord7 },
	Special = { fg = n.nord8 },
	SpecialChar = { fg = n.nord12 },
	Tag = { fg = n.nord8 },
	Delimiter = { fg = n.nord4 },
	Todo = { fg = n.nord13, bold = true },
	Error = { fg = n.nord11, bold = true },
	ErrorMsg = { fg = n.nord11, bold = true },
	WarningMsg = { fg = n.nord12, bold = true },
	MoreMsg = { fg = n.nord8, bold = true },
	ModeMsg = { fg = n.nord4, bold = true },
	Question = { fg = n.nord14 },
	Search = { fg = n.nord0, bg = n.nord8 },
	IncSearch = { fg = n.nord0, bg = n.nord14 },
	Visual = { bg = n.nord2 },
	VisualNOS = { bg = n.nord2 },
	LineNr = { fg = n.nord3 },
	CursorLineNr = { fg = n.nord8, bold = true },
	CursorLine = { bg = n.nord1 },
	CursorColumn = { bg = n.nord1 },
	ColorColumn = { bg = n.nord1 },
	SignColumn = { bg = n.nord0 },
	FoldColumn = { fg = n.nord3, bg = n.nord0 },
	Folded = { fg = n.nord3, bg = n.nord1 },
	WinSeparator = { fg = n.nord3 },
	VertSplit = { fg = n.nord3 },
	StatusLine = { fg = n.nord4, bg = n.nord1 },
	StatusLineNC = { fg = n.nord3, bg = n.nord0 },
	TabLine = { fg = n.nord3, bg = n.nord0 },
	TabLineFill = { bg = n.nord0 },
	TabLineSel = { fg = n.nord0, bg = n.nord8, bold = true },
	Pmenu = { fg = n.nord4, bg = n.nord1 },
	PmenuSel = { fg = n.nord0, bg = n.nord8 },
	PmenuSbar = { bg = n.nord1 },
	PmenuThumb = { bg = n.nord2 },
	NormalFloat = { fg = n.nord4, bg = n.nord0 },
	FloatBorder = { fg = n.nord3, bg = n.nord0 },
	DiagnosticError = { fg = n.nord11 },
	DiagnosticWarn = { fg = n.nord12 },
	DiagnosticInfo = { fg = n.nord9 },
	DiagnosticHint = { fg = n.nord7 },
	DiffAdd = { bg = n.nord1 },
	DiffChange = { bg = n.nord2 },
	DiffDelete = { fg = n.nord11, bg = n.nord1 },
	DiffText = { bg = n.nord3 },
}

local function apply()
	for group, spec in pairs(hl) do
		vim.api.nvim_set_hl(0, group, spec)
	end
end

apply()
vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("NordLocal", { clear = true }),
	callback = apply,
})

vim.opt.background = "dark"
vim.g.colors_name = "nord"

-- El plugin del Core registra un ColorScheme para repintar ui-highlights;
-- volver a dispararlo hace que use la paleta ya parcheada.
vim.cmd("doautocmd ColorScheme")
