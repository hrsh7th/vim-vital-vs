"
" define
"
function! s:define(map) abort
  let l:old = {}
  for [l:key, l:value] in items(a:map)
    let l:old[l:key] = eval(printf('&%s', l:key))
    execute printf('let &%s = "%s"', l:key, l:value)
  endfor
  return { -> s:define(l:old) }
endfunction

