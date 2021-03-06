"
" _vital_loaded
"
function! s:_vital_loaded(V) abort
  let s:Promise = a:V.import('Async.Promise')
  let s:Job = a:V.import('VS.System.Job')
endfunction

"
" _vital_depends
"
function! s:_vital_depends() abort
  return ['Async.Promise', 'VS.System.Job']
endfunction

"
" new
"
function! s:new(...) abort
  return s:Connection.new(get(a:000, 0, {}))
endfunction

"
" s:Connection
"
let s:Connection = {}

"
" new
"
function! s:Connection.new(args) abort
  return extend(deepcopy(s:Connection), {
  \   '_job': s:Job.new(),
  \   '_buffer':  '',
  \   '_header_length': -1,
  \   '_message_length': -1,
  \   '_request_id': 0,
  \   '_request_map': {},
  \   '_on_request_map': {},
  \   '_on_notification_map': {},
  \ })
endfunction

"
" start
"
function! s:Connection.start(args) abort
  if !self._job.is_running()
    call self._job.on_stdout(function(self._on_stdout, [], self))
    call self._job.start(a:args)
  endif
endfunction

"
" stop
"
function! s:Connection.stop() abort
  if self._job.is_running()
    call self._job.stop()
  endif
endfunction

"
" is_running
"
function! s:Connection.is_running() abort
  return self._job.is_running()
endfunction

"
" request
"
function! s:Connection.request(method, params) abort
  let self._request_id += 1

  let l:ctx = {}
  function! l:ctx.callback(id, method, params, resolve, reject) abort
    let self._request_map[a:id] = { 'resolve': a:resolve, 'reject': a:reject }
    let l:message = { 'id': a:id, 'method': a:method }
    if a:params isnot# v:null
      let l:message.params = a:params
    endif
    call self._send(l:message)
  endfunction
  function! l:ctx.cancel(id) abort
    if has_key(self._request_map, a:id)
      call remove(self._request_map, a:id)
    endif
  endfunction

  let l:p = s:Promise.new(function(l:ctx.callback, [self._request_id, a:method, a:params], self))
  let l:p._request = {}
  let l:p._request.id = self._request_id
  let l:p._request.cancel = function(l:ctx.cancel, [self._request_id], self)
  return l:p
endfunction

"
" notify
"
function! s:Connection.notify(method, params) abort
  let l:message = { 'method': a:method }
  if a:params isnot# v:null
    let l:message.params = a:params
  endif
  call self._send(l:message)
endfunction

"
" on_request
"
function! s:Connection.on_request(method, callback) abort
  let self._on_request_map[a:method] = a:callback
endfunction

"
" on_notification
"
function! s:Connection.on_notification(method, callback) abort
  let self._on_notification_map[a:method] = a:callback
endfunction

"
" _send
"
function! s:Connection._send(message) abort
  let a:message.jsonrpc = '2.0'
  let l:message = json_encode(a:message)
  call self._job.send('Content-Length: ' . strlen(l:message) . "\r\n\r\n" . l:message)
endfunction

"
" _on_stdout
"
function! s:Connection._on_stdout(data) abort
  let self._buffer .= join(a:data, "\n")

  while self._buffer !=# ''
    " header check.
    if self._header_length == -1
      let l:header_length = stridx(self._buffer, "\r\n\r\n") + 4
      if l:header_length < 4
        return
      endif
      let self._header_length = l:header_length
      let self._message_length = self._header_length + str2nr(get(matchlist(self._buffer, '\ccontent-length:\s*\(\d\+\)'), 1, '-1'))
    endif

    " content check.
    let l:buffer_len = strlen(self._buffer)
    if l:buffer_len < self._message_length
      return
    endif

    let l:content = strpart(self._buffer, self._header_length, self._message_length - self._header_length)
    try
      call self._on_message(json_decode(l:content))
    catch /.*/
      echomsg string({ 'exception': v:exception, 'throwpoint': v:throwpoint })
    endtry
    let self._buffer = strpart(self._buffer, self._message_length)
    let self._header_length = -1
  endwhile
endfunction

"
" _on_message
"
function! s:Connection._on_message(message) abort
  if has_key(a:message, 'id')
    " Request from server.
    if has_key(a:message, 'method')
      if has_key(self._on_request_map, a:message.method)
        let l:p = s:Promise.resolve()
        let l:p = l:p.then({ -> self._on_request_map[a:message.method](a:message.params) })
        let l:p = l:p.then({ result ->
        \   self._send({
        \     'id': a:message.id,
        \     'result': result
        \   })
        \ })
        let l:p = l:p.catch({ error ->
        \   has_key(error, 'code') && has_key(error, 'message')
        \     ? (
        \       self._send({
        \         'id': a:message.id,
        \         'error': error
        \       })
        \     ) : (
        \       self._send({
        \         'id': a:message.id,
        \         'error': {
        \           'code': -32603,
        \           'message': 'Internal error',
        \           'data': error,
        \         }
        \       })
        \     )
        \ })
      else
        call self._send({
        \   'error': {
        \     'code': -32601,
        \     'message': 'Method not found',
        \   }
        \ })
      endif

    " Response from server.
    else
      if has_key(self._request_map, a:message.id)
        let l:request = remove(self._request_map, a:message.id)
        if has_key(a:message, 'error')
          call l:request.reject(a:message.error)
        else
          call l:request.resolve(get(a:message, 'result', v:null))
        endif
      endif
    endif

  " Notify from server.
  elseif has_key(a:message, 'method')
    if has_key(self._on_notification_map, a:message.method)
      call self._on_notification_map[a:message.method](a:message.params)
    endif
  endif
endfunction

