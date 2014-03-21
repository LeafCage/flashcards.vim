if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
"=============================================================================
function! unite#sources#flashcards#define() "{{{
  return s:source
endfunction
"}}}

"=============================================================================
let s:source = {'name': 'flashcards', 'description': 'select a flashcards deck.', 'default_action': {'flashcards/deck': 'shuffled_start'}}
function! s:source.gather_candidates(args, context) "{{{
  return map(flashcards#get_decknames(), 's:_candidatify(v:val)')
endfunction
"}}}
function! s:_candidatify(deckname) "{{{
  return {'word': a:deckname, 'kind': 'flashcards/deck'}
endfunction
"}}}
"==================
let s:kind = {'name': 'flashcards/deck', 'default_action': 'start_shuffled',
  \ 'action_table': {'start': {'description': 'start flashcard.', 'is_selectable': 1},
  \ 'start_shuffled': {'description': 'start flashcard as shuffled.', 'is_selectable': 1},
  \ 'edit': {'description': 'edit flashcards deck', 'is_selectable': 0},
  \ }}
function! s:kind.action_table.start.func(candidates) "{{{
  "a:candidate.word
endfunction
"}}}
function! s:kind.action_table.start_shuffled.func(candidate) "{{{
endfunction
"}}}
function! s:kind.action_table.edit.func(candidate) "{{{
  call flashcards#edit_deck(a:candidate.word)
endfunction
"}}}

call unite#define_kind(s:kind)

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
