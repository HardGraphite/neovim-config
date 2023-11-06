local vim_g = vim.g
local vim_o = vim.o
local vim_keymap_set = vim.keymap.set
local usepkg = require "jet.usepkg"

usepkg.now("plenary", false) -- required by telescope

local is_gui = vim.g.neovide
local mod = nil -- temporary module variable

local function keymap_set_keys(mode, key_prefix, keys_and_funcs, opts)
  for k, f in pairs(keys_and_funcs) do
    vim_keymap_set("n", key_prefix .. k, f, opts)
  end
end

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
vim_o.colorcolumn = "80" -- must be a string!
vim_o.list = true
vim_o.listchars = "tab:▸ ,trail:·"
vim_o.showcmd = false
vim_o.showmode = false
usepkg.now("ibl")

--- status line ---
usepkg.now("lualine", {
  options = {
    theme = "onedark",
    section_separators = is_gui and { left = '', right = '' } or "",
    component_separators = is_gui and { left = '', right = '' } or "",
    globalstatus = true,
  }
})

--- startup screen ---
vim_o.shortmess = vim_o.shortmess .. "I" -- disable the intro message

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

-------------------------------------------------
----------------| Key bindings |-----------------
-------------------------------------------------

vim_g.mapleader = " "

-------------------------------------------------
----------| Search, list, and jump |-------------
-------------------------------------------------

--- the "telescope" plugin ---
usepkg.now("telescope", {
  defaults = {
    sorting_strategy = "ascending",
    winblend = 10,
    prompt_prefix = "» ",
    selection_caret = "☞ ",
    preview = {
      filesize_limit = 1,
      highlight_limit = 0.1,
      msg_bg_fillchar = "▚",
    },
    mappings = {
      n = {
        ["<M-?>"] = "which_key",
      },
      i = {
        ["<M-j>"] = "move_selection_next",
        ["<M-k>"] = "move_selection_previous",
        ["<M-u>"] = "preview_scrolling_up",
        ["<M-d>"] = "preview_scrolling_down",
        ["<M-?>"] = "which_key",
      },
    },
  },
})
mod = require("telescope.builtin")
keymap_set_keys("n", "<leader>" .. "f", {
  f = mod.find_files,
  g = mod.live_grep,
  s = mod.current_buffer_fuzzy_find,
  b = mod.buffers,
})
mod = nil

