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
---@field num_make_tasks number
---@field new_only boolean
---@field after_down function|nil
---@field has_ui boolean
---@field _iter_list table
---@field _iter_next function
---@field _iter_this string|nil
local SyncState = { }
SyncState.__index = SyncState

---Print a notification.
function SyncState:notify(msg, is_err)
  local level
  if not self.has_ui then
    msg = msg .. "\n"
  end
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
        self:notify("unknown package: " .. name, true)
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
    num_make_tasks = 0,
    new_only = filter == true,
    after_down = callback,
    has_ui = next(vim.api.nvim_list_uis()) ~= nil,
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

function SyncState:_may_done()
  if self._iter_this == nil and self.num_make_tasks == 0 then
    self:notify("done")
    if self.after_down then
      self.after_down(self)
    end
    return true
  end
  return false
end

function SyncState:_sync_next()
  local pkg_name, pkg_conf = self._iter_next(self._iter_list, self._iter_this)
  self._iter_this = pkg_name

  if not pkg_name then
    self:_may_done()
    return
  end

  local pkg_dir = M.pkgdir .. '/' .. pkg_name

  local function _callback(ok)
    self.num_done = self.num_done + 1
    local msg
    if ok then
      if pkg_conf.make then
        self.num_make_tasks = self.num_make_tasks + 1
        make_cmd({pkg_conf.make}, pkg_dir, function(ok1)
          self.num_make_tasks = self.num_make_tasks - 1
          local msg1
          if ok1 then
            msg1 = "completed"
          else
            msg1 = "failed"
          end
          self:notify(pkg_name .. ": make: " .. msg1)
          self:_may_done()
        end)
        msg = "make " .. pkg_conf.make
      else
        msg = "completed"
      end
    elseif ok == false then
      msg = "failed"
    end
    if msg then
      self:notify(pkg_name .. ": " .. msg)
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
  self:notify(string.format(
    "(%d/%d) %s `%s'...",
    self.num_done + 1, self.num_total, op_desc, pkg_name
  ))
end

---Download or update packages.
---@param filter boolean|string[] see `SyncState:new()`
---@param callback? function callback function to be called after done
function M.sync(filter, callback)
  local packages = load_pkglist()
  if not packages or M._sync_state then
    return
  end
  local sync_state = SyncState:new(packages, filter, function(s)
    assert(s == M._sync_state)
    M._sync_state = nil
    if callback then
      callback(true)
    end
  end)
  if sync_state then
    M._sync_state = sync_state
    sync_state:start()
  end
end

vim.api.nvim_create_user_command("PkgSync", function(arg)
  local cmd_args = arg.args
  local filter, callback
  if cmd_args == "" or cmd_args == "*" then
    filter = false
  elseif cmd_args == "+" then
    filter = true
  elseif cmd_args == "$" then
    filter = true
    callback = function(ok)
      vim.cmd("q")
    end
  else
    filter = {cmd_args}
  end
  M.sync(filter, callback)
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
