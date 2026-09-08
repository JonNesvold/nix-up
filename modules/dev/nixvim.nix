{ pkgs, ... }:
{
  programs.nixvim = {
    enable = true;
    globals.mapleader = " ";

    colorschemes.catppuccin.enable = true;

    plugins = {
      lualine.enable = true;
      nvim-tree.enable = true;
      web-devicons.enable = true;

      lsp = {
        enable = true;
        servers = {
          vtsls.enable = true;
          eslint.enable = true;
          tailwindcss.enable = true;
          cssls.enable = true;
          html.enable = true;
          jsonls.enable = true;
          tinymist = {
            enable = true;
            settings = {
              formatterMode = "typstyle";
            };
          };
        };
      };

      conform-nvim = {
        enable = true;
        settings = {
          format_on_save = {
            lsp_fallback = true;
            timeout_ms = 3000; # Increased from 500 to 3000 to prevent Prettier timeouts
          };
          formatters_by_ft = {
            javascript = [ "prettier" ];
            typescript = [ "prettier" ];
            javascriptreact = [ "prettier" ];
            typescriptreact = [ "prettier" ];
            css = [ "prettier" ];
            html = [ "prettier" ];
            json = [ "prettier" ];
          };
        };
      };

      telescope = {
        enable = true;
        keymaps = {
          "<leader>t" = "live_grep";
        };
      };

      treesitter = {
        enable = true;
        settings = {
          auto_install = true;
          highlight.enable = true;
          indent.enable = true;
        };
      };

      nvim-autopairs.enable = true;

      bufferline = {
        enable = true;
        settings = {
          options = {
            separator_style = "slant";
            show_buffer_close_icons = true;
            show_close_icon = true;
            enforce_regular_tabs = false;
            always_show_bufferline = true;
            diagnostics = "nvim_lsp";
            offsets = [
              {
                filetype = "NvimTree";
                text = "File Explorer";
                highlight = "Directory";
                text_align = "left";
              }
            ];
          };
        };
      };
    };

	extraPackages = with pkgs; [
      prettier
    ];

    extraPlugins = with pkgs.vimPlugins; [
      vim-easymotion
      vim-surround
      vim-nix
      vim-terraform
      lightline-bufferline
    ];

    keymaps = [
      {
        mode = "n";
        key = "<leader>f";
        action = "<Plug>(easymotion-overwin-f)";
      }
      {
        mode = "n";
        key = "<Tab>";
        action = "<Cmd>BufferLineCycleNext<CR>";
      }
      {
        mode = "n";
        key = "<S-Tab>";
        action = "<Cmd>BufferLineCyclePrev<CR>";
      }
      {
        mode = "n";
        key = "<leader>bd";
        action = "<Cmd>bd<CR>";
      }
      {
        mode = "n";
        key = "<leader>bp";
        action = "<Cmd>BufferLinePick<CR>";
      }
      {
        mode = "n";
        key = "<leader>mp";
        action = "<Cmd>silent !pandoc % -s -o /tmp/preview.html && xdg-open /tmp/preview.html &<CR>";
      }
      {
        mode = "n";
        key = "<leader>tp";
        action = "<Cmd>silent !typst compile % && zathura %:r.pdf &<CR>";
        options.desc = "Typst Preview - compile and view PDF";
      }
      {
        mode = "n";
        key = "<leader>lp";
        action = "<Cmd>silent !tectonic % && zathura %:r.pdf &<CR>";
        options = {
          desc = "LaTeX Preview - compile with tectonic and view PDF";
        };
      }
    ];

    extraConfigLua = ''
      vim.g.markdown_composer_browser = 'brave'
      vim.g.markdown_composer_open_browser = 0
      vim.g.markdown_composer_refresh_rate = 0
      vim.g.markdown_composer_syntax_theme = 'github-dark'

      vim.cmd("highlight Normal guibg=NONE ctermbg=NONE")
      vim.cmd("highlight NonText guibg=NONE ctermbg=NONE")
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "rust", "nix" },
        callback = function()
          vim.bo.tabstop = 4
          vim.bo.shiftwidth = 4
          vim.bo.expandtab = false
        end,
      })
    '';

    opts = {
      number = true;
      shiftwidth = 2;
      smartindent = true;
      autoindent = true;
      swapfile = false;
      splitbelow = true;
      splitright = true;
      winblend = 15;
      pumblend = 15;
      termguicolors = true;
    };
  };
}
