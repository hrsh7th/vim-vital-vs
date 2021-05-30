let s:Buffer = vital#vital#import('VS.Vim.Buffer')
let s:FloatingWindow = vital#vital#import('VS.Vim.Window.FloatingWindow')

let s:win = s:FloatingWindow.new()

call s:win.set_bufnr(s:Buffer.create())
call setbufline(s:win.get_bufnr(), 1, ['111'])
call s:win.open({
\   'row': 1,
\   'col': 1,
\   'width': 3,
\   'height': 3,
\   'border': v:true,
\ })
