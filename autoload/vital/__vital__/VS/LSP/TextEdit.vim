"
" _vital_loaded
"
function! s:_vital_loaded(V) abort
  let s:Text = a:V.import('VS.LSP.Text')
  let s:Position = a:V.import('VS.LSP.Position')
endfunction

"
" _vital_depends
"
function! s:_vital_depends() abort
  return ['VS.LSP.Text']
endfunction

let s:_method = 'auto'

"
" set_method
"
function! s:set_method(method) abort
  if a:method ==# 'nvim_buf_set_text' && exists('*nvim_buf_set_text')
    let s:_method = a:method
  elseif a:method ==# 'normal'
    let s:_method = a:method
  elseif a:method ==# 'func'
    let s:_method = a:method
  else
    let s:_method = 'auto'
  endif
endfunction

"
" get_method
"
function! s:get_method() abort
  let l:method = s:_method
  if l:method ==# 'auto'
    if exists('*nvim_buf_set_text')
      let l:method = 'nvim_buf_set_text'
    elseif !has('nvim')
      let l:method = 'normal'
    else
      let l:method = 'func'
    endif
  endif
  return l:method
endfunction

"
" is_text_mark_preserved
"
function! s:is_text_mark_preserved() abort
  return index(['nvim_buf_set_text', 'normal'], s:get_method())
endfunction

"
" apply
"
function! s:apply(path, text_edits) abort
  let l:current_bufname = bufname('%')
  let l:target_bufname = a:path
  let l:cursor_position = s:Position.cursor()

  let l:old_foldenable = &foldenable
  let l:old_virtualedit = &virtualedit
  let l:old_whichwrap = &whichwrap
  let l:old_selection = &selection
  let l:old_paste = &paste
  let l:view = winsaveview()

  let &foldenable = 0
  let &virtualedit = 'onemore'
  let &whichwrap = 'h,l'
  let &selection = 'exclusive'
  let &paste = 1

  try
    call s:_switch(l:target_bufname)
    let l:method = s:get_method()
    if l:method ==# 'nvim_buf_set_text'
      let l:fix_cursor = s:_apply_all_nvim_buf_set_text(bufnr(l:target_bufname), s:_normalize(a:text_edits), l:cursor_position)
    elseif l:method ==# 'normal'
      let l:fix_cursor = s:_apply_all_normal_command(bufnr(l:target_bufname), s:_normalize(a:text_edits), l:cursor_position)
    elseif l:method ==# 'func'
      let l:fix_cursor = s:_apply_all_func(bufnr(l:target_bufname), s:_normalize(a:text_edits), l:cursor_position)
    endif
    call s:_switch(l:current_bufname)
  catch /.*/
    call themis#log(string({ 'exception': v:exception, 'throwpoint': v:throwpoint }))
  endtry

  let &foldenable = l:old_foldenable
  let &virtualedit = l:old_virtualedit
  let &whichwrap = l:old_whichwrap
  let &selection = l:old_selection
  let &paste = l:old_paste
  call winrestview(l:view)

  if exists('l:fix_cursor') && l:fix_cursor && bufnr(l:current_bufname) == bufnr(l:target_bufname)
    call cursor(s:Position.lsp_to_vim('%', l:cursor_position))
  endif
endfunction

"
" _apply_all_nvim_buf_set_text
"
function! s:_apply_all_nvim_buf_set_text(bufnr, text_edits, cursor_position) abort
  let l:fix_cursor = v:false

  let l:buf = getbufline('%', '^', '$')
  for l:text_edit in a:text_edits
    let l:text_edit = s:_fix_text_edit(l:buf, deepcopy(l:text_edit))
    let l:start = s:Position.lsp_to_vim(a:bufnr, l:text_edit.range.start)
    let l:end = s:Position.lsp_to_vim(a:bufnr, l:text_edit.range.end)
    let l:lines = s:Text.split_by_eol(l:text_edit.newText)
    call nvim_buf_set_text(
    \   a:bufnr,
    \   l:start[0] - 1,
    \   l:start[1] - 1,
    \   l:end[0] - 1,
    \   l:end[1] - 1,
    \   l:lines
    \ )
    let l:fix_cursor = s:_fix_cursor(a:cursor_position, l:text_edit, l:lines) || l:fix_cursor
  endfor

  return l:fix_cursor
endfunction

"
" _apply_all_normal_command
"
function! s:_apply_all_normal_command(bufnr, text_edits, cursor_position) abort
  let l:fix_cursor = v:false

  let l:buf = getbufline('%', '^', '$')
  for l:text_edit in a:text_edits
    let l:text_edit = s:_fix_text_edit(l:buf, deepcopy(l:text_edit))
    let l:start = s:Position.lsp_to_vim(a:bufnr, l:text_edit.range.start)
    let l:end = s:Position.lsp_to_vim(a:bufnr, l:text_edit.range.end)
    if l:start[0] != l:end[0] || l:start[1] != l:end[1]
      let l:prepare = printf('%sG%s|v%sG%s|"_c', l:start[0], l:start[1], l:end[0], l:end[1])
    else
      let l:prepare = printf('%sG%s|i', l:start[0], l:start[1])
    endif
    noautocmd keepjumps execute printf("normal! %s%s\<Esc>", l:prepare, l:text_edit.newText)
    let l:fix_cursor = s:_fix_cursor(a:cursor_position, l:text_edit, s:Text.split_by_eol(l:text_edit.newText)) || l:fix_cursor
  endfor

  return l:fix_cursor
endfunction

"
" _apply_all_func
"
function! s:_apply_all_func(bufnr, text_edits, cursor_position) abort
  let l:fix_cursor = v:false

  let l:buf = getbufline('%', '^', '$')
  for l:text_edit in a:text_edits
    let l:text_edit = s:_fix_text_edit(l:buf, deepcopy(l:text_edit))
    let l:start_line = getline(l:text_edit.range.start.line + 1)
    let l:end_line = getline(l:text_edit.range.end.line + 1)
    let l:before_line = strcharpart(l:start_line, 0, l:text_edit.range.start.character)
    let l:after_line = strcharpart(l:end_line, l:text_edit.range.end.character, strchars(l:end_line) - l:text_edit.range.end.character)

    " create lines.
    let l:lines = s:Text.split_by_eol(l:text_edit.newText)
    let l:lines[0] = l:before_line . l:lines[0]
    let l:lines[-1] = l:lines[-1] . l:after_line

    " save length.
    let l:lines_len = len(l:lines)
    let l:range_len = (l:text_edit.range.end.line - l:text_edit.range.start.line) + 1

    " append or delete lines.
    if l:lines_len > l:range_len
      call append(l:text_edit.range.end.line, repeat([''], l:lines_len - l:range_len))
    elseif l:lines_len < l:range_len
      execute printf('%s,%sdelete _', l:text_edit.range.start.line + l:lines_len, l:text_edit.range.end.line)
    endif

    " set lines.
    let l:i = 0
    while l:i < len(l:lines)
      let l:lnum = l:text_edit.range.start.line + l:i + 1
      if get(getbufline(a:bufnr, l:lnum), 0, v:null) !=# l:lines[l:i]
        call setline(l:lnum, l:lines[l:i])
      endif
      let l:i += 1
    endwhile

    let l:fix_cursor = s:_fix_cursor(a:cursor_position, l:text_edit, s:Text.split_by_eol(l:text_edit.newText))
  endfor

  return l:fix_cursor
endfunction

"
" _fix_cursor
"
function! s:_fix_cursor(position, text_edit, lines) abort
  let l:lines_len = len(a:lines)
  let l:range_len = (a:text_edit.range.end.line - a:text_edit.range.start.line) + 1

  if a:text_edit.range.end.line < a:position.line
    let a:position.line += l:lines_len - l:range_len
    return v:true
  elseif a:text_edit.range.end.line == a:position.line && a:text_edit.range.end.character <= a:position.character
    let a:position.line += l:lines_len - l:range_len
    let a:position.character = strchars(a:lines[-1]) + (a:position.character - a:text_edit.range.end.character)
    if l:lines_len == 1
      let a:position.character += a:text_edit.range.start.character
    endif
    return v:true
  endif
  return v:false
endfunction

"
" _normalize
"
function! s:_normalize(text_edits) abort
  let l:text_edits = type(a:text_edits) == type([]) ? a:text_edits : [a:text_edits]
  let l:text_edits = s:_range(l:text_edits)
  let l:text_edits = sort(copy(l:text_edits), function('s:_compare', [], {}))
  let l:text_edits = s:_check(l:text_edits)
  return reverse(l:text_edits)
endfunction

"
" _range
"
function! s:_range(text_edits) abort
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
function! s:_check(text_edits) abort
  if len(a:text_edits) > 1
    let l:range = a:text_edits[0].range
    for l:text_edit in a:text_edits[1 : -1]
      if l:range.end.line > l:text_edit.range.start.line || (
      \   l:range.end.line == l:text_edit.range.start.line &&
      \   l:range.end.character > l:text_edit.range.start.character
      \ )
        throw 'VS.LSP.TextEdit: range overlapped.'
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

"
" _switch
"
function! s:_switch(path) abort
  if bufnr(a:path) >= 0
    execute printf('keepalt keepjumps %sbuffer!', bufnr(a:path))
  else
    execute printf('keepalt keepjumps edit! %s', fnameescape(a:path))
  endif
endfunction

"
" _fix_text_edit
"
function! s:_fix_text_edit(buf, text_edit) abort
  let l:max = len(a:buf)
  if l:max <= a:text_edit.range.start.line
    let a:text_edit.range.start.line = l:max - 1
    let a:text_edit.range.start.character = strchars(a:buf[-1])
    let a:text_edit.newText = "\n" . a:text_edit.newText[0 : -2]
  endif
  if l:max <= a:text_edit.range.end.line
    let a:text_edit.range.end.line = l:max - 1
    let a:text_edit.range.end.character = strchars(a:buf[-1])
    if &fixendofline && !&binary && a:text_edit.newText[-1 : -1] ==# "\n"
      let a:text_edit.newText = a:text_edit.newText[0 : -2]
    endif
  endif
  return a:text_edit
endfunction

