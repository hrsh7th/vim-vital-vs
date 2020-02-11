"
" cursor
"
function! s:cursor() abort
  return s:vim_to_lsp('%', getpos('.')[1 : 3])
endfunction

"
" vim_to_lsp
"
function! s:vim_to_lsp(expr, pos) abort
  if bufloaded(bufnr(a:expr))
    let l:lines = getbufline(a:expr, a:pos[0])
  elseif filereadable(a:expr)
    let l:lines = readfile(a:expr, '', a:pos[0])
  else
    return { 'line': a:pos[0] - 1, 'character': a:pos[1] + a:pos[2] - 1 }
  endif

  return {
  \   'line': a:pos[0] - 1,
  \   'character': strchars(strpart(l:lines[-1], 0, a:pos[1] + get(a:pos, 2, 0) - 1))
  \ }
endfunction

"
" lsp_to_vim
"
function! s:lsp_to_vim(expr, position) abort
  if bufloaded(bufnr(a:expr))
    let l:lines = getbufline(a:expr, a:position.line + 1)
  elseif filereadable(a:expr)
    let l:lines = readfile(a:expr, '', a:position.line + 1)
  else
    return [a:position.line + 1, a:position.character + 1]
  endif
  return [a:position.line + 1, strlen(strcharpart(l:lines[-1], 0, a:position.character)) + 1]
endfunction

