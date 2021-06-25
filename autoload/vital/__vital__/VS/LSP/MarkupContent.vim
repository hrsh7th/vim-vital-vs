"
" _vital_loaded
"
function! s:_vital_loaded(V) abort
  let s:Text = a:V.import('VS.LSP.Text')
endfunction

"
" _vital_depends
"
function! s:_vital_depends() abort
  return ['VS.LSP.Text']
endfunction

"
" normalize
"
function! s:normalize(markup_content) abort
  if type(a:markup_content) == type('')
    return s:_compact(a:markup_content)
  elseif type(a:markup_content) == type([])
    return s:_compact(join(a:markup_content, "\n"))
  elseif type(a:markup_content) == type({})
    let l:string = a:markup_content.value
    if has_key(a:markup_content, 'language')
      let l:string = '```' . a:markup_content.language . ' ' . l:string . ' ```'
    elseif get(a:markup_content, 'kind', 'plaintext') ==# 'plaintext'
      let l:string = '<text>' . l:string . '</text>'
    endif
    return s:_compact(l:string)
  endif
endfunction

"
" _compact
"
function! s:_compact(string) abort
  " normalize eol.
  let l:string = s:Text.normalize_eol(a:string)

  let l:string = substitute(l:string, "\\%(\\s\\|\n\\)*```\\s*\\(\\w\\+\\)\\%(\\s\\|\n\\)\\+", "\n\n```\\1 ", 'g')
  let l:string = substitute(l:string, "\\%(\\s\\|\n\\)\\+```\\%(\\s*\\%(\\%$\\|\n\\)\\)\\+", " ```\n\n", 'g')
  let l:string = substitute(l:string, "\\%^\\%(\\s\\|\n\\)*", '', 'g')
  let l:string = substitute(l:string, "\\%(\\s\\|\n\\)*\\%$", '', 'g')

  return l:string
endfunction

