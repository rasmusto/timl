" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_array_seq")
  finish
endif
let g:autoloaded_timl_array_seq = 1

function! timl#array_seq#create(array, ...) abort
  let cc = timl#bless('timl.lang/ArraySeq', {
        \ 'array': a:array,
        \ 'i': a:0 ? a:1 : 0})
  lockvar 1 cc
  return cc
endfunction

function! timl#array_seq#first(seq) abort
  return get(a:seq.array, a:seq.i, g:timl#nil)
endfunction

function! timl#array_seq#more(seq) abort
  if len(a:seq.array) - a:seq.i <= 1
    return g:timl#empty_list
  else
    return timl#array_seq#create(a:seq.array, a:seq.i+1)
  endif
endfunction

function! timl#array_seq#count(this) abort
  return len(a:this.array) - a:this.i
endfunction