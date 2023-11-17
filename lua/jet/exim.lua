--- External input method controlling ---

local ffi = require "ffi"

local M = {}

--
--- Back-end: the bridge to the external IM engine
--

---@class Backend
---@field name string
---@field query function (self) -> state: boolean|nil
---@field switch function (self, state: boolean)
local _backend

local function _dbus_setup(func_query, func_switch)
  local name = "dbus-1"
  local dbus = ffi.load(name)
  ffi.cdef[[
typedef struct DBusConnection DBusConnection;
typedef struct DBusMessage DBusMessage;
DBusConnection *dbus_bus_get(int, void *);
DBusMessage *dbus_message_new_method_call(const char *, const char *, const char *, const char *);
DBusMessage *dbus_connection_send_with_reply_and_block(DBusConnection *, DBusMessage *, int, void *);
void dbus_message_unref(DBusMessage *);
void dbus_connection_unref(DBusConnection *);
  ]]
  local function dbus_call_method(self, dest, path, iface, method, get_reply)
    local DBUS_BUS_SESSION = 0
    local dbus = self.dbus
    local bus = dbus.dbus_bus_get(DBUS_BUS_SESSION, nil)
    if bus == nil then
      error("D-Bus not available")
    end
    local msg = dbus.dbus_message_new_method_call(dest, path, iface, method)
    assert(msg ~= nil)
    local reply = dbus.dbus_connection_send_with_reply_and_block(bus, msg, -1, nil)
    if reply == nil then
      dbus.dbus_message_unref(msg)
      dbus.dbus_connection_unref(bus)
      error("D-Bus msg to " .. dest .. " failed")
    end
    local ret_val
    if get_reply then
      -- TODO: get value in replied message.
      ret_val = nil
    end
    dbus.dbus_message_unref(reply)
    dbus.dbus_message_unref(msg)
    dbus.dbus_connection_unref(bus)
    return ret_val
  end
  _backend = {
    name = name,
    dbus = dbus,
    call = dbus_call_method,
    query = func_query,
    switch = func_switch,
  }
end

local function _fcitx5_setup()
  _dbus_setup(
    function(self) -- query
      local state = self:call(
        "org.fcitx.Fcitx5", "/controller", "org.fcitx.Fcitx.Controller1",
        "State", true
      )
      if type(state) == "number" then
        return state == 2 -- 0 = down, 1 = inactive, 2 = active
      end
    end,
    function(self, x) -- switch
      self:call(
        "org.fcitx.Fcitx5", "/controller", "org.fcitx.Fcitx.Controller1",
        x and "Activate" or "Deactivate"
      )
    end
  )
end

local function _windows_setup()
  local name = "Imm32"
  local imm32 = ffi.load(name)
  ffi.cdef[[
typedef void * HWND;
typedef unsigned long HIMC;
HWND GetFocus(void);
HWND GetConsoleWindow(void);
HIMC ImmGetContext(HWND);
int ImmReleaseContext(HWND, HIMC);
int ImmGetOpenStatus(HIMC);
int ImmSetOpenStatus(HIMC, int);
  ]]
  local win_handle
  do
    local kernel32 = ffi.load("Kernel32")
    win_handle = kernel32.GetConsoleWindow()
    if win_handle == nil then
      local user32 = ffi.load("User32")
      win_handle = user32.GetFocus()
      if win_handle == nil then
        error("[exim] cannot get window handle")
      end
    end
  end
  local function _imm_status(b, op)
    local win = b.hwnd
    local ctx = b.imm32.ImmGetContext(win)
    if ctx == 0 then -- FIXME: always fail
      error("ImmGetContext() failed")
    end
    local ret
    if op == nil then
      ret = b.imm32.ImmGetOpenStatus(ctx)
    else
      b.imm32.ImmSetOpenStatus(ctx, op)
    end
    b.imm32.ImmReleaseContext(win, ctx)
    return ret
  end
  _backend = {
    name = name,
    imm32 = imm32,
    hwnd = win_handle,
    query = _imm_status,
    switch = _imm_status,
  }
end

--
--- Basic controls
--

local im_state --- Cached IM state.

---Get IM state. Your may want to access variable `im_state` directly.
---@param no_cache? boolean do not used cached state
---@return boolean state
function M.query(no_cache)
  if no_cache or im_state == nil then
    local x = _backend:query()
    if x == nil then
      if im_state == nil then
        im_state = false
      end
    else
      im_state = x
    end
  end
  return im_state
end

---Set IM state.
---@param x boolean on or off
---@param force? boolean ignore cached state
function M.switch(x, force)
  if not force and im_state == x then
    return
  end
  _backend:switch(x)
  im_state = x
end

---Toggle IM state.
function M.toggle()
  M.switch(not M.query())
end

--
--- Automatic switching
--

local _ausw_id

local function _ausw_setup()
  if _ausw_id ~= nil then
    vim.api.nvim_del_autocmd(_ausw_id)
  end
  _ausw_id = vim.api.nvim_create_autocmd(
    { "InsertEnter", "InsertLeave", "BufEnter", "BufLeave" },
    {callback = function(args)
      local event = args.event
      local bufnr = args.buf
      if event == "InsertEnter" then -- begin insert --
        local ok, bis = pcall(vim.api.nvim_buf_get_var, bufnr, "EximInsState")
        if ok and bis ~= im_state then
          M.switch(bis, true)
        end
      elseif event == "InsertLeave" then -- end insert --
        local bis = im_state
        vim.api.nvim_buf_set_var(bufnr, "EximInsState", bis)
        if bis then
          M.switch(false, true)
        end
      elseif event == "BufEnter" then -- enter buffer --
        local ok, bs = pcall(vim.api.nvim_buf_get_var, bufnr, "EximState")
        if ok and bs ~= im_state then
          M.switch(bs, true)
        end
      elseif event == "BufLeave" then -- leave buffer --
        local bs = im_state -- or `M.query(true)` ?
        vim.api.nvim_buf_set_var(bufnr, "EximState", bs)
      end
    end}
  )
end

--
--- User-friendly APIs
--

---Do configuration.
function M.setup()
  local os_name = jit.os
  if os_name == "Linux" then
    _fcitx5_setup()
  elseif os_name == "Windows" then
    _windows_setup()
  else
    error(os_name)
  end
  M.query(true)
  _ausw_setup()
end

--- Command: `IM [on|1|off|0|toggle|~]`
vim.api.nvim_create_user_command("IM", function(args)
  local cmd_arg = args.args
  if cmd_arg == "on" or cmd_arg == "1" then
    M.switch(true)
  elseif cmd_arg == "off" or cmd_arg == "0" then
    M.switch(false)
  elseif cmd_arg == "toggle" or cmd_arg == "~" or cmd_arg == "" then
    M.toggle()
  end
end, {nargs = "?"})

return M
