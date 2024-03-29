"
" _vital_loaded
"
function! s:_vital_loaded(V) abort
  let s:LanguageId = a:V.import('VS.LSP.LanguageId')
  let s:Dict = a:V.import('VS.VimL.Dict')
endfunction

"
" _vital_depends
"
function! s:_vital_depends() abort
  return ['VS.LSP.LanguageId', 'VS.VimL.Dict']
endfunction

"
" The dummy id for static capabilities.
"
let s:dummy_id = 0

"
" The mapping to method and capability property path.
"
let s:method_property_path_mapping = {
\   'workspace/workspaceFolders': ['workspace', 'workspaceFolders'],
\   'workspace/symbol': ['workspaceSymbolProvider'],
\   'workspace/executeCommand': ['executeCommandProvider'],
\   'workspace/willCreateFiles': ['workspace', 'fileOperations', 'willCreate'],
\   'workspace/didCreateFiles': ['workspace', 'fileOperations', 'didCreate'],
\   'workspace/willRenameFiles': ['workspace', 'fileOperations', 'willRename'],
\   'workspace/didRenameFiles': ['workspace', 'fileOperations', 'didRename'],
\   'workspace/willDeleteFiles': ['workspace', 'fileOperations', 'willDelete'],
\   'workspace/didDeleteFiles': ['workspace', 'fileOperations', 'didDelete'],
\   'textDocument/didOpen': ['textDocumentSync'],
\   'textDocument/didChange': ['textDocumentSync'],
\   'textDocument/didClose': ['textDocumentSync'],
\   'textDocument/willSave': ['textDocumentSync', 'willSave'],
\   'textDocument/willSaveWaitUntil': ['textDocumentSync', 'willSaveWaitUntil'],
\   'textDocument/didSave': ['textDocumentSync', 'save'],
\   'textDocument/completion': ['completionProvider'],
\   'textDocument/hover': ['hoverProvider'],
\   'textDocument/signatureHelp': ['signatureHelpProvider'],
\   'textDocument/declaration': ['declarationProvider'],
\   'textDocument/definition': ['definitionProvider'],
\   'textDocument/typeDefinition': ['typeDefinitionProvider'],
\   'textDocument/implementation': ['implementationProvider'],
\   'textDocument/references': ['referencesProvider'],
\   'textDocument/documentHighlight': ['documentHighlight'],
\   'textDocument/documentSymbol': ['documentSymbolProvider'],
\   'textDocument/codeAction': ['codeActionProvider'],
\   'textDocument/codeLens': ['codeLensProvider'],
\   'textDocument/documentLink': ['documentLinkProvider'],
\   'textDocument/documentColor': ['colorProvider'],
\   'textDocument/formatting': ['documentFormattingProvider'],
\   'textDocument/rangeFormatting': ['documentRangeFormattingProvider'],
\   'textDocument/onTypeFormatting': ['documentOnTypeFormattingProvider'],
\   'textDocument/rename': ['renameProvider'],
\   'textDocument/foldingRange': ['foldingRangeProvider'],
\   'textDocument/selectionRange': ['selectionRangeProvider'],
\   'textDocument/prepareCallHierarchy': ['callHierarchyProvider'],
\   'textDocument/semanticTokens': ['semanticTokensProvider'],
\   'textDocument/linkedEditingRange': ['linkedEditingRangeProvider'],
\   'textDocument/moniker': ['monikerProvider'],
\ }

"
" new
"
function! s:new(capabilities) abort
  return s:ServerCapabilities.new(a:capabilities)
endfunction

let s:ServerCapabilities = {}

"
" new
"
function! s:ServerCapabilities.new(capabilities) abort
  return extend(deepcopy(s:ServerCapabilities), {
  \   '_static': a:capabilities,
  \   '_dynamics': {},
  \ })
endfunction

"
" get_by_text_document
"
" @param {{ filetype?: string; language?: string; uri: string; }} doc
"
function! s:ServerCapabilities.get_by_text_document(doc, keys) abort
  for [l:id, l:register_options] in items(s:Dict.get(self._dynamics, a:keys, {}))
    for l:filter in get(l:register_options, 'documentSelector', [])
      let l:match = v:true
      if l:match && has_key(l:filter, 'language')
        let l:match = l:match && a:doc.language ==# l:filter.language
      endif
      if l:match && has_key(l:filter, 'filetype')
        let l:match = l:match && s:LanguageId.from_filetype(a:doc.filetype) ==# l:filter.language
      endif
      if l:match && has_key(l:filter, 'pattern')
        let l:match = l:match && match(glob2regpat(l:filter.pattern), a:doc.uri) != -1
      endif
      if l:match
        return l:register_options
      endif
    endfor
  endfor
  return s:Dict.get(self._statics, a:keys, v:null)
endfunction

"
" register
"
function! s:ServerCapabilities.register(method, id, register_options) abort
  if !has_key(s:method_property_path_mapping, a:method)
    echohl ErrorMsg | echo printf('[VS.LSP.ServerCapabilities] `%s` has no mapping to capabilities.', a:method) | echohl None
    return
  endif
  call s:Dict.set(self._dynamics, s:method_property_path_mapping[a:method] + [a:id], a:register_options)
endfunction

"
" unregister
"
function! s:ServerCapabilities.unregister(method, id) abort
  if !has_key(s:method_property_path_mapping, a:method)
    echohl ErrorMsg | echo printf('[VS.LSP.ServerCapabilities] `%s` has no mapping to capabilities.', a:method) | echohl None
    return
  endif
  call s:Dict.remove(self._dynamics, s:method_property_path_mapping[a:method] + [a:id])
endfunction

