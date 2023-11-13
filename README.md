# Neovim Configuration

Personal configuration for the [Neovim](https://neovim.io/) editor.

## Requirements

- `Neovim` 0.9
- `Git`
- `GNU Make`

Optional:

- `ripgrep`
- `fd`
- various LSP servers

## How to setup

1. Run "`make packages`" to install packages.
2. (Optional) start nvim and use "`TSInstall`" to install Tree-sitter parsers.

## About Neovide

[Neovide](https://neovide.dev/) is a GUI client for Neovim.
Start Neovide with command line argument "`--multigrid`"
so that wonderful visual effects can be available.
If there is a problem with the configuration, 
please refer to the notes in [config-neovide.lua](./config-neovide.lua).
