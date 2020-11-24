" @see https://code.visualstudio.com/docs/languages/identifiers
let s:_filetype_language_id_map = {
\   'sh': 'shellscript',
\   'javascript.tsx': 'javascriptreact',
\   'typescript.tsx': 'typescriptreact',
\   'plaintex': 'latex',
\ }

"
" from_filetype
"
function! s:from_filetype(filetype) abort
  return get(s:_filetype_language_id_map, a:filetype, a:filetype)
endfunction

"
" to_filetype
"
function! s:to_filetype(language_id) abort
  for [l:filetype, l:language_id] in items(s:_filetype_language_id_map)
    if l:language_id ==# a:language_id
      return l:filetype
    endif
  endfor
  return a:language_id
endfunction

