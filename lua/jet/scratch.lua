----- A scratch buffer like Emacs -----

local M = {}

---Default buffer name.
---@type string
M.name = "*scratch*"

---Default file type.
---@type string|nil
M.filetype = nil

---Initial text in the buffer.
---@type string[]|nil
M.text = nil

---Set options and prepare the scratch buffer.
function M.setup(opts)
  if opts then
    for k, v in pairs(opts) do
      M[k] = v
    end
  end
  if next(vim.fn.argv()) then
    M.make() -- new buffer
  else
    M.make(0) -- current buffer
  end
end

---Create or initialize a buffer to be the scratch.
---@param buf? number the buffer
function M.make(buf)
  local bo
  if buf then
    bo = vim.bo[buf]
    bo.modeline = false
  else
    buf = vim.api.nvim_create_buf(true, true)
    bo = vim.bo[buf]
  end
  vim.api.nvim_buf_set_name(buf, M.name)
  bo.buftype = "nofile"
  if M.filetype then
    bo.filetype = M.filetype
  end
  if M.text then
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, M.text)
  end
  return buf
end

return M
