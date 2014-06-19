if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================

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
function! s:_descsort_by_star(a, b) "{{{
  return s:_starq_of_order(a:b) - s:_starq_of_order(a:a)
endfunction
"}}}
function! s:_echoparse(str) "{{{
  return substitute(a:str, '\\n', "\n  ", 'g')
endfunction
"}}}
function! s:_get_deckpath(deckname) "{{{
  let path = expand(g:flashcards#decks_dir). '/'. a:deckname
  if filereadable(path)
    return [path, 0]
  end
  let path = expand(a:deckname)
  if filereadable(path)
    return [path, 1]
  end
  throw 'flashcards: unreadable'
endfunction
"}}}
function! s:_create_orderprop(entrystr) "{{{
  let meta = s:_get_meta_of(a:entrystr)
  let should_ignore = a:entrystr =~ '^\s*\%(#\|$\)' ? -1 : meta=~'#'
  return [should_ignore, len(s:_get_starc(meta))]
endfunction
"}}}
function! s:_should_ignore_of_order(order) "{{{
  return a:order[2][0]
endfunction
"}}}
function! s:_set_should_ignore_of_order(order, val) "{{{
  let a:order[2][0] = a:val
endfunction
"}}}
function! s:_starq_of_order(order) "{{{
  return a:order[2][1]
endfunction
"}}}
function! s:_set_starq_of_order(order, val) "{{{
  let a:order[2][1] = a:val
endfunction
"}}}
function! s:_get_starc(meta) "{{{
  return substitute(a:meta, '[^*]', '', 'g')
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
function! s:_get_meta_of(entrystr) "{{{
  return matchstr(a:entrystr, '\t#\[\zs[^[:tab:]]\{-}\ze\]$')
endfunction
"}}}
function! s:_calc_undisplayedlen_of(orders, wringout) "{{{
  return len(filter(a:orders, '!s:_should_ignore_of_order(v:val) && s:_starq_of_order(v:val)>=a:wringout'))
endfunction
"}}}
function! s:_get_wnr_in_crrtabpage(path) "{{{
  let bnr = bufnr(a:path)
  return index(tabpagebuflist(), bnr)+1
endfunction
"}}}

"------------------
function! s:_get_entries_and_orders(decknames) "{{{
  let [entries, orders, path2deckname_dic] = [{}, [], {}]
  let i = len(a:decknames)
  while i
    let i -= 1
    try
      let [path, is_outsidedeck] = s:_get_deckpath(a:decknames[i])
    catch /flashcards: unreadable/
      echoerr 'flashcards: such name deck is not readable: ' a:decknames[i]
      unlet a:decknames[i] | continue
    endtry
    if is_outsidedeck
      let a:decknames[i] = '"'.fnamemodify(path, ':t').'"'
    end
    let path2deckname_dic[path] = a:decknames[i]
    let entries[path] = readfile(path)
    call extend(orders, map(copy(entries[path]), '[path, v:key, s:_create_orderprop(v:val)]'))
  endwhile
  return [entries, orders, path2deckname_dic]
endfunction
"}}}
function! s:_modify_orders_for_continue(difftracks, orders, newlines, path, oldlen, oldi) "{{{
  let [offsets, modifier] = flashcards#_get_renewentries_offsets_and_modifier(a:difftracks, a:orders, a:path)
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
function! flashcards#_get_renewentries_offsets_and_modifier(difftracks, orders, path) "{{{
  let [offset, save_oldi, offsets, modifier] = [0, -1, [], s:newModifier(a:orders, a:path)]
  for [v, oldi, newi] in a:difftracks
    if v==0
      call extend(offsets, repeat([offset], oldi - save_oldi))
      let save_oldi = oldi
      continue
    end
    if oldi!=-1
      let orderidx = match(a:orders, '['''.a:path.''', '.oldi.',')
      if orderidx==-1| throw 'flashcards: order is not found: '.a:path.' '.oldi | end
    end
    call modifier.reserve(v, oldi, newi)
    let offset += v
  endfor
  return [s:newOffsets(offsets), modifier]
endfunction
"}}}


"--------------------------------------
let s:Cards = {'base_hi': 'NONE'}
let s:Cards.META_UNDISPLAY = '#'
function! s:newCards(decknames, options) "{{{
  let self = {'i': 0, 'j': 0, 'decknames': a:decknames, 'entries': {}, 'orders': []}
  call extend(self, s:Cards, 'keep')
  let [self.entries, self.orders, self.path2deckname_dic] = s:_get_entries_and_orders(a:decknames)
  let self.name = join(a:decknames, ', ')
  let self.totallen = len(self.orders)
  let self.is_displaymode = 0
  let self.wringoutlv = a:options['-wringout'] ? a:options['-wringout'] : 0
  if a:options['-shuffle']
    call s:_shuffle(self.orders)
  end
  if a:options['-ratesort']
    call sort(self.orders, 's:_descsort_by_star')
  end
  call self._update_displaylens()
  return self
endfunction
"}}}
function! s:newCards_continue(decknames, entries, orders, path2deckname_dic, i, is_displaymode, wringout) "{{{
  let self = {'i': a:i, 'j': 0, 'decknames': a:decknames, 'name': join(a:decknames, ', '), 'wringout': a:wringout,
    \ 'entries': a:entries, 'orders': a:orders, 'path2deckname_dic': a:path2deckname_dic}
  let self.totallen = len(self.orders)
  let self.is_displaymode = a:is_displaymode
  call extend(self, s:Cards, 'keep')
  call self._update_displaylens()
  call self.nexti(0)
  return self
endfunction
"}}}

function! s:Cards._get_crrcount() "{{{
  return self.is_displaymode ? self._get_displayed_crrcount() : self._get_normal_crrcount()
endfunction
"}}}
function! s:Cards._get_normal_crrcount() "{{{
  return len(filter(self.orders[:self.i], '!s:_should_ignore_of_order(v:val) && s:_starq_of_order(v:val)>=self.wringoutlv'))
endfunction
"}}}
function! s:Cards._get_displayed_crrcount() "{{{
  return len(filter(self.orders[:self.i], 's:_should_ignore_of_order(v:val)!=-1 && s:_starq_of_order(v:val)>=self.wringoutlv'))
endfunction
"}}}
function! s:Cards._get_jlen() "{{{
  return len(substitute(self.crrentry, '[^[:tab:]]', '', 'g'))+1
endfunction
"}}}
function! s:Cards._get_should_ignore_cx() "{{{
  return self.is_displaymode ? 's:_should_ignore_of_order(self.orders[self.i])==-1' : 's:_should_ignore_of_order(self.orders[self.i])'
endfunction
"}}}
function! s:Cards._shouldnot_wringout() "{{{
  return s:_starq_of_order(self.orders[self.i]) >= self.wringoutlv
endfunction
"}}}

function! s:Cards._update_displaylens() "{{{
  let tmp = filter(copy(self.orders), 's:_should_ignore_of_order(v:val)!=-1  && s:_starq_of_order(v:val)>=self.wringoutlv')
  let self.displayedlen = len(tmp)
  let self.undisplayedlen = s:_calc_undisplayedlen_of(tmp, self.wringoutlv)
endfunction
"}}}
function! s:Cards._update_crrprops() "{{{
  let [self.crrentrypath, self.crrentryi, orderprop] = self.orders[self.i]
  let self.crrshould_ignore = orderprop[0]
  let entry = self.entries[self.crrentrypath][self.crrentryi]
  let self.crrentry = substitute(entry, '\t#[^[:tab:]]*$', '', 'g')
  let self.crrmeta = s:_get_meta_of(entry)
endfunction
"}}}
function! s:Cards._write_modified_entry(newentry) "{{{
  let [path, oldi] = [self.crrentrypath, self.crrentryi]
  if !filereadable(path)
    return 1
  end
  let newlines = readfile(path)
  let diff = flashcards#get_diff(self.entries[path], newlines)
  let offsets = flashcards#_get_renewentries_offsets_and_modifier(diff.tracks, self.orders, path)[0]
  let newlines[offsets.get_newi(oldi)] = a:newentry
  call writefile(newlines, path)

  let self.entries[path][oldi] = a:newentry
  let save_wnr = winnr()
  let wnr = s:_get_wnr_in_crrtabpage(path)
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
function! s:Cards._act_back() "{{{
  if self.j > 0
    let self.j -= 1
  elseif self.i > 0
    let save_i = self.i
    call self.nexti(-1)
    let self.j = self.i == save_i ? 0 : self._get_jlen()-1
  end
  redraw!
  call self._rebuild()
endfunction
"}}}
function! s:Cards._act_next() "{{{
  redraw!
  call self.nexti(1)
  let self.j = 0
  call self._rebuild()
endfunction
"}}}
function! s:Cards._act_prev() "{{{
  redraw!
  call self.nexti(-1)
  let self.j = 0
  call self._rebuild()
endfunction
"}}}
function! s:Cards._act_head() "{{{
  redraw!
  let self.i = 0
  call self.nexti(0)
  let self.j = 0
  call self._rebuild()
endfunction
"}}}
function! s:Cards._act_last() "{{{
  redraw!
  let self.i = self.totallen-1
  if self.crrshould_ignore==-1 || !self.is_displaymode && self.crrshould_ignore
    call self.nexti(-1)
  end
  let self.j = 0
  call self._rebuild()
endfunction
"}}}
function! s:Cards._act_jump() "{{{
  echoh Question
  let input = str2nr(input('jump to > '))
  redraw!
  let crrlen = self.is_displaymode ? self.displayedlen : self.undisplayedlen
  if input==0 || input > crrlen
    call self._rebuild()
    return
  end
  let self.j = 0
  let [self.i, n] = [-1, 0]
  let should_ignore_cx = self._get_should_ignore_cx()
  while n < input
    let self.i += 1
    if !eval(should_ignore_cx)
      let n += 1
    end
  endwhile
  call self._rebuild()
endfunction
"}}}
function! s:Cards._act_suspend(filename) "{{{
  let suspenddir = expand(g:flashcards#settings_dir). '/suspended'
  if !isdirectory(suspenddir)
    call mkdir(suspenddir, 'p')
  end
  let params = {'i': self.i, 'decknames': self.decknames, 'path2deckname_dic': self.path2deckname_dic, 'is_displaymode': self.is_displaymode, 'orders': self.orders, 'entries': self.entries, 'wringout': self.wringoutlv}
  call writefile([string(params)], suspenddir. '/'. a:filename)
endfunction
"}}}
function! s:Cards._act_edit() "{{{
  let [path, oldi] = [self.crrentrypath, self.crrentryi]
  let wnr = s:_get_wnr_in_crrtabpage(path)
  if wnr
    exe wnr. 'wincmd w' | edit
  else
    exe 'tabnew' path
  end
  let newlines = getline(1, '$')
  let diff = flashcards#get_diff(self.entries[path], newlines)
  let offsets = flashcards#_get_renewentries_offsets_and_modifier(diff.tracks, self.orders, path)[0]
  let idx = offsets.get_newi(oldi)
  call cursor(idx+1, 1)
endfunction
"}}}
function! s:Cards._act_toggle_undisplay() "{{{
  let is_undisplayed = self.crrmeta=~#self.META_UNDISPLAY
  let newmeta = is_undisplayed ? substitute(self.crrmeta, self.META_UNDISPLAY, '', 'g') : self.META_UNDISPLAY. self.crrmeta
  if newmeta==#self.crrmeta || self._write_modified_entry(s:_get_newentry_of(self.crrentry, newmeta))
    return
  end
  let save_crrcount = self._get_crrcount()
  let self.crrmeta = newmeta
  call s:_set_should_ignore_of_order(self.orders[self.i], !is_undisplayed)
  let self.undisplayedlen = s:_calc_undisplayedlen_of(deepcopy(self.orders), self.wringoutlv)
  if !self.is_displaymode
    let [self.j, save_i] = [0, self.i]
    call self.nexti(1)
    if self.i == save_i
      call self.nexti(-1)
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
  let starq = len(s:_get_starc(newmeta))
  if starq>10 || newmeta==#self.crrmeta || self._write_modified_entry(s:_get_newentry_of(self.crrentry, newmeta))
    return
  end
  let self.crrmeta = newmeta
  call s:_set_starq_of_order(self.orders[self.i], starq)
  redraw!
  call self._rebuild()
  return 1
endfunction
"}}}
function! s:Cards._act_decstar() "{{{
  let newmeta = substitute(self.crrmeta, '\*$', '', '')
  let starq = len(s:_get_starc(newmeta))
  if newmeta==#self.crrmeta || self._write_modified_entry(s:_get_newentry_of(self.crrentry, newmeta))
    return
  end
  let self.crrmeta = newmeta
  call s:_set_starq_of_order(self.orders[self.i], starq)
  redraw!
  call self._rebuild()
  return 1
endfunction
"}}}
function! s:Cards._act_shuffle() "{{{
  echoh Question
  if input('are you ready to shuffle? [n/y] > ')!='y'
    redraw!
    call self._rebuild()
    return
  end
  call s:_shuffle(self.orders)
  redraw!
  let self.j = 0
  call self._rebuild()
endfunction
"}}}
function! s:Cards._act_rate_sort() "{{{
  echoh Question
  if input('are you ready to sort? [n/y] > ')!='y'
    redraw!
    call self._rebuild()
    return
  end
  let order = self.orders[self.i]
  call sort(self.orders, 's:_descsort_by_star')
  let self.i = match(self.orders, string(order))
  redraw!
  call self._rebuild()
endfunction
"}}}
function! s:Cards._act_wringout() "{{{
  let save_lv = self.wringoutlv
  echoh Question
  let lv = substitute(input('wringout level > '), '\D', '', 'g')
  if lv==''
    redraw! | call self._rebuild() | return
  end
  let self.wringoutlv = str2nr(lv)
  call self._update_displaylens()
  redraw!
  if self.undisplayedlen==0
    echoh WarningMsg | echo 'make a wringout level into a little lower value.'
    let self.wringoutlv = save_lv | call self._update_displaylens() | call self._rebuild()
    return
  end
  call self.nexti(0)
  call self._rebuild()
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

function! s:Cards.nexti(delta, ...) "{{{
  let restore_i = self.i
  let self.i += a:delta
  let delta = a:delta ? a:delta : 1
  let should_ignore_cx = self._get_should_ignore_cx()
  while self.i >= 0 && self.i < self.totallen
    if !eval(should_ignore_cx) && self._shouldnot_wringout()
      call self._update_crrprops()
      return self.i
    end
    let self.i += delta
  endwhile
  let self.i =  a:0 ? a:1 : self.nexti(!delta, restore_i)
  return self.i
endfunction
"}}}
function! s:Cards.show_status() "{{{
  echo ''
  let crrdeckname = self.path2deckname_dic[self.crrentrypath]
  if self.is_displaymode
    echoh Title | echon printf("%s > %s (%d/%d) ", self.name, crrdeckname, self._get_displayed_crrcount(), self.displayedlen)
    echoh Comment | echon '[#] '
  else
    echoh Title | echon printf("%s > %s (%d/%d) ", self.name, crrdeckname, self._get_normal_crrcount(), self.undisplayedlen)
  end
  echoh Question | echon s:_get_starc(self.crrmeta)
  let self.base_hi = self.crrshould_ignore ? 'Comment' : 'NONE'
  exe 'echoh' self.base_hi
  echo (self.crrshould_ignore ? '# ' : '> '). s:_echoparse(matchstr(self.crrentry, '^.\{-}\ze\%(\t\|$\)'))
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
    elseif index(g:flashcards#mappings.jump, act)!=-1
      call self._act_jump() | return
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
    elseif index(g:flashcards#mappings.shuffle, act)!=-1
      call self._act_shuffle() | return
    elseif index(g:flashcards#mappings.rate_sort, act)!=-1
      call self._act_rate_sort() | return
    elseif index(g:flashcards#mappings.wringout, act)!=-1
      call self._act_wringout() | return
    elseif index(g:flashcards#mappings.toggle_undisplaymode, act)!=-1
      call self._act_toggle_displaymode() | return
    "elseif index(g:flashcards#mappings.toggle_reversemode, act)!=-1
      "call self._act_switch_reversemode() | return
    elseif index(g:flashcards#mappings.undisplay, act)!=-1 && self._act_toggle_undisplay() | return
    elseif index(g:flashcards#mappings.decstar, act)!=-1 && self._act_decstar() | return
    elseif index(g:flashcards#mappings.incstar, act)!=-1 && self._act_incstar() | return
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
function! s:newModifier(orders, path) "{{{
  let modifier = deepcopy(s:Modifier)
  let modifier.orders = a:orders
  let modifier.orderslen = len(a:orders)
  let modifier.path = a:path
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
  call extend(self.orders, map(copy(newis), '[self.path, v:val, s:_create_orderprop(self.newlines[v:val])]'), self.ordersi)
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
  let newline = self.newlines[newi]
  let self.orders[self.ordersi] = [self.path, newi, s:_create_orderprop(newline)]
endfunction
"}}}
function! s:Modifier.lastadds() "{{{
  if !(self.oldi == self.oldlen-1 && has_key(self.adds, self.oldlen))
    return
  end
  let newis = self.adds[self.oldlen]
  call extend(self.orders, map(copy(newis), '[self.path, v:val, s:_create_orderprop(self.newlines[v:val])]'), self.ordersi)
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
  exe 'edit +set\ filetype=flashcards' path
endfunction
"}}}
function! flashcards#comp_decks(arglead, cmdline, cursorpos) "{{{
  let opts = ['-ratesort', '-shuffle', '-wringout=']
  let beens = split(a:cmdline)[1:]
  let optlead = (a:cmdline[a:cursorpos-1]=='-' && a:cmdline[a:cursorpos-2]==' ') ? '-' : a:arglead
  if optlead=~'^-'
    return filter(opts, 'v:val =~ "^".optlead && match(beens, v:val)==-1')
  end
  let decknames = flashcards#get_decknames()
  return filter(decknames, 'v:val =~ "^".a:arglead && index(beens, v:val)==-1')
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

function! flashcards#start(source, ...) "{{{
  let cards = a:0 ? s:newCards(a:source, a:1) : a:source
  let save_mfd = &mfd
  set maxfuncdepth=1000
  redraw!
  call cards.nexti(0)
  if !has_key(cards, 'crrentry')
    return
  end
  try
    while cards.i != -99
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
      call cards.nexti(1, -99)
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
    let suspenddir = expand(g:flashcards#settings_dir). '/suspended'
    call delete(suspenddir. '/on_error')
    if exists('cards') && cards.i >= cards.totallen
      call delete(suspenddir. '/continue')
    end
  endtry
endfunction
"}}}

function! flashcards#continue(...) "{{{
  let suspenddir = expand(g:flashcards#settings_dir). '/suspended'
  let _filename = a:0 ? a:1 : 'continue'
  if !filereadable(suspenddir. '/'. _filename)
    echoh WarningMsg | echo 'flashcards: continuefile is not exist.' | echoh NONE
    return
  end
  let suspended = eval(readfile(suspenddir. '/'. _filename)[0])
  let entries = suspended.entries
  let orders = suspended.orders
  let newentries = {}
  for [path, deckname] in items(suspended.path2deckname_dic)
    if !filereadable(path)
      echoerr 'flashcards: such name deck is not readable: ' deckname
      call filter(suspended.decknames, 'v:val!=deckname') | continue
    end
    let newentries[path] = readfile(path)
    let diff = flashcards#get_diff(entries[path], newentries[path])
    if diff.edit_distance
      let [orders, suspended.i] = s:_modify_orders_for_continue(diff.tracks, orders, newentries[path], path, len(entries[path]), suspended.i)
    end
  endfor
  let cards = s:newCards_continue(suspended.decknames, newentries, orders, suspended.path2deckname_dic, suspended.i, suspended.is_displaymode, suspended.wringout)
  call flashcards#start(cards)
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
