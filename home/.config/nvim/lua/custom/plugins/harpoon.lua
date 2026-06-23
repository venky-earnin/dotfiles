-- harpoon.nvim — pin 1-4 "hot" files; switch instantly with <leader>1..4.
-- Perfect for monorepos where you bounce between 3-4 files all day.
-- `<leader>a` to add current file; `<leader>m` to open the harpoon menu.

vim.pack.add {
  'https://github.com/nvim-lua/plenary.nvim',  -- harpoon dependency
  { src = 'https://github.com/ThePrimeagen/harpoon', version = 'harpoon2' },
}

local harpoon = require 'harpoon'
harpoon:setup()

local map = vim.keymap.set
map('n', '<leader>a', function() harpoon:list():add() end, { desc = 'Harpoon [A]dd file' })
map('n', '<leader>m', function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = 'Harpoon [M]enu' })
map('n', '<leader>1', function() harpoon:list():select(1) end, { desc = 'Harpoon → 1' })
map('n', '<leader>2', function() harpoon:list():select(2) end, { desc = 'Harpoon → 2' })
map('n', '<leader>3', function() harpoon:list():select(3) end, { desc = 'Harpoon → 3' })
map('n', '<leader>4', function() harpoon:list():select(4) end, { desc = 'Harpoon → 4' })
