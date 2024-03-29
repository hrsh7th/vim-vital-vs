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
      let l:normalized = join([
      \   '```' . a:markup_content.language,
      \   l:normalized,
      \   '```'
      \ ], "\n")
    endif
  endif
  let l:normalized = s:Text.normalize_eol(l:normalized)
  let l:normalized = s:_format(l:normalized, l:option.compact)
  return l:normalized
endfunction

"
" _format
"
function! s:_format(string, compact) abort
  let l:string = a:string
  if a:compact
    let l:string = substitute(l:string, "\\%(\\s\\|\n\\)*```\\s*\\(\\w\\+\\)\\%(\\s\\|\n\\)\\+", "\n\n```\\1 ", 'g')
    let l:string = substitute(l:string, "\\%(\\s\\|\n\\)\\+```\\%(\\s*\\%(\\%$\\|\n\\)\\)\\+", " ```\n\n", 'g')
  else
    let l:string = substitute(l:string, "```\n\\zs\\%(\\s\\|\n\\)\\+", "", 'g')
  endif
  let l:string = substitute(l:string, "\\%^\\%(\\s\\|\n\\)*", '', 'g')
  let l:string = substitute(l:string, "\\%(\\s\\|\n\\)*\\%$", '', 'g')
  return l:string
endfunction

