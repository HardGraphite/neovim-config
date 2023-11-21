--- Project management ---

-- AutoCmd User/ProjEnter : after project opened; `data` = project dir
-- AutoCmd User/ProjLeave : before project closed;  `data` = project dir

local M = {}

---@class ProjectType
---@field name string
---@field has_file? string|string[]

---@class ProjectInfo
---@field type ProjectType
---@field root string
---@field bufs integer[]

M.config = {
  ---@type ProjectType[]
  project_types = {},
  ---@type string
  project_list_file = vim.fn.stdpath("data") .. "/projects",
}

--
--- Internal implementations
--

local _path_sep = jit.os == "Windows" and "\\" or "/"

local function _path_is_parent(a, b)
  local n = #a
  if string.sub(b, 1, n) ~= a then
    return false
  end
  local n_p1 = n + 1
  return string.sub(b, n_p1, n_p1) == _path_sep
end

--- Open projects.
---@type table<string,ProjectInfo>
local projects = {}

--- List of known projects.
---@type table<string,string> { ROOT = TYPE, ... }
local _proj_list = {}

local function proj_list_reload()
  local fd = vim.loop.fs_open(M.config.project_list_file, "r", 0)
  if fd == nil then
    return false
  end
  local data = vim.loop.fs_read(fd, 0xffffffff, 0)
  vim.loop.fs_close(fd)
  _proj_list = vim.tbl_extend("force", _proj_list, vim.json.decode(data))
  return true
end

--- Iterator for `proj_root, proj_type_name`.
local function proj_list_iter()
  return pairs(_proj_list)
end

---@param root_dir string
---@return string? proj_type_name
---@return string? proj_dir
local function proj_list_find(root_dir)
  local type_name = _proj_list[root_dir]
  if type_name then
    return type_name, root_dir
  end
end

---@param proj_dir string
---@param proj_type ProjectType|nil
local function proj_list_set(proj_dir, proj_type)
  proj_list_reload()
  if proj_type == nil then
    _proj_list[proj_dir] = nil
  else
    _proj_list[proj_dir] = proj_type.name
  end
  local data = vim.json.encode(_proj_list)
  local fd = vim.loop.fs_open(M.config.project_list_file, "w", 420--[[644]])
  if fd == nil then
    error("[project] cannot write to " .. M.config.project_list_file)
  end
  vim.loop.fs_write(fd, data, 0)
  vim.loop.fs_close(fd)
end

---@param dir string
---@return ProjectType|nil
local function proj_type_of(dir)
  local fs_stat = vim.loop.fs_stat
  for _, pt in pairs(M.config.project_types) do
    local has_file = pt.has_file
    if has_file then
      if type(has_file) ~= "table" then
        has_file = { has_file }
      end
      for _, f in ipairs(has_file) do
        if fs_stat(dir .. _path_sep .. f) then
          return pt
        end
      end
    end
  end
  return nil -- not a project root
end

---@param dir string
---@param proj_type? ProjectType
---@return string
---@return ProjectType
local function add_proj(dir, proj_type)
  local proj_dir = vim.loop.fs_realpath(dir)
  if type(proj_dir) ~= "string" then
    error("[project] path does not exist: " .. dir)
  end
  if not proj_type then
    proj_type = proj_type_of(proj_dir) or
      error("[project] not a project: " .. proj_dir)
  end
  proj_list_set(proj_dir, proj_type)
  return proj_dir, proj_type
end

---@param dir string
---@return boolean
local function del_proj(dir)
  local proj_dir = vim.loop.fs_realpath(dir)
  if type(proj_dir) ~= "string" then
    return false
  end
  proj_list_set(proj_dir, nil)
  return true
end

---@param proj_dir string
---@return ProjectInfo proj
local function proj_open(proj_dir)
  local proj = projects[proj_dir]
  if proj then
    return proj
  end
  local proj_type
  local proj_type_name = proj_list_find(proj_dir)
  if proj_type_name == nil then -- new project --
    proj_dir, proj_type = add_proj(proj_dir)
  else -- known project --
    for _, tp in ipairs(M.config.project_types) do
      if tp.name == proj_type_name then
        proj_type = tp
        break
      end
    end
    if not proj_type then
      error("[project] unknown project type: " .. proj_type_name)
    end
  end
  proj = { type = proj_type, root = proj_dir, bufs = {} }
  projects[proj_dir] = proj
  vim.api.nvim_exec_autocmds("User", { pattern = "ProjEnter", data = proj_dir })
  return proj
end

---@param proj ProjectInfo
local function proj_close(proj)
  local vim_api = vim.api
  local buf_list = proj.bufs
  while not vim.tbl_isempty(buf_list) do
    local buf = table.remove(buf_list)
    if vim_api.nvim_buf_get_option(buf, "modified") then
      error("[project] no write for buffer: " .. vim_api.nvim_buf_get_name(buf))
    end
    vim_api.nvim_buf_delete(buf, {})
  end
  vim_api.nvim_exec_autocmds("User", { pattern = "ProjLeave", data = proj.root })
  if not vim.tbl_isempty(buf_list) then
    error()
  end
  projects[proj.root] = nil
end

---@param proj ProjectInfo
---@param buf integer
---@return boolean
local function proj_add_buf(proj, buf)
  local buf_list = proj.bufs
  if vim.tbl_contains(buf_list, buf) then
    return false
  end
  table.insert(buf_list, buf)
  vim.api.nvim_buf_set_var(buf, "ProjRoot", proj.root)
  return true
end

---@param proj ProjectInfo
---@param buf integer
---@return boolean
local function proj_rm_buf(proj, buf)
  local buf_list = proj.bufs
  local pos
  for i, b in ipairs(buf_list) do
    if b == buf then
      pos = i
      break
    end
  end
  if pos == nil then
    return false
  end
  vim.api.nvim_buf_del_var(buf, "ProjRoot")
  table.remove(buf_list, pos)
  return true
end

---@param buf integer
---@param open_proj_only? boolean only search for the project in open projects
---@return ProjectInfo|nil
local function proj_of_buf(buf, open_proj_only)
  local buf_file = vim.api.nvim_buf_get_name(buf)
  for proj_dir, proj in pairs(projects) do
    if _path_is_parent(proj_dir, buf_file) then
      return proj
    end
  end
  if open_proj_only then
    return nil
  end
  for proj_dir in proj_list_iter() do
    if _path_is_parent(proj_dir, buf_file) then
      return proj_open(proj_dir)
    end
  end
  return nil
end

--
--- Auto-commands
--

local function on_new_buf(args)
  local buf, file = args.buf, args.file
  if vim.api.nvim_buf_get_option(buf, "buftype") ~= "" or file == "" or
      not vim.api.nvim_buf_get_option(buf, "buflisted") then
    return
  end
  local proj = proj_of_buf(buf)
  if proj then
    proj_add_buf(proj, buf)
  end
end

local function on_quit_buf(args)
  local buf = args.buf
  local proj = projects[M.root_dir(buf)]
  if proj then
    proj_rm_buf(proj, buf)
    if vim.tbl_isempty(proj.bufs) then
      proj_close(proj)
    end
  end
end

vim.api.nvim_create_autocmd("BufAdd", { callback = on_new_buf })
vim.api.nvim_create_autocmd("BufUnload", { callback = on_quit_buf })

--
--- Commands
--

local function _safe_call(...)
  local ok, res, res2, res3 = pcall(...)
  if ok then
    return res, res2, res3
  end
  local pos = string.find(res, "%[project%]")
  if pos then
    res = string.sub(res, pos)
  end
  vim.notify(res, vim.log.levels.ERROR)
end

--- Command `ProjNew DIR`
vim.api.nvim_create_user_command("ProjNew", function(args)
  local proj_dir, proj_type = _safe_call(add_proj, args.args)
  if proj_dir then
    vim.notify(
      "[project] new " .. proj_type.name ..
      " project `" .. proj_dir .. "'"
    )
  end
end, { nargs = 1 })

--- Command `ProjDel DIR`
vim.api.nvim_create_user_command("ProjDel", function(args)
  _safe_call(del_proj, args.args)
end, { nargs = 1 })

--- Command `ProjInfo`
vim.api.nvim_create_user_command("ProjInfo", function(args)
  local proj = projects[M.root_dir(args.buf)]
  local msg
  if proj then
    msg = string.format(
      "Project Info\nRoot: %s\nType: %s\nBufs: %s",
      proj.root, proj.type.name,
      vim.inspect(vim.tbl_map(vim.api.nvim_buf_get_name, proj.bufs))
    )
  else
    msg = "(not in a project)"
  end
  vim.print(msg)
end, {})

--
--- Public APIs
--

--- Setup.
---@param opts table see `project.config`; `opts.project_types` can be a list of strings
function M.setup(opts)
  -- options
  if opts then
    if opts.project_types then
      for i, v in ipairs(opts.project_types) do
        if type(v) == "string" then
          opts.project_types[i] = M[v]
        end
      end
    end
    M.config = vim.tbl_extend("force", M.config, opts)
  end
  -- recored projects
  proj_list_reload()
  -- existing buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    on_new_buf{ buf = buf, file = vim.api.nvim_buf_get_name(buf) }
  end
end

--- List known projects.
---@return string[]
function M.list()
  return vim.tbl_keys(_proj_list)
end

--- Remove a known project
---@param proj string
---@return boolean
function M.delete(proj)
  return del_proj(proj)
end

--- Get project root directory of the buffer.
---@param buf? integer
---@return string|nil dir
function M.root_dir(buf)
  local ok, dir = pcall(vim.api.nvim_buf_get_var, buf or 0, "ProjRoot")
  if ok then
    return dir
  end
end

--- List buffers associated with the project.
---@param proj_dir string
---@return integer[]|nil
function M.list_bufs(proj_dir)
  local proj = projects[proj_dir]
  if proj then
    return proj.bufs
  end
end

--
--- Pre-defined project types
--

---@type ProjectType
M.git_project = {
  name = "Git",
  has_file = { ".git", ".gitignore" },
}

return M
