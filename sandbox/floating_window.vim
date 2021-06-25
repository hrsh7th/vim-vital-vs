let s:Buffer = vital#vital#import('VS.Vim.Buffer')
let s:MarkupContent = vital#vital#import('VS.LSP.MarkupContent')
let s:Markdown = vital#vital#import('VS.Vim.Syntax.Markdown')
let s:FloatingWindow = vital#vital#import('VS.Vim.Window.FloatingWindow')

let s:win = s:FloatingWindow.new()
call s:win.set_var('&conceallevel', 2)

call s:win.set_bufnr(s:Buffer.create())
let s:lines = s:MarkupContent.normalize(readfile(expand('%:p:h') . '/floating_window/lua.txt'))
let s:lines = map(split(s:lines, "\n"), 'v:val !=# "" ? " " . v:val . " " : ""')
" let s:lines = split(s:lines, "\n")
call setbufline(s:win.get_bufnr(), 1, s:lines)

let s:size = s:win.get_size({ 'wrap': v:true })
call s:win.open({
\   'row': 1,
\   'col': 1,
\   'width': s:size.width,
\   'height': s:size.height,
\   'border': v:true,
\ })
call s:Buffer.do(s:win.get_bufnr(), { -> s:Markdown.apply({ 'text': getline('^', '$') }) })
