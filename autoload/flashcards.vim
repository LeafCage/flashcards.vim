if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
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
function! s:_read_deck(deckname) "{{{
  let path = expand(g:flashcards#decks_dir). '/'. a:deckname
  if filereadable(path)
    return readfile(path)
  end
  echoh ErrorMsg| echo 'flashcards: such name deck is not existed.'| echoh NONE
  throw 'flashcards: unreadable'
endfunction
"}}}
function! s:_get_entries_and_orders(decknames) "{{{
  let [entries, orders, srcidxes] = [{}, [], {}]
  for deckname in a:decknames
    try
      let entries[deckname] = s:_read_deck(deckname)
    catch /flashcards: unreadable/
      continue
    endtry
    call extend(orders, map(copy(entries[deckname]), '[deckname, v:key, s:_should_ignore(v:val)]'))
  endfor
  return [entries, orders, srcidxes]
endfunction
"}}}
function! s:_should_ignore(entrystr) "{{{
  return a:entrystr =~ '^\s*\%(#\|$\)' ? -1 : s:_get_meta_of(a:entrystr)=~'#'
endfunction
"}}}
function! s:_get_meta_of(entrystr) "{{{
  return matchstr(a:entrystr, '\t#\[\zs[^[:tab:]]\{-}\ze\]$')
endfunction
"}}}
function! s:_get_newentry_of(oldentry, newmeta) "{{{
  if a:oldentry=~'\t#\%(\[[^[:tab:]]\{-}\]\)\?[^[[:tab:]][^[:tab:]]*$'
    if a:newmeta == ''
      return substitute(a:oldentry, '\t#\zs\[[^[:tab:]]\{-}\]\ze[^[:tab:]]\{-}$', '', '')
    else
      return substitute(a:oldentry, '\t#\zs\%(\[[^[:tab:]]\{-}\]\)\?\ze[^[:tab:]]\{-}$', '['.a:newmeta.']', '')
    end
  end
  if a:newmeta == ''
    return substitute(a:oldentry, '\t#\[[^[:tab:]]\{-}\]$', '', '')
  else
    return substitute(a:oldentry, '\t#\[[^[:tab:]]\{-}\]$\|$', '\t#['.a:newmeta.']', '')
  end
endfunction
"}}}
function! s:_get_wnr_in_crrtabpage(bname) "{{{
  let bnr = bufnr(a:bname)
  return index(tabpagebuflist(), bnr)+1
endfunction
"}}}

function! s:_modify_orders_for_continue(difftracks, orders, newlines, deckname, oldlen, oldi) "{{{
  let [offsets, modifier] = flashcards#_get_renewentries_offsets_and_modifier(a:difftracks, a:orders, a:deckname)
  call modifier.set_essential(a:newlines, a:oldlen)
  while modifier.ordersi < modifier.orderslen
    call modifier.set_oldi()
    call modifier.resolve_adds()
    if !modifier.resolve_dels()
      call modifier.resolve_offsets(offsets)
      let modifier.ordersi += 1
    end
    call modifier.lastadds()
  endwhile
  return [a:orders, offsets.get_newi(a:oldi)]
endfunction
"}}}
function! flashcards#_get_renewentries_offsets_and_modifier(difftracks, orders, deckname) "{{{
  let [offset, save_oldi, offsets, modifier] = [0, -1, [], s:newModifier(a:orders, a:deckname)]
  for [v, oldi, newi] in a:difftracks
    if v==0
      call extend(offsets, repeat([offset], oldi - save_oldi))
      let save_oldi = oldi
      continue
    end
    if oldi!=-1
      let orderidx = match(a:orders, '['''.a:deckname.''', '.oldi.',')
      if orderidx==-1| throw 'flashcards: order is not found: '.a:deckname.' '.oldi | end
    end
    call modifier.reserve(v, oldi, newi)
    let offset += v
  endfor
  return [s:newOffsets(offsets), modifier]
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
let s:Cards = {'base_hi': 'NONE'}
let s:Cards.META_UNDISPLAY = '#'
function! s:newCards(decknames) "{{{
  let self = {'i': 0, 'j': 0, 'decknames': a:decknames, 'name': join(a:decknames, ', '), 'entries': {}, 'orders': [],  'srcidxes': {}}
  let [self.entries, self.orders, self.srcidxes] = s:_get_entries_and_orders(a:decknames)
  if s:should_shuffle
    call s:_shuffle(self.orders)
  end
  let self.totallen = len(self.orders)
  let tmp = filter(copy(self.orders), 'v:val[2]!=-1')
  let self.displayedlen = len(tmp)
  let self.undisplayedlen = len(filter(tmp, '!v:val[2]'))
  let self.is_displaymode = 0
  call extend(self, s:Cards, 'keep')
  return self
endfunction
"}}}
function! s:newCards_continue(decknames, entries, orders, i, is_displaymode) "{{{
  let self = {'i': a:i, 'j': 0, 'decknames': a:decknames, 'name': join(a:decknames, ', '), 'entries': a:entries, 'orders': a:orders,  'srcidxes': {}}
  let self.totallen = len(self.orders)
  let tmp = filter(copy(self.orders), 'v:val[2]!=-1')
  let self.displayedlen = len(tmp)
  let self.undisplayedlen = len(filter(tmp, '!v:val[2]'))
  let self.is_displaymode = a:is_displaymode
  call extend(self, s:Cards, 'keep')
  call self.nexti(0)
  if self.i >= self.totallen
    let self.i = self.totallen-1
    call self.nexti(-1)
  end
  return self
endfunction
"}}}
function! s:Cards._get_normal_crrcount() "{{{
  return len(filter(self.orders[:self.i], '!v:val[2]'))
endfunction
"}}}
function! s:Cards._get_displayed_crrcount() "{{{
  return len(filter(self.orders[:self.i], 'v:val[2]!=-1'))
endfunction
"}}}
function! s:Cards._get_crrcount() "{{{
  return self.is_displaymode ? self._get_displayed_crrcount() : self._get_normal_crrcount()
endfunction
"}}}
function! s:Cards._get_starstate() "{{{
  return substitute(self.crrmeta, '[^*]', '', 'g')
endfunction
"}}}
function! s:Cards._get_jlen() "{{{
  return len(substitute(self.crrentry, '[^[:tab:]]', '', 'g'))+1
endfunction
"}}}
function! s:Cards._write_modified_entry(newentry) "{{{
  let order = self.orders[self.i]
  let [deckname, oldi] = [order[0], order[1]]
  let srcpath = expand(g:flashcards#decks_dir). '/'. deckname
  if !filereadable(srcpath)
    return 1
  end
  let newlines = readfile(srcpath)
  let diff = flashcards#get_diff(self.entries[deckname], newlines)
  let offsets = flashcards#_get_renewentries_offsets_and_modifier(diff.tracks, self.orders, deckname)[0]
  let newlines[offsets.get_newi(oldi)] = a:newentry
  call writefile(newlines, srcpath)

  let self.entries[deckname][oldi] = a:newentry
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
function! s:Cards._act_help() "{{{
  redraw!
  echoh MoreMsg
  for [key, desc] in [['j', 'forward'], ['k', 'back'], ['n', 'go to next entry'], ['p', 'go to previous entry'], ['^', 'go to initial entry'], ['$', 'go to last entry'], ['u', 'undisplay/display this entry'], ['U', 'toggle ignore mode'], ['e', 'edit deck source file'], ['s', 'suspend frashcards'], ['q', 'quit frashcards'], ['?', 'show helps']]
    echo key. "\t". desc
  endfor
  exe 'echoh' self.base_hi
  call getchar()
  redraw!
  call self._rebuild()
endfunction
"}}}
function! s:Cards._act_back() "{{{
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
function! s:Cards._act_next() "{{{
  redraw!
  call self.nexti(1)
  let self.i = self.i >= self.totallen ? self.totallen-1 : self.i
  let self.j = 0
  call self._rebuild()
endfunction
"}}}
function! s:Cards._act_prev() "{{{
  redraw!
  call self.nexti(-1)
  let self.i = self.i < 0 ? 0 : self.i
  let self.j = 0
  call self._rebuild()
endfunction
"}}}
function! s:Cards._act_head() "{{{
  redraw!
  let self.i = 0
  call self.nexti(0)
  let self.i = self.i >= self.totallen ? self.totallen-1 : self.i
  let self.j = 0
  call self._rebuild()
endfunction
"}}}
function! s:Cards._act_last() "{{{
  redraw!
  let self.i = self.totallen-1
  let order = self.orders[self.i]
  if order[2]==-1 || !self.is_displaymode && order[2]
    call self.nexti(-1)
  end
  let self.i = self.i < 0 ? 0 : self.i
  let self.j = 0
  call self._rebuild()
endfunction
"}}}
function! s:Cards._act_suspend(filename) "{{{
  let suspenddir = expand(g:flashcards#settings_dir). '/suspended'
  if !isdirectory(suspenddir)
    call mkdir(suspenddir, 'p')
  end
  let params = {'i': self.i, 'decknames': self.decknames, 'is_displaymode': self.is_displaymode, 'orders': self.orders, 'entries': self.entries}
  call writefile([string(params)], suspenddir. '/'. a:filename)
endfunction
"}}}
function! s:Cards._act_edit() "{{{
  let order = self.orders[self.i]
  let [deckname, oldi] = [order[0], order[1]]
  let bname = expand(g:flashcards#decks_dir). '/'. deckname
  let wnr = s:_get_wnr_in_crrtabpage(bname)
  if wnr
    exe wnr. 'wincmd w' | edit
  else
    exe 'tabnew' bname
  end
  let newlines = getline(1, '$')
  let diff = flashcards#get_diff(self.entries[deckname], newlines)
  let offsets = flashcards#_get_renewentries_offsets_and_modifier(diff.tracks, self.orders, deckname)[0]
  let idx = offsets.get_newi(oldi)
  call cursor(idx+1, 1)
endfunction
"}}}
function! s:Cards._act_undisplay() "{{{
  let is_undisplayed = self.crrmeta=~#self.META_UNDISPLAY
  let newmeta = is_undisplayed ? substitute(self.crrmeta, self.META_UNDISPLAY, '', 'g') : self.META_UNDISPLAY. self.crrmeta
  if newmeta==#self.crrmeta || self._write_modified_entry(s:_get_newentry_of(self.crrentry, newmeta))
    return
  end
  let save_crrcount = self._get_crrcount()
  let self.crrmeta = newmeta
  let self.orders[self.i][2] = !is_undisplayed
  let self.undisplayedlen = len(filter(copy(self.orders), '!v:val[2]'))
  if !self.is_displaymode
    let self.j = 0
    let save_i = self.i
    call self.nexti(1)
    if self.crrmeta =~# self.META_UNDISPLAY
      call self.nexti(-1)
      if self.crrmeta =~# self.META_UNDISPLAY
        let self.i = save_i
      end
    end
  end
  redraw!
  echoh Question | echo '#'. save_crrcount 'entry is' (is_undisplayed ? 'displayed.' : 'undisplayed.')
  call self._rebuild()
  return 1
endfunction
"}}}
function! s:Cards._act_incstar() "{{{
  let newmeta = self.crrmeta . '*'
  let starc = substitute(newmeta, '[^*]', '', 'g')
  if len(starc)>5 || newmeta==#self.crrmeta || self._write_modified_entry(s:_get_newentry_of(self.crrentry, newmeta))
    return
  end
  let self.crrmeta = newmeta
  redraw!
  call self._rebuild()
  return 1
endfunction
"}}}
function! s:Cards._act_decstar() "{{{
  let newmeta = substitute(self.crrmeta, '\*$', '', '')
  if newmeta==#self.crrmeta || self._write_modified_entry(s:_get_newentry_of(self.crrentry, newmeta))
    return
  end
  let self.crrmeta = newmeta
  redraw!
  call self._rebuild()
  return 1
endfunction
"}}}
function! s:Cards._act_toggle_displaymode() "{{{
  let self.is_displaymode = !self.is_displaymode
  redraw!
  call self._rebuild()
endfunction
"}}}
function! s:Cards._act_switch_reversemode() "{{{
endfunction
"}}}

function! s:Cards.nexti(delta) "{{{
  let self.i += a:delta
  let delta = a:delta ? a:delta : 1
  while self.i >= 0 && self.i < self.totallen
    let order = self.orders[self.i]
    if order[2]==-1 || !self.is_displaymode && order[2]
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
function! s:Cards.show_status() "{{{
  echo ''
  if !self.is_displaymode
    echoh Title | echon printf("%s (%d/%d) ", self.name, self._get_normal_crrcount(), self.undisplayedlen)
  else
    echoh Title | echon printf("%s (%d/%d) ", self.name, self._get_displayed_crrcount(), self.displayedlen)
    echoh Comment | echon '[#] '
  end
  echoh Question | echon self._get_starstate()
  let self.base_hi = self.crrmeta=~self.META_UNDISPLAY ? 'Comment' : 'NONE'
  exe 'echoh' self.base_hi
  echo (self.crrmeta=~self.META_UNDISPLAY ? '# ' : '> '). s:_echoparse(matchstr(self.crrentry, '^.\{-}\%(\t\|$\)'))
  let self.jlen = self._get_jlen()
endfunction
"}}}
function! s:Cards.flip(j) "{{{
  exe 'echoh' self.base_hi
  echo '- '. s:_echoparse(matchstr(self.crrentry, '^\%(.\{-}\t\)\{'.(a:j).'}\zs.\{-}\ze\%(\t\|$\)'))
endfunction
"}}}
function! s:Cards.ask_action() "{{{
  if self.j >= self.jlen-1
    echoh MoreMsg | echo 'continue >'
  end
  while 1
    let act = nr2char(getchar())
    if index(g:flashcards#mappings.advance, act)!=-1
      return 1
    elseif index(g:flashcards#mappings.back, act)!=-1
      call self._act_back() | return
    elseif index(g:flashcards#mappings.next, act)!=-1
      call self._act_next() | return
    elseif index(g:flashcards#mappings.prev, act)!=-1
      call self._act_prev() | return
    elseif index(g:flashcards#mappings.head, act)!=-1
      call self._act_head() | return
    elseif index(g:flashcards#mappings.last, act)!=-1
      call self._act_last() | return
    elseif index(g:flashcards#mappings.quit, act)!=-1 || act=="\<C-c>"
      redraw! | throw 'flashcards: finish'
    elseif index(g:flashcards#mappings.suspend, act)!=-1
      call self._act_suspend('continue')
      redraw! | throw 'flashcards: finish'
    elseif index(g:flashcards#mappings.edit, act)!=-1
      redraw!
      call self._act_suspend('continue')
      call self._act_edit()
      throw 'flashcards: finish'
    elseif index(g:flashcards#mappings.toggle_undisplaymode, act)!=-1
      call self._act_toggle_displaymode() | return
    elseif index(g:flashcards#mappings.toggle_reversemode, act)!=-1
      call self._act_switch_reversemode() | return
    elseif index(g:flashcards#mappings.undisplay, act)!=-1 && self._act_undisplay() | return
    elseif index(g:flashcards#mappings.decstar, act)!=-1 && self._act_decstar() | return
    elseif index(g:flashcards#mappings.incstar, act)!=-1 && self._act_incstar() | return
    elseif index(g:flashcards#mappings.help, act)!=-1
      call self._act_help() | return
    end
  endwhile
endfunction
"}}}


"------------------
let s:Offsets = {}
function! s:newOffsets(offsetslist) "{{{
  let self = copy(s:Offsets)
  let self.offsets = a:offsetslist
  return self
endfunction
"}}}
function! s:Offsets.get_newi(oldi) "{{{
  return a:oldi + self.offsets[a:oldi]
endfunction
"}}}


"------------------
let s:Modifier = {'adds': {}, 'dels': {}, 'ordersi': 0}
function! s:newModifier(orders, deckname) "{{{
  let modifier = deepcopy(s:Modifier)
  let modifier.orders = a:orders
  let modifier.orderslen = len(a:orders)
  let modifier.deckname = a:deckname
  return modifier
endfunction
"}}}
function! s:Modifier.reserve(v, oldi, newi) "{{{
  if a:v==1
    let self.adds[a:oldi+1] = add(get(self.adds, a:oldi+1, []), a:newi)
  else
    let self.dels[a:oldi] = ''
  end
endfunction
"}}}
function! s:Modifier.set_essential(newlines, oldlen) "{{{
  let self.newlines = a:newlines
  let self.oldlen = a:oldlen
endfunction
"}}}
function! s:Modifier.set_oldi() "{{{
  let self.oldi = self.orders[self.ordersi][1]
endfunction
"}}}
function! s:Modifier.resolve_adds() "{{{
  if !has_key(self.adds, self.oldi)
    return
  end
  let newis = self.adds[self.oldi]
  call extend(self.orders, map(newis, '[self.deckname, v:val, s:_should_ignore(self.newlines[v:val])]'), self.ordersi)
  let adjust = len(newis)
  let self.orderslen += adjust
  let self.ordersi += adjust
endfunction
"}}}
function! s:Modifier.resolve_dels() "{{{
  if !has_key(self.dels, self.oldi)
    return
  end
  unlet self.orders[self.ordersi]
  let self.orderslen -= 1
  return 1
endfunction
"}}}
function! s:Modifier.resolve_offsets(offsets) "{{{
  let newi = a:offsets.get_newi(self.oldi)
  let self.orders[self.ordersi] = [self.deckname, newi, s:_should_ignore(self.newlines[newi])]
endfunction
"}}}
function! s:Modifier.lastadds() "{{{
  if !(self.oldi == self.oldlen-1 && has_key(self.adds, self.oldlen))
    return
  end
  let newis = self.adds[self.oldlen]
  call extend(self.orders, map(newis, '[self.deckname, v:val, s:_should_ignore(self.newlines[v:val])]'), self.ordersi)
  let adjust = len(newis)
  let self.orderslen += adjust
  let self.ordersi += adjust
endfunction
"}}}


"--------------------------------------
let s:Diff = {'fp': {}}
function! flashcards#get_diff(old, new) "{{{
  let diff = deepcopy(s:Diff)
  let lenold = len(a:old)
  let lennew = len(a:new)
  let diff.is_swapped = lenold > lennew
  if diff.is_swapped
    let diff.short = a:new
    let diff.long = a:old
    let diff.shortlen = lennew
    let diff.longlen = lenold
  else
    let diff.short = a:old
    let diff.long = a:new
    let diff.shortlen = lenold
    let diff.longlen = lennew
  end
  return diff.calc_diff()
endfunction
"}}}
function! s:Diff.calc_diff() "{{{
  let delta = self.longlen - self.shortlen
  let self.tracker = s:newDiffTracker(delta, self.is_swapped)
  let p = -1
  while get(self.fp, delta, -1) != self.longlen
    let p += 1
    let k = -p
    while k < delta
      let self.fp[k] = self._snake(k)
      let k += 1
    endwhile
    let k = delta + p
    while k > delta
      let self.fp[k] = self._snake(k)
      let k -= 1
    endwhile
    let self.fp[delta] = self._snake(delta)
  endwhile
  return {'tracks': self.tracker.get_tracks(), 'edit_distance': delta + 2 * p}
endfunction
"}}}
function! s:Diff._get_variation(y, x) "{{{
  if self.is_swapped
    return [x, self.short[x]]
  end
  return [a:y, self.long[a:y]]
endfunction
"}}}
function! s:Diff._get_y(k) "{{{
  let [old_y1, old_y2] =  [get(self.fp, a:k-1, -1)+1, get(self.fp, a:k+1, -1)]
  if old_y1 > old_y2
    call self.tracker.add_change(a:k, old_y1, 1)
    return old_y1
  else
    call self.tracker.add_change(a:k, old_y2, -1)
    return old_y2
  end
endfunction
"}}}
function! s:Diff._snake(k) "{{{
  let y = self._get_y(a:k)
  let x = y - a:k
  while x < self.shortlen && y < self.longlen && self.short[x] ==# self.long[y]
    let [x, y] =[x+1, y+1]
    call self.tracker.add_equal(a:k, y)
  endwhile
  return y
endfunction
"}}}


"------------------
let s:DiffTracker = {}
function! s:newDiffTracker(delta, is_swapped) "{{{
  let self = copy(s:DiffTracker)
  let self.tracker = {}
  let self.delta = a:delta
  let self.is_swapped = a:is_swapped
  return self
endfunction
"}}}
function! s:DiffTracker.add_change(k, y, v) "{{{
  let before_k = a:k - a:v
  let self.tracker[a:k] = has_key(self.tracker, before_k) ? deepcopy(self.tracker[before_k]) : []
  call add(self.tracker[a:k], [a:v, a:y-a:k-1, a:y-1])
endfunction
"}}}
function! s:DiffTracker.add_equal(k, y) "{{{
  call add(self.tracker[a:k], [0, a:y-a:k-1, a:y-1])
endfunction
"}}}
function! s:DiffTracker.get_tracks() "{{{
  let tracks = self.tracker[self.delta]
  if tracks!=[]
    unlet tracks[0]
  end
  return self.is_swapped ? map(tracks, '[-v:val[0], v:val[2], v:val[1]]') : tracks
endfunction
"}}}


"======================================
"Public:
function! flashcards#get_decknames() "{{{
  let decksdir = expand(g:flashcards#decks_dir). '/'
  return map(split(globpath(decksdir, '**/*'), '\n'), 'isdirectory(v:val) ? substitute(v:val, decksdir, "", "")."/" : substitute(v:val, decksdir, "", "")')
endfunction
"}}}
function! flashcards#edit_deck(deckname) "{{{
  let path = expand(g:flashcards#decks_dir). '/'. a:deckname
  if isdirectory(path)
    echoerr 'flashcards: directoryは指定できません。'
    return
  end
  let dir = fnamemodify(path, ':h')
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  end
  exe 'edit' path
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

function! flashcards#start(...) "{{{
  let is_continue = a:0
  if !is_continue
    call flashcards#reset()
    call flashcards#load('test.tango')
  end
  let save_mfd = &mfd
  set maxfuncdepth=10000
  let cards = is_continue ? a:1 : s:newCards(s:setteddecknames)
  redraw!
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
  catch /\%(E132\|E169\):/
    call cards._act_suspend('on_error')
    unlet! cards
    call flashcards#continue('on_error')
  catch /flashcards: finish/
  finally
    echoh NONE
    let &mfd = save_mfd
  endtry
endfunction
"}}}

function! flashcards#continue(...) "{{{
  let suspenddir = expand(g:flashcards#settings_dir). '/suspended'
  let _filename = a:0 ? a:1 : 'continue'
  if !filereadable(suspenddir. '/'. _filename)
    echo 'flashcards: continuefile is not exist.'
    return
  end
  let suspended = eval(readfile(suspenddir. '/'. _filename)[0])
  let entries = suspended.entries
  let orders = suspended.orders
  let newentries = {}
  for deckname in suspended.decknames
    try
      let newentries[deckname] = s:_read_deck(deckname)
    catch /flashcards: unreadable/
      call filter(orders, 'v:val!~# "^['''.deckname.''', "')
      continue
    endtry
    let diff = flashcards#get_diff(entries[deckname], newentries[deckname])
    if diff.edit_distance
      let [orders, suspended.i] = s:_modify_orders_for_continue(diff.tracks, orders, newentries[deckname], deckname, len(entries[deckname]), suspended.i)
    end
  endfor
  let cards = s:newCards_continue(suspended.decknames, newentries, orders, suspended.i, suspended.is_displaymode)
  call flashcards#start(cards)
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
