if exists('g:loaded_flashcards')| finish| endif| let g:loaded_flashcards = 1
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let g:flashcards#settings_dir = get(g:, 'flashcards#settings_dir', '~/flashcards.vim')
let g:flashcards#decks_dir = get(g:, 'flashcards#decks_dir', g:flashcards#settings_dir. '/decks')
let defa_mappings = {}
let defa_mappings.advance = ["j", "\<CR>"]
let defa_mappings.back = ["k"]
let defa_mappings.next = ["n"]
let defa_mappings.prev = ["p"]
let defa_mappings.head = ["^"]
let defa_mappings.last = ["$"]
let defa_mappings.suspend = ["s"]
let defa_mappings.edit = ["e"]
let defa_mappings.undisplay = ["u"]
let defa_mappings.quit = ["q", "\<C-c>"]
let defa_mappings.incstar = ["l"]
let defa_mappings.decstar = ["h"]
let defa_mappings.toggle_undisplaymode = ["U"]
let defa_mappings.help = ["?"]
let g:flashcards#mappings = extend(defa_mappings, get(g:, 'flashcards#mappings', {}))

aug flashcards
  au!
  exe 'autocmd BufRead,BufNewFile' g:flashcards#decks_dir. '/*  setfiletype flashcards'
aug END

command! -nargs=1 -complete=customlist,s:decks_comp  FlashcardsEdit    call s:flashcards_edit(<q-args>)
command! -nargs=+ -complete=customlist,s:decks_comp  FlashcardsBegin    echo 'ok'
command! -nargs=+ -complete=customlist,s:decks_comp  FlashcardsBeginShuffled    echo 'ok'
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
