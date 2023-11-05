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

--- marks and rulers ---
vim_o.hlsearch = true
vim_o.cursorline = true
vim_o.colorcolumn = 80
vim_o.list = true
vim_o.listchars = "tab:▸ ,trail:·"
vim_o.showcmd = false
vim_o.showmode = false

--- status line ---
usepkg.now("lualine", {
  options = {
    theme = "onedark",
    section_separators = is_gui and { left = '', right = '' } or "",
    component_separators = is_gui and { left = '', right = '' } or "",
    globalstatus = true,
  }
})


-------------------------------------------------
--------------| Editor behaviour |---------------
-------------------------------------------------

--- records and backups ---
vim_o.history = 64
vim_o.backup = false
vim_o.undofile = false
vim_o.swapfile = false

--- file formats ---
vim_o.fileformats = "unix"
vim_o.encoding = "utf-8"

--- text display ---
vim_o.wrap = true
vim_o.scrolloff = 5

--- indentations ---
vim_o.autoindent = true
vim_o.smartindent = true
vim_o.tabstop = 8
vim_o.softtabstop = 4
vim_o.shiftwidth = 4
vim_o.expandtab = true

--- search ---
vim_o.incsearch = true
vim_o.smartcase = true
vim_o.ignorecase = true
