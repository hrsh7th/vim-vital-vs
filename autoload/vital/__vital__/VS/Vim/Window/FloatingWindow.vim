"
" is_available
"
function! s:is_available() abort
  if has('nvim')
    return v:true
  endif
  return exists('*popup_create') && exists('*popup_hide') && exists('*popup_move') && exists('*popup_getpos')
endfunction

"
" managed floating windows.
"
let s:floating_windows = {}

"
" new
"
function! s:new(...) abort
  call s:_init()

  return s:FloatingWindow.new(get(a:000, 0, {}))
endfunction

"
" _notify_opened
"
" @param {number} win
" @param {VS.Vim.Window.FloatingWindow} floating_window
"
function! s:_notify_opened(win, floating_window) abort
  let s:floating_windows[a:win] = a:floating_window
  call a:floating_window.on_opened(a:floating_window)
endfunction

"
" _notify_closed
"
function! s:_notify_closed() abort
  for [l:win, l:floating_window] in items(s:floating_windows)
    if win_id2win(l:win) == 0
      call l:floating_window.on_closed(l:floating_window)
      unlet s:floating_windows[l:win]
    endif
  endfor
endfunction

let s:FloatingWindow = {}

"
" new
"
" @param {function?} args.on_opened
" @param {function?} args.on_closed
"
function! s:FloatingWindow.new(args) abort
  return extend(deepcopy(s:FloatingWindow), {
  \   'win': v:null,
  \   'on_opened': get(a:args, 'on_opened', { -> {} }),
  \   'on_closed': get(a:args, 'on_closed', { -> {} }),
  \ })
endfunction

"
" open
"
" @param {number} args.row 0-based indexing
" @param {number} args.col 0-based indexing
" @param {number} args.width
" @param {number} args.height
" @param {string} args.winhl
" @param {number} args.bufnr
"
function! s:FloatingWindow.open(args) abort
  let l:style = {
    \   'row': a:args.row,
    \   'col': a:args.col,
    \   'width': a:args.width,
    \   'height': a:args.height,
    \ }

  if self.is_visible()
    call s:_move(self.win, l:style)
  else
    let self.win = s:_open(a:args.bufnr, l:style)
    if has('nvim')
      call setwinvar(self.win, '&winhighlight', get(a:args, 'winhl', ''))
    endif
    call s:_notify_opened(self.win, self)
  endif
endfunction

"
" close
"
function! s:FloatingWindow.close() abort
  if self.is_visible()
    call s:_close(self.win)
    call s:_notify_closed()
  endif
  let self.win = v:null
endfunction

"
" enter
"
function! s:FloatingWindow.enter() abort
  call s:_enter(self.win)
endfunction

"
" is_visible
"
function! s:FloatingWindow.is_visible() abort
  return s:_exists(self.win) ? v:true : v:false
endfunction

"
" open
"
if has('nvim')
  function! s:_open(buf, style) abort
    return nvim_open_win(a:buf, v:false, s:_style(a:style))
  endfunction
else
  function! s:_open(buf, style) abort
    return popup_create(a:buf, s:_style(a:style))
  endfunction
endif

"
" close
"
if has('nvim')
  function! s:_close(win) abort
    call nvim_win_close(a:win, v:true)
  endfunction
else
  function! s:_close(win) abort
    call popup_hide(a:win)
  endfunction
endif

"
" move
"
if has('nvim')
  function! s:_move(win, style) abort
    call nvim_win_set_config(a:win, s:_style(a:style))
  endfunction
else
  function! s:_move(win, style) abort
    call popup_move(a:win, s:_style(a:style))
  endfunction
endif

"
" enter
"
if has('nvim')
  function! s:_enter(win) abort
    call win_gotoid(a:win)
  endfunction
else
  function! s:_enter(win) abort
    " not supported.
  endfunction
endif

"
" exists
"
if has('nvim')
  function! s:_exists(win) abort
    return type(a:win) == type(0) && nvim_win_is_valid(a:win) && nvim_win_get_number(a:win) != -1
  endfunction
else
  function! s:_exists(win) abort
    return type(a:win) == type(0) && !empty(popup_getpos(a:win))
  endfunction
endif

"
" style
"
if has('nvim')
  function! s:_style(style) abort
    return {
    \   'relative': 'editor',
    \   'width': a:style.width,
    \   'height': a:style.height,
    \   'row': a:style.row,
    \   'col': a:style.col,
    \   'focusable': v:true,
    \   'style': 'minimal',
    \ }
  endfunction
else
  function! s:_style(style) abort
    return {
    \   'line': a:style.row + 1,
    \   'col': a:style.col + 1,
    \   'pos': 'topleft',
    \   'moved': [0, 0, 0],
    \   'scrollbar': 0,
    \   'maxwidth': a:style.width,
    \   'maxheight': a:style.height,
    \   'minwidth': a:style.width,
    \   'minheight': a:style.height,
    \   'tabpage': 0,
    \ }
  endfunction
endif

"
" init
"
let s:has_init = v:false
function! s:_init() abort
  if s:has_init
    return
  endif
  let s:has_init = v:true
  augroup printf('<sfile>')
    autocmd!
    autocmd WinEnter * call <SID>_notify_closed()
  augroup END
endfunction

