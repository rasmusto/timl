" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_interactive')
  finish
endif
let g:autoloaded_timl_interactive = 1

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
endfunction

function! s:lencompare(a, b) abort
  return len(a:b) - len(a:b)
endfunction

function! timl#interactive#ns_for_file(file) abort
  let file = fnamemodify(a:file, ':p')
  let candidates = []
  for glob in split(&runtimepath, ',')
    let candidates += filter(split(glob(glob), "\n"), 'file[0 : len(v:val)-1] ==# v:val && file[len(v:val)] =~# "[\\/]"')
  endfor
  if empty(candidates)
    return 'user'
  endif
  let dir = sort(candidates, s:function('s:lencompare'))[-1]
  let path = file[len(dir)+1 : -1]
  return substitute(tr(fnamemodify(path, ':r:r'), '\/_', '..-'), '^\%(autoload\|plugin\|test\).', '', '')
endfunction

function! timl#interactive#ns_for_cursor(...) abort
  call timl#loader#init()
  let pattern = '\c(\%(in-\)\=ns\s\+''\=[[:alpha:]]\@='
  let line = 0
  if !a:0 || a:1
    let line = search(pattern, 'bcnW')
  endif
  if !line
    let i = 1
    while i < line('$') && i < 100
      if getline(i) =~# pattern
        let line = i
        break
      endif
      let i += 1
    endwhile
  endif
  if line
    let ns = matchstr(getline(line), pattern.'\zs[[:alnum:]._-]\+')
  else
    let ns = timl#interactive#ns_for_file(expand('%:p'))
  endif
  if !exists('g:autoloaded_timl_loader')
    runtime! autoload/timl/loader.vim
  endif
  let nsobj = timl#namespace#find(timl#symbol(ns))
  if nsobj isnot# g:timl#nil
    return ns
  else
    return 'user'
  endif
endfunction

function! timl#interactive#eval_opfunc(type) abort
  let selection = &selection
  let clipboard = &clipboard
  let reg = @@
  try
    set selection=inclusive clipboard=
    if a:type =~# '^\d\+$'
      let open = '[[{(]'
      let close = '[]})]'
      let skip = 'synIDattr(synID(line("."),col("."),1),"name") =~? "comment\\|string\\|regex\\|character"'
      call searchpair(open, '', close, 'r', skip)
      call setpos("']", getpos("."))
      call searchpair(open, '', close, 'b', skip)
      if col('.') > 2 && getline('.')[col('.')-3 : col('.')-2] ==# '#*'
        normal! 2h
      endif
      while col('.') > 1 && getline('.')[col('.')-2] =~# '[#''`~@]'
        normal! h
      endwhile
      call setpos("'[", getpos("."))
      silent exe "normal! `[v`]y"
    elseif a:type =~# "[vV\C-V]"
      silent exe "normal! `<" . a:type . "`>y"
    elseif a:type ==# 'line'
      silent exe "normal! '[V']y"
    elseif a:type ==# 'block'
      silent exe "normal! `[\<C-V>`]y"
    elseif a:type ==# 'char'
      silent exe "normal! `[v`]y"
    else
      return
    endif
    let string = @@
  finally
    let &selection = selection
    let &clipboard = clipboard
    let @@ = reg
  endtry
  let ns = g:timl#core#_STAR_ns_STAR_
  let port = timl#reader#open_string(string, expand('%:p'), line("'["))
  try
    let g:timl#core#_STAR_ns_STAR_ = timl#namespace#find(timl#symbol(timl#interactive#ns_for_cursor()))
    echo timl#printer#string(timl#loader#consume(port))
  catch //
    echohl ErrorMsg
    echo v:exception
    echohl NONE
    unlet! g:timl#core#_STAR_e
    let g:timl#core#_STAR_e = timl#exception#build(v:exception, v:throwpoint)
  finally
    call timl#reader#close(port)
    let g:timl#core#_STAR_ns_STAR_ = ns
  endtry
endfunction

function! timl#interactive#omnicomplete(findstart, base) abort
  if a:findstart
    let line = getline('.')[0 : col('.')-2]
    return col('.') - strlen(matchstr(line, '\k\+$')) - 1
  endif
  let results = []
  let ns = timl#interactive#ns_for_cursor()
  if timl#namespace#find(ns) is g:timl#nil
    let ns = 'user'
  endif
  let results = map(keys(timl#namespace#find(ns).mappings), '{"word": v:val}')
  return filter(results, 'v:val.word[0] !=# "#" && (a:base ==# "" || a:base ==# v:val.word[0 : strlen(a:base)-1])')
endfunction

function! timl#interactive#input_complete(A, L, P) abort
  let prefix = matchstr(a:A, '\%(.* \|^\)\%(#\=[\[{('']\)*')
  let keyword = a:A[strlen(prefix) : -1]
  return sort(map(timl#interactive#omnicomplete(0, keyword), 'prefix . v:val.word'))
endfunction

function! timl#interactive#repl(...) abort
  if a:0
    let ns = g:timl#core#_STAR_ns_STAR_
    try
      let g:timl#core#_STAR_ns_STAR_ = timl#namespace#create(timl#symbol(a:1))
      call timl#loader#require(timl#symbol('timl.repl'))
      call timl#namespace#refer(timl#symbol('timl.repl'))
      return timl#interactive#repl()
    finally
      let g:timl#core#_STAR_ns_STAR_ = ns
    endtry
  endif

  let cmpl = 'customlist,timl#interactive#input_complete'
  let more = &more
  try
    set nomore
    call timl#loader#require(timl#symbol('timl.repl'))
    if g:timl#core#_STAR_ns_STAR_.name[0] ==# 'user'
      call timl#namespace#refer(timl#symbol('timl.repl'))
    endif
    let input = input(g:timl#core#_STAR_ns_STAR_.name[0].'=> ', '', cmpl)
    if input =~# '^:q\%[uit]'
      return ''
    elseif input =~# '^:'
      return input
    endif
    let _ = {}
    while !empty(input)
      echo "\n"
      try
        while 1
          try
            let read = timl#reader#read_string_all(input)
            break
          catch /^timl#reader: unexpected EOF/
            let space = repeat(' ', len(g:timl#core#_STAR_ns_STAR_.name[0])-2)
            let input .= "\n" . input(space.'#_=> ', '', cmpl)
            echo "\n"
          endtry
        endwhile
        let _.val = timl#eval(timl#cons#create(timl#symbol('do'), read))
        call extend(g:, {
              \ 'timl#core#_STAR_3': g:timl#core#_STAR_2,
              \ 'timl#core#_STAR_2': g:timl#core#_STAR_1,
              \ 'timl#core#_STAR_1': _.val})
        echo timl#printer#string(_.val)
      catch /^timl#repl: exit/
        redraw
        return v:exception[16:-1]
      catch /^Vim\%((\a\+)\)\=:E168/
        return ''
      catch
        unlet! g:timl#core#_STAR_e
        let g:timl#core#_STAR_e = timl#exception#build(v:exception, v:throwpoint)
        echohl ErrorMSG
        echo v:exception
        echohl NONE
      endtry
      let input = input(g:timl#core#_STAR_ns_STAR_.name[0].'=> ', '', cmpl)
    endwhile
    return input
  finally
    let &more = more
  endtry
endfunction

function! timl#interactive#scratch() abort
  if exists('s:scratch') && bufnr(s:scratch) !=# -1
    execute bufnr(s:scratch) . 'sbuffer'
    return ''
  elseif !exists('s:scratch')
    let s:scratch = tempname().'.tim'
    execute 'silent' (empty(bufname('')) && !&modified ? 'edit' : 'split') s:scratch
  else
    execute 'split '.s:scratch
  endif
  call setline(1, [
        \ ";; This buffer is for notes you don't want to save, and for TimL evaluation.",
        \ ";; Use cpp to evaluate the top level form under the cursor,",
        \ ";; or cp{motion} to evaluate an arbitrary selection.",
        \ ""])
  setlocal bufhidden=hide filetype=timl nomodified
  autocmd BufLeave <buffer> update
  return '$'
endfunction

function! timl#interactive#copen(error) abort
  if !empty(a:error)
    call setqflist(a:error.qflist)
    copen
    let w:quickfix_title = a:error.exception . " @ line " . a:error.line
  endif
endfunction