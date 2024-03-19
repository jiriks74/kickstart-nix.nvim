if vim.g.did_load_autocommands_plugin then
  return
end
vim.g.did_load_autocommands_plugin = true

local api = vim.api
local wk = require('which-key')

local tempdirgroup = api.nvim_create_augroup('tempdir', { clear = true })
-- Do not set undofile for files in /tmp
api.nvim_create_autocmd('BufWritePre', {
  pattern = '/tmp/*',
  group = tempdirgroup,
  callback = function()
    vim.cmd.setlocal('noundofile')
  end,
})

-- Disable spell checking in terminal buffers
local nospell_group = api.nvim_create_augroup('nospell', { clear = true })
api.nvim_create_autocmd('TermOpen', {
  group = nospell_group,
  callback = function()
    vim.wo[0].spell = false
  end,
})

-- LSP
local keymap = vim.keymap

local function preview_location_callback(_, result)
  if result == nil or vim.tbl_isempty(result) then
    return nil
  end
  local buf, _ = vim.lsp.util.preview_location(result[1])
  if buf then
    local cur_buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].filetype = vim.bo[cur_buf].filetype
  end
end

local function peek_definition()
  local params = vim.lsp.util.make_position_params()
  return vim.lsp.buf_request(0, 'textDocument/definition', params, preview_location_callback)
end

local function peek_type_definition()
  local params = vim.lsp.util.make_position_params()
  return vim.lsp.buf_request(0, 'textDocument/typeDefinition', params, preview_location_callback)
end

--- Don't create a comment string when hitting <Enter> on a comment line
vim.api.nvim_create_autocmd('BufEnter', {
  group = vim.api.nvim_create_augroup('DisableNewLineAutoCommentString', {}),
  callback = function()
    vim.opt.formatoptions = vim.opt.formatoptions - { 'c', 'r', 'o' }
  end,
})

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    local bufnr = ev.buf
    local client = vim.lsp.get_client_by_id(ev.data.client_id)

    -- Attach plugins
    -- require('nvim-navic').attach(client, bufnr)

    vim.cmd.setlocal('signcolumn=yes')
    vim.bo[bufnr].bufhidden = 'hide'

    -- Enable completion triggered by <c-x><c-o>
    vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'
    local function desc(description)
      return { noremap = true, silent = true, buffer = bufnr, desc = description }
    end

    -- Set name for the <space>l prefix
    keymap.set('n', 'gD', vim.lsp.buf.declaration, desc('lsp [g]o to [D]eclaration'))
    keymap.set('n', 'gd', vim.lsp.buf.definition, desc('lsp [g]o to [d]efinition'))
    keymap.set('n', 'K', vim.lsp.buf.hover, desc('[lsp] hover'))
    keymap.set('n', 'gi', vim.lsp.buf.implementation, desc('lsp [g]o to [i]mplementation'))
    keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, desc('[lsp] signature help'))
    keymap.set('n', '<M-CR>', vim.lsp.buf.code_action, desc('[lsp] code action'))
    keymap.set('n', '<M-l>', vim.lsp.codelens.run, desc('[lsp] run code lens'))
    keymap.set('n', 'gr', vim.lsp.buf.references, desc('lsp [g]et [r]eferences'))
    wk.register({
      l = {
        name = "[l]sp",
        g = {
          name = "[g]o to",
          t = { "<cmd>vim.lsp.buf.type_definition<cr>", '[l]sp [g]o to [t]ype definition' },
        },

        p = {
          name = "[p]eek",
          d = { peek_definition, '[l]sp [p]eek [d]efinition' },
          t = { peek_type_definition, '[l]sp [p]eek [t]ype definition' },
        },

        w = {
          name = "[w]orkspace",
          a = { "<cmd>vim.lsp.buf.add_workspace_folder<cr>", '[l]sp add [w]orksp[a]ce folder' },
          r = { "<cmd>vim.lsp.buf.remove_workspace_folder<cr>", '[l]sp [w]orkspace folder [r]emove' },
          l = { function() vim.print(vim.lsp.buf.list_workspace_folders()) end, '[l]sp [w]orkspace folders [l]ist' },
          q = { "<cmd>vim.lsp.buf.workspace_symbol<cr>", '[l]sp [w]orkspace symbol [q]' },
        },

        r = { "<cmd>vim.lsp.buf.rename<cr>", '[l]sp [r]ename' },
        d = { "<cmd>vim.lsp.buf.document_symbol<cr>", '[l]sp [d]ocument symbol' },
        R = { "<cmd>vim.lsp.codelens.refresh<cr>", '[l]sp code lenses [R]efresh' },
        f = { function() vim.lsp.buf.format { async = true } end, '[l]sp [f]ormat buffer' },
      },
    }, { prefix = "<leader>" })
    if client.server_capabilities.inlayHintProvider then
        -- keymap.set('n', '<space>lh', function()
      wk.register({
        ['<leader>lh'] = { function()
          local current_setting = vim.lsp.inlay_hint.is_enabled(bufnr)
            vim.lsp.inlay_hint.enable(bufnr, not current_setting)
          end, '[l]sp toggle inlay [h]ints' }})
        end
    -- TODO: InlayHint setting not working - the code below is the original one
    -- if client.server_capabilities.inlayHintProvider then
    --   keymap.set('n', '<space>lh', function()
    --     local current_setting = vim.lsp.inlay_hint.is_enabled(bufnr)
    --     vim.lsp.inlay_hint.enable(bufnr, not current_setting)
    --   end, desc('[l]sp toggle inlay [h]ints'))
    -- end

    -- Auto-refresh code lenses
    if not client then
      return
    end
    local function buf_refresh_codeLens()
      vim.schedule(function()
        if client.server_capabilities.codeLensProvider then
          vim.lsp.codelens.refresh()
          return
        end
      end)
    end
    local group = api.nvim_create_augroup(string.format('lsp-%s-%s', bufnr, client.id), {})
    if client.server_capabilities.codeLensProvider then
      vim.api.nvim_create_autocmd({ 'InsertLeave', 'BufWritePost', 'TextChanged' }, {
        group = group,
        callback = buf_refresh_codeLens,
        buffer = bufnr,
      })
      buf_refresh_codeLens()
    end
  end,
})

-- More examples, disabled by default

-- Toggle between relative/absolute line numbers
-- Show relative line numbers in the current buffer,
-- absolute line numbers in inactive buffers
-- local numbertoggle = api.nvim_create_augroup('numbertoggle', { clear = true })
-- api.nvim_create_autocmd({ 'BufEnter', 'FocusGained', 'InsertLeave', 'CmdlineLeave', 'WinEnter' }, {
--   pattern = '*',
--   group = numbertoggle,
--   callback = function()
--     if vim.o.nu and vim.api.nvim_get_mode().mode ~= 'i' then
--       vim.opt.relativenumber = true
--     end
--   end,
-- })
-- api.nvim_create_autocmd({ 'BufLeave', 'FocusLost', 'InsertEnter', 'CmdlineEnter', 'WinLeave' }, {
--   pattern = '*',
--   group = numbertoggle,
--   callback = function()
--     if vim.o.nu then
--       vim.opt.relativenumber = false
--       vim.cmd.redraw()
--     end
--   end,
-- })
