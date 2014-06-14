if exists('g:loaded_flashcards')| finish| endif| let g:loaded_flashcards = 1
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let g:flashcards#settings_dir = get(g:, 'flashcards#settings_dir', '~/flashcards.vim')
let g:flashcards#decks_dir = get(g:, 'flashcards#decks_dir', g:flashcards#settings_dir. '/decks')
let s:defa_mappings = {}
let s:defa_mappings.advance = ["j", "\<CR>"]
let s:defa_mappings.back = ["k"]
let s:defa_mappings.next = ["n"]
let s:defa_mappings.prev = ["p"]
let s:defa_mappings.head = ["^"]
let s:defa_mappings.last = ["$"]
let s:defa_mappings.suspend = ["s"]
let s:defa_mappings.edit = ["e"]
let s:defa_mappings.undisplay = ["u"]
let s:defa_mappings.quit = ["q", "\<C-c>"]
let s:defa_mappings.incstar = ["l"]
let s:defa_mappings.decstar = ["h"]
let s:defa_mappings.toggle_undisplaymode = ["U"]
let s:defa_mappings.toggle_reversemode = ["R"]
let g:flashcards#mappings = extend(s:defa_mappings, get(g:, 'flashcards#mappings', {}))

aug flashcards
  au!
  exe 'autocmd BufRead,BufNewFile' g:flashcards#decks_dir. '/*  setfiletype flashcards'
aug END

command! -nargs=1 -complete=customlist,s:decks_comp  FlashcardsEdit    call s:flashcards_edit(<q-args>)
command! -nargs=+ -complete=customlist,s:decks_comp  FlashcardsBegin    call flashcards#start([<f-args>], 0)
command! -nargs=+ -complete=customlist,s:decks_comp  FlashcardsBeginShuffled    call flashcards#start([<f-args>], 1)
command! -nargs=0  FlashcardsContinue    call flashcards#continue()

function! s:decks_comp(arglead, cmdline, cursorpos) "{{{
  let decknames = flashcards#get_decknames()
  let beens = split(a:cmdline)[1:]
  return filter(decknames, 'v:val =~ "^".a:arglead && index(beens, v:val)==-1')
endfunction
"}}}
function! s:flashcards_edit(deckname) "{{{
  call flashcards#edit_deck(tr(a:deckname, ':*?"<>|\', ';#!''{}-/'))
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
