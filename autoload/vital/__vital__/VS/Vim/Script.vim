let s:cache = {}

"
" call function for external source.
"
function! s:call(path, name, args) abort
  return call(printf('<SNR>%d_%s', s:id(a:path), a:name), a:args)
endfunction

"
" get sid from `expand('<sfile>')`
"
function! s:id(path) abort
  let l:path = fnamemodify(a:path, ':p:~')
  if has_key(s:cache, l:path)
    return s:cache[l:path]
  endif
  let l:match = matchlist(execute('scriptnames'), printf('\(\d\+\): \V%s', escape(l:path, '\')))
  if empty(l:match)
    throw printf('VS.Vim.Script: failed to get script id for `%s`', l:path)
  endif
  let s:cache[l:path] = l:match[1]
  return s:cache[l:path]
endfunction

"
" for testing only.
"
function! s:_spec(num1, num2) abort
  return a:num1 + a:num2
endfunction

