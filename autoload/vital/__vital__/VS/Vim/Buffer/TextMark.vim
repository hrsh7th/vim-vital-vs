let s:namespace = {}
let s:prop_type = {}

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
" @param {[number, number]} marks[number].start_pos
" @param {[number, number]} marks[number].end_pos
" @param {string?}          marks[number].highlight
"
function! s:set(bufnr, id, marks) abort
  call s:_set(a:bufnr, a:id, a:marks)
endfunction

"
" get
"
" @param {number} bufnr
" @param {string} id
" @param {[number, number]?} pos
" @returns {array}
"
function! s:get(bufnr, id, ...) abort
  let l:pos = get(a:000, 0, [])
  return s:_get(a:bufnr, a:id, l:pos)
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

"
" set
"
if has('nvim')
  function! s:_set(bufnr, id, marks) abort
    if !has_key(s:namespace, a:id)
      let s:namespace[a:id] = nvim_create_namespace(a:id)
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
      \   s:namespace[a:id],
      \   l:mark.start_pos[0] - 1,
      \   l:mark.start_pos[1] - 1,
      \   l:opts
      \ )
    endfor
  endfunction
else
  function! s:_set(bufnr, id, marks) abort
    for l:mark in a:marks
      let l:type = s:_create_name(l:mark)
      if !has_key(s:prop_type, l:type)
        let s:prop_type[l:type] = s:_create_opts(l:mark)
        call prop_type_add(l:type, s:prop_type[l:type])
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
  function! s:_create_name(mark) abort
    return printf('VS.Vim.Buffer.TextMark: %s', get(a:mark, 'highlight', ''))
  endfunction
  function! s:_create_opts(mark) abort
    let l:type = { 'start_incl': v:true, 'end_incl': v:true, }
    if has_key(a:mark, 'highlight')
      let l:type.highlight = a:mark.highlight
    endif
    return l:type
  endfunction
endif

"
" get
"
if has('nvim')
  function! s:_get(bufnr, id, pos) abort
    if !has_key(s:namespace, a:id)
      return []
    endif
    let l:extmarks = nvim_buf_get_extmarks(bufnr(a:bufnr), s:namespace[a:id], 0, -1, { 'details': v:true })
    if !empty(a:pos)
      let l:marks = []
      for l:extmark in l:extmarks " TODO: efficiency.
        let l:mark = s:from_extmark(l:extmark)
        let l:contains = v:true
        let l:contains = l:contains && l:mark.start_pos[0] < a:pos[0] || (l:mark.start_pos[0] == a:pos[0] && l:mark.start_pos[1] <= a:pos[1])
        let l:contains = l:contains && l:mark.end_pos[0] > a:pos[0] || (l:mark.end_pos[0] == a:pos[0] && l:mark.end_pos[1] >= a:pos[1])
        if !l:contains
          continue
        endif
        let l:marks += [l:mark]
      endfor
      return l:marks
    else
      return map(l:extmarks, 's:from_extmark(v:val)')
    endif
  endfunction
  function! s:from_extmark(extmark) abort
    let l:mark = {}
    let l:mark.start_pos = [a:extmark[1] + 1, a:extmark[2] + 1]
    let l:mark.end_pos = [a:extmark[3].end_row + 1, a:extmark[3].end_col + 1]
    if has_key(a:extmark[3], 'hl_group')
      let l:mark.highlight = a:extmark[3].hl_group
    endif

    " swap ranges if needed.
    if l:mark.start_pos[0] > l:mark.end_pos[0] || (l:mark.start_pos[0] == l:mark.end_pos[0] && l:mark.start_pos[1] > l:mark.end_pos[1])
      let l:start_pos = l:mark.start_pos
      let l:mark.start_pos = l:mark.end_pos
      let l:mark.end_pos = l:start_pos
    endif

    return l:mark
  endfunction
else
  function! s:_get(bufnr, id, pos) abort
    let l:props = []

    let l:prev = {}
    let l:end_lnum = 1
    let l:end_col = 0
    while 1
      let l:end_col += 1

      let l:curr = prop_find({ 'bufnr': a:bufnr, 'id': a:id, 'lnum': l:end_lnum, 'col': l:end_col }, 'f')
      if empty(l:curr)
        break
      endif

      " ignore unmanaged text-prop.
      if !has_key(s:prop_type, l:curr.type)
        continue
      endif

      " skip for adjacent text-prop.
      if l:prev == l:curr
        continue
      endif

      let l:start_pos = [l:curr.lnum, l:curr.col]
      let l:end_byte = line2byte(l:curr.lnum) + l:curr.col + l:curr.length - 1
      let l:end_lnum = byte2line(l:end_byte)
      let l:end_col = (l:end_byte - line2byte(l:end_lnum)) + 1
      let l:end_pos = [l:end_lnum, l:end_col]

      " position check if specified.
      if !empty(a:pos)
        if a:pos[0] < l:start_pos[0] || (a:pos[0] == l:start_pos[0] && a:pos[1] < l:start_pos[1])
          break
        endif
        let l:contains = v:true
        let l:contains = l:contains && l:start_pos[0] < a:pos[0] || (l:start_pos[0] == a:pos[0] && l:start_pos[1] <= a:pos[1])
        let l:contains = l:contains && l:end_pos[0] > a:pos[0] || (l:end_pos[0] == a:pos[0] && l:end_pos[1] >= a:pos[1])
        if !l:contains
          continue
        endif
      endif

      if has_key(s:prop_type, l:curr.type)
        let l:prop = {}
        let l:prop.start_pos = l:start_pos
        let l:prop.end_pos = l:end_pos
        if has_key(s:prop_type[l:curr.type], 'highlight')
          let l:prop.highlight = s:prop_type[l:curr.type].highlight
        endif
        call add(l:props, l:prop)
      endif
      let l:prev = l:curr
    endwhile

    return l:props
  endfunction
  function! s:from_prop(prop) abort
  endfunction
endif

"
" clear
"
if has('nvim')
  function! s:_clear(bufnr, id) abort
    if !has_key(s:namespace, a:id)
      return
    endif
    call nvim_buf_clear_namespace(bufnr(a:bufnr), s:namespace[a:id], 0, -1)
  endfunction
else
  function! s:_clear(bufnr, id) abort
    call prop_remove({ 'bufnr': a:bufnr, 'id': a:id, 'all': v:true })
  endfunction
endif

