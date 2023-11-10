local vim_g = vim.g
local vim_o = vim.o
local vim_keymap_set = vim.keymap.set
local usepkg = require "jet.usepkg"

usepkg.now("plenary", false) -- required by telescope

local is_gui = vim.g.neovide
local mod = nil -- temporary module variable
local tmp = nil -- temporary variable

local function keymap_set_keys(mode, key_prefix, keys_and_funcs, opts)
  for k, f in pairs(keys_and_funcs) do
    vim_keymap_set("n", key_prefix .. k, f, opts)
  end
end

local function add_to_rtp(path, stdpath_base_dir)
  if stdpath_base_dir then
    path = vim.fn.stdpath(stdpath_base_dir) .. '/' .. path
  end
  vim.opt.rtp:append(path)
  return path
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

-------------------------------------------------
------------| Programming support |--------------
-------------------------------------------------

--- tree-sitter ---
usepkg.now("nvim-treesitter", false)
require("nvim-treesitter.configs").setup{
  parser_install_dir = add_to_rtp("treesitter_parsers", "data"),
  highlight = { enable = true },
  --incremental_selection = { enable = true },
}

--- language server protocol ---
mod = usepkg.now("lspconfig", false)
tmp = {
  on_attach = function(_, bufnr)
    local vim_lsp_buf = vim.lsp.buf
    local map_opts = { buffer = bufnr }
    keymap_set_keys("n", "g", {
      d = vim_lsp_buf.definition,
      D = vim_lsp_buf.declaration,
      h = vim_lsp_buf.hover,
      i = vim_lsp_buf.implementation,
      r = vim_lsp_buf.references,
    }, map_opts)
    vim.opt.signcolumn = "yes"
  end,
  capabilities = usepkg.now("cmp_nvim_lsp").default_capabilities(),
}
for _, x in ipairs{
  "clangd", -- C/C++
  "pyright", -- Python
  "cmake", -- CMake
  "lua_ls", -- Lua
  "texlab", -- LaTeX
} do
  mod[x].setup(tmp)
end
tmp = nil
mod = vim.diagnostic
keymap_set_keys("n", "", {
  ["[e"] = mod.goto_prev,
  ["]e"] = mod.goto_next,
  ["<cr>e"] = mod.open_float,
  ["\\e"] = mod.setloclist,
})
mod = nil

--- code snippets ---
usepkg.now("luasnip", false)

--- completion ---
mod = usepkg.now("cmp", false)
mod.setup{
  completion = {
    completeopt = "menu,menuone",
  },
  snippet = {
    expand = function(arg)
      require("luasnip").lsp_expand(arg.body)
    end,
  },
  mapping = {
    ["<up>"] = mod.mapping.select_prev_item(),
    ["<down>"] = mod.mapping.select_next_item(),
    ["<M-k>"] = mod.mapping.select_prev_item(),
    ["<M-j>"] = mod.mapping.select_next_item(),
    ["<M-K>"] = mod.mapping.scroll_docs(-5),
    ["<M-J>"] = mod.mapping.scroll_docs(5),
    ["<cr>"] = mod.mapping.confirm(),
    ["<tab>"] = mod.mapping.complete_common_string(),
    ["<M-esc>"] = mod.mapping.abort(),
  },
  sources = {
    { name = "nvim_lsp" },
    { name = "luasnip" },
  },
}
mod = nil
