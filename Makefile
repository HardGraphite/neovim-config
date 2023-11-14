NVIM ?= nvim
NVIM_CMD_FLAGS = --headless --clean '+lua vim.opt.rtp:append(".")'

.PHONY: help packages pkgnew profile

help:
	@echo 'make help      # print help messages'
	@echo 'make packages  # install/update packages'
	@echo 'make pkgnew    # install/update new packages'
	@echo 'make profile   # start Nevim with tools/init-profile.lua'

packages:
	@${NVIM} ${NVIM_CMD_FLAGS} '+lua require "jet.usepkg"' +PkgSync!

pkgnew:
	@${NVIM} ${NVIM_CMD_FLAGS} '+lua require "jet.usepkg"' '+PkgSync! +'

profile:
	@${NVIM} -u tools/init-profile.lua
