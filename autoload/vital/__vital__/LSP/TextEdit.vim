"
" _vital_loaded
"
function! s:_vital_loaded(V) abort
  let s:Position = a:V.import('LSP.Position')
endfunction

"
" apply
"
function! s:apply(expr, text_edits) abort
  let l:current_bufnr = bufnr('%')
  let l:target_bufnr = bufnr(a:expr)
  let l:cursor = s:Position.cursor()

  execute printf('keepalt keepjumps %sbuffer!', l:target_bufnr)
  for l:text_edit in (type(a:text_edits) == type([]) ? a:text_edits : [a:text_edits])
    call s:_apply(l:cursor, l:text_edit)
  endfor
  execute printf('keepalt keepjumps %sbuffer!', l:current_bufnr)

  if l:current_bufnr == l:target_bufnr
    call setpos('.', s:Position.lsp_to_vim(l:cursor))
  endif
endfunction

"
" _apply
"
function! s:_apply(cursor, text_edit) abort
endfunction

