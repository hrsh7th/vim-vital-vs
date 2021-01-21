function! s:_vital_loaded(V) abort
  let s:Position = a:V.import('VS.LSP.Position')
  let s:TextEdit = a:V.import('VS.LSP.TextEdit')
  let s:Text = a:V.import('VS.LSP.Text')
endfunction

"
" confirm
"
" @param {v:completed_item} completed_item
" @param {LSP.Position} request_position
" @param {LSP.CompletionItem} completion_item
" @param {(args: { body: string; }) => void} snippet
"
" # Pre condition
" This method will work only accepting item via `<C-y>` and the cursor position must be the end of completed word.
"
" # The positoins
"
"   0. The example case
"
"     call getbufl|<C-x><C-o><C-n><C-y>   ->   call getbufline|
"
"   1. current_position
"
"     call getbufline|
"
"   2. request_position
"
"     call getbufl|ine
"
"   3. suggest_position
"
"     call |getbufline
"
"
function! s:confirm(completed_item, request_position, completion_item, ...) abort
  let l:Snippet = get(a:000, 0, v:null)
  let l:current_position = s:Position.cursor()
  let l:suggest_position = { 'line': l:current_position.line, 'character': l:current_position.character - strchars(a:completed_item.word) }

  " 1. Restore state of the timing when `textDocument/completion` was sent if expansion is needed
  let l:replacement = s:_get_replacement(l:suggest_position, l:current_position, a:request_position, a:completion_item)
  if !empty(l:replacement)
    call s:TextEdit.apply('%', [{
    \   'range': { 'start': a:request_position, 'end': l:current_position },
    \   'newText': ''
    \ }])
  endif

  " 2. Apply additionalTextEdits
  if type(get(a:completion_item, 'additionalTextEdits', v:null)) == type([])
    call s:TextEdit.apply('%', a:completion_item.additionalTextEdits)
  endif

  " 3. Apply expansion
  if !empty(l:replacement)
    let l:current_position = s:Position.cursor() " Update current_position to after additionalTextEdits.
    let l:range = {
    \   'start': extend({
    \     'character': l:current_position.character - l:replacement.overflow_before,
    \   }, l:current_position, 'keep'),
    \   'end': extend({
    \     'character': l:current_position.character + l:replacement.overflow_after,
    \   }, l:current_position, 'keep')
    \ }

    " Snippet.
    if l:replacement.is_snippet && !empty(l:Snippet)
      call s:TextEdit.apply('%', [{ 'range': l:range, 'newText': '' }])
      call l:Snippet({ 'body': l:replacement.new_text })

    " TextEdit.
    else
      call s:TextEdit.apply('%', [{ 'range': l:range, 'newText': l:replacement.new_text }])

      " Move cursor position to end of new_text like as snippet.
      let l:lines = s:Text.split_by_eol(l:replacement.new_text)
      let l:cursor = copy(l:range.start)
      let l:cursor.line += len(l:lines) - 1
      let l:cursor.character = len(l:lines) == 1 ? l:cursor.character + strchars(l:lines[-1]) : strchars(l:lines[-1])
      call cursor(s:Position.lsp_to_vim('%', l:cursor))
    endif
  endif
endfunction

"
" _get_replacement
"
function! s:_get_replacement(suggest_position, current_position, request_position, completion_item) abort
  let l:line = getline('.')
  let l:is_snippet = get(a:completion_item, 'insertTextFormat', 1) == 2
  if type(get(a:completion_item, 'textEdit', v:null)) == type({})
    let l:inserted_text = strcharpart(l:line, a:request_position.character, a:current_position.character - a:request_position.character)
    let l:overflow_before = a:request_position.character - a:completion_item.textEdit.range.start.character
    let l:overflow_after = a:completion_item.textEdit.range.end.character - a:request_position.character
    let l:inserted = ''
    \   . strcharpart(l:line, a:request_position.character - l:overflow_before, l:overflow_before)
    \   . strcharpart(l:line, a:request_position.character, strchars(l:inserted_text) + l:overflow_after)
    let l:new_text = a:completion_item.textEdit.newText
    if s:_trim_tabstop(l:new_text) !=# l:inserted
      return {
      \   'overflow_before': l:overflow_before,
      \   'overflow_after': l:overflow_after,
      \   'new_text': l:new_text,
      \   'is_snippet': l:is_snippet,
      \ }
    endif
  elseif l:is_snippet
    let l:inserted = strcharpart(l:line, a:suggest_position.character, a:current_position.character - a:suggest_position.character)
    let l:new_text = get(a:completion_item, 'insertText', a:completion_item.label)
    if s:_trim_tabstop(l:new_text) !=# l:inserted
      return {
      \   'overflow_before': a:request_position.character - a:suggest_position.character,
      \   'overflow_after': 0,
      \   'new_text': l:new_text,
      \   'is_snippet': v:true,
      \ }
    endif
  endif
  return {}
endfunction

"
" _trim_tabstop
"
function! s:_trim_tabstop(text) abort
  return substitute(a:text, '\%(\$0\|\${0}\)$', '', 'g')
endfunction

