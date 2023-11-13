--- Configuration for Neovim ---

local vim_g = vim.g
local vim_o = vim.o
local vim_autocmd = vim.api.nvim_create_autocmd
local util = require "jet.confutil"
local usepkg = require "jet.usepkg"

usepkg.now("plenary", false) -- required by telescope

local is_gui = vim_g.neovide
local mod = nil -- temporary module variable
local tmp = nil -- temporary variable

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
----------| Editor UI and behaviours |-----------
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

--- options for specific options ---
vim_autocmd("TermOpen", {
  callback = function()
    local vim_wo = vim.wo
    vim_wo.number = false
    vim_wo.relativenumber = false
    vim_wo.cursorline = false
    vim_wo.colorcolumn = nil
    vim_wo.list = false
  end
})

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
    -- winblend = 10, -- enable when blurred background is available
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
util.set_keys("n", {
  "<leader>" .. "f",
  f = mod.find_files,
  g = mod.live_grep,
  s = mod.current_buffer_fuzzy_find,
  b = mod.buffers,
})
mod = nil

--- the "flash.nvim" plugin ---
mod = usepkg.now("flash", {
  jump = {
    nohlsearch = true,
  },
  modes = {
    char = { enabled = false },
  },
  highlight = { backdrop = false },
  prompt = { enabled = false },
})
util.set_keys({"n", "x", "o"}, {
  ["?"] = mod.jump,
  ["g?"] = mod.treesitter,
})
util.set_key("o", "r", mod.remote)
mod = nil

-------------------------------------------------
------------| Programming support |--------------
-------------------------------------------------

--- auto pair ---
usepkg.now("nvim-autopairs", {
  check_ts = true,
  fast_wrap = {
    map = "<M-'>",
    keys = "asdfghjkl",
    end_key = "'",
    before_key = ";",
    after_key = "'",
  },
})

--- comment/uncomment ---
usepkg.now("Comment", {
  toggler = { line = "z;;", block = "z::" },
  opleader = { line = "z;", block = "z:" },
  extra = { above = "z;O", below = "z;o", eol = "z;A" },
})

--- tree-sitter ---
usepkg.now("nvim-treesitter", false)
require("nvim-treesitter.configs").setup{
  parser_install_dir = util.add_path("treesitter_parsers", "data"),
  highlight = { enable = true },
  --incremental_selection = { enable = true },
  indent = { enable = true },
}

--- language server protocol ---
mod = usepkg.now("lspconfig", false)
tmp = {
  on_attach = function(_, bufnr)
    local vim_lsp_buf = vim.lsp.buf
    local util_set_keys = require("jet.confutil").set_keys
    local map_opts = { buffer = bufnr }
    util_set_keys("n", {
      "g",
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
util.set_keys("n", {
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

-------------------------------------------------
----------------| Extra tools |------------------
-------------------------------------------------

--- start up screen and the scratch buffer ---
vim_o.shortmess = vim_o.shortmess .. "I" -- disable the intro message
require("jet.scratch").setup({
  text = {"--- This buffer is NOT part of GNU Emacs. ---"},
})

--- Git integration ---
-- Git operation panel
usepkg.now("neogit", {
  filewatcher = { enabled = false },
  signs = {
    section = { "⮚", "⮛" },
    item = { "", "" },
    hunk = { "", "" },
  },
})
-- Git signs for buffers
usepkg.now("gitsigns", {
  watch_gitdir = { enable = false },
  attach_to_untracked = false,
  update_debounce = 600,
  max_file_length = 10000,
})
