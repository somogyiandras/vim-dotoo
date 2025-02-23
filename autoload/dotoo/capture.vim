if exists('g:autoloaded_dotoo_capture')
  finish
endif
let g:autoloaded_dotoo_capture = 1

call dotoo#utils#set('dotoo#capture#refile', expand('~/Documents/dotoo-files/refile.dotoo'))
call dotoo#utils#set('dotoo#capture#templates', {
      \ 't': {
      \   'description': 'Todo',
      \   'lines': [
      \     '* TODO %?',
      \     'DEADLINE: [%(strftime(g:dotoo#time#datetime_format))]'
      \   ],
      \  'target': 'refile',
      \  'clock': 1,
      \ },
      \ 'n': {
      \   'description': 'Note',
      \   'lines': ['* %? :NOTE:'],
      \ },
      \ 'j': {
      \   'description': 'Journal Entry',
      \   'lines': [
      \     '* %?'
      \   ],
      \   'target': 'notes/diary/%(strftime(g:dotoo#time#date_format)).dotoo',
      \   'append': 1,
      \ },
      \ 'm': {
      \   'description': 'Meeting',
      \   'lines': ['* MEETING with %? :MEETING:'],
      \   'clock': 1
      \ },
      \ 'p': {
      \   'description': 'Phone call',
      \   'lines': ['* PHONE %? :PHONE:'],
      \   'clock': 1
      \ },
      \ 'h': {
      \   'description': 'Habit',
      \   'lines': [
      \     '* NEXT %?',
      \     'SCHEDULED: [%(strftime(g:dotoo#time#date_day_format)) +1m]',
      \     ':PROPERTIES:',
      \     ':STYLE: habit',
      \     ':REPEAT_TO_STATE: NEXT',
      \     ':END:'
      \   ]
      \ }
      \})

function! s:capture_menu()
  let ts = deepcopy(g:dotoo#capture#templates)
  let menu_lines = values(map(deepcopy(ts), {k, t -> "(".k.") ".t.description}))
  let acceptable_input = '[' . join(keys(ts),'') . ']'
  call add(menu_lines, 'Select capture template: ')
  return dotoo#utils#getchar(join(menu_lines, "\n"), acceptable_input)
endfunction

function! s:get_selected_template(short_key)
  return get(g:dotoo#capture#templates, a:short_key, '')
endfunction

function! s:capture_template_eval_line(template)
  if a:template =~# '%(.*)'
    return substitute(a:template, '%(\(.*\))', '\=eval(submatch(1))', 'g')
  endif
  return a:template
endfunction

function! s:get_capture_target(template)
  let capture_target = get(a:template, 'target', g:dotoo#capture#refile)
  if dotoo#utils#is_dotoo_file(capture_target)
    let capture_target = s:capture_template_eval_line(capture_target)
    if capture_target !~# '^/'
      let capture_target = printf("%s/%s", g:dotoo#home, capture_target)
    endif
  else
    let btarget = bufname(capture_target)
    if empty(btarget)
      let capture_target = g:dotoo#capture#refile
    endif
  endif
  return capture_target
endfunction

function! s:capture_template_eval(template)
  return map(a:template, 's:capture_template_eval_line(v:val)')
endfunction

let s:capture_tmp_file = tempname()
function! s:capture_edit(cmd, ...)
  let file = a:0 ? a:1 : s:capture_tmp_file
  let append = a:0 ? 1 : 0
  silent exe 'keepalt' a:cmd file
  if !append
    :%delete
  endif
  setl nobuflisted nofoldenable
  setf dotoocapture
endfunction

function! s:capture_select()
  let old_search = @/
  call search('%?', 'b')
  exe "normal! \<Esc>viw\<C-G>"
  let @/ = old_search
endfunction

function! dotoo#capture#refile_now() abort
  let dotoo = dotoo#parser#parse({'lines': getline(1,'$'), 'force': 1})
  let headline = dotoo.headlines[0]
  if headline.is_clocking()
    call dotoo#clock#stop(headline)
  endif
  let target = b:capture_target
  if type(target) == v:t_dict
    call target.add_headline(headline)
    call target.save('edit')
  elseif type(target) == v:t_string
    echom "writing to" target
    call writefile(headline.serialize(), target, 'a')
  endif
endfunction

function! dotoo#capture#capture()
  let selected = s:capture_menu()
  if !empty(selected)
    let template = s:get_selected_template(selected)
    let template_lines = template.lines
    let capture_target = s:get_capture_target(template)
    let capture_append = get(template, 'append', 0)
    let clock_start = get(template, 'clock', 0)
    let template_lines = s:capture_template_eval(template_lines)
    if capture_append
      call s:capture_edit('split', capture_target)
    else
      call s:capture_edit('split')
    endif
    let dotoo = dotoo#parser#parse({'lines': template_lines, 'force': 1})
    let headline = dotoo.headlines[0]
    let todo = headline.todo
    if clock_start | call dotoo#clock#start(headline, 0) | endif
    call headline.change_todo(todo) " work around clocking todo state change
    if capture_append
      call append('$', headline.serialize())
    else
      call setline(1, headline.serialize())
    endif
    let b:capture_target = capture_target
    call s:capture_select()
  endif
endfunction
