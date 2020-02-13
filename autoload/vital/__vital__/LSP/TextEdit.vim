"
" _vital_loaded
"
function! s:_vital_loaded(V) abort
  let s:Text = a:V.import('LSP.Text')
endfunction

"
" _vital_depends
"
function! s:_vital_depends() abort
  return ['LSP.Text']
endfunction

"
" apply
"
function! s:apply(expr, text_edits) abort
  let l:current_bufnr = bufnr('%')
  let l:target_bufnr = bufnr(a:expr)
  let l:cursor_pos = getpos('.')[1 : 3]
  let l:cursor_offset = 0
  let l:topline = line('w0')

  execute printf('keepalt keepjumps %sbuffer!', l:target_bufnr)
  for l:text_edit in s:_normalize(l:target_bufnr, a:text_edits)
    let l:cursor_offset += s:_apply(l:target_bufnr, l:text_edit, l:cursor_pos)
  endfor
  execute printf('keepalt keepjumps %sbuffer!', l:current_bufnr)

  if l:current_bufnr == l:target_bufnr
    let l:length = strlen(getline(l:cursor_pos[0]))
    let l:cursor_pos[2] = max([0, l:cursor_pos[1] + l:cursor_pos[2] - l:length])
    let l:cursor_pos[1] = min([l:length, l:cursor_pos[1] + l:cursor_pos[2]])
    call cursor(l:cursor_pos)
    call winrestview({ 'topline': l:topline + l:cursor_offset })
  endif
endfunction

"
" _apply
"
function! s:_apply(bufnr, text_edit, cursor_pos) abort
  " create before/after line.
  let l:start_line = getline(a:text_edit.range.start.line + 1)
  let l:end_line = getline(a:text_edit.range.end.line + 1)
  let l:before_line = strcharpart(l:start_line, 0, a:text_edit.range.start.character)
  let l:after_line = strcharpart(l:end_line, a:text_edit.range.end.character, strchars(l:end_line) - a:text_edit.range.end.character)

  " create new lines.
  let l:new_lines = s:Text.split_eol(a:text_edit.newText)
  let l:new_lines[0] = l:before_line . l:new_lines[0]
  let l:new_lines[-1] = l:new_lines[-1] . l:after_line
  let l:new_lines_len = len(l:new_lines)

  " fix cursor pos
  let l:cursor_offset = 0
  if a:text_edit.range.end.line <= a:cursor_pos[0]
    let l:cursor_offset = l:new_lines_len - (a:text_edit.range.end.line - a:text_edit.range.start.line) - 1
    let a:cursor_pos[0] += l:cursor_offset
  endif

  " append new lines.
  call append(a:text_edit.range.start.line, l:new_lines)

  " remove old lines
  execute printf('%s,%sdelete _',
  \   l:new_lines_len + a:text_edit.range.start.line + 1,
  \   l:new_lines_len + a:text_edit.range.end.line + 1
  \ )

  return l:cursor_offset
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

