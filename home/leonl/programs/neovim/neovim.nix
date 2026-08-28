{ pkgs, ...}:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;

    viAlias = true;
    vimAlias = true;

    # Programs Neovim/plugins need available on PATH
    extraPackages = with pkgs; [
      # LSPs
      lua-language-server

      # Telescope
      ripgrep
      fd

      # Clipboard support on Wayland
      wl-clipboard
    ];

    plugins = with pkgs.vimPlugins; [
      # Treesitter + parsers
      (nvim-treesitter.withPlugins (parsers: with parsers; [
	lua
	vim
	vimdoc
	c
	cpp
	rust
	go
	python
	javascript
	typescript
	tsx
	html
	css
	json
	markdown
	markdown_inline
      ]))

      # Completion
      blink-cmp

      # LSP
      nvim-lspconfig

      # Telescope
      plenary-nvim
      nvim-web-devicons
      telescope-nvim

      # UI
      lualine-nvim
      which-key-nvim

      # Utilities
      nvim-autopairs
      todo-comments-nvim

      # File explorer
      nvim-tree-lua
    ];

    initLua = builtins.readFile ./init.lua;
  };
}
