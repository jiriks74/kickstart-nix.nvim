-- Exit if the language server isn't available
if vim.fn.executable('clangd') ~= 1 then
  return
end

local root_files = {
  'compile_commands.json',
  '.vscode',
  '.git',
}

vim.lsp.start {
  name = 'clangd',
  cmd = { 'clangd' },
  root_dir = vim.fs.dirname(vim.fs.find(root_files, { upward = true })[1]),
  capabilities = require('user.lsp').make_client_capabilities(),
}

local dap = require("dap")

if require('user.file_exists').file_exists(vim.fs.dirname(vim.fs.find(root_files, { upward = true })[1]) .. "/.vscode/launch.json") then
  require("dap.ext.vscode").load_launchjs(nil, { cppdbg = { "c", "cpp", "asm" } })
end

dap.adapters.gdb = {
  type = "executable",
  command = "gdb",
  args = { "-i", "dap" }
}

dap.configurations.c = {
  {
    name = "Launch",
    type = "gdb",
    request = "launch",
    program = function()
      return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
    end,
    cwd = "${workspaceFolder}",
    stopAtBeginningOfMainSubprogram = false,
  },
}
