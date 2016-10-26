let s:language_map = {}
let s:language_map['C']    = ['*.c', '*.C', '*.h', '*.H']
let s:language_map['C++']  = ['*.cpp', '*.cc', '*.hpp']
let s:language_map['Java'] = ['*.java']

function! s:tags_file_path() abort
    return split(&tags, ',')[0]
endfunction

function! s:language_list() abort
    return get(b:, 'tagmgr_languages', ['C', 'C++'])
endfunction

function! s:subdirs_list() abort
    return get(b:, 'tagmgr_src_subdirs', [''])
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
    let cmd = 'ctags --fields=+ianS --extra=+q --excmd=number '

    if get(b:, 'tagmgr_recurse_dirs')
        let cmd .= '-R '
    endif

    let cmd .= '--languages=' . join(s:language_list(), ',') . ' '

    return cmd
endfunction

function! s:belongs_to_dir(file) abort
    let path = fnamemodify(a:file, ':h')

    for d in s:subdirs_list()
        let ppath = resolve(fnameescape(getcwd() . '/' . d))
        if (path ==# ppath)
            return 1
        endif
    endfor

    return 0
endfunction

function! s:matches_language(file) abort
    let name = fnamemodify(a:file, ':t')

    for l in s:language_list()
        if has_key(s:language_map, l)
            for glob in s:language_map[l]
                if match(name, '\C' . glob2regpat(glob)) != -1
                    return 1
                endif
            endfor
        else
            echo 'No entry in language map for language "' . l . '"'
        endif
    endfor

    return 0
endfunction

function! tagmgr#update() abort
    let tags = s:tags_file_path()
    if tags ==# ''
        echo 'No tag file configured'
        return
    endif

    let cmd = s:ctags_cmd_base() . '-f ' . tags . ' '

    for d in s:subdirs_list()
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

    if !s:belongs_to_dir(file) || !s:matches_language(file)
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
    autocmd BufWritePost * call tagmgr#update_one()
augroup END
