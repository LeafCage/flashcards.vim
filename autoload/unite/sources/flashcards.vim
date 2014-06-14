if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
"=============================================================================
function! unite#sources#flashcards#define() "{{{
  return s:source
endfunction
"}}}

"=============================================================================
let s:source = {'name': 'flashcards', 'description': 'select a flashcards deck.'}
function! s:source.gather_candidates(args, context) "{{{
  let candidates = map(flashcards#get_decknames(), 's:_candidatify(v:val)')
  let path = expand(g:flashcards#settings_dir). '/suspended/continue'
  if filereadable(path)
    call insert(candidates, {'word': '[:continue:]', 'kind': 'flashcards/continue'})
  end
  return candidates
endfunction
"}}}
function! s:_candidatify(deckname) "{{{
  return {'word': a:deckname, 'kind': 'flashcards/deck'}
endfunction
"}}}

"==================
let s:kind = {'name': 'flashcards/deck', 'default_action': g:flashcards#unite_default_action,
  \ 'action_table': {'begin': {'description': 'begin flashcard.', 'is_selectable': 1},
  \ 'begin_shuffled': {'description': 'begin flashcard as shuffled.', 'is_selectable': 1},
  \ 'edit': {'description': 'edit flashcards deck', 'is_selectable': 0},
  \ }}
function! s:kind.action_table.begin.func(candidates) "{{{
  call flashcards#start(map(a:candidates, 'v:val.word'), 0)
endfunction
"}}}
function! s:kind.action_table.begin_shuffled.func(candidates) "{{{
  call flashcards#start(map(a:candidates, 'v:val.word'), 1)
endfunction
"}}}
function! s:kind.action_table.edit.func(candidate) "{{{
  call flashcards#edit_deck(a:candidate.word)
endfunction
"}}}
call unite#define_kind(s:kind)
unlet s:kind

"==================
let s:kind = {'name': 'flashcards/continue', 'default_action': 'continue',
  \ 'action_table': {'continue': {'description': 'continue flashcard.', 'is_selectable': 0},
  \ 'drop': {'description': 'delete flashcards continuefile', 'is_selectable': 0},
  \ }}
function! s:kind.action_table.continue.func(candidates) "{{{
  call flashcards#continue()
endfunction
"}}}
function! s:kind.action_table.drop.func(candidates) "{{{
  call delete(suspenddir. '/continue')
endfunction
"}}}
call unite#define_kind(s:kind)
unlet s:kind

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
