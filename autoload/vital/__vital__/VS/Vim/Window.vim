function! s:_vital_loaded(V) abort
  let s:Buffer = a:V.import('VS.Vim.Buffer')
endfunction

function! s:_vital_depends() abort
  return ['VS.Vim.Buffer']
endfunction

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
" set_var
"
function! s:set_var(win, key, value) abort
  if win_gettype(a:win) !=# 'unknown'
    let l:map = getwinvar(a:win, '___VS_Vim_Window', {})
    let l:map[a:key] = a:value
    call setwinvar(a:win, '___VS_Vim_Window', l:map)
  endif
endfunction

"
" get_var
"
function! s:get_var(win, key) abort
  if win_gettype(a:win) !=# 'unknown'
    let l:map = getwinvar(a:win, '___VS_Vim_Window', {})
    return get(l:map, a:key, v:null)
  endif
  return v:null
endfunction

"
" scroll
"
function! s:scroll(delta) abort
  if a:delta == 0
    return
  endif

  let l:wins = []
  let l:wins += map(range(1, tabpagewinnr(tabpagenr(), '$')), 'win_getid(v:val)')
  let l:wins += exists('*popup_list') ? popup_list() : []
  for l:win in l:wins
    if s:get_var(l:win, 'scrollable')
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
        if win_gettype(a:win) ==# 'popup' && exists('*popup_create')
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
      call timer_start(0, { -> s:do(l:win, function(l:ctx.callback, [l:win, a:delta], l:ctx)) })
      break
    endif
  endfor
  return "\<Ignore>"
endfunction

"
" screenpos
"
function! s:screenpos(pos) abort
  let l:pos = getpos('.')
  let l:scroll_x = (l:pos[2] + l:pos[3]) - wincol()
  let l:scroll_y = l:pos[1] - winline()
  let l:winpos = win_screenpos(win_getid())
  return [l:winpos[0] + (a:pos[0] - l:scroll_y) - 2, l:winpos[1] + (a:pos[1] - l:scroll_x) - 2]
endfunction

