if vim.g.did_load_copilot_plugin then
  return
end
vim.g.did_load_copilot_plugin = true

-- local configs = require('copilot')
-- many plugins annoyingly require a call to a 'setup' function to be loaded,
-- even with default configs

require("copilot").setup({
  suggestion = { enabled = false },
  panel = { enabled = false },
})


