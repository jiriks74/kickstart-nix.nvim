-- Exit if the language server isn't available
if vim.fn.executable('asm-lsp') ~= 1 then
  return
end

-- require'lspconfig'.asm_lsp.setup{}

local root_files = {
  '.asm-lsp.toml',
  '.vscode',
  '.git',
}

vim.lsp.start {
  name = 'asm-lsp',
  cmd = { 'asm-lsp' },
  root_dir = vim.fs.dirname(vim.fs.find(root_files, { upward = true })[1]),
  capabilities = require('user.lsp').make_client_capabilities(),
  -- capabilities = { offsetEncoding = "utf-8" },
}
