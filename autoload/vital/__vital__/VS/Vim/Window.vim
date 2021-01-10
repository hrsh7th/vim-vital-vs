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
" scrollable
"
function! s:scrollable(win, ...) abort
  if len(a:000) == 1
    call s:set_var(a:win, 'scrollable', a:000[0])
  else
    return s:get_var(a:win, 'scrollable')
  endif
endfunction

"
" set_var
"
function! s:set_var(win, key, value) abort
  if winheight(a:win) != -1
    let l:map = getwinvar(a:win, '___VS_Vim_Window', {})
    let l:map[a:key] = a:value
    call setwinvar(a:win, '___VS_Vim_Window', l:map)
  endif
endfunction

"
" get_var
"
function! s:get_var(win, key) abort
  if winheight(a:win) != -1
    let l:map = getwinvar(a:win, '___VS_Vim_Window', {})
    return get(l:map, a:key, v:null)
  endif
  return v:null
endfunction

"
" scroll
"
" NOTE: We can't test it because it uses timer.
"
function! s:scroll(delta) abort
  if a:delta == 0
    return
  endif

  let l:wins = []
  let l:wins += map(range(1, tabpagewinnr(tabpagenr(), '$')), 'win_getid(v:val)')
  let l:wins += exists('*popup_list') ? popup_list() : []
  for l:win in l:wins
    if s:scrollable(l:win)
      let l:ctx = {}
      function! l:ctx.callback(win, delta) abort
        let l:height = line('w$') - line('w0')
        let l:topline = line('w0') + a:delta
        let l:topline = max([l:topline, 1])
        let l:topline = min([l:topline, line('$') - l:height])
        let l:delta = l:topline - line('w0')
        if l:delta == 0
          return
        endif

        if exists('*popup_create') && !empty(popup_getpos(a:win))
          call popup_setoptions(a:win, {
          \   'firstline': l:topline,
          \ })
        else
          execute printf('normal! %s%s%s%s',
          \   abs(l:delta),
          \   l:delta >= 0 ? "\<C-e>" : "\<C-y>",
          \   abs(l:delta),
          \   l:delta >= 0 ? 'j' : 'k',
          \ )
        endif
      endfunction
      call timer_start(0, { -> s:do(l:win, { -> l:ctx.callback(l:win, a:delta) }) })
      break
    endif
  endfor
  return "\<Ignore>"
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

