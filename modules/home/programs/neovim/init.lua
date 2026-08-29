-- Leader keys
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local in_vscode = vim.g.vscode ~= nil

-- Options
vim.opt.termguicolors = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.showmode = false
vim.opt.clipboard = "unnamedplus"
vim.opt.breakindent = true
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
vim.opt.inccommand = "split"
vim.opt.cursorline = true
vim.opt.hlsearch = true
vim.opt.wrap = true

vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.textwidth = 80

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Stop here when running inside VS Code Neovim.
-- VS Code handles completion, LSP, file explorer, etc.
if in_vscode then
  return
end

-- Diagnostics
vim.diagnostic.config({
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = " ",
      [vim.diagnostic.severity.WARN] = " ",
      [vim.diagnostic.severity.INFO] = " ",
      [vim.diagnostic.severity.HINT] = " ",
    },
  },
  virtual_text = true,
})

-- Treesitter
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    pcall(vim.treesitter.start, args.buf)
  end,
})

-- Completion
require("blink.cmp").setup({
  completion = {
    documentation = {
      auto_show = true,
    },
  },

  keymap = {
    ["<C-n>"] = { "select_next", "fallback_to_mappings" },
    ["<C-p>"] = { "select_prev", "fallback_to_mappings" },
    ["<C-y>"] = { "select_and_accept", "fallback" },
    ["<C-e>"] = { "cancel", "fallback" },

    ["<Tab>"] = { "snippet_forward", "select_next", "fallback" },
    ["<S-Tab>"] = { "snippet_backward", "select_prev", "fallback" },
    ["<CR>"] = { "select_and_accept", "fallback" },
    ["<Esc>"] = { "cancel", "hide_documentation", "fallback" },

    ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
    ["<C-b>"] = { "scroll_documentation_up", "fallback" },
    ["<C-f>"] = { "scroll_documentation_down", "fallback" },
    ["<C-k>"] = { "show_signature", "hide_signature", "fallback" },
  },

  fuzzy = {
    implementation = "lua",
  },
})

-- LSP
local lsp_servers = {
  lua_ls = {
    Lua = {
      workspace = {
        library = vim.api.nvim_get_runtime_file("lua", true),
      },
    },
  },
}

for server, config in pairs(lsp_servers) do
  vim.lsp.config(server, {
    settings = config,

    on_attach = function(_, bufnr)
      vim.keymap.set("n", "grd", vim.lsp.buf.definition, {
        buffer = bufnr,
        desc = "Go to definition",
      })

      vim.keymap.set("n", "grf", vim.lsp.buf.format, {
        buffer = bufnr,
        desc = "Format file",
      })
    end,
  })

  vim.lsp.enable(server)
end

-- Telescope
require("telescope").setup({})

local pickers = require("telescope.builtin")

vim.keymap.set("n", "<leader>sp", pickers.builtin, {
  desc = "[S]earch Builtin [P]ickers",
})

vim.keymap.set("n", "<leader>sb", pickers.buffers, {
  desc = "[S]earch [B]uffers",
})

vim.keymap.set("n", "<leader>sf", pickers.find_files, {
  desc = "[S]earch [F]iles",
})

vim.keymap.set("n", "<leader>sw", pickers.grep_string, {
  desc = "[S]earch Current [W]ord",
})

vim.keymap.set("n", "<leader>sg", pickers.live_grep, {
  desc = "[S]earch by [G]rep",
})

vim.keymap.set("n", "<leader>sr", pickers.resume, {
  desc = "[S]earch [R]esume",
})

vim.keymap.set("n", "<leader>sh", pickers.help_tags, {
  desc = "[S]earch [H]elp",
})

vim.keymap.set("n", "<leader>sm", pickers.man_pages, {
  desc = "[S]earch [M]anuals",
})

-- Statusline
require("lualine").setup({
  options = {
    section_separators = { left = "", right = "" },
    component_separators = { left = "", right = "" },
  },
})

-- Which-key
require("which-key").setup({
  spec = {
    {
      "<leader>s",
      group = "[S]earch",
      icon = {
        icon = "",
        color = "green",
      },
    },
  },
})

-- Utility plugins
require("nvim-autopairs").setup()
require("todo-comments").setup()

-- File explorer
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("nvim-tree").setup({
  update_focused_file = {
    enable = true,
  },

  view = {
    width = 35,
  },
})

vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", {
  desc = "Toggle file explorer",
})
