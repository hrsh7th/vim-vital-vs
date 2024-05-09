let s:Do = { -> {} }

"
" do
"
function! s:do(winid, func) abort
  let l:curr_winid = win_getid()
  if l:curr_winid == a:winid
    call a:func()
    return
  endif

  if !has('nvim') && exists('*win_execute')
    let s:Do = a:func
    try
      noautocmd keepalt keepjumps call win_execute(a:winid, 'call s:Do()')
    catch /.*/
      echomsg string({ 'exception': v:exception, 'throwpoint': v:throwpoint })
    endtry
    unlet s:Do
    return
  endif

  noautocmd keepalt keepjumps call win_gotoid(a:winid)
  try
    call a:func()
  catch /.*/
    echomsg string({ 'exception': v:exception, 'throwpoint': v:throwpoint })
  endtry
  noautocmd keepalt keepjumps call win_gotoid(l:curr_winid)
endfunction

"
" info
"
if has('nvim')
  function! s:info(winid) abort
    let l:info = getwininfo(a:winid)[0]

    if s:is_floating(a:winid)
      let l:config = nvim_win_get_config(a:winid)
      let l:config.border = get(l:config, 'border', 'none')
      if type(l:config.border) !=# type([])
        if index(['rounded', 'single', 'double', 'solid'], l:config.border) >= 0
          let l:width_off = 2
          let l:height_off = 2
        elseif l:config.border ==# 'shadow'
          let l:width_off = 1
          let l:height_off = 1
        else
          let l:width_off = 0
          let l:height_off = 0
        endif
      else
        let l:has_top = v:false
        let l:has_top = l:has_top || get(l:config.border, 0, '') !=# ''
        let l:has_top = l:has_top || get(l:config.border, 1, '') !=# ''
        let l:has_top = l:has_top || get(l:config.border, 2, '') !=# ''
        let l:has_right = v:false
        let l:has_right = l:has_right || get(l:config.border, 2, '') !=# ''
        let l:has_right = l:has_right || get(l:config.border, 3, '') !=# ''
        let l:has_right = l:has_right || get(l:config.border, 4, '') !=# ''
        let l:has_bottom = v:false
        let l:has_bottom = l:has_bottom || get(l:config.border, 4, '') !=# ''
        let l:has_bottom = l:has_bottom || get(l:config.border, 5, '') !=# ''
        let l:has_bottom = l:has_bottom || get(l:config.border, 6, '') !=# ''
        let l:has_left = v:false
        let l:has_left = l:has_left || get(l:config.border, 6, '') !=# ''
        let l:has_left = l:has_left || get(l:config.border, 7, '') !=# ''
        let l:has_left = l:has_left || get(l:config.border, 0, '') !=# ''

        let l:width_off = (l:has_left ? 1 : 0) + (l:has_right ? 1 : 0)
        let l:height_off = (l:has_top ? 1 : 0) + (l:has_bottom ? 1 : 0)
      endif
      let l:left = get(l:config, '')
      let l:info.core_width = l:config.width - l:width_off
      let l:info.core_height = l:config.height - l:height_off
    else
      let l:info.core_width = l:info.width
      let l:info.core_height = l:info.height
    endif

    return {
    \   'width': l:info.width,
    \   'height': l:info.height,
    \   'core_width': l:info.core_width,
    \   'core_height': l:info.core_height,
    \   'topline': l:info.topline,
    \ }
  endfunction
else
  function! s:info(winid) abort
    if s:is_floating(a:winid)
      let l:info = popup_getpos(a:winid)
      return {
      \   'width': l:info.width,
      \   'height': l:info.height,
      \   'core_width': l:info.core_width,
      \   'core_height': l:info.core_height,
      \   'topline': l:info.firstline
      \ }
    endif

    let l:ctx = {}
    let l:ctx.info = {}
    function! l:ctx.callback() abort
      let self.info.width = winwidth(0)
      let self.info.height = winheight(0)
      let self.info.core_width = self.info.width
      let self.info.core_height = self.info.height
      let self.info.topline = line('w0')
    endfunction
    call s:do(a:winid, { -> l:ctx.callback() })
    return l:ctx.info
  endfunction
endif

"
" find
"
function! s:find(callback) abort
  let l:winids = []
  let l:winids += map(range(1, tabpagewinnr(tabpagenr(), '$')), 'win_getid(v:val)')
  let l:winids += s:_get_visible_popup_winids()
  return filter(l:winids, 'a:callback(v:val)')
endfunction

"
" is_floating
"
if has('nvim')
  function! s:is_floating(winid) abort
    let l:config = nvim_win_get_config(a:winid)
    return empty(l:config) || !empty(get(l:config, 'relative', ''))
  endfunction
else
  function! s:is_floating(winid) abort
    return winheight(a:winid) != -1 && win_id2win(a:winid) == 0
  endfunction
endif

"
" scroll
"
function! s:scroll(winid, topline) abort
  let l:ctx = {}
  function! l:ctx.callback(winid, topline) abort
    let l:wininfo = s:info(a:winid)
    let l:topline = a:topline
    let l:topline = min([l:topline, line('$') - l:wininfo.core_height + 1])
    let l:topline = max([l:topline, 1])

    if l:topline == l:wininfo.topline
      return
    endif

    if !has('nvim') && s:is_floating(a:winid)
      call popup_setoptions(a:winid, {
      \   'firstline': l:topline,
      \ })
    else
      let l:delta = l:topline - l:wininfo.topline
      let l:key = l:delta > 0 ? "\<C-e>" : "\<C-y>"
      execute printf('noautocmd silent normal! %s', repeat(l:key, abs(l:delta)))
    endif
  endfunction
  call s:do(a:winid, { -> l:ctx.callback(a:winid, a:topline) })
endfunction

"
" screenpos
"
" @param {[number, number]} pos - position on the current buffer.
"
function! s:screenpos(pos) abort
  let l:y = a:pos[0]
  let l:x = a:pos[1] + get(a:pos, 2, 0)

  let l:view = winsaveview()
  let l:scroll_x = l:view.leftcol
  let l:scroll_y = l:view.topline

  let l:winpos = win_screenpos(win_getid())
  let l:y = l:winpos[0] + l:y - l:scroll_y
  let l:x = l:winpos[1] + l:x - l:scroll_x
  return [l:y, l:x + (wincol() - virtcol('.')) - 1]
endfunction

"
" _get_visible_popup_winids
"
function! s:_get_visible_popup_winids() abort
  if !exists('*popup_list')
    return []
  endif
  return filter(popup_list(), 'popup_getpos(v:val).visible')
endfunction

