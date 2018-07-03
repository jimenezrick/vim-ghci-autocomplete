function! s:connect_ghci() abort
	let l:addr = readfile('.ghci_complete')[0]
	echomsg printf('Connecting to GHCi server: %s', l:addr)
	let b:ghci_chan = ch_open(l:addr, {"timeout": g:ghci_complete_timeout})
endfunction

function! s:send_command(command) abort
	if !exists('b:ghci_chan')
		call s:connect_ghci()
	elseif ch_status(b:ghci_chan) != 'open'
		call s:connect_ghci()
	endif

	if ch_status(b:ghci_chan) != 'open'
		throw 'error_connect_ghci'
	endif

	return ch_evalexpr(b:ghci_chan, a:command)
endfunction

function! ghci#omnifunc(findstart, base) abort
	if a:findstart
		let b:ghci_current_line= getline('.')
		let b:ghci_current_col = col('.')
	endif

	let l:cmd = {
	\    'command': 'findstart',
	\    'line': b:ghci_current_line,
	\    'column': b:ghci_current_col,
	\    'complete_first': 1,
	\    'complete_last': g:ghci_complete_batch_size,
	\ }

	if !a:findstart
		let l:cmd['command'] = 'complete'
	endif

	while 1
		try
			"echomsg printf('GHCi <= Command: %s', l:cmd)
			let l:resp = s:send_command(l:cmd)
			"echomsg printf('GHCi => Response: %s', l:resp)
		catch /error_connect_ghci/
			echohl WarningMsg | echomsg 'Error: failed to connect to GHCi server' | echohl None
			return -1
		catch
			echohl ErrorMsg | echomsg 'Error: failed to send command to GHCi server' | echohl None
			return -1
		endtry

		if empty(l:resp)
			echohl ErrorMsg | echomsg "Error: timeout GHCi server didn't reply" | echohl None
			return -1
		endif

		if a:findstart
			return l:resp['start']
		else
			if empty(l:resp['results'])
				return []
			endif

			for r in l:resp['results']
				call complete_add(r)
			endfor

			if !l:resp['more']
				return []
			endif

			if complete_check()
				return []
			endif

			let l:cmd['complete_first'] += g:ghci_complete_batch_size
			let l:cmd['complete_last'] += g:ghci_complete_batch_size
		endif
	endwhile
endfun

function! ghci#typeat() abort
	let l:cmd = {
	\    'command': 'typeat',
	\    'file': expand('%'),
	\    'line': line('.'),
	\    'column': col('.'),
	\    'under': expand('<cWORD>'),
	\ }

	" XXX: handle errors
	let l:resp = s:send_command(l:cmd)
	echomsg printf("%s :: %s", l:resp['expr'], l:resp['type'])
endfun
