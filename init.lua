local usepkg = require "jet.usepkg"

local conf_dir = vim.fn.stdpath("config") .. '/'
local conf_list = { "config" }
if vim.g.neovide then
  table.insert(conf_list, "config-neovide")
end
for _, x in pairs(conf_list) do
  dofile(conf_dir .. x .. ".lua")
end
