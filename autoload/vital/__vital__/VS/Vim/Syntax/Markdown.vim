function! s:apply(text, ...) abort
  if !exists('b:___VS_Vim_Syntax_Markdown')
    runtime! syntax/markdown.vim
    let b:___VS_Vim_Syntax_Markdown = {}
  endif

  try
    for [l:mark, l:filetype] in items(s:_get_filetype_map(a:text, get(a:000, 0, {})))
      let l:group = substitute(toupper(l:mark), '\.', '_', 'g')
      if has_key(b:___VS_Vim_Syntax_Markdown, l:group)
        continue
      endif
      let b:___VS_Vim_Syntax_Markdown[l:group] = v:true

      try
        unlet b:current_syntax
        execute printf('syntax include @%s syntax/%s.vim', l:group, l:filetype)
        execute printf('syntax region %s matchgroup=Conceal start=/%s/rs=e matchgroup=Conceal end=/%s/re=s contains=@%s containedin=ALL keepend concealends',
        \   l:group,
        \   printf('^\s*```\s*%s\s*', l:mark),
        \   '\s*```\s*$',
        \   l:group
        \ )
      catch /.*/
        echomsg printf("[VS.Vim.Syntax.Markdown] `%s` isn't valid filetype.")
        echomsg printf('[VS.Vim.Syntax.Markdown] You can add `%s` to g:markdown_fenced_languages.')
      endtry
    endfor
  catch /.*/
    echomsg string({ 'exception': v:exception, 'throwpoint': v:throwpoint })
  endtry
endfunction

"
" _get_filetype_map
"
function! s:_get_filetype_map(text, filetype_map) abort
  let l:filetype_map = {}
  for l:mark in s:_find_marks(a:text)
    let l:filetype_map[l:mark] = s:_get_filetype_from_mark(l:mark, a:filetype_map)
  endfor
  return l:filetype_map
endfunction

"
" _find_marks
"
function! s:_find_marks(text) abort
  let l:marks = {}

  " find from buffer contents.
  let l:pos = 0
  while 1
    let l:match = matchlist(a:text, '```\s*\(\w\+\)', l:pos, 1)
    if empty(l:match)
      break
    endif
    let l:marks[l:match[1]] = v:true
    let l:pos = matchend(a:text, '```\s*\(\w\+\)', l:pos, 1)
  endwhile

  return keys(l:marks)
endfunction

"
" _get_filetype_from_mark
"
function! s:_get_filetype_from_mark(mark, filetype_map) abort
  for l:config in get(g:, 'markdown_fenced_languages', [])
    if l:config !~# '='
      if l:config ==# a:mark
        return a:mark
      endif
    else
      let l:config = split(l:config, '=')
      if l:config[1] ==# a:mark
        return l:config[0]
      endif
    endif
  endfor
  return get(a:filetype_map, a:mark, a:mark)
endfunction

