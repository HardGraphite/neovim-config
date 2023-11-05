--- Configuration for Neovim on Neovide ---
--- see: https://neovide.dev/configuration.html

local vim_g = vim.g
local vim_o = vim.o

vim_o.guifont = "JetBrainsMono Nerd Font Mono:mono:Symbols Nerd Font Mono:h15"
-- If the font size is unreasonable on X11,
-- consider setting the environment variable `WINIT_X11_SCALE_FACTOR` to 1.

vim_g.neovide_scroll_animation_length = 0.5
vim_g.neovide_hide_mouse_when_typing = true

vim_g.neovide_remember_window_size = false
vim_g.neovide_remember_window_position = false

vim_g.neovide_cursor_animation_length = 0.05
vim_g.neovide_cursor_trail_size = 0.5
vim_g.neovide_cursor_antialiasing = false
vim_g.neovide_cursor_animate_command_line = false
