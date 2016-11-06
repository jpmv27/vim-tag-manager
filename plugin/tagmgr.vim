let s:language_map = {}
let s:language_map['C']    = ['*.c', '*.C', '*.h', '*.H']
let s:language_map['C++']  = ['*.cpp', '*.cc', '*.hpp']
let s:language_map['Java'] = ['*.java']

function! s:tags_file_path() abort
    return split(&tags, ',', 1)[0]
endfunction

function! s:language_list() abort
    return get(b:, 'tagmgr_languages', ['C', 'C++'])
endfunction

function! s:subdirs_list() abort
    return get(b:, 'tagmgr_src_subdirs', [''])
endfunction

function! s:spellfile() abort
    return get(b:, 'tagmgr_spell_file', '')
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

function! s:generate_tag_file(name) abort
    let cmd = s:ctags_cmd_base() . '-f ' . a:name . ' '

    for d in s:subdirs_list()
        let cmd .= simplify(fnameescape(getcwd() . '/' . d) . '/*') . ' '
    endfor

    call s:run_command(cmd)
endfunction

function! s:maybe_update_tag_file(file, tags)
    let temp = a:tags . '.tmp'

    if !s:belongs_to_dir(a:file) || !s:matches_language(a:file)
        return
    endif

    let cmd = 'sed "/' . escape(a:file, './') . '/d" ' . a:tags . ' > ' . temp
    let cmd .= '; ' . s:ctags_cmd_base() . '-a -f ' . temp . ' ' . a:file
    let cmd .= '; mv ' . temp . ' ' . a:tags

    call s:run_command(cmd)
endfunction

function! s:maybe_generate_spell_file(tags) abort
    let spell = s:spellfile()

    if spell ==# ''
        return
    endif

    let cmd = "grep -v '^!' " . a:tags
    let cmd .= "| awk '{ print $1 \"/=\" }' > " . spell

    call s:run_command(cmd)
    execute 'silent mkspell! ' . spell
endfunction

function! tagmgr#update() abort
    let tags = s:tags_file_path()
    if tags ==# ''
        echo 'No tag file configured'
        return
    endif

    call s:generate_tag_file(tags)

    call s:maybe_generate_spell_file(tags)
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

    call s:maybe_update_tag_file(resolve(fnameescape(expand('%:p'))), tags)

    call s:maybe_generate_spell_file(tags)
endfunction

command! -nargs=0 TagsUpdate call tagmgr#update()

command! -nargs=0 TagsErase call tagmgr#erase()

augroup tagmgr
    autocmd!
    autocmd BufWritePost * call tagmgr#update_one()
augroup END
