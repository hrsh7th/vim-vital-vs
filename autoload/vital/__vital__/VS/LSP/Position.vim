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
  let l:line = s:_get_buffer_line(a:expr, a:pos[0])
  if l:line is v:null
    return {
    \   'line': a:pos[0] - 1,
    \   'character': a:pos[1] - 1
    \ }
  endif

  return {
  \   'line': a:pos[0] - 1,
  \   'character': s:_charidx(l:line, a:pos[1] - 1)
  \ }
endfunction

"
" lsp_to_vim
"
function! s:lsp_to_vim(expr, position) abort
  let l:line = s:_get_buffer_line(a:expr, a:position.line + 1)
  if l:line is v:null
    return [a:position.line + 1, a:position.character + 1]
  endif
  return [a:position.line + 1, s:_byteidx(l:line, a:position.character) + 1]
endfunction

"
" _get_buffer_line
"
if exists('*bufload')
  function! s:_get_buffer_line(expr, lnum) abort
    if bufloaded(bufnr(a:expr))
      return get(getbufline(a:expr, a:lnum), 0, v:null)
    elseif filereadable(a:expr)
      call bufload(bufnr(a:expr, v:true))
      return get(getbufline(a:expr, a:lnum), 0, v:null)
    endif
    return v:null
  endfunction
else
  function! s:_get_buffer_line(expr, lnum) abort
    if bufloaded(bufnr(a:expr))
      return get(getbufline(a:expr, a:lnum), 0, v:null)
    elseif filereadable(a:expr)
      return get(readfile(a:expr, '', a:lnum), 0, v:null)
    endif
    return v:null
  endfunction
endif

"
" _byteidx
"
if exists('*byteidx')
  function! s:_byteidx(line, charidx) abort
    return byteidx(a:line, a:charidx)
  endfunction
elseif has('nvim')
  function! s:_byteidx(line, charidx) abort
    return v:lua.vim.str_byteindex(a:line, a:charidx)
  endfunction
else
  function! s:_byteidx(line, charidx) abort
    return strlen(strcharpart(a:line, 0, a:charidx))
  endfunction
endif

"
" _charidx
"
if exists('*charidx')
  function! s:_charidx(line, byteidx) abort
    return charidx(a:line, a:byteidx, v:true)
  endfunction
elseif has('nvim')
  function! s:_charidx(line, byteidx) abort
    return v:lua.vim.str_utfindex(a:line, a:byteidx)
  endfunction
else
  function! s:_charidx(line, byteidx) abort
    return strchars(strpart(a:line, 0, a:byteidx))
  endfunction
endif
