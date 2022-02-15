"=============== JETPACK.vim =================
"      The lightnig-fast plugin manager
"     Copyrigh (c) 2022 TANGUCHI Masaya.
"          All Rights Reserved.
"=============================================

let g:pack#optimization = 1
let g:pack#njobs = 8

let s:home = expand(has('nvim') ? '~/.local/share/nvim/site' : '~/.vim')
let s:packdir = s:home .. '/pack/jetpack'

let s:pkgs = []
let s:plugs = []
let s:ignores = [
  \ "**/.*",
  \ "**/.*/**/*",
  \ "**/t/**/*",
  \ "**/test/**/*",
  \ "**/VimFlavor*",
  \ "**/Flavorfile*",
  \ "**/README*",
  \ "**/Rakefile*",
  \ "**/Gemfile*",
  \ "**/Makefile*",
  \ "**/LICENSE*",
  \ "**/LICENCE*",
  \ "**/CONTRIBUTING*",
  \ "**/CHANGELOG*",
  \ "**/NEWS*",
  \ ]

let s:events = [
  \ 'BufNewFile', 'BufReadPre', 'BufRead', 'BufReadPost', 'BufReadCmd',
  \ 'FileReadPre', 'FileReadPost', 'FileReadCmd', 'FilterReadPre',
  \ 'FilterReadPost', 'StdinReadPre', 'StdinReadPost', 'BufWrite',
  \ 'BufWritePre', 'BufWritePost', 'BufWriteCmd', 'FileWritePre',
  \ 'FileWritePost', 'FileWriteCmd', 'FileAppendPre', 'FileAppendPost',
  \ 'FileAppendCmd', 'FilterWritePre', 'FilterWritePost', 'BufAdd', 'BufCreate',
  \ 'BufDelete', 'BufWipeout', 'BufFilePre', 'BufFilePost', 'BufEnter',
  \ 'BufLeave', 'BufWinEnter', 'BufWinLeave', 'BufUnload', 'BufHidden',
  \ 'BufNew', 'SwapExists', 'FileType', 'Syntax', 'EncodingChanged',
  \ 'TermChanged', 'VimEnter', 'GUIEnter', 'GUIFailed', 'TermResponse',
  \ 'QuitPre', 'VimLeavePre', 'VimLeave', 'FileChangedShell',
  \ 'FileChangedShellPost', 'FileChangedRO', 'ShellCmdPost', 'ShellFilterPost',
  \ 'FuncUndefined', 'SpellFileMissing', 'SourcePre', 'SourceCmd', 'VimResized',
  \ 'FocusGained', 'FocusLost', 'CursorHold', 'CursorHoldI', 'CursorMoved',
  \ 'CursorMovedI', 'WinEnter', 'WinLeave', 'TabEnter', 'TabLeave',
  \ 'CmdwinEnter', 'CmdwinLeave', 'InsertEnter', 'InsertChange', 'InsertLeave',
  \ 'InsertCharPre', 'TextChanged', 'TextChangedI', 'ColorScheme',
  \ 'RemoteReply', 'QuickFixCmdPre', 'QuickFixCmdPost', 'SessionLoadPost',
  \ 'MenuPopup', 'CompleteDone', 'User'
  \ ]

function s:files(path)
  let files = []
  for item in glob(a:path .. '/**/*', '', 1)
    if glob(item .. '/') == ''
      call add(files, item)
    endif
  endfor
  return files
endfunction

function s:ignorable(filename)
  for ignore in s:ignores
    if a:filename =~ glob2regpat(ignore)
      return 1
    endif
  endfor
  return 0
endfunction

function s:mergable(pkgs, pkg)
  let path = []
  for pkg in a:pkgs
    call add(path, pkg.path)
  endfor
  let path = join(path, ',')
  for abspath in s:files(a:pkg.path)
    let relpath = substitute(abspath, a:pkg.path, '', '')
    if !s:ignorable(relpath) && globpath(path, '**/' .. relpath) != ''
      return 0
    endif
  endfor
  return 1
endfunction

function s:jobstatus(job)
  if has('nvim')
    if jobwait([a:job], 0)[0] == -1
      return 'run'
    endif
    return 'dead'
  endif
  return job_status(a:job)
endfunction

function s:jobcount(jobs)
  let c = 0
  for job in a:jobs
    if s:jobstatus(job) == 'run'
      let c = c + 1
    endif
  endfor
  return c
endfunction

function s:jobwait(jobs, njobs)
  let running = s:jobcount(a:jobs)
  while running > a:njobs
    let running = s:jobcount(a:jobs)
  endwhile
endfunction

function s:jobstart(cmd, cb)
  if has('nvim')
    return jobstart(a:cmd, { 'on_exit': a:cb })
  else
    return job_start(a:cmd, { 'exit_cb': a:cb })
  endif
endfunction

function s:syntax()
  syntax clear
  syntax keyword packProgress Installing
  syntax keyword packProgress Updating
  syntax keyword packProgress Checking
  syntax keyword packProgress Copying
  syntax keyword packComplete Installed
  syntax keyword packComplete Updated
  syntax keyword packComplete Checked
  syntax keyword packComplete Copied
  syntax keyword packSkipped Skipped
  highlight def link packProgress DiffChange
  highlight def link packComplete DiffAdd
  highlight def link packSkipped DiffDelete
endfunction

function s:setbufline(lnum, text, ...)
  call setbufline('PackStatus', a:lnum, a:text)
  redraw
endfunction

function s:createbuf()
  silent vsplit +setlocal\ buftype=nofile\ nobuflisted\ noswapfile\ nonumber\ nowrap PackStatus
  vertical resize 40
  call s:syntax()
  redraw
endfunction

function s:deletebuf()
  execute 'bdelete ' .. bufnr('PackStatus')
  redraw
endfunction

function pack#install(...)
  call s:createbuf()
  call s:setbufline(2, '------------------------------------------------')
  let jobs = []
  for i in range(len(s:pkgs))
    call s:setbufline(1, printf('Install Plugins (%d / %d)', (len(jobs) - s:jobcount(jobs)), len(s:pkgs)))
    call s:setbufline(i+3, printf('Installing %s ...', s:pkgs[i].name))
    if (a:0 > 0 && index(a:000, s:pkgs[i].name) < 0) || glob(s:pkgs[i].path .. '/') != ''
      call s:setbufline('PackInstall', i+3, printf('Skipped %s', s:pkgs[i].name))
      continue
    endif
    let cmd = ['git', 'clone', '--depth', '1']
    if s:pkgs[i].branch
      call extend(cmd, ['-b', s:pkgs[i].branch])
    endif
    call extend(cmd, [s:pkgs[i].url, s:pkgs[i].path])
    let job = s:jobstart(cmd, function('<SID>setbufline', [i+3, printf('Installed %s', s:pkgs[i].name)]))
    call add(jobs, job)
    call s:jobwait(jobs, g:pack#njobs)
  endfor
  call s:jobwait(jobs, 0)
  call s:deletebuf()
endfunction

function pack#update(...)
  call s:createbuf()
  call s:setbufline(2, '------------------------------------------------')
  let jobs = []
  for i in range(len(s:pkgs))
    call s:setbufline(1, printf('Update Plugins (%d / %d)', (len(jobs) - s:jobcount(jobs)), len(s:pkgs)))
    call s:setbufline(i+3, printf('Updating %s ...', s:pkgs[i].name))
    if (a:0 > 0 && index(a:000, s:pkgs[i].name) < 0) || (s:pkgs[i].frozen || glob(s:pkgs[i].path .. '/') == '')
      call s:setbufline(i+3, printf('Skipped %s', s:pkgs[i].name))
      continue
    endif
    let cmd = ['git', '-C', s:pkgs[i].path, 'pull']
    let job = s:jobstart(cmd, function('<SID>setbufline', [i+3, printf('Updated %s', s:pkgs[i].name)]))
    call add(jobs, job)
    call s:jobwait(jobs, g:pack#njobs)
  endfor
  call s:jobwait(jobs, 0)
  call s:deletebuf()
endfunction

function pack#bundle()
  call s:createbuf()
  call s:setbufline(2, '------------------------------------------------')
  let bundle = []
  let unbundle = []
  for i in range(len(s:pkgs))
    call s:setbufline(1, printf('Check Plugins (%d / %d)', i, len(s:pkgs)))
    call s:setbufline(i+3, printf('Checking %s ...', s:pkgs[i].name))
    if g:pack#optimization >= 1
         \ && s:pkgs[i].packtype == 'start'
         \ && (g:pack#optimization || s:mergable(bundle, s:pkgs[i]))
      call add(bundle, s:pkgs[i])
    else
      call add(unbundle, s:pkgs[i])
    endif
    call s:setbufline(i+3, printf('Checked %s', s:pkgs[i].name))
  endfor
  call delete(s:packdir .. '/opt', 'rf')
  call delete(s:packdir .. '/start', 'rf')
  let destdir = s:packdir .. '/start/_'
  call s:deletebuf()

  call s:createbuf()
  call s:setbufline(2, '------------------------------------------------')
  for i in range(len(bundle))
    let pkg = bundle[i]
    call s:setbufline(1, printf('Copy Plugins (%d / %d)', i, len(s:pkgs)))
    call s:setbufline(i+3, printf('Coping %s ...', pkg.name))
    let srcdir = pkg.path .. '/' .. pkg.subdir
    for srcfile in s:files(srcdir)
      let destfile = substitute(srcfile, srcdir, destdir, '') 
      call mkdir(fnamemodify(destfile, ':p:h'), 'p')
      let blob = readfile(srcfile, 'b')
      call writefile(blob, destfile, 'b')
    endfor
    call s:setbufline(i+3, printf('Copied %s ...', pkg.name))
  endfor

  for i in unbundle
    let pkg = unbundle[i]
    call s:setbufline(1, printf('Copy Plugins (%d / %d)', i+len(bundle), len(s:pkgs)))
    call s:setbufline(i+len(bundle)+3, printf('Copying %s ...', pkg.name))
    let srcdir = pkg.path .. '/' .. pkg.subdir
    let destdir = s:packdir .. '/' .. pkg.packtype .. '/' .. pkg.name
    for srcfile in s:files(srcdir)
      let destfile = substitute(srcfile, srcdir, destdir, '')
      call mkdir(fnamemodify(destfile, ':p:h'), 'p')
      let blob = readfile(srcfile, 'b')
      call writefile(blob, destfile, 'b')
    endfor
    call s:setbufline(i+len(bundle)+3, printf('Copyied %s ...', pkg.name))
  endfor
  call s:deletebuf()
endfunction

function pack#postupdate()
  packloadall 
  for pkg in s:pkgs
    if type(pkg.hook) == v:t_func
      call pkg.hook()
    endif
    if type(pkg.hook) == v:t_string
      if pkg.hook =~ '^:'
        call system(pkg.hook)
      else
        execute pkg.hook
      endif
    endif
  endfor
  packloadall | silent! helptags ALL
endfunction

function pack#sync()
  echomsg 'Installing plugins ...'
  call pack#install()
  echomsg 'Updating plugins ...'
  call pack#update()
  echomsg 'Bundling plugins ...'
  call pack#bundle()
  echomsg 'Running the post-update hooks ...'
  call pack#postupdate()
  echomsg 'Complete'
endfunction

function pack#add(plugin, ...)
  let opts = {}
  if a:0 > 0
    call extend(opts, a:1)
  endif
  let name = fnamemodify(a:plugin, ':t')
  let path = s:packdir .. '/src/' .. name
  let pkg  = {
        \  'url': 'https://github.com/' .. a:plugin,
        \  'branch': get(opts, 'branch', get(opts, 'tag')),
        \  'hook': get(opts, 'do'),
        \  'subdir': get(opts, 'rtp', '.'),
        \  'name': get(opts, 'as', name),
        \  'frozen': get(opts, 'frozen'),
        \  'path': get(opts, 'dir', path),
        \  'packtype': get(opts, 'opt') ? 'opt' : 'start',
        \ }
  let ft = get(opts, 'for', [])
  let ft = type(ft) == v:t_string ? split(ft, ',') : ft
  let ft = ft == [''] ? [] : ft
  for it in ft
    let pkg.packtype = 'opt'
    execute printf('autocmd FileType %s silent! packadd %s', it, name)
  endfor
  let cmd = get(opts, 'on', [])
  let cmd = type(cmd) == v:t_string ? split(cmd, ',') : cmd
  let cmd = cmd == [''] ? [] : cmd
  for it in cmd
    let pkg.packtype = 'opt'
    if it =~ '^<Plug>'
      execute printf("nnoremap %s :execute '".'packadd %s \| call feedkeys("\%s")'."'<CR>", it, name, it)
    elseif index(s:events, it) >= 0
      execute printf('autocmd %s silent! packadd %s', it, name)
    else
      execute printf('autocmd CmdUndefined %s silent! packadd %s', it, name)
    endif
  endfor
  call add(s:pkgs, pkg)
endfunction

function pack#begin(...)
  if a:0 != 0
    let s:home = a:1
    let s:packdir = s:home .. '/pack/jetpack'
    execute 'set packpath^=' .. s:home
  endif
  command! -nargs=+ Pack call pack#add(<args>)
endfunction

function pack#end()
  delcommand Pack
endfunction

command! -nargs=* PackInstall call pack#install(<q-args>)
command! -nargs=* PackUpdate call pack#update(<q-args>)
command! PackBundle call pack#bundle()
command! PackPostUpdate call pack#postupdate()
command! PackSync call pack#sync()
