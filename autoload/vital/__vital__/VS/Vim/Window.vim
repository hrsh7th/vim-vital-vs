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

  if exists('*win_execute')
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
  function! s:info(win) abort
    let l:info = getwininfo(a:win)[0]
    return {
    \   'width': l:info.width,
    \   'height': l:info.height,
    \   'topline': l:info.topline,
    \ }
  endfunction
else
  function! s:info(win) abort
    if exists('*popup_list') && index(popup_list(), a:win) >= 0
      let l:info = popup_getpos(a:win)
      return {
      \   'width': l:info.width,
      \   'height': l:info.height,
      \   'topline': l:info.firstline
      \ }
    endif

    let l:ctx = {}
    let l:ctx.info = {}
    function! l:ctx.callback() abort
      let self.info.width = winwidth(0)
      let self.info.height = winheight(0)
      let self.info.topline = line('w0')
    endfunction
    call s:do(a:win, { -> l:ctx.callback() })
    return l:ctx.info
  endfunction
endif

"
" find
"
function! s:find(callback) abort
  let l:winids = []
  let l:winids += map(range(1, tabpagewinnr(tabpagenr(), '$')), 'win_getid(v:val)')
  let l:winids += exists('*popup_list') ? popup_list() : []
  return filter(l:winids, 'a:callback(v:val)')
endfunction

"
" scroll
"
function! s:scroll(win, topline) abort
  let l:ctx = {}
  function! l:ctx.callback(win, topline) abort
    let l:wininfo = s:info(a:win)
    let l:topline = a:topline
    let l:topline = max([l:topline, 1])
    let l:topline = min([l:topline, line('$') - l:wininfo.height + 1])

    if l:topline == l:wininfo.topline
      return
    endif

    if exists('*popup_list') && index(popup_list(), a:win) >= 0
      call popup_setoptions(a:win, {
      \   'firstline': l:topline,
      \ })
    else
      let l:delta = l:topline - l:wininfo.topline
      let l:key = l:delta > 0 ? "\<C-e>" : "\<C-y>"
      execute printf('normal! %s', repeat(l:key, abs(l:delta)))
    endif
  endfunction
  call s:do(a:win, { -> l:ctx.callback(a:win, a:topline) })
endfunction

"
" screenpos
"
" @param {[number, number]} pos - position on the current buffer.
"
function! s:screenpos(pos) abort
  let l:ui_x = wincol() - col('.')
  let l:view = winsaveview()
  let l:scroll_x = l:view.leftcol
  let l:scroll_y = l:view.topline - 1
  let l:winpos = win_screenpos(win_getid())
  let l:origin1 = [l:winpos[0] + (a:pos[0] - l:scroll_y) - 1, l:winpos[1] + (a:pos[1] + a:pos[2] + l:ui_x - l:scroll_x) - 1]
  return [l:origin1[0] - 1, l:origin1[1] - 1]
endfunction

