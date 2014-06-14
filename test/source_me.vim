if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
function! s:echo(name, result) "{{{
  if a:result
    echon ' ' a:name ': ok'
  else
    echoerr string(a:name) ': fail'
  end
endfunction
"}}}

"======================================
function! s:diff_test() "{{{
  echo 'diff_test'
  " flashcards#get_diff(old_list, new_list)
  " tracksの各要素の解説(リストインリスト) : [差(0 or 1 or -1), oldのidx, newのidx]

  " 差がないとき
  let diff = flashcards#get_diff(['a', 'b', 'c'], ['a', 'b', 'c'])
  call s:echo(1.1, diff.edit_distance ==# 0)
  call s:echo(1.2, diff.tracks ==# [[0, 0, 0], [0, 1, 1], [0, 2, 2]])

  " 余計なものが挿入されたとき
  let diff = flashcards#get_diff(['a', 'b', 'c'], ['a', 'A', 'b', 'c'])
  call s:echo(2.1, diff.edit_distance ==# 1)
  call s:echo(2.2, diff.tracks ==# [[0, 0, 0], [1, 0, 1], [0, 1, 2], [0, 2, 3]])

  " 要素が削除されたとき
  let diff = flashcards#get_diff(['a', 'b', 'c'], ['a', 'c'])
  call s:echo(3.1, diff.edit_distance ==# 1)
  call s:echo(3.2, diff.tracks ==# [[0, 0, 0], [-1, 1, 0], [0, 2, 1]])

  " 追加して削除があったとき (要素が修正されたとき)
  let diff = flashcards#get_diff(['a', 'b', 'c'], ['a', 'B', 'c'])
  call s:echo(4.1, diff.edit_distance ==# 2)
  call s:echo(4.2, diff.tracks ==# [[0, 0, 0], [1, 0, 1], [-1, 1, 1], [0, 2, 2]])

  " 初めの要素が削除されたとき (idxには-1が入る)
  let diff = flashcards#get_diff(['a', 'b', 'c'], ['c'])
  call s:echo(5.1, diff.edit_distance ==# 2)
  call s:echo(5.2, diff.tracks ==# [[-1, 0, -1], [-1, 1, -1], [0, 2, 0]])

  " 初めに要素が挿入されたとき
  let diff = flashcards#get_diff(['a', 'b', 'c'], ['', '', 'a', 'b', 'c'])
  call s:echo(6.1, diff.edit_distance ==# 2)
  call s:echo(6.2, diff.tracks ==# [[1, -1, 0], [1, -1, 1], [0, 0, 2], [0, 1, 3], [0, 2, 4]])

  " 初めに要素が修正されたとき
  let diff = flashcards#get_diff(['a', 'b', 'c'], ['A', 'b', 'c'])
  call s:echo(7.1, diff.edit_distance ==# 2)
  call s:echo(7.2, diff.tracks ==# [[1, -1, 0], [-1, 0, 0], [0, 1, 1], [0, 2, 2]])
endfunction
"}}}

"======================================
function! s:get_offsets_and_modifier_test() "{{{
  echo 'get_offsets_test'
  let deckname = 'test'

  " 変化なしの場合
  let entry = ['a', '', 'b', "c\ti", 'd']
  let orders = [['test', 0, 0], ['test', 1, -1], ['test', 2, 0], ['test', 3, 1], ['test', 4, 0]]
  let diff = flashcards#get_diff(entry, entry)
  let result = flashcards#_get_renewentries_offsets_and_modifier(diff.tracks, orders, deckname)
  let [offsets, modifier] = result
  call s:echo(1.1, result[0].offsets ==# [0, 0, 0, 0, 0])
  call s:echo(1.2, result[1].adds ==# {})
  call s:echo(1.3, result[1].dels ==# {})

  " 削除が行われた場合
  " delsreserve の要素解説 key: oldi, val: ''
  let entry = ['a', '', 'b', "c\ti", 'd']
  let orders = [['test', 0, 0], ['test', 1, -1], ['test', 2, 0], ['test', 3, 1], ['test', 4, 0]]
  let newentry = ['a', 'b', 'd']
  let diff = flashcards#get_diff(entry, newentry)
  let result = flashcards#_get_renewentries_offsets_and_modifier(diff.tracks, orders, deckname)
  call s:echo(2.1, result[0].offsets ==# [0, -1, -1, -2, -2])
  call s:echo(2.2, result[1].adds ==# {})
  call s:echo(2.3, result[1].dels ==# {'1': '', '3': ''})
  " ordersの順番を入れかえても結果は変わらない
  let orders = [['test', 4, 0], ['test', 0, 0], ['test', 3, 1], ['test', 1, -1], ['test', 2, 0], ]
  let diff = flashcards#get_diff(entry, newentry)
  let result = flashcards#_get_renewentries_offsets_and_modifier(diff.tracks, orders, deckname)
  call s:echo(2.4, result[0].offsets ==# [0, -1, -1, -2, -2])
  call s:echo(2.5, result[1].adds ==# {})
  call s:echo(2.6, result[1].dels ==# {'1': '', '3': ''})

  " 先頭と末尾にに新しく要素が加えられた場合
  " addsreserve の要素解説 key: oldi, val: [newi, newi, ...]
  let entry = ['a', '', 'b', "c\ti", 'd']
  let orders = [['test', 0, 0], ['test', 1, -1], ['test', 2, 0], ['test', 3, 1], ['test', 4, 0]]
  let newentry = ['', '', 'a', '', 'b', "c\ti", 'd', '', '']
  let diff = flashcards#get_diff(entry, newentry)
  let result = flashcards#_get_renewentries_offsets_and_modifier(diff.tracks, orders, deckname)
  call s:echo(3.1, result[0].offsets ==# [2, 2, 2, 2, 2])
  call s:echo(3.2, result[1].adds ==# {'0': [0, 1], '5': [7, 8]})
  call s:echo(3.3, result[1].dels ==# {})
  " ordersの順番を入れかえても結果は変わらない
  let orders = [['test', 4, 0], ['test', 0, 0], ['test', 3, 1], ['test', 1, -1], ['test', 2, 0], ]
  let diff = flashcards#get_diff(entry, newentry)
  let result = flashcards#_get_renewentries_offsets_and_modifier(diff.tracks, orders, deckname)
  call s:echo(3.4, result[0].offsets ==# [2, 2, 2, 2, 2])
  call s:echo(3.5, result[1].adds ==# {'0': [0, 1], '5': [7, 8]})
  call s:echo(3.6, result[1].dels ==# {})

  " 初めの2つの要素が変更された場合
  " addsreserve の要素解説 key: oldi, val: [newi, newi, ...]
  " delsreserve の要素解説 key: oldi, val: ''
  let entry = ['a', '', 'b', "c\ti", 'd']
  let orders = [['test', 0, 0], ['test', 1, -1], ['test', 2, 0], ['test', 3, 1], ['test', 4, 0]]
  let newentry = ['A1', 'A2', 'b', "c\ti", 'd']
  let diff = flashcards#get_diff(entry, newentry)
  let result = flashcards#_get_renewentries_offsets_and_modifier(diff.tracks, orders, deckname)
  call s:echo(4.1, result[0].offsets ==# [0, 0, 0, 0, 0])
  call s:echo(4.2, result[1].adds ==# {'0': [0, 1]})
  call s:echo(4.3, result[1].dels ==# {'0': '', '1': ''})
  " ordersの順番を入れかえても結果は変わらない
  let orders = [['test', 4, 0], ['test', 0, 0], ['test', 3, 1], ['test', 1, -1], ['test', 2, 0], ]
  let diff = flashcards#get_diff(entry, newentry)
  let result = flashcards#_get_renewentries_offsets_and_modifier(diff.tracks, orders, deckname)
  call s:echo(4.4, result[0].offsets ==# [0, 0, 0, 0, 0])
  call s:echo(4.5, result[1].adds ==# {'0': [0, 1]})
  call s:echo(4.6, result[1].dels ==# {'0': '', '1': ''})

  let entry = ['a', '', 'b', "c\ti", 'd']
  let orders = [['test', 4, 0], ['test', 0, 0], ['test', 3, 1], ['test', 1, -1], ['test', 2, 0], ]
  let newentry = ['', 'Z', 'a', 'A', 'B', 'b', 'd', 'e', 'f', 'g']
  let diff = flashcards#get_diff(entry, newentry)
  let result = flashcards#_get_renewentries_offsets_and_modifier(diff.tracks, orders, deckname)
  call s:echo(5.1, result[0].offsets ==# [2, 3, 3, 2, 2])
  call s:echo(5.2, result[1].adds ==# {'0': [0, 1], '1': [3, 4], '5': [7, 8, 9]})
  call s:echo(5.3, result[1].dels ==# {'1': '', '3': ''})
endfunction
"}}}

"======================================
function! s:s_get_newentry_of() "{{{
  echo 's_get_newentry_of test'
  let S = taste#get_sfuncs('autoload/flashcards.vim')
  if S=={}
    echo 'autoload/flashcards.vim がまだ読み込まれていません'
    return
  end
  call s:echo(1.1, S._get_newentry_of("\t#aaa", 'i') == "\t#[i]aaa")
  call s:echo(1.2, S._get_newentry_of("\t#[i]aaa", '') == "\t#aaa")
  call s:echo(1.3, S._get_newentry_of("\t#aaa", '') == "\t#aaa")
  call s:echo(2.1, S._get_newentry_of("aaaa", 'i') == "aaaa\t#[i]")
  call s:echo(2.2, S._get_newentry_of("aaaa\t#[jkl]", '') == "aaaa")
  call s:echo(2.3, S._get_newentry_of("aaaa\t", '***') == "aaaa\t\t#[***]")
endfunction
"}}}

call s:diff_test()
call s:get_offsets_and_modifier_test()
call s:s_get_newentry_of()
"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
