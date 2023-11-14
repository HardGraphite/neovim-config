----- A simple package manager and loader. -----

local M = {}

---Path to the package list file.
M.pkglist = vim.fn.stdpath("config") .. '/packages.conf'

---Path to a directory to put package files.
M.pkgdir = vim.fn.stdpath("data") .. '/packages'

--
--- Package downloading and updating ---
--

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

--- `PkgSync[!] [+|*|PACKAGE...]`
--- - `!`: quit after done
--- - `+`: new packages only
--- - `*`: all packages (default)
--- - `PACKAGE...`: a list of package names
vim.api.nvim_create_user_command("PkgSync", function(args)
  local cmd_args = args.args
  local filter, callback
  if cmd_args == "" or cmd_args == "*" then
    filter = false
  elseif cmd_args == "+" then
    filter = true
  else
    filter = vim.fn.split(cmd_args)
  end
  if args.bang then
    callback = function()
      vim.cmd.q()
    end
  end
  M.sync(filter, callback)
end, {nargs = "?", bang = true})

--
--- Package loading management ---
--

---Add package directory into rtp.
---@param pkg string package name
function M.add_path(pkg)
  local path = M.pkgdir .. '/' .. pkg
  vim.opt.rtp:append(path)
  return path
end

---Load package now.
---@param pkg string package name
---@param setup? boolean|table whether to call the setup function
---@return mod table the loaded module (the return value from `require()`)
---@return dir string the runtime path associated with this package
function M.now(pkg, setup)
  -- Load the module.
  local dir = M.add_path(pkg)
  local mod = require(pkg)
  -- Call `setup()`.
  if setup ~= false then
    if setup == true then
      setup = nil
    end
    mod.setup(setup)
  end
  return mod, dir
end

M._deferred = {
  pkgs = {}, -- { NAME = { setup, callback } , ... }
  au = {}, -- autocmd lists: { EVENT1 = {PKG1, PKG2, ... }, ... }
  cmd = {}, -- command lists: { CMD1 = {PKG1, PKG2, ... }, ... }
  hook = {}, -- hook lists: { HOOK1 = {PKG1, PKG2, ... }, ... }
  ---Record a package (name and config)
  rec = function(self, pkg, setup, cb)
    self.pkgs[pkg] = { setup, cb }
  end,
  ---Register a trigger for a package
  add = function(self, type_, arg, pkg)
    local dict = self[type_]
    local list = dict[arg]
    if list then
      table.insert(list, pkg)
      return false
    else
      dict[arg] = { pkg }
      return true
    end
  end,
  ---Load a package by trigger
  now = function(self, type_, arg)
    local list = self[type_][arg]
    if not list then
      return false
    end
    self[type_][arg] = nil
    for _, pkg in ipairs(list) do
      local conf = self.pkgs[pkg]
      if not conf then
        goto continue
      end
      self.pkgs[pkg] = nil
      local mod, dir = M.now(pkg, conf[1]) -- load package
      if conf[2] then
        conf[2](pkg, mod) -- execute callback
      end
      local files = vim.fn.glob(dir .. "/plugin/*.lua")
      if files ~= "" then
        for _, x in ipairs(vim.fn.split(files, "\n")) do
          dofile(x) -- source plugin files
        end
      end
      ::continue::
    end
    return true
  end
}

---Defer a package loading.
---@param triggers {string:string|table} trigger types (au|cmd|hook) and the arguments
---@param pkg string package name
---@param setup? boolean|table see function `usepkg.now()`
---@param callback? function callback function that takes arguments (name, module)
function M.when(triggers, pkg, setup, callback)
  local d = M._deferred
  -- Record the configuration.
  d:rec(pkg, setup, callback)
  -- Register triggers.
  for t_type, t_args in pairs(triggers) do
    if type(t_args) ~= "table" then
      t_args = { t_args }
    end
    for _, t_arg in ipairs(t_args) do
      local arg_is_new = d:add(t_type, t_arg, pkg)
      if t_type == "au" then
        if arg_is_new then
          vim.api.nvim_create_autocmd(t_arg, {callback = function(ev)
            M._deferred:now("au", ev.event)
            return true -- delete this autocmd
          end})
        end
      elseif t_type == "cmd" then
        if arg_is_new then
          vim.api.nvim_create_user_command(t_arg, function(args)
            vim.api.nvim_del_user_command(args.name)
            M._deferred:now("cmd", args.name)
            vim.api.nvim_cmd({
              cmd = args.name,
              args = vim.fn.split(args.args),
              bang = args.bang,
            }, {})
          end, {
            nargs = "*",
            bang = true,
            force = false,
          })
        end
      elseif t_type == "hook" then
        -- do nothing
      else
        error("bad trigger tpye: " .. t_type)
      end
    end
  end
end

---Modify package setup options. See `usepkg.when()`.
---@param pkg string package name
---@param opts? table new options
---@return table|nil opts updated options; `nil` if package not recorded
function M.options(pkg, opts)
  local rec = M._deferred.pkgs[pkg]
  if not rec then
    return nil
  end
  if opts then
    opts = vim.tbl_deep_extend("force", rec[1], opts)
    rec[1] = opts
  else
    opts = rec[1]
  end
  return opts
end

---Trigger hook and load associated packages. See `usepkg.when()`.
---@param name string hook name
---@return boolean ok
function M.hook(name)
  return M._deferred:now("hook", name)
end

---Enable or disable package load timing.
---@param op? boolean|nil `true`: enable; `false`: disable; `nil`: get results
function M.timing(op)
  if op == nil then -- get results
    return M._times
  elseif op then -- enable
    if not M._now then
      M._now = M.now
      M._times = {}
      M.now = function(pkg, opts)
        local t0 = os.clock()
        local mod, dir = M._now(pkg, opts)
        local dt = os.clock() - t0
        if not M._times[pkg] then
          M._times[pkg] = dt
        end
        return mod, dir
      end
    end
  else -- disable
    if M._now then
      M.now = M._now
      M._now = nil
      M._times = nil
    end
  end
end

return M
