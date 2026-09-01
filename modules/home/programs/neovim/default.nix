{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    inputs.nixvim.homeModules.nixvim
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    viAlias = true;
    vimAlias = true;

    globals = {
      mapleader = " ";
      maplocalleader = " ";

      # nvim-tree replaces Neovim's built-in file explorer.
      loaded_netrw = 1;
      loaded_netrwPlugin = 1;
    };

    opts = {
      termguicolors = true;
      number = true;
      relativenumber = true;
      mouse = "a";
      showmode = false;
      clipboard = "unnamedplus";
      breakindent = true;
      undofile = true;
      ignorecase = true;
      smartcase = true;
      signcolumn = "yes";
      updatetime = 250;
      timeoutlen = 300;
      splitright = true;
      splitbelow = true;
      list = true;
      listchars = {
        tab = "» ";
        trail = "·";
        nbsp = "␣";
      };
      inccommand = "split";
      cursorline = true;
      hlsearch = true;
      wrap = true;

      tabstop = 2;
      shiftwidth = 2;
      expandtab = true;
      textwidth = 80;
    };

    # Apply the basic editor options in VS Code, but let VS Code provide LSP,
    # completion, its explorer, and the rest of the editor UI.
    extraConfigLuaPre = lib.mkOrder 700 ''
      vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

      if vim.g.vscode ~= nil then
        return
      end
    '';

    diagnostic.settings = {
      signs.text = [
        " "
        " "
        " "
        " "
      ];
      virtual_text = true;
    };

    extraPackages = with pkgs;
      [
        ripgrep
        fd
      ]
      ++ lib.optionals pkgs.stdenv.isLinux [
        wl-clipboard
      ];

    plugins = {
      treesitter = {
        enable = true;
        highlight.enable = true;

        grammarPackages =
          with config.programs.nixvim.plugins.treesitter.package.builtGrammars;
          [
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
          ];
      };

      blink-cmp = {
        enable = true;

        settings = {
          completion.documentation.auto_show = true;

          keymap = {
            "<C-n>" = [
              "select_next"
              "fallback_to_mappings"
            ];
            "<C-p>" = [
              "select_prev"
              "fallback_to_mappings"
            ];
            "<C-y>" = [
              "select_and_accept"
              "fallback"
            ];
            "<C-e>" = [
              "cancel"
              "fallback"
            ];
            "<Tab>" = [
              "snippet_forward"
              "select_next"
              "fallback"
            ];
            "<S-Tab>" = [
              "snippet_backward"
              "select_prev"
              "fallback"
            ];
            "<CR>" = [
              "select_and_accept"
              "fallback"
            ];
            "<Esc>" = [
              "cancel"
              "hide_documentation"
              "fallback"
            ];
            "<C-space>" = [
              "show"
              "show_documentation"
              "hide_documentation"
            ];
            "<C-b>" = [
              "scroll_documentation_up"
              "fallback"
            ];
            "<C-f>" = [
              "scroll_documentation_down"
              "fallback"
            ];
            "<C-k>" = [
              "show_signature"
              "hide_signature"
              "fallback"
            ];
          };

          fuzzy.implementation = "lua";
        };
      };

      lsp = {
        enable = true;

        keymaps.lspBuf = {
          grd = {
            action = "definition";
            desc = "Go to definition";
          };
          grf = {
            action = "format";
            desc = "Format file";
          };
        };

        servers.lua_ls = {
          enable = true;
          settings.workspace.library.__raw =
            ''vim.api.nvim_get_runtime_file("lua", true)'';
        };
      };

      telescope = {
        enable = true;

        keymaps = {
          "<leader>sp" = {
            action = "builtin";
            options.desc = "[S]earch Builtin [P]ickers";
          };
          "<leader>sb" = {
            action = "buffers";
            options.desc = "[S]earch [B]uffers";
          };
          "<leader>sf" = {
            action = "find_files";
            options.desc = "[S]earch [F]iles";
          };
          "<leader>sw" = {
            action = "grep_string";
            options.desc = "[S]earch Current [W]ord";
          };
          "<leader>sg" = {
            action = "live_grep";
            options.desc = "[S]earch by [G]rep";
          };
          "<leader>sr" = {
            action = "resume";
            options.desc = "[S]earch [R]esume";
          };
          "<leader>sh" = {
            action = "help_tags";
            options.desc = "[S]earch [H]elp";
          };
          "<leader>sm" = {
            action = "man_pages";
            options.desc = "[S]earch [M]anuals";
          };
        };
      };

      lualine = {
        enable = true;
        settings.options = {
          section_separators = {
            left = "";
            right = "";
          };
          component_separators = {
            left = "";
            right = "";
          };
        };
      };

      which-key = {
        enable = true;
        settings.spec = [
          {
            __unkeyed-1 = "<leader>s";
            group = "[S]earch";
            icon = {
              icon = "";
              color = "green";
            };
          }
        ];
      };

      nvim-autopairs.enable = true;
      todo-comments.enable = true;
      web-devicons.enable = true;

      nvim-tree = {
        enable = true;
        settings = {
          update_focused_file.enable = true;
          view.width = 35;
        };
      };
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>NvimTreeToggle<CR>";
        options.desc = "Toggle file explorer";
      }
    ];
  };
}
