function! s:tags_file_path() abort
    return get(b:, 'tagmgr_tags_file', '')
endfunction

function! s:run_command(command)
    let log = system(a:command)
    if v:shell_error == 0
        return 1
    else
        echo 'Updating failed with exit status' v:shell_error
        echo a:command
        echo log
        return 0
    endif
endfunction

function! s:ctags_cmd_base() abort
    let cmd = 'ctags --c++-kinds=+p --fields=+iaS --extra=+q '

    if get(b:, 'tagmgr_recurse_dirs')
        let cmd .= '-R '
    endif

    return cmd
endfunction

function! tagmgr#update() abort
    let tags = s:tags_file_path()
    if tags ==# ''
        echo 'No tag file configured'
        return
    endif

    let cmd = s:ctags_cmd_base() . '-f ' . tags . ' '

    for d in get(b:, 'tagmgr_src_subdirs', [''])
        let cmd .= simplify(fnameescape(getcwd() . '/' . d) . '/*') . ' '
    endfor

    call s:run_command(cmd)
endfunction

function! tagmgr#erase() abort
    let tags = s:tags_file_path()
    if (tags ==# '') || !filereadable(tags)
        return
    endif

    call delete(tags)
endfunction

function! tagmgr#update_one() abort
    if !get(b:, 'tagmgr_autoupdate', 1)
        return
    endif

    let tags = s:tags_file_path()
    if (tags ==# '') || !filereadable(tags)
        return
    endif

    let temp = tags . '.tmp'

    let file = resolve(fnameescape(expand('%:p')))
    let path = fnamemodify(file, ':h')

    let matched = 0
    for d in get(b:, 'tagmgr_src_subdirs', [''])
        let ppath = resolve(fnameescape(getcwd() . '/' . d))
        if (path ==# ppath)
            let matched = 1
        endif
    endfor

    if !matched
        return
    endif

    let cmd = 'sed "/' . escape(file, './') . '/d" ' . tags . ' > ' . temp
    let cmd .= '; ' . s:ctags_cmd_base() . '-a -f ' . temp . ' ' . file
    let cmd .= '; mv ' . temp . ' ' . tags

    call s:run_command(cmd)
endfunction

command! -nargs=0 TagsUpdate call tagmgr#update()

command! -nargs=0 TagsErase call tagmgr#erase()

augroup tagmgr
    autocmd!
    autocmd BufWritePost *.cpp,*.h,*.c call tagmgr#update_one()
augroup END
