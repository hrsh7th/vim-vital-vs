let s:encode_cache = {}
let s:decode_cache = {}

"
" is_windows
"
function! s:is_windows(v) abort
  let s:_is_windows = a:v
endfunction
let s:_is_windows = has('win16') || has('win32') || has('win64') || has('win')

"
" clear
"
function! s:clear() abort
  let s:encode_cache = {}
  let s:decode_cache = {}
endfunction

"
" encode
"
" @see https://github.com/microsoft/vscode-uri/blob/master/src/uri.ts#L486
"
function! s:encode(path) abort
  let l:path = a:path
  let l:path = empty(l:path) ? getcwd() : l:path
  let l:path = s:_is_windows ? substitute(l:path, '\%(\\\\\|\\\)', '/', 'g') : l:path
  let l:path = s:_is_windows ? substitute(l:path, '^\(\w\)\ze:', '\=tolower(submatch(1))', 'g') : l:path
  let l:path = s:_fullpath(l:path)
  if has_key(s:encode_cache, l:path)
    return s:encode_cache[l:path]
  endif

  let l:uri = 'file://' . substitute(l:path, '\([^a-zA-Z0-9-._~/]\)', '\=s:_encode_char(submatch(1))', 'g')
  let s:encode_cache[l:path] = l:uri
  return l:uri
endfunction

"
" decode
"
function! s:decode(uri) abort
  if has_key(s:decode_cache, a:uri)
    return s:decode_cache[a:uri]
  endif

  let l:path = a:uri
  let l:path = substitute(l:path, '^\w*://', '', 'g')
  let l:path = substitute(l:path, '%\(\x\x\)', '\=printf("%c", str2nr(submatch(1), 16))', 'g')
  let l:path = s:_is_windows ? substitute(l:path, '/\ze\w:', '', 'g') : l:path
  let l:path = s:_is_windows ? substitute(l:path, '/', '\\\\', 'g') : l:path
  let s:decode_cache[a:uri] = l:path
  return l:path
endfunction

"
" _encode_char
"
function! s:_encode_char(char) abort
  return join(map(range(0, strlen(a:char) - 1), 'printf("%%%02X", char2nr(a:char[v:val]))'), '')
endfunction

"
" _fullpath
"
function! s:_fullpath(path) abort
  let l:path = fnamemodify(a:path, ':p')
  let l:path = l:path[-1 : -1] ==# '/' ? l:path[0 : -2] : l:path
  let l:path = l:path[0 : 0] ==# '/' ? l:path : '/' . l:path
  return l:path
endfunction

