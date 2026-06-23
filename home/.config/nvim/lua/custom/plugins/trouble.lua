-- trouble.nvim — pretty pane for LSP diagnostics, references, quickfix.
-- Much better than the default quickfix list for navigating LSP results.
-- For "show me everywhere this function is used", use `<leader>xr` after
-- placing the cursor on the symbol.

vim.pack.add { 'https://github.com/folke/trouble.nvim' }

require('trouble').setup {}

local map = vim.keymap.set
map('n', '<leader>xx', '<cmd>Trouble diagnostics toggle<cr>',                 { desc = 'Trouble: workspace diagnostics' })
map('n', '<leader>xd', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>',    { desc = 'Trouble: [D]ocument diagnostics' })
map('n', '<leader>xs', '<cmd>Trouble symbols toggle focus=false<cr>',         { desc = 'Trouble: [S]ymbols' })
map('n', '<leader>xr', '<cmd>Trouble lsp toggle focus=false win.position=right<cr>', { desc = 'Trouble: LSP [R]efs/defs' })
map('n', '<leader>xq', '<cmd>Trouble qflist toggle<cr>',                      { desc = 'Trouble: [Q]uickfix' })
map('n', '<leader>xl', '<cmd>Trouble loclist toggle<cr>',                     { desc = 'Trouble: [L]ocation list' })
