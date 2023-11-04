----- A simple package manager and loader. -----

local M = {}

---Path to a key-value file that stores the package name and the repo URL
---like "NAME REPO" in each line. Lines start with "#" are ignored.
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

local function load_pkglist()
  local ok, lines = pcall(vim.fn.readfile, M.pkglist)
  if ok then
    local list = {}
    for _, line in ipairs(lines) do
      if line ~= "" and string.sub(line, 1, 1) ~= "#" then
        local pos0, pos1 = string.find(line, "%s+")
        if pos0 then
          list[string.sub(line, 1, pos0 - 1)] = string.sub(line, pos1 + 1)
        end
      end
    end
    return list
  else
    vim.notify(
      "Cannot read from package list file: " .. M.pkglist,
      vim.log.levels.ERROR
    )
  end
end

local function sync_next()
  local name, repo = M._sync_next(M._sync_list, M._sync_curr)
  if not name then
    vim.notify(string.format(
      "Sync done, %d/%d succeeded",
      M._sync_succ, M._sync_succ + M._sync_fail
    ))
    M._sync_next = nil
    M._sync_list = nil
    M._sync_curr = nil
    M._sync_fail = nil
    return
  else
    M._sync_curr = name
  end
  dir = M.pkgdir .. '/' .. name

  local function sync_callback(ok)
    if ok then
      M._sync_succ = M._sync_succ + 1
    else
      M._sync_fail = M._sync_fail + 1
    end
    sync_next()
  end

  if vim.loop.fs_stat(dir) then
    git_cmd({"pull"}, dir, sync_callback)
  else
    git_cmd(
      {"clone", repo, dir, "--filter=blob:none", "--depth=1"},
      nil, sync_callback
    )
  end
  vim.notify("Syncing package `" .. name .. "' ...")
end

---Download or update packages.
function M.sync()
  local packages = load_pkglist()
  if not packages or M._sync_list then
    return
  end
  if not vim.loop.fs_stat(M.pkgdir) then
    vim.fn.mkdir(M.pkgdir)
  end
  M._sync_next, M._sync_list, M._sync_curr = pairs(packages)
  M._sync_succ, M._sync_fail = 0, 0
  sync_next()
end

---Command: PkgSync
vim.api.nvim_create_user_command("PkgSync", M.sync, {})

---Add package directory into rpt.
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
