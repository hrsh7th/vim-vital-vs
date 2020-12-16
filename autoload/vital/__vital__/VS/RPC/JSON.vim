"
" _vital_loaded
"
function! s:_vital_loaded(V) abort
  let s:Promise = a:V.import('Async.Promise')
  let s:Job = a:V.import('VS.System.Job')
  let s:Emitter = a:V.import('VS.Event.Emitter')
endfunction

"
" _vital_depends
"
function! s:_vital_depends() abort
  return ['Async.Promise', 'VS.Event.Emitter', 'VS.System.Job']
endfunction

"
" new
"
function! s:new() abort
  return s:Connection.new()
endfunction

"
" s:Connection
"
let s:Connection = {}

"
" new
"
function! s:Connection.new() abort
  return extend(deepcopy(s:Connection), {
  \   'job': s:Job.new(),
  \   'events': s:Emitter.new(),
  \   'buffer':  '',
  \   'request_map': {},
  \ })
endfunction

"
" start
"
function! s:Connection.start(args) abort
  if !self.job.is_running()
    call self.job.events.on('stdout', self.on_stdout)
    call self.job.events.on('stderr', self.on_stderr)
    call self.job.events.on('exit', self.on_exit)
    call self.job.start(a:args)
  endif
endfunction

"
" stop
"
function! s:Connection.stop() abort
  if self.job.is_running()
    call self.job.events.off('stdout', self.on_stdout)
    call self.job.events.off('stderr', self.on_stderr)
    call self.job.events.off('exit', self.on_exit)
    call self.job.stop()
  endif
endfunction

"
" is_running
"
function! s:Connection.is_running() abort
  return self.job.is_running()
endfunction

"
" request
"
function! s:Connection.request(id, method, ...) abort
  let l:ctx = {}
  function! l:ctx.callback(id, method, params, resolve, reject) abort
    let self.request_map[a:id] = {}
    let self.request_map[a:id].resolve = a:resolve
    let self.request_map[a:id].reject = a:reject
    let l:message = { 'id': a:id, 'method': a:method }
    let l:message = extend(l:message, type(a:params) == type({}) ? { 'params': a:params } : {})
    call self.job.send(self.to_message(l:message))
  endfunction
  return s:Promise.new(function(l:ctx.callback, [a:id, a:method, get(a:000, 0, v:null)], self))
endfunction

"
" response
"
function! s:Connection.response(id, ...) abort
  let l:message = { 'id': a:id }
  let l:message = extend(l:message, len(a:000) > 0 ? a:000[0] : {})
 call self.job.send(self.to_message(l:message))
endfunction

"
" notify
"
function! s:Connection.notify(method, ...) abort
  let l:message = { 'method': a:method }
  let l:message = extend(l:message, len(a:000) > 0 ? { 'params': a:000[0] } : {})
  call self.job.send(self.to_message(l:message))
endfunction

"
" cancel
"
function! s:Connection.cancel(id) abort
  if has_key(self.request_map, a:id)
    call remove(self.request_map, a:id)
  endif
endfunction

"
" to_message
"
function! s:Connection.to_message(message) abort
  let l:message = json_encode(extend({ 'jsonrpc': '2.0' }, a:message))
  return 'Content-Length: ' . strlen(l:message) . "\r\n\r\n" . l:message
endfunction

"
" on_message
"
function! s:Connection.on_message(message) abort
  if has_key(a:message, 'id')
    " Request from server.
    if has_key(a:message, 'method')
      call self.events.emit('request', a:message)

    " Response from server.
    else
      if has_key(self.request_map, a:message.id)
        let l:request = remove(self.request_map, a:message.id)
        if has_key(a:message, 'error')
          call l:request.reject(a:message.error)
        else
          call l:request.resolve(get(a:message, 'result', v:null))
        endif
      endif
    endif

  " Notify from server.
  elseif has_key(a:message, 'method')
    call self.events.emit('notify', a:message)
  endif
endfunction

"
" flush
"
function! s:Connection.flush(data) abort
  let self.buffer .= a:data

  while 1
    " header check.
    let l:header_length = stridx(self.buffer, "\r\n\r\n") + 4
    if l:header_length < 4
      return
    endif

    " content length check.
    let l:content_length = stridx(self.buffer, 'Content-Length:') + 15
    if l:content_length < 15
      return
    endif
    let l:content_length = str2nr(self.buffer[l:content_length : l:header_length])
    let l:message_length = l:header_length + l:content_length

    " content check.
    let l:buffer_len = strlen(self.buffer)
    if l:buffer_len < l:message_length
      return
    endif

    let l:content = strpart(self.buffer, l:header_length, l:message_length - l:header_length)
    let self.buffer = self.buffer[l:message_length : ]
    try
      call self.on_message(json_decode(l:content))
    catch /.*/
    endtry

    if l:buffer_len <= l:message_length
      break
    endif
  endwhile
endfunction

"
" on_stdout
"
function! s:Connection.on_stdout(data) abort
  call self.flush(a:data)
endfunction

"
" on_stderr
"
function! s:Connection.on_stderr(data) abort
  call self.events.emit('stderr', a:data)
endfunction

"
" on_exit
"
function! s:Connection.on_exit(code) abort
  call self.events.emit('exit', a:code)
endfunction

