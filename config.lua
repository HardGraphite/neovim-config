--- Configuration for Neovim ---

local vim_g = vim.g
local vim_o = vim.o
local vim_autocmd = vim.api.nvim_create_autocmd
local util = require "jet.confutil"
local usepkg = require "jet.usepkg"

usepkg.now("plenary", false) -- required by neogit, telescope

local use_icons = vim_g.neovide
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

--- icon characters ---
usepkg.now("nvim-web-devicons")

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
usepkg.when({ au = "UIEnter" }, "ibl") -- indent guide

--- status line ---
usepkg.now("lualine", {
  options = {
    theme = "onedark",
    section_separators = use_icons and { left = '', right = '' } or "",
    component_separators = use_icons and { left = '', right = '' } or "",
    always_divide_middle = false,
    globalstatus = true,
    refresh = { statusline = 10000, tabline = 10000, winbar = 10000 },
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = { { "location", padding = { left = 1 }, separator = "" }, "progress" },
    lualine_c = { "filename" },
    lualine_x = { "diff", "branch" },
    lualine_y = { "diagnostics", "filetype" },
    lualine_z = { },
  }
})
-- HACK: modify mode display names
do
  -- See: lualine/utils/mode.lua
  local trans_map = {
    ["NORMAL"] = "N", ["O-PENDING"] = "N+",
    ["INSERT"] = "I",
    ["VISUAL"] = "V", ["V-LINE"] = "V=", ["V-BLOCK"] = "V#",
    ["SELECT"] = "S", ["S-LINE"] = "S=", ["S-BLOCK"] = "S#",
    ["REPLACE"] = "R", ["V-REPLACE"] = "R*",
    ["COMMAND"] = "C", ["EX"] = "C>",
    ["TERMINAL"] = "T",
    -- ["SHELL"] = "$",
    -- ["MORE"] = "M",
    -- ["CONFIRM"] = "?",
  }
  local mode_map = require("lualine.utils.mode").map
  for k, v in pairs(mode_map) do
    local r = trans_map[v]
    if r then
      mode_map[k] = r
    end
  end
  -- See: lualine/highlight.lua: get_mode_suffix()
  local mode_to_highlight = {
    ["I"] = "_insert",
    ["V"] = "_visual", ["V="] = "_visual", ["V#"] = "_visual",
    ["S"] = "_visual", ["S="] = "_visual", ["S#"] = "_visual",
    ["R"] = "_replace", ["R*"] = "_replace",
    ["C"] = "_command", ["C>"] = "_command",
    ["T"] = "_terminal",
    ["MORE"] = "_command", ["CONFIRM"] = "_command",
  }
  local highlight = require("lualine.highlight")
  function highlight.get_mode_suffix()
    return mode_to_highlight[mode_map[vim.api.nvim_get_mode().mode]] or "_normal"
  end
end

--- records and backups ---
vim_o.history = 64
vim_o.backup = false
vim_o.undofile = false
vim_o.swapfile = false
vim_o.shadafile = vim.fn.stdpath("run") .. "/nvim.shada" -- temporary shada file

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
usepkg.when({ au = "UIEnter" }, "telescope", {
  defaults = {
    sorting_strategy = "ascending",
    --winblend = 10, -- enable when blurred background is available
    prompt_prefix = use_icons and " " --[[ nf-fa-search, U+F002 ]] or "» ",
    selection_caret = "☞ ",
    multi_icon = "✓",
    path_display = { "truncate" },
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
        ["<M-Esc>"] = "close",
      },
    },
    history = false,
  },
  pickers = {
    buffers = {
      --sort_lastused = true,
      sort_mru = true,
    },
    find_files = {
      find_command = { "fd", "--type", "f", "--color", "never" }, -- telescope/builtin/__files.lua
    },
  },
}, function()
  local builtin = require("telescope.builtin")
  util.set_keys("n", {
    "<leader>" .. "f",
    f = builtin.find_files,
    F = builtin.oldfiles,
    g = builtin.live_grep,
    s = builtin.current_buffer_fuzzy_find,
    b = builtin.buffers,
    m = builtin.marks,
    r = builtin.registers,
    q = builtin.quickfix,
    Q = builtin.quickfixhistory,
    l = builtin.loclist,
    j = builtin.jumplist,
  })
end)

--- the "flash.nvim" plugin ---
usepkg.when({ au = "UIEnter" }, "flash", {
  jump = {
    nohlsearch = true,
  },
  modes = {
    char = { enabled = false },
  },
  highlight = { backdrop = false },
  prompt = { enabled = false },
}, function(_, mod)
  util.set_keys({"n", "x", "o"}, {
    ["?"] = mod.jump,
    ["g?"] = mod.treesitter,
  })
  util.set_key("o", "r", mod.remote)
end)

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

--- TODO highlighting ---
usepkg.now("todo-comments", {
  merge_keywords = false,
  keywords = {
    TODO = { icon = "", color = "info" },
    FIXME = { icon = "", color = "error" },
    HACK = { icon = "", signs = false, color = "warning" },
    NOTE = { icon = "", color = "hint", alt = { "INFO" } },
  },
  gui_style = { fg = "bold,underline" },
  highlight = {
    keyword = "fg",
    after = "",
  },
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
vim.lsp.set_log_level("OFF") -- disable LSP logging
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
usepkg.when({ au = "UIEnter" }, "luasnip", false)
-- HACK: inhibit luasnip.log (see |luasnip-logging|)
assert(package.loaded["luasnip.util.log"] == nil)
package.loaded["luasnip.util.log"] = setmetatable({}, {
  __index = function(self, key)
    if key == "new" then
      return function(_) return self end
    else
      return function(...) end
    end
  end
})

--- completion ---
usepkg.when({ au = "UIEnter" }, "cmp", false, function(_, cmp)
  local mapping = cmp.mapping
  -- Constants.
  local cmp_kind_icon_map = {
    Text = "",
    Method = "",
    Function = "󰡱",
    Constructor = "",
    Field = "",
    Variable = "",
    Class = "",
    Interface = "",
    Module = "",
    Property = "󰑭",
    Unit = "",
    Value = "󰎠",
    Enum = "",
    Keyword = "",
    Snippet = "",
    Color = "",
    File = "",
    Reference = "󰈇",
    Folder = "",
    EnumMember = "",
    Constant = "",
    Struct = "",
    Event = "",
    Operator = "",
    TypeParameter = "",
  }
  -- Do setup.
  cmp.setup{
    completion = {
      completeopt = "menu,menuone",
    },
    snippet = {
      expand = function(arg)
        require("luasnip").lsp_expand(arg.body)
      end,
    },
    mapping = {
      ["<up>"] = mapping.select_prev_item(),
      ["<down>"] = mapping.select_next_item(),
      ["<S-tab>"] = mapping.select_prev_item(),
      ["<tab>"] = mapping.select_next_item(),
      ["<M-k>"] = mapping.select_prev_item(),
      ["<M-j>"] = mapping.select_next_item(),
      ["<M-K>"] = mapping.scroll_docs(-5),
      ["<M-J>"] = mapping.scroll_docs(5),
      ["<cr>"] = mapping.confirm(),
      ["<M-esc>"] = mapping.abort(),
    },
    formatting = {
      format = function(_, vim_item)
        vim_item.kind = cmp_kind_icon_map[vim_item.kind] or ""
        return vim_item
      end
    },
    sources = {
      { name = "nvim_lsp" },
      { name = "luasnip" },
    },
  }
  -- Add parentheses for functions.
  cmp.event:on(
    "confirm_done",
    require("nvim-autopairs.completion.cmp").on_confirm_done()
  )
end)

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
usepkg.when({ cmd = "Neogit" }, "neogit", {
  filewatcher = { enabled = false },
  remember_settings = false,
  use_per_project_settings = false,
  signs = {
    section = { "⮚", "⮛" },
    item = { "", "" },
    hunk = { "", "" },
  },
})
-- Git signs for buffers
usepkg.when({ au = "UIEnter" }, "gitsigns", {
  watch_gitdir = { enable = false },
  attach_to_untracked = false,
  update_debounce = 600,
  max_file_length = 10000,
})
