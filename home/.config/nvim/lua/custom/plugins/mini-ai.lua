-- mini.ai — smarter text objects.
-- Extends vim's a/i (around/inside) with more nouns:
--   af / if  - a function / inside function     e.g. daf = delete whole fn
--   ac / ic  - a class / inside class
--   ao / io  - an argument / inside argument    e.g. cio = change arg
--   a? / i?  - prompt for delimiters interactively
--
-- Works in any language treesitter understands (Python, Lua, JS, etc.).

vim.pack.add { 'https://github.com/echasnovski/mini.ai' }

require('mini.ai').setup {
  n_lines = 500,
}
