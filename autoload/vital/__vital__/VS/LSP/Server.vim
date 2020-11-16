"
" _vital_loaded
"
function! s:_vital_loaded(V) abort
  let s:Promise = a:V.import('Async.Promise')
  let s:Emitter = a:V.import('VS.Event.Emitter')
  let s:RequestToken = a:V.import('VS.LSP.Server.RequestToken')
endfunction

"
" _vaital_depends
"
function! s:_vaital_depends() abort
  return ['Async.Promise', 'VS.Event.Emitter', 'VS.RPC.JSON', 'VS.LSP.Server.RequestToken']
endfunction

"
" new
"
function! s:new(rpc) abort
  return s:Server.new(a:rpc)
endfunction

let s:Server = {}

"
" new
"
function! s:Server.new(rpc, logger) abort
  return extend(deepcopy(s:Server), {
  \   'events': s:Emitter.new(),
  \   'rpc': a:rpc,
  \   'request_tokens': {},
  \   'request_id': 0,
  \ })
endfunction

"
" start
"
function! s:Server.start(root_uri) abort
  call self.rpc.events.on('request', function(self.on_request, [], self))
  call self.rpc.events.on('notify', function(self.on_notify, [], self))
  call self.rpc.events.on('stderr', function(self.on_stderr, [], self))
  call self.rpc.events.on('exit', function(self.on_exit, [], self))
  call self.rpc.start({
  \   'cwd': a:root_uri
  \ })
endfunction

"
" stop
"
function! s:Server.stop() abort
  call self.rpc.events.off('request', self.on_request)
  call self.rpc.events.off('notify', self.on_notify)
  call self.rpc.events.off('stderr', self.on_stderr)
  call self.rpc.events.off('exit', self.on_exit)
  call self.rpc.stop()
endfunction

"
" request
"
function! s:Server.request(method, params, ...) abort
  let l:request_token = len(a:000) == 1 ? a:000[0] : s:RequestToken.new()
  let l:request_token.id = self.create_request_id()
  return self.rpc.request(l:request_token.id, a:method, get(a:000, 0, v:null))
endfunction

"
" is_running
"
function! s:Server.is_running() abort
  return self.rpc.is_running()
endfunction

"
" create_request_id
"
function! s:Server.create_request_id() abort
  let l:request_id = self.request_id
  let self.request_id += 1
  return l:request_id
endfunction

