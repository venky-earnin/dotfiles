-- oil.nvim — edit a directory like a buffer.
-- `-` opens the parent directory of the current file as an oil buffer.
-- Inside oil: edit lines like text. `dd` deletes a file, `cw` renames, paste
-- a path on a new line to create, `:w` to commit changes.

vim.pack.add { 'https://github.com/stevearc/oil.nvim' }

require('oil').setup {
  default_file_explorer = true,   -- replaces netrw
  view_options = { show_hidden = true },
  keymaps = {
    ['g?'] = 'actions.show_help',
    ['<CR>'] = 'actions.select',
    ['<C-s>'] = { 'actions.select', opts = { vertical = true } },
    ['<C-h>'] = { 'actions.select', opts = { horizontal = true } },
    ['<C-p>'] = 'actions.preview',
    ['<C-c>'] = 'actions.close',
    ['<C-l>'] = 'actions.refresh',
    ['-'] = 'actions.parent',
    ['_'] = 'actions.open_cwd',
    ['`'] = 'actions.cd',
    ['~'] = { 'actions.cd', opts = { scope = 'tab' } },
    ['gs'] = 'actions.change_sort',
    ['gx'] = 'actions.open_external',
    ['g.'] = 'actions.toggle_hidden',
  },
}

vim.keymap.set('n', '-', '<cmd>Oil<cr>', { desc = 'Open parent dir (oil)' })
vim.keymap.set('n', '<leader>e', '<cmd>Oil<cr>', { desc = 'File [E]xplorer (oil)' })
