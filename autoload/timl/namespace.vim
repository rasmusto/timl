" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_namespace")
  finish
endif
let g:autoloaded_timl_namespace = 1

let s:type = timl#type#intern('timl.lang/Namespace')

function! timl#namespace#create(name, ...)
  let name = timl#symbol#coerce(a:name)
  if !has_key(g:timl#namespaces, name[0])
    let g:timl#namespaces[name[0]] = timl#bless(s:type, {'name': name, 'referring': [], 'aliases': {}})
  endif
  let ns = g:timl#namespaces[name[0]]
  if !a:0
    return ns
  endif
  let opts = a:1
  return ns
endfunction

function! timl#namespace#name(ns)
  return a:ns.name
endfunction

function! timl#namespace#select(name)
  let g:timl#core#_STAR_ns_STAR_ = timl#namespace#create(a:name)
  return g:timl#core#_STAR_ns_STAR_
endfunction

function! timl#namespace#refer(name)
  let me = g:timl#core#_STAR_ns_STAR_
  let sym = timl#symbol#coerce(a:name)
  if sym isnot# me.name && index(me.referring, sym) < 0
    call insert(me.referring, sym)
  endif
  return g:timl#nil
endfunction

function! timl#namespace#use(name)
  call timl#require(a:name)
  return timl#namespace#refer(a:name)
endfunction

function! timl#namespace#alias(alias, name)
  let me = g:timl#core#_STAR_ns_STAR_
  let me.aliases[timl#str(a:alias)] = a:name
  return g:timl#nil
endfunction

function! timl#namespace#find(name)
  return get(g:timl#namespaces, timl#str(a:name), g:timl#nil)
endfunction

function! timl#namespace#the(name)
  if timl#type#string(a:name) ==# 'timl.lang/Namespace'
    return a:name
  endif
  let name = timl#str(a:name)
  if has_key(g:timl#namespaces, name)
    return g:timl#namespaces[name]
  endif
  throw 'timl: no such namespace '.name
endfunction

function! timl#namespace#all()
  return timl#seq(values(g:timl#namespaces))
endfunction

if !exists('g:timl#namespaces')
  let g:timl#namespaces = {
        \ 'timl.core': timl#bless('timl.lang/Namespace', {'name': timl#symbol('timl.core'), 'referring': [], 'aliases': {}}),
        \ 'user':      timl#bless('timl.lang/Namespace', {'name': timl#symbol('user'), 'referring': [timl#symbol('timl.core')], 'aliases': {}})}
endif

if !exists('g:timl#core#_STAR_ns_STAR_')
  let g:timl#core#_STAR_ns_STAR_ = g:timl#namespaces['user']
endif
