----- Neovim configuration utilities -----

local M = {}

---Add a new key mapping.
---@type function
M.set_key = vim.keymap.set

---Add new key mappings.
---@param modes string|string[] mode short name(s)
---@param defs table key-cmd pair(s); optional element `defs[1]` is the prefix keys
---@param opts? table keymap options
function M.set_keys(modes, defs, opts)
  -- Set keys in multiple modes.
  if type(modes) == "table" then
    local do_set_keys = M.set_keys
    for _, m in ipairs(modes) do
      do_set_keys(m, defs, opts)
    end
    return
  end
  -- Handle prefix keys.
  local key_prefix = defs[1]
  if key_prefix then
    defs[1] = nil
  end
  -- Set keys.
  local do_set_key = M.set_key
  for k, c in pairs(defs) do
    if key_prefix then
      k = key_prefix .. k
    end
    do_set_key(modes, k, c, opts)
  end
end

---Add a path to the rtp (runtime paths).
---@param path string the path to add
---@param stdpath_prefix? string use an stdpath as the prefix
---@return string path the added path
function M.add_path(path, stdpath_prefix)
  if stdpath_prefix then
    path = vim.fn.stdpath(stdpath_prefix) .. "/" .. path
  end
  vim.opt.rtp:append(path)
  return path
end

return M
