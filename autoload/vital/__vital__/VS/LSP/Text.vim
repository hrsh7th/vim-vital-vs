"
" normalize_eol
"
function! s:normalize_eol(text) abort
  let l:text = a:text
  let l:text = substitute(l:text, "\r\n", "\n", 'g')
  let l:text = substitute(l:text, "\r", "\n", 'g')
  return l:text
endfunction

"
" split_by_eol
"
function! s:split_by_eol(text) abort
  return split(a:text, "\r\n\\|\r\\|\n", v:true)
endfunction

