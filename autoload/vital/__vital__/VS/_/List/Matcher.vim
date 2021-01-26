let s:file = expand('<sfile>:p:h') . '/Matcher.lua'

"
" _vital_depends
"
function! s:_vital_depends() abort
  return {
  \   'files': ['./Matcher.lua']
  \ }
endfunction

"
" match
"
function! s:match(args) abort
  let l:items = a:args.items
  let l:query = a:args.query
  let l:key = get(a:args, 'key', v:null)
  try
    if has('nvim')
      return luaeval(printf('dofile("%s").match(_A[1], _A[2], _A[3])', s:file), [l:items, l:query, l:key])
    else
      return matchfuzzy(l:items, l:query, { 'key': l:key })
    endif
  catch /.*/
    echomsg string({ 'exception': v:exception, 'throwpoint': v:throwpoint })
  endtry
  return []
endfunction

