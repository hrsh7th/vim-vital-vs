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
  let l:cursor_pos = s:Position.lsp_to_vim('%', s:Position.cursor())

  execute printf('keepalt keepjumps %sbuffer!', l:target_bufnr)
  for l:text_edit in s:_normalize(l:target_bufnr, a:text_edits)
    call s:_apply(l:target_bufnr, l:text_edit, l:cursor_pos)
  endfor
  execute printf('keepalt keepjumps %sbuffer!', l:current_bufnr)

  if l:current_bufnr == l:target_bufnr
    call setpos('.', l:cursor_pos)
  endif
endfunction

"
" _apply
"
function! s:_apply(bufnr, text_edit, cursor_pos) abort
  let l:start_pos = s:Position.lsp_to_vim(a:bufnr, a:text_edit.range.start)
  let l:end_pos = s:Position.lsp_to_vim(a:bufnr, a:text_edit.range.end)

  let l:start_line = getline(l:start_pos[0])
  let l:before_line = strpart(l:start_line, 0, l:start_pos[1] - 1)
  let l:end_line = getline(l:end_pos[0])
  let l:after_line = strpart(l:end_line, l:end_pos[1] - 1, strlen(l:end_line) - (l:end_pos[1] - 1))

  let l:new_text_lines = split(a:text_edit.newText, "\n", v:true)
  let l:new_text_lines[0] = l:before_line . l:new_text_lines[0]
  let l:new_text_lines[-1] = l:new_text_lines[-1] . l:after_line

  let l:new_text_line_count = len(l:new_text_lines)
  let l:text_edit_line_count = l:end_pos[0] - l:start_pos[0]

  " fix cursor pos
  if l:end_pos[0] <= a:cursor_pos[0]
    if l:end_pos[0] == a:cursor_pos[0]
      if  l:end_pos[1] <= a:cursor_pos[1]
        let a:cursor_pos[1] = a:cursor_pos[1] + strlen(l:new_text_lines[-1]) - strlen(l:end_line)
      endif
    endif

    " line fix.
    let a:cursor_pos[0] += l:new_text_line_count - l:text_edit_line_count - 1
  endif

  " padding
  let l:padding = l:new_text_line_count - l:text_edit_line_count - 1
  if l:padding > 0
    call append(l:end_pos[0] - 1, repeat([''], l:padding))
  endif

  call setline(l:start_pos[0], l:new_text_lines)

  if l:padding < 0
    let l:start = l:start_pos[0] + l:new_text_line_count
    let l:end = min([l:end_pos[0] + abs(l:padding) - 1, len(getbufline(a:bufnr, '^', '$'))])
    execute printf('%s,%sdelete _', l:start, l:end)
  endif
endfunction

"
" _normalize
"
function! s:_normalize(bufnr, text_edits) abort
  let l:text_edits = type(a:text_edits) == type([]) ? a:text_edits : [a:text_edits]
  let l:text_edits = s:_range(a:bufnr, l:text_edits)
  let l:text_edits = sort(copy(l:text_edits), function('s:_compare', [], {}))
  let l:text_edits = s:_check(a:bufnr, l:text_edits)
  return reverse(l:text_edits)
endfunction

"
" _range
"
function! s:_range(bufnr, text_edits) abort
  for l:text_edit in a:text_edits
    if l:text_edit.range.start.line > l:text_edit.range.end.line || (
          \   l:text_edit.range.start.line == l:text_edit.range.end.line &&
          \   l:text_edit.range.start.character > l:text_edit.range.end.character
          \ )
      let l:text_edit.range = { 'start': l:text_edit.range.end, 'end': l:text_edit.range.start }
    endif
  endfor
  return a:text_edits
endfunction

"
" _check
"
function! s:_check(bufnr, text_edits) abort
  if len(a:text_edits) > 1
    let l:range = a:text_edits[0].range
    for l:text_edit in a:text_edits[1 : -1]
      if l:range.end.line > l:text_edit.range.start.line || (
      \   l:range.end.line == l:text_edit.range.start.line &&
      \   l:range.end.character > l:text_edit.range.start.character
      \ )
        throw 'LSP.TextEdit: range overlapped.'
      endif
      let l:range = l:text_edit.range
    endfor
  endif
  return a:text_edits
endfunction

"
" _compare
"
function! s:_compare(text_edit1, text_edit2) abort
  let l:diff = a:text_edit1.range.start.line - a:text_edit2.range.start.line
  if l:diff == 0
    return a:text_edit1.range.start.character - a:text_edit2.range.start.character
  endif
  return l:diff
endfunction

