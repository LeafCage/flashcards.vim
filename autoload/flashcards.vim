if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let g:flashcards#settings_dir = '~/.cache/vim/flashcards'

let g:flashcards#settings_dir = get(g:, 'flashcards#settings_dir', '~/.cache/flashcards')
let g:flashcards#decks_dir = get(g:, 'flashcards#decks_dir', g:flashcards#settings_dir. '/decks')

let s:DIALOGUE = 'j, k, n, p, m, i, I, e, s, q, ? '
let s:setteddecknames = []
let s:should_shuffle = 0

"======================================
"Misc:
let s:R = vital#of('flashcards').import('Random.Xor128')
call s:R.srand()
function! s:_rand()
  return s:R.rand()
endfunction

"--------------------------------------
function! s:_shuffle(list) "{{{
  let len = len(a:list)
  let i = len
  while i
    let i -= 1
    let j = s:_rand() * (i + 1) % len
    if i == j
      continue
    endif
    let k = a:list[i]
    let a:list[i] = a:list[j]
    let a:list[j] = k
  endwhile
  return a:list
endfunction
"}}}
function! s:_echoparse(str) "{{{
  return substitute(a:str, '\\n', "\n  ", 'g')
endfunction
"}}}
function! s:_get_entries_and_orders(decknames) "{{{
  let [entries, orders, ftimesaves, srcidxes] = [{}, [], {}, {}]
  for deckname in a:decknames
    let path = expand(g:flashcards#decks_dir). '/'. deckname
    if !filereadable(path)
      echoh ErrorMsg| echo 'flashcards: such name deck is not existed.'| echoh NONE
      continue
    end
    let srcidxconts = []
    let entries[deckname] = filter(readfile(path), 's:_filter_src(v:val, v:key, srcidxconts)')
    let srcidxes[deckname] = srcidxconts
    call extend(orders, map(copy(entries[deckname]), '[deckname, v:key, s:_get_meta_of(v:val)=~"i"]'))
    let ftimesaves[deckname] = getftime(path)
  endfor
  return [entries, orders, ftimesaves, srcidxes]
endfunction
"}}}
function! s:_get_meta_of(entry) "{{{
  return matchstr(a:entry, '\t#\zs[^[:tab:]]\{-}$')
endfunction
"}}}
function! s:_get_wnr_in_crrtabpage(bname) "{{{
  let bnr = bufnr(a:bname)
  return index(tabpagebuflist(), bnr)+1
endfunction
"}}}
"------------------
function! s:_filter_src(srcentry, srcidx, srcidxconts) "{{{
  if a:srcentry =~ '^\s*\%(#\|$\)'
    return 0
  end
  call add(a:srcidxconts, a:srcidx)
  return 1
endfunction
"}}}


"--------------------------------------
let s:Cards = {'i': 0, 'j': 0}
let s:Cards.CONTINUE = 1
let s:Cards.NORMAL_MODE = 0
let s:Cards.WHOLE_MODE = 1
function! s:Cards(decknames) "{{{
  let _ = {'decknames': a:decknames, 'name': join(a:decknames, ', '), 'entries': {}, 'orders': [], 'ftimesaves': [], 'srcidxes': {}}
  let [_.entries, _.orders, _.ftimesaves, _.srcidxes] = s:_get_entries_and_orders(a:decknames)
  if s:should_shuffle
    call s:_shuffle(_.orders)
  end
  let _.totallen = len(_.orders)
  let _.deductedlen = len(filter(copy(_.orders), '!v:val[2]'))
  let _.mode = s:Cards.NORMAL_MODE
  call extend(_, s:Cards, 'keep')
  return _
endfunction
"}}}
function! s:Cards._get_normal_crrcount() "{{{
  return len(filter(self.orders[:self.i], '!v:val[2]'))
endfunction
"}}}
function! s:Cards._get_jlen() "{{{
  call s:CharCounter.reset()
  call substitute(self.crrentry, '\t\|$', '\=s:CharCounter.inc()', 'g')
  return s:CharCounter.count
endfunction
"}}}
function! s:Cards._write_modified_entry(newentry) "{{{
  let order = self.orders[self.i]
  let [deckname, orderi] = [order[0], order[1]]
  let srcpath = expand(g:flashcards#decks_dir). '/'. deckname
  if !filereadable(srcpath)
    return 1
  end
  let srcidx = self.srcidxes[deckname][orderi]
  let lines = readfile(srcpath)
  if getftime(srcpath)==get(self.ftimesaves, deckname, 0)
    let lines[srcidx] = a:newentry
    call writefile(lines, srcpath)
    let self.ftimesaves[deckname] = getftime(srcpath)
  else
    let idx = match(lines, '^'.self.crrentry.'\%(\t#[^[:tab:]]*\)\?$')
    if idx==-1| return 1| end
    let lines[idx] = a:newentry
    call writefile(lines, srcpath)
  end
  let self.entries[deckname][orderi] = a:newentry
  let save_wnr = winnr()
  let wnr = s:_get_wnr_in_crrtabpage(srcpath)
  if !wnr
    return
  end
  exe wnr. 'wincmd w'
  silent edit
  exe save_wnr. 'wincmd w'
endfunction
"}}}

function! s:Cards._rebuild() "{{{
  call self.show_status()
  let j = 1
  while j <= self.j
    call self.flip(j)
    let j += 1
  endwhile
  if self.ask_action()
    let self.j += 1
  end
endfunction
"}}}
function! s:Cards._act_k() "{{{
  redraw!
  if self.j > 0
    let self.j -= 1
    call self._rebuild()
  elseif self.i > 0
    cal self.nexti(-1)
    let self.i = self.i < 0 ? 0 : self.i
    let self.j = self._get_jlen()-1
    call self._rebuild()
  else
    let self.j = 0
    call self._rebuild()
  end
endfunction
"}}}
function! s:Cards._act_n() "{{{
  redraw!
  call self.nexti(1)
  let self.i = self.i >= self.totallen ? self.totallen-1 : self.i
  let self.j = 0
  call self._rebuild()
endfunction
"}}}
function! s:Cards._act_p() "{{{
  redraw!
  call self.nexti(-1)
  let self.i = self.i < 0 ? 0 : self.i
  let self.j = 0
  call self._rebuild()
endfunction
"}}}
function! s:Cards._act_suspend() "{{{
  let suspenddir = expand(g:flashcards#settings_dir). '/suspended'
  if !isdirectory(suspenddir)
    call mkdir(suspenddir, 'p')
  end
  call writefile(map(copy(self.orders), 'string(v:val)'), suspenddir.'/entries')
  let params = {'i': self.i, 'j': self.j, 'name': self.name, 'decknames': self.decknames, 'totallen': self.totallen, 'deductedlen': self.deductedlen, 'mode': self.mode, 'time': strftime('%Y-%m-%d %T')}
  call writefile([string(params)], suspenddir.'/params')
endfunction
"}}}
function! s:Cards._act_ignore() "{{{
  let is_ignored = self.crrmeta=~#'i'
  let meta = is_ignored ? substitute(self.crrmeta, 'i', '', 'g') : self.crrmeta.'i'
  let newentry = self.crrentry. (meta=='' ? '' : "\t#". meta)
  if self._write_modified_entry(newentry)
    return
  end
  let save_crrcount = self.mode==self.NORMAL_MODE ? self._get_normal_crrcount() : self.i+1
  let self.crrmeta = meta
  let self.orders[self.i][2] = !is_ignored
  let self.deductedlen = len(filter(copy(self.orders), '!v:val[2]'))
  if self.mode==self.NORMAL_MODE
    let self.j = 0
    let save_i = self.i
    call self.nexti(1)
    if self.crrmeta =~ 'i'
      call self.nexti(-1)
      if self.crrmeta =~ 'i'
        let self.i = save_i
      end
    end
  end
  redraw!
  echoh Question | echo '#'. save_crrcount 'entry is' (is_ignored ? 'unignored.' : 'ignored.') | echoh NONE
  call self._rebuild()
endfunction
"}}}
function! s:Cards._act_mark() "{{{
  let is_marked = self.crrmeta=~#'m'
  let meta = is_marked ? substitute(self.crrmeta, 'm', '', 'g') : self.crrmeta.'m'
  let newentry = self.crrentry. (meta=='' ? '' : "\t#". meta)
  if self._write_modified_entry(newentry)
    return
  end
  let self.crrmeta = meta
  redraw!
  let crrcount = self.mode==self.NORMAL_MODE ? self._get_normal_crrcount() : self.i+1
  echoh Question | echo '#'. crrcount 'entry is' (is_marked ? 'unmarked.' : 'marked.') | echoh NONE
  call self._rebuild()
endfunction
"}}}
function! s:Cards._act_switch_ignoremode() "{{{
  let self.mode = self.mode==self.NORMAL_MODE ? self.WHOLE_MODE : self.NORMAL_MODE
  redraw!
  call self._rebuild()
endfunction
"}}}
function! s:Cards._act_edit() "{{{
  let order = self.orders[self.i]
  let [deckname, orderi] = [order[0], order[1]]
  let bname = expand(g:flashcards#decks_dir). '/'. deckname
  let wnr = s:_get_wnr_in_crrtabpage(bname)
  if wnr
    exe wnr. 'wincmd w' | edit
  else
    exe 'tabnew' bname
  end
  let srcidx = self.srcidxes[deckname][orderi]
  call cursor(srcidx+1, 1)
  if getline('.')!=self.crrentry
    call search('^'.self.crrentry, 'cw')
  end
endfunction
"}}}

function! s:Cards.nexti(delta) "{{{
  let self.i += a:delta
  let delta = a:delta ? a:delta : 1
  while self.i >= 0 && self.i < self.totallen
    let order = self.orders[self.i]
    if self.mode==self.NORMAL_MODE && order[2]
      let self.i += delta | continue
    end
    let entry = get(self.entries[order[0]], order[1], '')
    if entry == ''
      let self.i += delta | continue
    end
    let self.crrentry = substitute(entry, '\t#[^[:tab:]]*$', '', 'g')
    let self.crrmeta = s:_get_meta_of(entry)
    break
  endwhile
endfunction
"}}}
function! s:Cards.init_entry() "{{{
  let order = self.orders[self.i]
  if self.mode==self.NORMAL_MODE && order[2]
    return 1
  end
  let entry = get(self.entries[order[0]], order[1], '')
  if entry == ''
    return 1
  end
  let self.crrentry = substitute(entry, '\t#[^[:tab:]]*$', '', 'g')
  let self.crrmeta = s:_get_meta_of(entry)
endfunction
"}}}
function! s:Cards.show_status() "{{{
  echo ''
  if self.crrmeta=~'i'
    echoh ErrorMsg | echon '[i]'
  end
  if self.crrmeta=~'m'
    echoh TODO | echon '[m]'
  end
  echoh NONE | echon ' '
  if self.mode==self.NORMAL_MODE
    echoh Title | echon printf("%s (%d/%d) ", self.name, self._get_normal_crrcount(), self.deductedlen)
  else
    echoh Title | echon printf("%s ([I]: %d/%d) ", self.name, self.i+1, self.totallen)
  end
  echoh MoreMsg | echon s:DIALOGUE | echoh NONE
  echo '> '. s:_echoparse(matchstr(self.crrentry, '^.\{-}\%(\t\|$\)'))
  let self.jlen = self._get_jlen()
endfunction
"}}}
function! s:Cards.flip(j) "{{{
  echo '- '. s:_echoparse(matchstr(self.crrentry, '^\%(.\{-}\t\)\{'.(a:j).'}\zs.\{-}\ze\%(\t\|$\)'))
endfunction
"}}}
function! s:Cards.ask_action() "{{{
  if self.j >= self.jlen-1
    echoh MoreMsg | echo 'continue >'| echoh NONE
  end
  while 1
    let act = nr2char(getchar())
    if act==#'j' || act=="\<CR>"
      return 1
    elseif act==#'k'
      call self._act_k() | return
    elseif act=~#'n\|J'
      call self._act_n() | return
    elseif act=~#'p\|K'
      call self._act_p() | return
    elseif act==#'q' || act=="\<C-c>"
      redraw! | throw 'flashcards: finish'
    elseif act==#'s'
      call self._act_suspend()
      redraw! | throw 'flashcards: finish'
    elseif act==#'e'
      redraw!
      call self._act_suspend()
      call self._act_edit()
      throw 'flashcards: finish'
    elseif act==#'I'
      call self._act_switch_ignoremode() | return
    elseif act==#'i'
      call self._act_ignore() | return
    elseif act==#'m'
      call self._act_mark() | return
    end
  endwhile
endfunction
"}}}


"--------------------------------------
let s:CharCounter = {'count': 0}
function! s:CharCounter.reset() "{{{
  let self.count = 0
endfunction
"}}}
function! s:CharCounter.inc() "{{{
  let self.count += 1
endfunction
"}}}


"======================================
"Public:
function! flashcards#get_decknames() "{{{
  let decksdir = expand(g:flashcards#decks_dir)
  return map(split(globpath(decksdir, '**/*'), '\n'), 'substitute(v:val, decksdir, "", "")')
endfunction
"}}}
function! flashcards#edit_deck(deckname) "{{{
  exe 'edit' expand(g:flashcards#decks_dir). a:deckname
endfunction
"}}}

"======================================
"Main:
function! flashcards#create() "{{{
  let name = tr(input('input flashcards file name > '), ':*?"<>|\', ';#!''{}-/')
  if name=~'^\s*$'
    return
  end
  call flashcards#edit_deck(name)
endfunction
"}}}
function! flashcards#reset() "{{{
  let s:setteddecknames = []
  let s:should_shuffle = 0
endfunction
"}}}
function! flashcards#load(deckname) "{{{
  let path = expand(g:flashcards#decks_dir). '/'. a:deckname
  if !filereadable(path)
    echoh ErrorMsg| echo 'flashcards: such name deck is not existed.'| echoh NONE
    return
  end
  let s:setteddecknames += [a:deckname]
endfunction
"}}}
function! flashcards#shuffle() "{{{
  let s:should_shuffle = 1
endfunction
"}}}

function! flashcards#start() "{{{
  call flashcards#reset()
  call flashcards#load('test.tango')
  let cards = s:Cards(s:setteddecknames)
  call cards.nexti(0)
  try
    while cards.i < cards.totallen
      call cards.show_status()
      if cards.ask_action()
        let cards.j = 1
      end
      while cards.j < cards.jlen
        call cards.flip(cards.j)
        if cards.ask_action()
          let cards.j += 1
        end
      endwhile
      call cards.nexti(1)
      let cards.j = 0
      redraw!
    endwhile
  catch /flashcards: finish/
    return
  endtry
endfunction
"}}}

function! flashcards#continue() "{{{
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
