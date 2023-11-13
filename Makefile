NVIM ?= nvim
NVIM_CMD_FLAGS = --headless --clean '+lua vim.opt.rtp:append(".")'

.PHONY: help
help:
	@echo 'make help      # print help messages'
	@echo 'make packages  # install/update packages'

packages:
	@${NVIM} ${NVIM_CMD_FLAGS} '+lua require "jet.usepkg"' '+PkgSync $$'
