let s:nvim_namespace = {}
let s:vim_prop_types = {}

"
" is_available
"
function! s:is_available() abort
  if has('nvim')
    return exists('*nvim_buf_set_text')
  else
    return exists('*prop_type_add') && exists('*prop_add')
  endif
endfunction

"
" @param {number} bufnr
" @param {string} id
" @param {array} marks
" @param {VS.LSP.Range} marks[0].range
" @param {string?} marks[0].highlight
"
function! s:set(bufnr, id, marks) abort
  call s:_set(a:bufnr, a:id, a:marks)
endfunction

"
" get
"
" @param {number} bufnr
" @param {string} id
" @returns {array}
"
function! s:get(bufnr, id) abort
  return s:_get(a:bufnr, a:id)
endfunction

"
" clear
"
" @param {number} bufnr
" @param {string} id
"
function! s:clear(bufnr, id) abort
  return s:_clear(a:bufnr, a:id)
endfunction

if has('nvim')
  function! s:_set(bufnr, id, marks) abort
    if !has_key(s:nvim_namespace, a:id)
      let s:nvim_namespace[a:id] = nvim_create_namespace(a:id)
    endif
    for l:mark in a:marks
      let l:opts = {
      \   'end_line': l:mark.end_pos[0] - 1,
      \   'end_col': l:mark.end_pos[1] - 1,
      \ }
      if has_key(l:mark, 'highlight')
        let l:opts.hl_group = l:mark.highlight
      endif
      call nvim_buf_set_extmark(
      \   bufnr(a:bufnr),
      \   s:nvim_namespace[a:id],
      \   l:mark.start_pos[0] - 1,
      \   l:mark.start_pos[1] - 1,
      \   l:opts
      \ )
    endfor
  endfunction
else
  function! s:_set(bufnr, id, marks) abort
    for l:mark in a:marks
      let l:type = s:_create_prop_type_name(l:mark)
      if !has_key(s:vim_prop_types, l:type)
        let s:vim_prop_types[l:type] = s:_create_prop_type_dict(l:mark)
        call prop_type_add(l:type, s:vim_prop_types[l:type])
      endif
      call prop_add(l:mark.start_pos[0], l:mark.start_pos[1], {
      \   'id': a:id,
      \   'bufnr': a:bufnr,
      \   'end_lnum': l:mark.end_pos[0],
      \   'end_col': l:mark.end_pos[1],
      \   'type': l:type,
      \ })
    endfor
  endfunction

  function! s:_create_prop_type_name(mark) abort
    return printf('VS.Vim.Buffer.TextMark: %s', get(a:mark, 'highlight', ''))
  endfunction

  function! s:_create_prop_type_dict(mark) abort
    let l:type = { 'start_incl': v:true, 'end_incl': v:true, }
    if has_key(a:mark, 'highlight')
      let l:type.highlight = a:mark.highlight
    endif
    return l:type
  endfunction
endif

if has('nvim')
  function! s:_get(bufnr, id) abort
    if !has_key(s:nvim_namespace, a:id)
      return []
    endif

    let l:marks = []
    for l:extmark in nvim_buf_get_extmarks(bufnr(a:bufnr), s:nvim_namespace[a:id], 0, -1, { 'details': v:true })
      let l:mark = {}
      let l:mark.start_pos = [l:extmark[1] + 1, l:extmark[2] + 1]
      let l:mark.end_pos = [l:extmark[3].end_row + 1, l:extmark[3].end_col + 1]
      if has_key(l:extmark[3], 'hl_group')
        let l:mark.highlight = l:extmark[3].hl_group
      endif

      if l:mark.start_pos[0] > l:mark.end_pos[0] || (
      \   l:mark.start_pos[0] == l:mark.end_pos[0] &&
      \   l:mark.start_pos[1] > l:mark.end_pos[1]
      \ )
        let l:start_pos = l:mark.start_pos
        let l:mark.start_pos = l:mark.end_pos
        let l:mark.end_pos = l:start_pos
      endif

      call add(l:marks, l:mark)
    endfor
    return l:marks
  endfunction
else
  function! s:_get(bufnr, id) abort
    let l:props = []

    let l:prev_prop = {}
    let l:end_lnum = 1
    let l:end_col = 1
    while 1
      let l:prop = prop_find({ 'bufnr': a:bufnr, 'id': a:id, 'lnum': l:end_lnum, 'col': l:end_col }, 'f')
      if empty(l:prop)
        break
      endif
      if l:prev_prop == l:prop
        let l:end_col += 1
        continue
      endif

      let l:start_pos = [l:prop.lnum, l:prop.col]
      let l:end_byte = line2byte(l:prop.lnum) + l:prop.col + l:prop.length - 1
      let l:end_lnum = byte2line(l:end_byte)
      let l:end_col = (l:end_byte - line2byte(l:end_lnum)) + 1
      let l:end_pos = [l:end_lnum, l:end_col]

      if has_key(s:vim_prop_types, l:prop.type)
        let l:_prop = {
        \   'start_pos': l:start_pos,
        \   'end_pos': l:end_pos,
        \ }
        if has_key(s:vim_prop_types[l:prop.type], 'highlight')
          let l:_prop.highlight = s:vim_prop_types[l:prop.type].highlight
        endif
        call add(l:props, l:_prop)
      endif
      let l:prev_prop = l:prop
    endwhile

    return l:props
  endfunction
endif

if has('nvim')
  function! s:_clear(bufnr, id) abort
    if !has_key(s:nvim_namespace, a:id)
      return
    endif
    call nvim_buf_clear_namespace(bufnr(a:bufnr), s:nvim_namespace[a:id], 0, -1)
  endfunction
else
  function! s:_clear(bufnr, id) abort
    call prop_remove({ 'bufnr': a:bufnr, 'id': a:id, 'all': v:true })
  endfunction
endif

