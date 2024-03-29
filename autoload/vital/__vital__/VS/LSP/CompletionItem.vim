"
" _vital_loaded
"
function! s:_vital_loaded(V) abort
  let s:Position = a:V.import('VS.LSP.Position')
  let s:TextEdit = a:V.import('VS.LSP.TextEdit')
  let s:Text = a:V.import('VS.LSP.Text')
endfunction

"
" _vital_depends
"
function! s:_vital_depends() abort
  return ['VS.LSP.Position', 'VS.LSP.TextEdit', 'VS.LSP.Text']
endfunction

"
" confirm
"
" @param {LSP.Position}                                                 args.suggest_position
" @param {LSP.Position}                                                 args.request_position
" @param {LSP.Position}                                                 args.current_position
" @param {string}                                                       args.current_line
" @param {LSP.CompletionItem}                                           args.completion_item
" @param {(args: { body: string; insert_text_mode: number; }) => void?} args.expand_snippet
"
" # Pre-condition
"
"   - You must pass `current_position` that represents the position when `CompleteDone` was fired.
"   - You must pass `current_line` that represents the line when `CompleteDone` was fired.
"   - You must call this function after the commit characters has been inserted.
"
" # The positoins
"
"   0. The example case
"
"     call getbufl|<C-x><C-o><C-n><C-y>   ->   call getbufline|
"
"   1. suggest_position
"
"     call |getbufline
"
"   2. request_position
"
"     call getbufl|ine
"
"   3. current_position
"
"     call getbufline|
"
"
function! s:confirm(args) abort
  let l:suggest_position = a:args.suggest_position
  let l:request_position = a:args.request_position
  let l:current_position = a:args.current_position
  let l:current_line = a:args.current_line
  let l:completion_item = a:args.completion_item
  let l:ExpandSnippet = get(a:args, 'expand_snippet', v:null)

  " 1. Prepare for alignment to VSCode behavior.
  let l:expansion = s:_get_expansion({
  \   'suggest_position': l:suggest_position,
  \   'request_position': l:request_position,
  \   'current_position': l:current_position,
  \   'current_line': l:current_line,
  \   'completion_item': l:completion_item,
  \ })
  if !empty(l:expansion)
    " Remove commit characters if expansion is needed.
    if getline('.') !=# l:current_line
      call setline(l:current_position.line + 1, l:current_line)
      call cursor(s:Position.lsp_to_vim('%', l:current_position))
    endif

    " Restore state of the timing when `textDocument/completion` was sent.
    call s:TextEdit.apply('%', [{
    \   'range': { 'start': l:request_position, 'end': l:current_position },
    \   'newText': ''
    \ }])
  endif

  " 2. Apply additionalTextEdits
  if type(get(l:completion_item, 'additionalTextEdits', v:null)) == type([])
    call s:TextEdit.apply('%', l:completion_item.additionalTextEdits)
  endif

  " 3. Apply expansion
  if !empty(l:expansion)
    let l:current_position = s:Position.cursor() " Update current_position to after additionalTextEdits.
    let l:range = {
    \   'start': extend({
    \     'character': l:current_position.character - l:expansion.overflow_before,
    \   }, l:current_position, 'keep'),
    \   'end': extend({
    \     'character': l:current_position.character + l:expansion.overflow_after,
    \   }, l:current_position, 'keep')
    \ }

    " Snippet.
    if l:expansion.is_snippet && !empty(l:ExpandSnippet)
      call s:TextEdit.apply('%', [{ 'range': l:range, 'newText': '' }])
      call cursor(s:Position.lsp_to_vim('%', l:range.start))
      call l:ExpandSnippet({ 'body': l:expansion.new_text, 'insert_text_mode': get(l:completion_item, 'insertTextMode', 2) })

    " TextEdit.
    else
      call s:TextEdit.apply('%', [{ 'range': l:range, 'newText': l:expansion.new_text }])

      " Move cursor position to end of new_text like as snippet.
      let l:lines = s:Text.split_by_eol(l:expansion.new_text)
      let l:cursor = copy(l:range.start)
      let l:cursor.line += len(l:lines) - 1
      let l:cursor.character = strchars(l:lines[-1]) + (len(l:lines) == 1 ? l:cursor.character : 0)
      call cursor(s:Position.lsp_to_vim('%', l:cursor))
    endif
  endif
endfunction

"
" _get_expansion
"
function! s:_get_expansion(args) abort
  let l:current_line = a:args.current_line
  let l:suggest_position = a:args.suggest_position
  let l:request_position = a:args.request_position
  let l:current_position = a:args.current_position
  let l:completion_item = a:args.completion_item

  let l:is_snippet = get(l:completion_item, 'insertTextFormat', 1) == 2
  if type(get(l:completion_item, 'textEdit', v:null)) == type({})
    let l:inserted_text = strcharpart(l:current_line, l:request_position.character, l:current_position.character - l:request_position.character)
    let l:overflow_before = l:request_position.character - l:completion_item.textEdit.range.start.character
    let l:overflow_after = l:completion_item.textEdit.range.end.character - l:request_position.character
    let l:inserted = ''
    \   . strcharpart(l:current_line, l:request_position.character - l:overflow_before, l:overflow_before)
    \   . strcharpart(l:current_line, l:request_position.character, strchars(l:inserted_text) + l:overflow_after)
    let l:new_text = l:completion_item.textEdit.newText
    if s:_trim_tabstop(l:new_text) !=# l:inserted
      " The LSP spec says `textEdit range must contain the request position.`
      return {
      \   'overflow_before': max([0, l:overflow_before]),
      \   'overflow_after': max([0, l:overflow_after]),
      \   'new_text': l:new_text,
      \   'is_snippet': l:is_snippet,
      \ }
    endif
  else
    let l:inserted = strcharpart(l:current_line, l:suggest_position.character, l:current_position.character - l:suggest_position.character)
    let l:new_text = get(l:completion_item, 'insertText', v:null)
    let l:new_text = !empty(l:new_text) ? l:new_text : l:completion_item.label
    if s:_trim_tabstop(l:new_text) !=# l:inserted
      return {
      \   'overflow_before': l:request_position.character - l:suggest_position.character,
      \   'overflow_after': 0,
      \   'new_text': l:new_text,
      \   'is_snippet': l:is_snippet,
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

