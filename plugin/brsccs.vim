" brsccs.vim the sccs browser
"
" based on the sccs.vim code by Erik Janssen
" written by Alexander Gorshenev, Denis Antrushin
"
"TODO: 
"2. make increase and decrease to work with branches 
"3. add mouse binding for decrease under
"4. extract all the paratemers into the header:
"	current ver. highlite
"	widthes
"	vertical/horizontal split
"	etc
"5. more attention to "nonu", "noh" etc
"
if exists("g:brsccs_loaded")
    finish
endif
let g:brsccs_loaded = 1

if !exists('SccsBrowser_Split')
  let SccsBrowser_Split = 0
endif

function! SccsLoadHistory(original)
  if SccsTryWindow("sccs_versions") == 0
    silent exe "20vnew sccs_versions"
    set buftype=nofile
  endif
  let b:original = a:original
  1,$d
  exe "silent 0r!sccs prs -e -d\":I:\\t:P:\\n:C:\" " . a:original . " 2>/dev/null"
  normal! gg
endfunction

function! SccsBrowse()
  let l:original = bufname( "%" )
  let l:syntax = &syntax
  let b:original = l:original
  let b:current_version = "default.version"
  call SccsLoadVersion(b:original, "default.version")
  exe "set syntax=" . l:syntax
  normal! gg
  call SccsLoadHistory(b:original)
  exe "set syntax=" . l:syntax
  wincmd p
endfunction

augroup brsccs_
  au! 
  autocmd BufFilePost,BufEnter sccs_* nnoremap <Return> :call SccsGetVersion()<CR>
  autocmd BufFilePost,BufEnter sccs_* nnoremap <LeftMouse> <LeftMouse>:call SccsGetVersion()<CR>
  autocmd BufLeave sccs_* nunmap <Return>
  autocmd BufLeave sccs_* nunmap <LeftMouse>
augroup END

augroup versions_
  au!
  autocmd BufFilePost,BufEnter sccs_versions nnoremap <Down> /^[0-9\.][0-9\.]*<CR>:noh<CR>
  autocmd BufFilePost,BufEnter sccs_versions nnoremap j /^[0-9\.][0-9\.]*<CR>:noh<CR>
  autocmd BufFilePost,BufEnter sccs_versions nnoremap <Up> ?^[0-9\.][0-9\.]*<CR>:noh<CR>
  autocmd BufFilePost,BufEnter sccs_versions nnoremap k ?^[0-9\.][0-9\.]*<CR>:noh<CR>
  autocmd BufLeave sccs_versions nunmap <Down>
  autocmd BufLeave sccs_versions nunmap j
  autocmd BufLeave sccs_versions nunmap <Up>
  autocmd BufLeave sccs_versions nunmap k
augroup END

" Matches an sccs version number at the beginning of the line 
function! SccsFigureOutVersion()
  return substitute(getline("."), "^\\([0-9\\.][0-9\\.]*\\).*$", "\\1", "")
endfunction

" If the window is open, jump to it and return 1
" Otherwise return 0 and do NOT open a new window
function! SccsTryWindow(name)
  if bufname( "%" ) == a:name
    return 1
  endif
  " If the window is open, jump to it
  let winnum = bufwinnr(a:name)
  if winnum != -1
  " Jump to the existing window
     if winnr() != winnum
       exe winnum . 'wincmd w'
     endif
     return 1
   endif
   return 0
endfunction

"This is what needs to be done when user presses enter
function! SccsGetVersion()
  let l:version = SccsFigureOutVersion()
  call SccsLoadVersion(b:original, l:version)
endfunction

"Scroll the history window so that the current version 
"is in the center of the window
function! SccsPositionHistory(version)
  if a:version == "default.version" 
    return 
  endif
  if SccsTryWindow("sccs_versions") == 1
    normal! gg
    exe "/^" . a:version . "\t"
    :noh
    normal! z.
    :hi sccs_versions ctermfg=cyan guifg=#80a0ff 
    exe ":match sccs_versions /^" .a:version. "	/"
  endif
endfunction

"Given a line number in a version
"calculate the matching line number in another version
function! SccsRecalculateLineNumber(original, current_version, current_position, new_version)

  if a:current_version == "default.version" || a:new_version == "default.version"
    return a:current_position
  endif

  if !exists("g:scratchbufnr")
    hide enew
    let g:scratchbufnr = bufnr("%")
  else
    exec 'hide buffer ' . g:scratchbufnr
  endif
  set buftype=nofile bufhidden=hide noswapfile
  1,$d

  silent exe "0r!sccs sccsdiff -b -w -c -r" . a:current_version . " -r" . a:new_version . " " .  a:original ." 2>/dev/null | egrep \"^--- |^\\*\\*\\* \"| tail +3" 
  $d

" The hidden buffer now contains pairs of lines:
"*** 4662,4672 ****
"--- 4688,4705 ----

  let l:old_beg = 0
  let l:old_end = 0
  let l:new_beg = 0
  let l:new_end = 0

  normal! gg
  while line(".") < line("$")
    let l:old_beg = substitute(getline("."), "\\*\\*\\* \\([0-9][0-9]*\\)\\,.*$", "\\1", "")
    let l:old_end = substitute(getline("."), "^.*,\\([0-9][0-9]*\\) .*$", "\\1", "")
    normal! j
    let l:new_beg = substitute(getline("."), "--- \\([0-9][0-9]*\\)\\,.*$", "\\1", "")
    let l:new_end = substitute(getline("."), "^.*,\\([0-9][0-9]*\\) .*$", "\\1", "")

    if a:current_position < l:old_beg
      buffer #
      return a:current_position + l:new_beg - l:old_beg
    elseif (l:old_beg <= a:current_position) && (a:current_position <= l:old_end)
      buffer #
      return a:current_position + l:new_beg - l:old_beg
    endif

    normal! j
  endwhile

  buffer #
  return a:current_position + l:new_end - l:old_end

endfunction

" Loads specific version of the file
" Or if the arg is "default.version" loads the "sccs get -pm"
function! SccsLoadVersion(original, version)
  "Leave this window for a second
  call SccsPositionHistory(a:version)
  if SccsTryWindow("sccs_browser") == 0
    if g:SccsBrowser_Split || filewritable(a:original)
	let cmd = 'new'
    else
	let cmd = 'file'
    endif
    silent exe cmd . " sccs_browser"
    set buftype=nofile
    set nodiff
    let b:current_version = a:version
  endif
  let l:current_position = line(".")
  let l:current_winline = winline()
  let l:recalculated_position = SccsRecalculateLineNumber(a:original, b:current_version, l:current_position, a:version)
  1,$d
  let b:original = a:original
  let b:current_version = a:version
  if a:version == "default.version"
    silent exe "0r!sccs get -pm " . b:original . " 2>/dev/null"
  else 
    silent exe "0r!sccs get -pm -r" . a:version . " " . b:original . " 2>/dev/null"
  endif
  $d
  exe l:recalculated_position
  let l:winline_scroll = l:current_winline - winline()
  if l:winline_scroll > 0 
    exe "normal!". l:winline_scroll . ""
  elseif l:winline_scroll < 0
    let l:winline_scroll = -l:winline_scroll
    exe "normal!". l:winline_scroll . "^Y"
  endif

endfunction

function! SccsUserRequest(version)
  if exists("b:original")
  	call SccsLoadVersion(b:original, a:version)
  else 
  	call SccsBrowse()
	call SccsLoadVersion(b:original, a:version)
  endif
endfunction

" Currently to evaluate the next and the previous versions
" of a file I use the following two commands:
"sccs prs -l -r1.19 -d":I:" ./brsccs.vim | tail -2  | head -1
"sccs prs -e -r1.1 -d":I:" ./brsccs.vim | head -2 | tail -1  
" This is wrong as 1.18.1.2-like branches should be taken into account!

function! SccsIncreaseGivenDelta(original, delta)
  if a:delta == "default.version"
    return "default.version"
  endif
  let l:new_version = system("sccs prs -l -r" . a:delta . " -d\":I:\" " . a:original .  " | tail -2  | head -1")
  " chop
  return substitute(l:new_version, "[^0-9\.].*$", "", "")
endfunction


function! SccsDecreaseGivenDelta(original, delta)
  if a:delta == "default.version"
    let l:new_version = system("sccs prs -e -d\":I:\" " . a:original .  " | head -1")
  else 
    let l:new_version = system("sccs prs -e -r" . a:delta . " -d\":I:\" " . a:original .  " | head -2 | tail -1")
  endif
  " chop
  return substitute(l:new_version, "[^0-9\.].*$", "", "")
endfunction


function! SccsIncrease()
  if bufname( "%" ) != "sccs_browser"
    return
  endif
  if b:current_version == "default.version"
    return
  endif
  call SccsLoadVersion(b:original, SccsIncreaseGivenDelta(b:original, b:current_version))
endfunction


function! SccsDecrease()
  if bufname( "%" ) != "sccs_browser"
      return
  endif
  call SccsLoadVersion(b:original, SccsDecreaseGivenDelta(b:original, b:current_version))
endfunction

function! SccsDecreaseUnder()
  if bufname( "%" ) != "sccs_browser"
      return
  endif
  let l:version = SccsFigureOutVersion()
  call SccsLoadVersion(b:original, SccsDecreaseGivenDelta(b:original, l:version))
endfunction




nmap <silent> ,v :call SccsBrowse()<CR>
nmap <silent> ,+ :call SccsIncrease()<CR>
nmap <silent> ,= :call SccsIncrease()<CR>
nmap <silent> ,- :call SccsDecrease()<CR>
nmap <silent> ,< :call SccsDecreaseUnder()<CR>

command! -nargs=1 Sccs call SccsUserRequest(<q-args>)

