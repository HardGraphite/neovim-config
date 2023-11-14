NVIM ?= nvim
NVIM_CMD_FLAGS = --headless --clean '+lua vim.opt.rtp:append(".")'

.PHONY: help packages pkgnew

help:
	@echo 'make help      # print help messages'
	@echo 'make packages  # install/update packages'
	@echo 'make pkgnew    # install/update new packages'

packages:
	@${NVIM} ${NVIM_CMD_FLAGS} '+lua require "jet.usepkg"' +PkgSync!

pkgnew:
	@${NVIM} ${NVIM_CMD_FLAGS} '+lua require "jet.usepkg"' '+PkgSync! +'
