local project = require("jet.project")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local configs = require("telescope.config").values
local builtin = require("telescope.builtin")
local actions = require("telescope.actions")
local action_state = require "telescope.actions.state"

local function _action_get_proj()
  local entry = action_state.get_selected_entry()
  if entry then
    return entry[1]
  end
end

local ext_actions = {
  find_files = function()
    local proj = _action_get_proj()
    if proj then
      builtin.find_files{cwd = proj}
    end
  end,
  live_grep = function()
    local proj = _action_get_proj()
    if proj then
      builtin.live_grep{cwd = proj}
    end
  end,
  delete = function(prompt_bufnr)
    local proj = _action_get_proj()
    if proj then
      project.delete(proj)
      actions.close(prompt_bufnr)
    end
  end,
}

local ext_mappings

local function setup(opts)
  ext_mappings = opts.mappings
  if ext_mappings then
    for _, defs in pairs(ext_mappings) do
      for key, func in pairs(defs) do
        if type(func) == "string" then
          defs[key] = ext_actions[func]
        end
      end
    end
  end
end

local function pick_proj(opts)
  pickers.new(opts, {
    prompt_title = "Projects",
    previewer = false,
    finder = finders.new_table{
      results = project.list(),
    },
    sorter = configs.file_sorter(opts),
    attach_mappings = function(_, map)
      if ext_mappings then
        for mode, defs in pairs(ext_mappings) do
          for key, func in pairs(defs) do
            map(mode, key, func)
          end
        end
      end
      return true
    end,
  }):find()
end

return require("telescope").register_extension {
  setup = setup,
  exports = { project = pick_proj },
}
