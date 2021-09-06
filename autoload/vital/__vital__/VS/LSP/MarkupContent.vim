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
function! s:normalize(markup_content, ...) abort
  let l:option = get(a:000, 0, {})
  let l:option.compact = get(l:option, 'compact', v:true)

  let l:normalized = ''
  if type(a:markup_content) == type('')
    let l:normalized = a:markup_content
  elseif type(a:markup_content) == type([])
    let l:normalized = join(a:markup_content, "\n")
  elseif type(a:markup_content) == type({})
    let l:normalized = a:markup_content.value
    if has_key(a:markup_content, 'language')
      let l:normalized = '```' . a:markup_content.language . ' ' . l:normalized . ' ```'
    endif
  endif
  if l:option.compact
    return s:_compact(l:normalized)
  endif
  return l:normalized
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

