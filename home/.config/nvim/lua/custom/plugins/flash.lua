-- flash.nvim — type `s` + 2 chars to jump anywhere visible.
-- Replaces most uses of hjkl mashing, w/b counting, and :line-number jumps.
-- `S` does treesitter-aware jumps (functions, blocks, etc.).
-- `r` in operator-pending mode = remote flash (`drw` deletes a word elsewhere).

vim.pack.add { 'https://github.com/folke/flash.nvim' }

require('flash').setup {
  modes = {
    search = { enabled = true },
    char = { enabled = true, jump_labels = true },
  },
}

local map = vim.keymap.set
map({ 'n', 'x', 'o' }, 's', function() require('flash').jump() end, { desc = 'Flash jump' })
map({ 'n', 'x', 'o' }, 'S', function() require('flash').treesitter() end, { desc = 'Flash treesitter' })
map('o', 'r', function() require('flash').remote() end, { desc = 'Remote flash' })
map({ 'o', 'x' }, 'R', function() require('flash').treesitter_search() end, { desc = 'Treesitter search' })
map('c', '<c-s>', function() require('flash').toggle() end, { desc = 'Toggle flash search' })
