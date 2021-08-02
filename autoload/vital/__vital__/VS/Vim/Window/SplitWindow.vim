"
" _vital_loaded
"
function! s:_vital_loaded(V) abort
  let s:Window = a:V.import('VS.Vim.Window')
endfunction

"
" _vital_depends
"
function! s:_vital_depends() abort
  return ['VS.Vim.Window']
endfunction

"
" managed windows.
"
let s:windows = {}

"
" new
"
function! s:new(...) abort
  call s:_init()

  return s:SplitWindow.new(get(a:000, 0, {}))
endfunction

"
" _notify_opened
"
" @param {number} winid
" @param {VS.Vim.Window.FloatingWindow} floating_window
"
function! s:_notify_opened(winid, window) abort
  let s:windows[a:winid] = a:window
  call a:window._on_opened()
endfunction

"
" _notify_closed
"
function! s:_notify_closed() abort
  for [l:winid, l:window] in items(s:windows)
    if winheight(l:winid) == -1
      call l:window._on_closed()
      unlet s:windows[l:winid]
    endif
  endfor
endfunction

let s:SplitWindow = {}

"
" new
"
" @param {function?} args.on_opened
" @param {function?} args.on_closed
"
function! s:SplitWindow.new(args) abort
  return extend(deepcopy(s:SplitWindow), {
  \   '_winid': v:null,
  \   '_bufnr': v:null,
  \   '_vars': {},
  \   '_on_opened': get(a:args, 'on_opened', { -> {} }),
  \   '_on_closed': get(a:args, 'on_closed', { -> {} }),
  \ })
endfunction

"
" set_bufnr
"
" @param {number} bufnr
"
function! s:SplitWindow.set_bufnr(bufnr) abort
  let self._bufnr = a:bufnr
endfunction

"
" get_bufnr
"
function! s:SplitWindow.get_bufnr() abort
  return self._bufnr
endfunction

"
" get_winid
"
function! s:SplitWindow.get_winid() abort
  if self.is_visible()
    return self._winid
  endif
  return v:null
endfunction

"
" info
"
function! s:SplitWindow.info() abort
  if self.is_visible()
    let l:info = getwininfo(self._winid)[0]
    return {
    \   'row': l:info.winrow,
    \   'col': l:info.wincol,
    \   'width': l:info.width,
    \   'height': l:info.height,
    \   'topline': l:info.topline,
    \ }
  endif
  return v:null
endfunction

"
" set_var
"
" @param {string}  key
" @param {unknown} value
"
function! s:SplitWindow.set_var(key, value) abort
  let self._vars[a:key] = a:value
  if self.is_visible()
    call setwinvar(self._winid, a:key, a:value)
  endif
endfunction

"
" get_var
"
" @param {string} key
"
function! s:SplitWindow.get_var(key) abort
  return self._vars[a:key]
endfunction

"
" open
"
" @param {string} args.move - H J K L
" @param {number} args.size
" @param {number?} args.topline
"
function! s:SplitWindow.open(args) abort
  let l:will_move = self.is_visible()
  if l:will_move
    let self._winid = s:_move(self, self._winid, self._bufnr, a:args)
  else
    let self._winid = s:_open(self, self._bufnr, a:args)
  endif
  for [l:key, l:value] in items(self._vars)
    call setwinvar(self._winid, l:key, l:value)
  endfor
  if !l:will_move
    call s:_notify_opened(self._winid, self)
  endif
endfunction

"
" close
"
function! s:SplitWindow.close() abort
  if self.is_visible()
    execute printf('noautocmd silent %sclose', win_id2win(self._winid))
  endif
  let self._winid = v:null
endfunction

"
" enter
"
function! s:SplitWindow.enter() abort
  if self.is_visible()
    call win_gotoid(self._winid)
  endif
endfunction

"
" is_visible
"
function! s:SplitWindow.is_visible() abort
  return win_id2win(self._winid) != 0
endfunction

"
" _open
"
function! s:_open(self, bufnr, args) abort
  let l:cmd = {
  \   'H': 'vertical topleft split',
  \   'J': 'botright split',
  \   'K': 'topleft split',
  \   'L': 'vertical botright split'
  \ }[a:args.move]
  let l:prev_winid = win_getid()
  execute printf('noautocmd silent %s #%s', l:cmd, a:bufnr)
  let l:next_winid = win_getid()
  call s:_layout(win_id2win(l:next_winid), a:args.move, a:args.size)
  " noautocmd silent! win_gotoid(l:prev_winid)
  return l:next_winid
endfunction

"
" _move
"
function! s:_move(self, winid, bufnr, args) abort
  let l:winnr = win_id2win(a:winid)
  execute printf('noautocmd silent %swincmd %s', l:winnr, a:args.move)
  call s:_layout(l:winnr, a:args.move, a:args.size)
  if winbufnr(l:winnr) != a:bufnr
    call s:Window.do(a:winid, { -> execute('noautocmd silent %sbuffer', a:bufnr) })
  endif
endfunction

"
" _layout
"
function! s:_layout(winnr, move, size) abort
  if a:move ==# 'H' || a:move ==# 'L'
    echomsg printf('noautocmd silent vertical %sresize %s', a:winnr, a:size)
  elseif a:move ==# 'J' || a:move ==# 'K'
    echomsg printf('noautocmd silent %sresize %s', a:winnr, a:size)
  endif
endfunction

"
" init
"
let s:has_init = v:false
let s:filepath = expand('<sfile>:p')
function! s:_init() abort
  if s:has_init || !has('nvim')
    return
  endif
  let s:has_init = v:true
  execute printf('augroup VS_Vim_Window_SplitWindow:%s', s:filepath)
    autocmd!
    autocmd WinEnter * call <SID>_notify_closed()
  augroup END
endfunction


