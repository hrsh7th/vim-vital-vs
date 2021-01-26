"
" new
"
function! s:new() abort
  return s:Job.new()
endfunction

let s:chunk_size = 2048

let s:Job = {}

"
" new
"
function! s:Job.new() abort
  return extend(deepcopy(s:Job), {
  \   '_on_stdout': { -> {} },
  \   '_on_stderr': { -> {} },
  \   '_on_exit': { -> {} },
  \   '_write_buffer': '',
  \   '_write_timer': -1,
  \   '_job': v:null,
  \ })
endfunction

"
" start
"
function! s:Job.start(args) abort
  if self.is_running()
    return
  endif

  let l:option = {}
  for l:key in ['cwd', 'env']
    if has_key(a:args, l:key)
      let l:option[l:key] = a:args[l:key]
    endif
  endfor

  if has_key(l:option, 'cwd') && !isdirectory(l:option.cwd)
    unlet! l:option.cwd
  endif

  let self._job = s:_create(a:args.cmd, l:option, self)
endfunction

"
" stop
"
function! s:Job.stop() abort
  if !self.is_running()
    return
  endif
  call self._job.stop()
  let self._job = v:null
endfunction

"
" is_running
"
function! s:Job.is_running() abort
  return !empty(self._job)
endfunction

"
" send
"
function! s:Job.send(data) abort
  if !self.is_running()
    return
  endif
  let self._write_buffer .= a:data
  if self._write_timer != -1
    return
  endif
  call self._write(0)
endfunction

"
" on_stdout
"
function! s:Job.on_stdout(callback) abort
  let self._on_stdout = a:callback
endfunction

"
" on_stderr
"
function! s:Job.on_stderr(callback) abort
  let self._on_stderr = a:callback
endfunction

"
" on_exit
"
function! s:Job.on_exit(callback) abort
  let self._on_exit = a:callback
endfunction

"
" write
"
function! s:Job._write(timer) abort
  let self._write_timer = -1
  if self._write_buffer ==# ''
    return
  endif
  call self._job.send(strpart(self._write_buffer, 0, s:chunk_size))
  let self._write_buffer = strpart(self._write_buffer, s:chunk_size)
  if self._write_buffer !=# ''
    let self._write_timer = timer_start(0, function(self._write, [], self))
  endif
endfunction

"
" create job instance
"
if has('nvim')
  function! s:_create(cmd, option, self) abort
    let a:option.on_stdout = { id, data, event -> a:self._on_stdout(data) }
    let a:option.on_stderr = { id, data, event -> a:self._on_stderr(data) }
    let a:option.on_exit = { id, code, event -> a:self._on_exit(code) }
    let l:job = jobstart(a:cmd, a:option)
    return {
    \   'stop': function('jobstop', [l:job]),
    \   'send': function('jobsend', [l:job]),
    \ }
  endfunction
else
  function! s:_create(cmd, option, self) abort
    let a:option.noblock = v:true
    let a:option.in_io = 'pipe'
    let a:option.in_mode = 'raw'
    let a:option.out_io = 'pipe'
    let a:option.out_mode = 'raw'
    let a:option.err_io = 'pipe'
    let a:option.err_mode = 'raw'
    let a:option.out_cb = { job, data -> a:self._on_stdout(split(data, "\n")) }
    let a:option.err_cb = { job, data -> a:self._on_stderr(split(data, "\n")) }
    let a:option.exit_cb = { job, code -> a:self._on_exit(code) }
    let l:job = job_start(a:cmd, a:option)
    return {
    \   'stop': function('ch_close', [l:job]),
    \   'send': function('ch_sendraw', [l:job]),
    \ }
  endfunction
endif

