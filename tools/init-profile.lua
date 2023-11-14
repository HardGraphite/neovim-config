---
----- Neovim profile init file -----
---
-- Start Neovim with option `-u /path/to/this/file`.
--

local function _tbl_iter_val_sorted(tbl, rev)
  local a = {}
  local b = {}
  for k, v in pairs(tbl) do
    table.insert(a, v)
    b[v] = k
  end
  local f = nil
  if rev then
    f = function(x, y)
      return x > y
    end
  end
  table.sort(a, f)
  local i = 0
  return function()
    i = i + 1
    if a[i] == nil then
      return nil
    else
      local v = a[i]
      return b[v], v
    end
  end
end

local function _tbl_sum_vals(tbl)
  local sum = 0
  for _, v in pairs(tbl) do
    sum = sum + v
  end
  return sum
end

local function _tbl_max_val(tbl)
  local max = nil
  for _, v in pairs(tbl) do
    if max == nil or v > max then
      max = v
    end
  end
  return max
end

Profile = {
  timestamps = {},
  loadingtimes = {},

  report_delay = 2000, -- 2.0 sec
  _report_buffer = -1,

  record_timestamp = function(self, name, t)
    if not t then
      t = os.clock()
    end
    self.timestamps[name] = t
  end,

  record_timestamp_on_event = function(self, event, name)
    if not name then
      name = "event:" .. event
    end
    vim.api.nvim_create_autocmd(event, {
      callback = function()
        self:record_timestamp(name)
        return true
      end
    })
  end,

  display = function(self)
    -- Prepare results
    local lines = {}
    local function puts(s)
      table.insert(lines, s)
    end
    puts("## Timestamps")
    puts("")
    for n, t in _tbl_iter_val_sorted(self.timestamps) do
      puts(string.format("- %8.3f ms : %s", t * 1e3, n))
    end
    puts("")
    puts("## Package loading durations")
    puts("")
    local t_sum = _tbl_sum_vals(self.loadingtimes)
    local t_max = _tbl_max_val(self.loadingtimes)
    for n, t in _tbl_iter_val_sorted(self.loadingtimes, true) do
      local percent = t / t_sum * 1e2
      local bar = string.rep("=", 30 * t / t_max)
      puts(string.format("- %-20s: %6.3f ms, %5.2f%% %s", n, t * 1e3, percent, bar))
    end
    puts("")
    puts(string.format("*sum*: %.3f ms", t_sum))
    -- Write to buffer
    local buf_name = "ProfileReport"
    local buf = self._report_buffer
    if buf == -1 or not string.match(vim.api.nvim_buf_get_name(buf), buf_name .. "$") then
      buf = vim.api.nvim_create_buf(false, false)
      self._report_buffer = buf
      vim.bo[buf].buftype = "nofile"
      vim.bo[buf].filetype = "markdown"
      vim.api.nvim_buf_set_name(buf, buf_name)
    else
      vim.bo[buf].modifiable = true
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.api.nvim_win_set_buf(0, buf)
  end,
}

Profile:record_timestamp_on_event("VimEnter")
Profile:record_timestamp_on_event("UIEnter")
Profile:record_timestamp("init-start")
local usepkg = require "jet.usepkg"
usepkg.timing(true)
Profile.loadingtimes = usepkg._times
dofile(vim.fn.stdpath("config") .. "/init.lua")
Profile:record_timestamp("init-end")
Profile:record_timestamp_on_event("UIEnter", "event:UIEnter (2)")

vim.api.nvim_create_autocmd("UIEnter", {
  callback = function()
    vim.notify("[Profile] preparing report...")
    vim.defer_fn(function()
      Profile:display()
    end, Profile.report_delay)
  end
})

vim.api.nvim_create_user_command("ProfileReport", function()
  Profile:display()
end, {})
