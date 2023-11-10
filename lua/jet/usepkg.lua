----- A simple package manager and loader. -----

local M = {}

---Path to the package list file.
M.pkglist = vim.fn.stdpath("config") .. '/packages.conf'

---Path to a directory to put package files.
M.pkgdir = vim.fn.stdpath("data") .. '/packages'

local function git_cmd(args, cwd, callback)
  local handle
  handle = vim.loop.spawn(
    "git", { stdio = {nil, nil, nil}, args = args, cwd = cwd },
    function(exit_code)
      handle:close()
      if callback then
        local ok = exit_code == 0
        vim.schedule(function() callback(ok) end)
      end
    end
  )
end

local function make_cmd(args, cwd, callback)
  local handle
  handle = vim.loop.spawn(
    "make", { stdio = {nil, nil, nil}, args = args, cwd = cwd },
    function(exit_code)
      handle:close()
      if callback then
        local ok = exit_code == 0
        vim.schedule(function() callback(ok) end)
      end
    end
  )
end

local function load_pkglist()
  local conf = require "jet.rdconf" (M.pkglist)
  if not conf then
    vim.notify(
      "[usepkg] cannot read from package list file: " .. M.pkglist,
      vim.log.levels.ERROR
    )
  end
  return conf
end

---@class SyncState
---@field num_total number
---@field num_done number
---@field new_only boolean
---@field after_down function|nil
---@field _iter_list table
---@field _iter_next function
---@field _iter_this string|nil
local SyncState = { }
SyncState.__index = SyncState

---Print a notification.
function SyncState.notify(msg, is_err)
  local level
  if is_err then
    level = vim.log.levels.ERROR
  else
    level = vim.log.levels.INFO
  end
  vim.notify("[usepkg.sync] " .. msg, level)
end

---Create SyncState object
---@param pkg_list table package list
---@param filter? boolean|string[] `false` = all; `true` = new only; list = names
---@param callback? function function to be called after finished
function SyncState:new(pkg_list, filter, callback)
  local n = 0
  if type(filter) == "table" then
    local new_list = {}
    for _, name in pairs(filter) do
      local pkg = pkg_list[name]
      if not pkg then
        self.notify("unknown package: " .. name, true)
        return nil
      end
      new_list[name] = pkg
    end
    pkg_list = new_list
    n = #filter
  else
    for _ in pairs(pkg_list) do
      n = n + 1
    end
  end
  local obj = {
    num_total = n,
    num_done = 0,
    new_only = filter == true,
    after_down = callback,
  }
  obj._iter_next, obj._iter_list, obj._iter_this = pairs(pkg_list)
  setmetatable(obj, SyncState)
  return obj
end

---Start synchronization.
function SyncState:start()
  if self.num_done == 0 then
    if not vim.loop.fs_stat(M.pkgdir) then
      vim.fn.mkdir(M.pkgdir)
    end
    self:_sync_next()
  end
end

function SyncState:_sync_next()
  local pkg_name, pkg_conf = self._iter_next(self._iter_list, self._iter_this)
  if not pkg_name then
    self.notify("done")
    if self.after_down then
      self.after_down(self)
    end
    return
  end

  self._iter_this = pkg_name
  local pkg_dir = M.pkgdir .. '/' .. pkg_name

  local function _callback(ok)
    self.num_done = self.num_done + 1
    if ok then
      if pkg_conf.make then
        make_cmd({pkg_conf.make}, pkg_dir)
        self.notify(pkg_name .. ": make " .. pkg_conf.make)
      end
    else
      self.notify(pkg_name .. ": failed")
    end
    self:_sync_next()
  end

  local op_desc
  if vim.loop.fs_stat(pkg_dir) then
    if self.new_only then
      op_desc = "skip"
      vim.schedule(_callback)
    else
      op_desc = "updating"
      git_cmd({"pull"}, pkg_dir, _callback)
    end
  else
    op_desc = "downloading"
    git_cmd(
      {"clone", pkg_conf.repo, pkg_dir, "--filter=blob:none", "--depth=1"},
      nil, _callback
    )
  end
  self.notify(string.format(
    "(%d/%d) %s `%s'...",
    self.num_done + 1, self.num_total, op_desc, pkg_name
  ))
end

---Download or update packages.
function M.sync(filter)
  local packages = load_pkglist()
  if not packages or M._sync_state then
    return
  end
  local sync_state = SyncState:new(packages, filter, function(s)
    assert(s == M._sync_state)
    M._sync_state = nil
  end)
  if sync_state then
    M._sync_state = sync_state
    sync_state:start()
  end
end

vim.api.nvim_create_user_command("PkgSync", function(arg)
  local cmd_args = arg.args
  local filter
  if cmd_args == "" or cmd_args == "*" then
    filter = false
  elseif cmd_args == "+" then
    filter = true
  else
    filter = {cmd_args}
  end
  M.sync(filter)
end, {nargs = "?"})

---Add package directory into rtp.
---@param pkg string
function M.add_path(pkg)
  local path = M.pkgdir .. '/' .. pkg
  vim.opt.rtp:append(path)
  return path
end

---Load package now.
---@param pkg string
---@param setup? boolean|table
function M.now(pkg, setup)
  M.add_path(pkg)
  local m = require(pkg)
  if setup ~= false then
    if setup == true then
      setup = nil
    end
    m.setup(setup)
  end
  return m
end

return M
