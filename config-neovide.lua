--- Configuration for Neovim on Neovide ---
--- see: https://neovide.dev/configuration.html

-- Notes:
--
-- 1. If the font size is weird on X11, try setting the environment variable
-- `WINIT_X11_SCALE_FACTOR` to `1`.
--
-- 2. Run Neovide with option `--multigrid` to enabled Neovim's multigrid
-- functionality, so that floating window blurred backgrounds, smooth scrolling,
-- and window animations are available.

local vim_g = vim.g
local vim_o = vim.o
local usepkg = require "jet.usepkg"

--- font ---
vim_o.guifont = "JetBrainsMono NF:mono:Symbols Nerd Font Mono:h15"

--- title ---
vim_o.title = true
vim_o.titlestring = "%f %m – Neovim"

--- basic behaviors ---
vim_g.neovide_hide_mouse_when_typing = true
--vim_g.neovide_remember_window_size = false
vim_g.neovide_remember_window_position = false

--- scroll animations ---
vim_g.neovide_scroll_animation_length = 0.2
vim_g.neovide_scroll_animation_far_lines = 10

--- cursor animations ---
vim_g.neovide_cursor_animation_length = 0.03
vim_g.neovide_cursor_trail_size = 0.38
vim_g.neovide_cursor_antialiasing = false
vim_g.neovide_cursor_animate_command_line = false

--- floating window: blurred backgrounds ---
--- Note: multigrid required!!!
--vim_g.neovide_floating_blur_amount_x = 2
--vim_g.neovide_floating_blur_amount_y = 2
vim_o.pumblend = 30
vim_o.winblend = 30
--require("telescope.config").values.winblend = 40
usepkg.options("telescope", { defaults = { winblend = 40 } })

--- floating window: shadow ---
vim_g.neovide_floating_z_height = 6
