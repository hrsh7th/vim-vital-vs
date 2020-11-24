"
" normalize_eol
"
function! s:normalize_eol(text) abort
  return substitute(a:text, "\r\n\\|\r\\|\n", "\n", 'g')
endfunction

"
" split_by_eol
"
function! s:split_by_eol(text) abort
  return split(a:text, "\r\n\\|\r\\|\n", v:true)
endfunction

