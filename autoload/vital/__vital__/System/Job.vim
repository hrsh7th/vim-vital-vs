"
" _vital_loaded
"
function! s:_vital_loaded(V) abort
  let s:Emitter = a:V.import('Event.Emitter')
endfunction

"
" new
"
function! s:new(args) abort
  if has('nvim')
    return s:Nvim.new(a:args)
  else
    return s:Vim.new(a:args)
  endif
endfunction

"
" Nvim
"
let s:Nvim = {}

"
" new
"
function! s:Nvim.new(args) abort
  return extend(deepcopy(s:Nvim), {
  \   'command': a:args.command,
  \   'emitter': s:Emitter.new(),
  \   'job': v:null,
  \ })
endfunction

"
" start
"
function! s:Nvim.start() abort
  let self.job = jobstart(self.command, {
  \   'on_stdout': { id, data, event -> self.emitter.emit('stdout', join(data, "\n")) },
  \   'on_stderr': { id, data, event -> self.emitter.emit('stderr', join(data, "\n")) },
  \   'on_exit': { id, data, event -> self.emitter.emit('exit', join(data, "\n")) },
  \ })
endfunction

"
" stop
"
function! s:Nvim.stop() abort
  call jobstop(self.job)
  let self.job = v:null
endfunction

"
" send
"
function! s:Nvim.send(data) abort
  call jobsend(self.job, a:data)
endfunction

"
" is_running
"
function! s:Nvim.is_running() abort
  return jobwait([self.job], 0)[0] == -1
endfunction

"
" Vim
"
let s:Vim = {}

"
" new
"
function! s:Vim.new(args) abort
  return extend(deepcopy(s:Vim), {
  \   'command': a:args.command,
  \   'emitter': s:Emitter.new(),
  \   'job': v:null,
  \ })
endfunction

"
" start
"
function! s:Vim.start() abort
  let self.job = job_start(self.command, {
  \   'in_io': 'pipe',
  \   'in_mode': 'raw',
  \   'out_io': 'pipe',
  \   'out_mode': 'raw',
  \   'err_io': 'pipe',
  \   'err_mode': 'raw',
  \   'out_cb': { job, data -> self.emitter.emit('stdout', data) },
  \   'err_cb': { job, data -> self.emitter.emit('stderr', data) },
  \   'exit_cb': { job, data -> self.emitter.emit('exit', data) }
  \ })
endfunction

"
" stop
"
function! s:Vim.stop() abort
  call ch_close(self.job)
  let self.job = v:null
endfunction

"
" send
"
function! s:Vim.send(data) abort
  call ch_sendraw(self.job, a:data)
endfunction

"
" is_running
"
function! s:Vim.is_running() abort
  return ch_status(self.job) ==# 'open'
endfunction

