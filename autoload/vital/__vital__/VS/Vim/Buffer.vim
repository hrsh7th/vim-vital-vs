"
" get_line_count
"
if exists('*nvim_buf_line_count')
  function! s:get_line_count(bufnr) abort
    return nvim_buf_line_count(a:bufnr)
  endfunction
elseif has('patch-8.2.0019')
  function! s:get_line_count(bufnr) abort
    return getbufinfo(a:bufnr)[0].linecount
  endfunction
else
  function! s:get_line_count(bufnr) abort
    if bufnr('%') == bufnr(a:bufnr)
      return line('$')
    endif
    return len(getbufline(a:bufnr, '^', '$'))
  endfunction
endif

