----- Read configuration file -----

local M = {}

---Read file contents.
---@param file string
---@param split_lines? boolean
---@return string|table|nil
function M.read_file(file, split_lines)
  local ok, lines = pcall(vim.fn.readfile, file)
  if not ok then
    return nil
  end
  if split_lines then
    return lines
  else
    return table.concat(lines, "\n")
  end
end

---Read configuration from file.
---@param file string
---@return table|nil
function M.read_conf(file)
  local lines = M.read_file(file, true)
  if not lines then
    return nil
  end
  local anon_section = {}
  local section = anon_section
  local config = {} -- { SECTION_NAME = DATA , ... }
  for _, line in ipairs(lines) do
    if line == "" then -- empty line
      goto continue -- ignore
    end
    local first_char = line:sub(1, 1)
    if first_char == "#" then -- comment line
      goto continue -- ignore
    end
    if first_char == "[" and line:sub(#line) == "]" then -- section head
      section = {}
      config[line:sub(2, #line - 1)] = section
    else -- ``KEY = VALUE``
      local pos0, pos1 = line:find("%s*=%s*")
      if pos0 then
        section[line:sub(1, pos0 - 1)] = line:sub(pos1 + 1)
      else
        section[line] = ""
      end
    end
    ::continue::
  end
  if next(anon_section) then
    config[""] = anon_section
  end
  return config
end

setmetatable(M, { __call = function(m, f) return m.read_conf(f) end })
return M
