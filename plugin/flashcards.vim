if exists('g:loaded_flashcards')| finish| endif| let g:loaded_flashcards = 1
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let g:flashcards#settings_dir = get(g:, 'flashcards#settings_dir', '~/.config/vim/flashcards')
let g:flashcards#decks_dir = get(g:, 'flashcards#decks_dir', g:flashcards#settings_dir. '/decks')
let g:flashcards#unite_default_action = get(g:, 'flashcards#unite_default_action', 'begin_shuffled')
let s:defa_mappings = {}
let s:defa_mappings.advance = ["j", "\<CR>"]
let s:defa_mappings.back = ["k"]
let s:defa_mappings.next = ["n"]
let s:defa_mappings.prev = ["p"]
let s:defa_mappings.head = ["^"]
let s:defa_mappings.last = ["$"]
let s:defa_mappings.jump = ["g"]
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

command! -nargs=1 -complete=customlist,flashcards#comp_decks  FlashcardsEdit    call s:flashcards_edit(<q-args>)
command! -nargs=+ -complete=customlist,flashcards#comp_decks  FlashcardsBegin    call s:parse_flashcardsbegin([<f-args>])
command! -nargs=0  FlashcardsContinue    call flashcards#continue()

function! s:parse_flashcardsbegin(decknames) "{{{
  let [i, should_shuffle] = [len(a:decknames), 0]
  while i
    let i -= 1
    if a:decknames[i] =~ '^-'
      let opt = remove(a:decknames, i)
      if opt ==# '-shuffle'
        let should_shuffle = 1
      else
        echoerr 'invalid option:' opt
      end
    end
  endwhile
  if a:decknames==[]
    echoh Error | echom 'flashcards: deckname required' | echoh NONE
    return
  end
  call flashcards#start(a:decknames, should_shuffle)
endfunction
"}}}
function! s:flashcards_edit(deckname) "{{{
  call flashcards#edit_deck(tr(a:deckname, ':*?"<>|\', ';#!''{}-/'))
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
