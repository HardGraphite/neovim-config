local vim_o = vim.o
local usepkg = require "jet.usepkg"

local is_gui = vim.g.neovide

-------------------------------------------------
---------------| Theme and color |---------------
-------------------------------------------------

--- color scheme ---
usepkg.now("onedark", {
  toggle_style_list = nil,
  lualine = { transparent = true },
  ending_tildes = true,
}).load()

-------------------------------------------------
------------| Editor UI components |-------------
-------------------------------------------------

--- line number ---
vim_o.number = true
vim_o.relativenumber = true

--- status line ---
usepkg.now("lualine", {
  options = {
    theme = "onedark",
    section_separators = is_gui and { left = '', right = '' } or "",
    component_separators = is_gui and { left = '', right = '' } or "",
    globalstatus = true,
  }
})
