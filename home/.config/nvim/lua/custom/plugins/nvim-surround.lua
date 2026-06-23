-- nvim-surround — operate on surrounding chars.
--
-- Core verbs (memorize these three, the rest follow):
--   ys{motion}{char}  - add surrounding (You Surround)
--   cs{old}{new}      - change surrounding
--   ds{char}          - delete surrounding
--
-- Examples:
--   ysiw"   wrap word under cursor in "
--   ysiw)   wrap word in ()        (closing bracket = no space inside)
--   ysiw(   wrap word in ( )       (opening bracket = padded with spaces)
--   yss"    wrap whole line in "
--   cs"'    change " around to '
--   cs'<q>  change ' to <q></q>
--   ds(     delete surrounding ( )
--   S"      in visual mode, wrap selection in "

vim.pack.add { 'https://github.com/kylechui/nvim-surround' }

require('nvim-surround').setup {}
