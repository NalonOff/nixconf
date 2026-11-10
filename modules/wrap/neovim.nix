{ ... }: {
  flake.wrappers.neovim = { wlib, pkgs, ... }:
    let
      lib = pkgs.lib;

      # Single source of truth: one entry per filetype.
      #   parsers: treesitter grammars   lsp: lspconfig server name (or null)
      #   fmt: conform formatter (or null)
      # Filetypes with neither an LSP nor a formatter get whitespace trimming on save.
      languages = {
        nix        = { parsers = [ "nix" ];        lsp = "nixd";    fmt = "nixfmt"; };
        python     = { parsers = [ "python" ];     lsp = "pyright"; fmt = "black"; };
        c          = { parsers = [ "c" ];          lsp = "clangd";  fmt = null; };
        cpp        = { parsers = [ "cpp" ];        lsp = "clangd";  fmt = null; };
        sh         = { parsers = [ "bash" ];       lsp = "bashls";  fmt = "shfmt"; };
        bash       = { parsers = [ "bash" ];       lsp = "bashls";  fmt = "shfmt"; };
        zsh        = { parsers = [ ];              lsp = null;      fmt = null; };
        lua        = { parsers = [ "lua" ];        lsp = null;      fmt = "stylua"; };
        html       = { parsers = [ "html" ];       lsp = "html";    fmt = "prettier"; };
        css        = { parsers = [ "css" ];        lsp = "cssls";   fmt = "prettier"; };
        javascript = { parsers = [ "javascript" ]; lsp = "ts_ls";   fmt = "prettier"; };
        json       = { parsers = [ "json" ];       lsp = "jsonls";  fmt = "prettier"; };
        yaml       = { parsers = [ "yaml" ];       lsp = "yamlls";  fmt = "prettier"; };
        vim        = { parsers = [ "vim" "vimdoc" ]; lsp = null;    fmt = null; };
      };

      # Parsers needed without a dedicated filetype entry (markdown has no LSP/formatter here)
      extraParsers = [ "markdown" "markdown_inline" ];

      lspPackages = {
        nixd = [ pkgs.nixd ];
        pyright = [ pkgs.pyright ];
        clangd = [ pkgs.clang-tools ];
        bashls = [ pkgs.bash-language-server ];
        html = [ pkgs.vscode-langservers-extracted ];
        cssls = [ pkgs.vscode-langservers-extracted ];
        jsonls = [ pkgs.vscode-langservers-extracted ];
        yamlls = [ pkgs.yaml-language-server ];
        ts_ls = [ pkgs.typescript-language-server ];
      };

      fmtPackages = {
        nixfmt = pkgs.nixfmt;
        black = pkgs.black;
        prettier = pkgs.prettier;
        shfmt = pkgs.shfmt;
        stylua = pkgs.stylua;
      };

      entries = lib.attrValues languages;
      nonNull = lib.filter (x: x != null);

      lsps = lib.unique (nonNull (map (l: l.lsp) entries));
      fmts = lib.unique (nonNull (map (l: l.fmt) entries));
      parsers = lib.unique (lib.concatMap (l: l.parsers) entries ++ extraParsers);
      lspFiletypes = lib.attrNames (lib.filterAttrs (_: l: l.lsp != null) languages);
      trimFiletypes = lib.attrNames (lib.filterAttrs (_: l: l.lsp == null && l.fmt == null) languages);

      luaList = xs: "{ " + lib.concatMapStringsSep ", " (x: "\"${x}\"") xs + " }";

      conformFormatters = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (ft: l: lib.optionalString (l.fmt != null) "${ft} = { \"${l.fmt}\" },") languages
      );
    in
    {
    imports = [ wlib.wrapperModules.neovim ];

    # Everything neovim shells out to: helpers, plus LSP servers and formatters
    # derived from the language table above
    runtimePkgs =
      (with pkgs; [ git ripgrep fd wl-clipboard ])
      ++ lib.unique (lib.concatMap (n: lspPackages.${n}) lsps)
      ++ map (n: fmtPackages.${n}) fmts;

    # Options and keymaps live in a store-provided init.lua, plugin config lives in specs
    settings.config_directory = pkgs.writeTextDir "init.lua" ''
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      local opt = vim.opt
      opt.number = true
      opt.relativenumber = true
      opt.tabstop = 2
      opt.shiftwidth = 2
      opt.expandtab = true
      opt.wrap = false
      opt.swapfile = false
      opt.backup = false
      opt.undofile = true
      opt.hlsearch = true
      opt.incsearch = true
      opt.termguicolors = true
      opt.scrolloff = 8
      opt.signcolumn = "yes"
      opt.isfname:append("@-@")
      opt.updatetime = 250
      opt.colorcolumn = "80"
      opt.cursorline = true
      opt.splitbelow = true
      opt.splitright = true
      opt.clipboard = "unnamedplus"
      opt.mouse = "a"
      opt.ignorecase = true
      opt.smartcase = true
      opt.timeoutlen = 300

      vim.diagnostic.config({ virtual_text = true, severity_sort = true })

      local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { desc = desc })
      end

      -- Don't clobber the system clipboard (clipboard = unnamedplus)
      map({ "n", "v" }, "x", '"_x', "Delete char (no yank)")
      map({ "n", "v" }, "c", '"_c', "Change (no yank)")
      map("n", "C", '"_C', "Change to end of line (no yank)")
      map("x", "p", "P", "Paste without overwriting the register")

      -- Visual mode: keep the selection when indenting
      map("v", "<", "<gv", "Indent left and reselect")
      map("v", ">", ">gv", "Indent right and reselect")

      -- General
      map("n", "<leader>w", "<cmd>w<CR>", "Save file")
      map("n", "<leader>q", "<cmd>q<CR>", "Quit")
      map("n", "<leader>Q", "<cmd>qa<CR>", "Quit all")
      map("n", "<leader>fn", "<cmd>enew<CR>", "New file")

      -- File explorer
      map("n", "<leader>e", "<cmd>Neotree toggle<CR>", "Toggle file explorer")

      -- Buffers: [b and ]b are built in since Neovim 0.11
      -- Delete a buffer without closing the windows (splits) that show it
      local function bufdelete(buf)
        buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf

        -- Special buffers (help, terminal, quickfix...): plain bdelete is fine
        if vim.bo[buf].buftype ~= "" then
          vim.cmd("bdelete! " .. buf)
          return
        end

        if vim.bo[buf].modified then
          local choice = vim.fn.confirm(
            ("Save changes to %q?"):format(vim.fn.bufname(buf)),
            "&Yes\n&No\n&Cancel"
          )
          if choice == 1 then
            vim.api.nvim_buf_call(buf, function() vim.cmd("write") end)
          elseif choice ~= 2 then
            return
          end
        end

        -- Pick a replacement: alternate buffer first, then any other listed one
        local function replacement()
          local alt = vim.fn.bufnr("#")
          if alt ~= buf and alt ~= -1 and vim.fn.buflisted(alt) == 1 then
            return alt
          end
          for _, b in ipairs(vim.api.nvim_list_bufs()) do
            if b ~= buf and vim.bo[b].buflisted then
              return b
            end
          end
          return vim.api.nvim_create_buf(true, false)
        end

        for _, win in ipairs(vim.fn.win_findbuf(buf)) do
          vim.api.nvim_win_set_buf(win, replacement())
        end

        if vim.api.nvim_buf_is_valid(buf) then
          vim.cmd("bdelete! " .. buf)
        end
      end

      _G.bufdelete = bufdelete
      map("n", "<leader>bp", "<cmd>BufferLinePick<CR>", "Pick buffer")
      map("n", "<leader>bo", "<cmd>BufferLineCloseOthers<CR>", "Close other buffers")
      for i = 1, 9 do
        map("n", "<leader>" .. i, "<cmd>BufferLineGoToBuffer " .. i .. "<CR>", "Go to buffer " .. i)
      end
      map("n", "<leader>bd", function() bufdelete(0) end, "Delete buffer (keep splits)")

      -- Window navigation (Alt + WASD)
      map("n", "<M-w>", "<C-w>k", "Window up")
      map("n", "<M-a>", "<C-w>h", "Window left")
      map("n", "<M-s>", "<C-w>j", "Window down")
      map("n", "<M-d>", "<C-w>l", "Window right")

      -- Window resizing (Alt + Shift + WASD)
      map("n", "<M-W>", "<cmd>resize +2<CR>", "Increase window height")
      map("n", "<M-S>", "<cmd>resize -2<CR>", "Decrease window height")
      map("n", "<M-A>", "<cmd>vertical resize -2<CR>", "Decrease window width")
      map("n", "<M-D>", "<cmd>vertical resize +2<CR>", "Increase window width")

      -- Splits
      map("n", "<leader>sv", "<cmd>vsplit<CR>", "Split vertically")
      map("n", "<leader>sh", "<cmd>split<CR>", "Split horizontally")
      map("n", "<leader>sx", "<cmd>close<CR>", "Close split")
      map("n", "<leader>se", "<C-w>=", "Equalize splits")
      map("n", "<leader>so", "<cmd>only<CR>", "Keep only this window")

      -- Terminal: leave terminal mode and keep the Alt+WASD window navigation
      map("t", "<Esc><Esc>", "<C-\\><C-n>", "Exit terminal mode")
      map("t", "<M-w>", "<C-\\><C-n><C-w>k", "Window up")
      map("t", "<M-a>", "<C-\\><C-n><C-w>h", "Window left")
      map("t", "<M-s>", "<C-\\><C-n><C-w>j", "Window down")
      map("t", "<M-d>", "<C-\\><C-n><C-w>l", "Window right")

      -- Move lines (Alt + J/K)
      map("n", "<M-j>", "<cmd>m .+1<CR>==", "Move line down")
      map("n", "<M-k>", "<cmd>m .-2<CR>==", "Move line up")
      map("v", "<M-j>", ":m '>+1<CR>gv=gv", "Move selection down")
      map("v", "<M-k>", ":m '<-2<CR>gv=gv", "Move selection up")

      -- Search and scrolling
      map("n", "<Esc>", "<cmd>nohlsearch<CR>", "Clear search highlight")
      map("n", "<C-d>", "<C-d>zz", "Scroll down half page")
      map("n", "<C-u>", "<C-u>zz", "Scroll up half page")
      map("n", "n", "nzzzv", "Next search result")
      map("n", "N", "Nzzzv", "Previous search result")

      -- Git
      map("n", "<leader>gb", "<cmd>Gitsigns blame_line<CR>", "Git blame line")
      map("n", "<leader>gp", "<cmd>Gitsigns preview_hunk<CR>", "Preview hunk")
      map("n", "<leader>gr", "<cmd>Gitsigns reset_hunk<CR>", "Reset hunk")
      -- stage_hunk toggles: running it on an already staged hunk unstages it
      map("n", "<leader>gs", "<cmd>Gitsigns stage_hunk<CR>", "Stage / unstage hunk")

      -- Visual mode: stage / reset only the selected lines
      map("v", "<leader>gs", function()
        require("gitsigns").stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Stage / unstage selected lines")
      map("v", "<leader>gr", function()
        require("gitsigns").reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Reset selected lines")

      -- Hunk navigation (falls back to the built-in diff motions in diff mode)
      map("n", "]h", function()
        if vim.wo.diff then
          vim.cmd.normal({ "]c", bang = true })
        else
          require("gitsigns").nav_hunk("next")
        end
      end, "Next hunk")
      map("n", "[h", function()
        if vim.wo.diff then
          vim.cmd.normal({ "[c", bang = true })
        else
          require("gitsigns").nav_hunk("prev")
        end
      end, "Previous hunk")

      -- LSP: K, grn, gra, [d and ]d are built in since Neovim 0.11.
      -- <leader>c* mirrors grn/gra so everything shows up under which-key's "code" group.
      map("n", "<leader>cd", vim.diagnostic.open_float, "Line diagnostics")
      map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
      map("n", "<leader>cr", vim.lsp.buf.rename, "Rename")

      -- Goes through conform (black, nixfmt, prettier), falls back to the LSP
      map({ "n", "v" }, "<leader>cf", function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end, "Format")

      -- Navigation keys only while a language server is attached.
      -- They use Telescope pickers instead of the quickfix list.
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local function bmap(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, { buffer = args.buf, desc = desc })
          end
          local function picker(name)
            return function() require("telescope.builtin")[name]() end
          end

          bmap("gd", picker("lsp_definitions"), "Go to definition")
          bmap("gD", vim.lsp.buf.declaration, "Go to declaration")
          bmap("grr", picker("lsp_references"), "References")
          bmap("gri", picker("lsp_implementations"), "Implementations")
          bmap("grt", picker("lsp_type_definitions"), "Type definition")
          bmap("gO", picker("lsp_document_symbols"), "Document symbols")
        end,
      })

      -- Recursively load every file with a configured LSP under a directory, so the
      -- language servers analyse them, then open the diagnostics picker once the
      -- results settle. Buffers are unlisted: they stay out of the bufferline.
      local lsp_filetypes = {}
      for _, ft in ipairs(${luaList lspFiletypes}) do
        lsp_filetypes[ft] = true
      end

      local function workspace_diagnostics(dir)
        dir = vim.fn.fnamemodify(dir, ":p")
        local files = vim.fn.systemlist({ "fd", "--type", "f", "--absolute-path", ".", dir })
        if vim.v.shell_error ~= 0 then
          vim.notify("fd failed in " .. dir, vim.log.levels.ERROR)
          return
        end

        local max_files = 1000
        local supported = 0
        for _, path in ipairs(files) do
          local ft = vim.filetype.match({ filename = path })
          if ft and lsp_filetypes[ft] then
            if supported >= max_files then
              vim.notify("Stopped at " .. max_files .. " files", vim.log.levels.WARN)
              break
            end
            supported = supported + 1
            local existed = vim.fn.bufnr(path) ~= -1
            local buf = vim.fn.bufadd(path)
            -- bufadd() lists the buffer: unlist the ones we create so they stay out of the
            -- bufferline (opening one from the picker lists it again). Buffers that already
            -- existed keep their state.
            if not existed then
              vim.bo[buf].buflisted = false
            end
            if not vim.api.nvim_buf_is_loaded(buf) then
              vim.fn.bufload(buf)
              if vim.bo[buf].filetype ~= ft then
                vim.bo[buf].filetype = ft
              end
            end
          end
        end

        if supported == 0 then
          vim.notify("No files with a language server in " .. dir)
          return
        end
        vim.notify(("Analysing %d files in %s ..."):format(supported, dir))

        -- Open the picker once no new diagnostics arrived for 1.5 s (6 s max wait)
        local done = false
        local timer = vim.uv.new_timer()
        local group = vim.api.nvim_create_augroup("WorkspaceDiagnostics", { clear = true })
        local function finish()
          if done then return end
          done = true
          timer:stop()
          timer:close()
          vim.api.nvim_clear_autocmds({ group = group })
          require("telescope.builtin").diagnostics()
        end
        local function arm(ms)
          if done then return end
          timer:stop()
          timer:start(ms, 0, vim.schedule_wrap(finish))
        end
        vim.api.nvim_create_autocmd("DiagnosticChanged", {
          group = group,
          callback = function() arm(1500) end,
        })
        arm(6000)
      end

      vim.api.nvim_create_user_command("WorkspaceDiagnostics", function(opts)
        workspace_diagnostics(opts.args ~= "" and opts.args or vim.fn.getcwd())
      end, { nargs = "?", complete = "dir", desc = "Diagnostics for all files in a directory" })

      map("n", "<leader>cD", function() workspace_diagnostics(vim.fn.getcwd()) end,
        "Diagnostics: whole directory")

      -- Autocommands
      local trim_filetypes = {}
      for _, ft in ipairs(${luaList trimFiletypes}) do
        trim_filetypes[ft] = true
      end

      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = "*",
        desc = "Remove trailing whitespace on save (filetypes without a formatter)",
        callback = function()
          if not trim_filetypes[vim.bo.filetype] then
            return
          end
          local view = vim.fn.winsaveview()
          vim.cmd([[keeppatterns %s/\s\+$//e]])
          vim.fn.winrestview(view)
        end,
      })

      vim.api.nvim_create_autocmd("TextYankPost", {
        pattern = "*",
        desc = "Highlight yanked text",
        callback = function() vim.highlight.on_yank() end,
      })

      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "qf", "help", "man" },
        callback = function()
          vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = true })
          vim.opt_local.buflisted = false
        end,
      })

      vim.api.nvim_create_autocmd("BufReadPost", {
        desc = "Restore cursor position",
        callback = function()
          local mark = vim.api.nvim_buf_get_mark(0, '"')
          local lcount = vim.api.nvim_buf_line_count(0)
          if mark[1] > 0 and mark[1] <= lcount then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
          end
        end,
      })
    '';

    specs = {
      catppuccin = {
        data = pkgs.vimPlugins.catppuccin-nvim;
        config = ''
          require("catppuccin").setup({
            flavour = "mocha",
            transparent_background = true,
            float = { transparent = true },
          })
          vim.cmd.colorscheme("catppuccin")
        '';
      };

      web-devicons = pkgs.vimPlugins.nvim-web-devicons;
      neo-tree-deps = [
        pkgs.vimPlugins.plenary-nvim
        pkgs.vimPlugins.nui-nvim
      ];

      alpha = {
        data = pkgs.vimPlugins.alpha-nvim;
        config = ''
          local function button(shortcut, text, on_press)
            return {
              type = "button",
              val = text,
              on_press = on_press,
              opts = {
                shortcut = shortcut,
                position = "center",
                cursor = 3,
                width = 50,
                align_shortcut = "right",
                hl_shortcut = "Keyword",
              },
            }
          end

          -- One random line below the buttons at each startup
          local taglines = {
            "It worked on my machine. 🤷",
            "One bug fixed, three to go. Shall we? 🐛",
            ":q! is not a solution, but it is tempting. 🚪",
            "Time to turn coffee into code. ☕",
            "Never push to prod on a Friday. 🔥",
            "Exiting Vim: the true final boss. 👾",
            "Today, zero warnings. Promise. 🤞",
          }
          math.randomseed(os.time())
          local tagline = taglines[math.random(#taglines)]

          local layout = {
              { type = "padding", val = 12 },
              {
                type = "text",
                val = {
                  "                                                     ",
                  "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗",
                  "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║",
                  "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║",
                  "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║",
                  "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║",
                  "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
                  "                                                     ",
                },
                opts = { position = "center", hl = "Type" },
              },
              { type = "padding", val = 2 },
              {
                type = "group",
                val = {
                  button("SPC f f", "  Find file", function() require("telescope.builtin").find_files() end),
                  button("SPC f n", "  New file", function() vim.cmd("enew") end),
                  button("SPC f o", "  Recent files", function() require("telescope.builtin").oldfiles() end),
                  button("SPC f g", "  Find text", function() require("telescope.builtin").live_grep() end),
                  button("SPC q", "  Quit", function() vim.cmd("qa") end),
                },
              },
          }

          -- Center the tagline in the space between the buttons and the bottom of the
          -- window. The used height is read from the layout above, so adding or removing
          -- a button needs no manual change. 2 lines are reserved for the tabline and
          -- statusline, which don't exist yet at this point.
          local used = 0
          for _, el in ipairs(layout) do
            if el.type == "padding" then
              used = used + el.val
            else
              used = used + #el.val
            end
          end
          local free_height = vim.fn.winheight(0) - 2 - used
          local tagline_padding = math.max(1, math.floor((free_height - 1) / 2))

          vim.list_extend(layout, {
            { type = "padding", val = tagline_padding },
            {
              type = "text",
              val = tagline,
              opts = { position = "center", hl = "Comment" },
            },
          })

          require("alpha").setup({ layout = layout })
        '';
      };

      neo-tree = {
        data = pkgs.vimPlugins.neo-tree-nvim;
        config = ''
          require("neo-tree").setup({
            close_if_last_window = true,
            window = { width = 30, auto_expand_width = false },
            filesystem = {
              follow_current_file = { enabled = true },
              use_libuv_file_watcher = true,
            },
          })
        '';
      };

      telescope = {
        data = [
          pkgs.vimPlugins.telescope-nvim
          pkgs.vimPlugins.telescope-fzf-native-nvim
        ];
        config = ''
          local telescope = require("telescope")
          telescope.setup({
            defaults = {
              layout_strategy = "horizontal",
              layout_config = {
                horizontal = { prompt_position = "top", preview_width = 0.6 },
                width = 0.87,
                height = 0.80,
              },
              prompt_prefix = "   ",
              selection_caret = "  ",
              entry_prefix = "  ",
              sorting_strategy = "ascending",
              file_ignore_patterns = { "^.git/", "^node_modules/", "^target/", "^build/" },
            },
          })
          pcall(telescope.load_extension, "fzf")

          local builtin = require("telescope.builtin")
          vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
          vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
          vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Buffers" })
          vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help tags" })
          vim.keymap.set("n", "<leader>fc", builtin.grep_string, { desc = "Grep word under cursor" })
          vim.keymap.set("n", "<leader>fo", builtin.oldfiles, { desc = "Recent files" })
          vim.keymap.set("n", "<leader>fs", builtin.lsp_document_symbols, { desc = "Document symbols" })
          vim.keymap.set("n", "<leader>fS", builtin.lsp_dynamic_workspace_symbols, { desc = "Workspace symbols" })
          vim.keymap.set("n", "<leader>fd", function() builtin.diagnostics({ bufnr = 0 }) end, { desc = "Buffer diagnostics" })
          vim.keymap.set("n", "<leader>fD", builtin.diagnostics, { desc = "Workspace diagnostics" })
        '';
      };

      lualine = {
        data = pkgs.vimPlugins.lualine-nvim;
        after = [ "catppuccin" ];
        config = ''
          require("lualine").setup({
            options = { globalstatus = true },
            sections = {
              lualine_a = { "mode" },
              lualine_b = { "branch", "diff", "diagnostics" },
              lualine_c = { "filename" },
              lualine_x = { "encoding", "fileformat", "filetype" },
              lualine_y = { "progress" },
              lualine_z = { "location" },
            },
          })
        '';
      };

      bufferline = {
        data = pkgs.vimPlugins.bufferline-nvim;
        after = [ "catppuccin" ];
        config = ''
          require("bufferline").setup({
            highlights = require("catppuccin.special.bufferline").get_theme(),
            options = {
              mode = "buffers",
              themable = true,
              numbers = "ordinal",
              close_command = function(n) _G.bufdelete(n) end,
              indicator = { style = "icon", icon = "▎" },
              modified_icon = "●",
              close_icon = "",
              max_name_length = 18,
              tab_size = 18,
              diagnostics = "nvim_lsp",
              offsets = {
                {
                  filetype = "neo-tree",
                  text = "File Explorer",
                  text_align = "center",
                  separator = true,
                },
              },
              show_buffer_icons = true,
              show_buffer_close_icons = true,
              separator_style = "thin",
              always_show_bufferline = true,
            },
          })
        '';
      };

      treesitter = {
        data = pkgs.vimPlugins.nvim-treesitter.withPlugins (p: map (n: p.${n}) parsers);
        config = ''
          -- Native highlighting: the parsers come from nix, no setup() call needed
          vim.api.nvim_create_autocmd("FileType", {
            callback = function(args) pcall(vim.treesitter.start, args.buf) end,
          })
        '';
      };

      lsp = {
        data = pkgs.vimPlugins.nvim-lspconfig;
        config = ''
          vim.lsp.config("*", {
            capabilities = require("cmp_nvim_lsp").default_capabilities(),
          })
          vim.lsp.enable(${luaList lsps})
        '';
      };

      snippets = pkgs.vimPlugins.friendly-snippets;

      cmp = {
        data = [
          pkgs.vimPlugins.nvim-cmp
          pkgs.vimPlugins.luasnip
          pkgs.vimPlugins.cmp_luasnip
          pkgs.vimPlugins.cmp-nvim-lsp
          pkgs.vimPlugins.cmp-path
          pkgs.vimPlugins.cmp-buffer
        ];
        config = ''
          local cmp = require("cmp")
          local luasnip = require("luasnip")
          require("luasnip.loaders.from_vscode").lazy_load()

          cmp.setup({
            snippet = {
              expand = function(args) luasnip.lsp_expand(args.body) end,
            },
            mapping = {
              ["<C-b>"] = cmp.mapping.scroll_docs(-4),
              ["<C-f>"] = cmp.mapping.scroll_docs(4),
              ["<C-Space>"] = cmp.mapping.complete(),
              ["<C-e>"] = cmp.mapping.abort(),
              ["<CR>"] = cmp.mapping.confirm({ select = false }),
              ["<Tab>"] = cmp.mapping(function(fallback)
                if cmp.visible() then
                  cmp.select_next_item()
                elseif luasnip.expand_or_jumpable() then
                  luasnip.expand_or_jump()
                else
                  fallback()
                end
              end, { "i", "s" }),
              ["<S-Tab>"] = cmp.mapping(function(fallback)
                if cmp.visible() then
                  cmp.select_prev_item()
                elseif luasnip.jumpable(-1) then
                  luasnip.jump(-1)
                else
                  fallback()
                end
              end, { "i", "s" }),
            },
            sources = {
              { name = "nvim_lsp" },
              { name = "luasnip" },
              { name = "path" },
              { name = "buffer" },
            },
          })

          -- Add "(" after confirming a function completion
          cmp.event:on(
            "confirm_done",
            require("nvim-autopairs.completion.cmp").on_confirm_done()
          )
        '';
      };

      conform = {
        data = pkgs.vimPlugins.conform-nvim;
        config = ''
          require("conform").setup({
            formatters_by_ft = {
${conformFormatters}
            },
            format_on_save = { timeout_ms = 500, lsp_format = "fallback" },
          })
        '';
      };

      gitsigns = {
        data = pkgs.vimPlugins.gitsigns-nvim;
        config = ''
          require("gitsigns").setup({
            signs = {
              add = { text = "│" },
              change = { text = "│" },
              delete = { text = "_" },
              topdelete = { text = "‾" },
              changedelete = { text = "~" },
              untracked = { text = "┆" },
            },
            current_line_blame = false,
          })
        '';
      };

      autopairs = {
        data = pkgs.vimPlugins.nvim-autopairs;
        config = ''
          require("nvim-autopairs").setup({
            check_ts = true,
            disable_filetype = { "TelescopePrompt" },
          })
        '';
      };

      indent-blankline = {
        data = pkgs.vimPlugins.indent-blankline-nvim;
        config = ''
          require("ibl").setup({
            indent = { char = "│" },
            scope = { enabled = false },
            exclude = { filetypes = { "help", "alpha", "dashboard", "neo-tree" } },
          })
        '';
      };

      which-key = {
        data = pkgs.vimPlugins.which-key-nvim;
        config = ''
          require("which-key").setup({
            delay = 300,
            spec = {
              { "<leader>f", group = "file/find" },
              { "<leader>c", group = "code" },
              { "<leader>g", group = "git" },
              { "<leader>b", group = "buffer" },
              { "<leader>s", group = "split" },
            },
          })
        '';
      };

      dressing = {
        data = pkgs.vimPlugins.dressing-nvim;
        config = ''
          require("dressing").setup({})
        '';
      };

      sleuth = pkgs.vimPlugins.vim-sleuth;
      surround = pkgs.vimPlugins.vim-surround;
      repeat = pkgs.vimPlugins.vim-repeat;
    };
  };
}
