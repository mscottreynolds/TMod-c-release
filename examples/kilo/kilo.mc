program kilo(argc: integer, argv: ^char[]): integer
(**
 * From "Build Your Own Text Editor" at:
 * 		https://viewsourcecode.org/snaptoken/kilo/
 *
 * Author of this file: M. Scott Reynolds
 * Start date: 7 September 2026
 * Language: TMod-c
 * 
 * An experiment to follow a tutor for a program in C,
 * and instead port it to TMod-c to explore 
 * TMod-c's current features as of 0.26.7.191.
 *
 * Notes:
 *	- Original Kilo:
 * 		https://github.com/antirez/kilo
 *	- VT100: 
 *		https://en.wikipedia.org/wiki/VT100
 *	- Clearing the screen:
 *		https://vt100.net/docs/vt100-ug/chapter3.html#ED
 *	- VT100 User Guide:
 *		https://vt100.net/docs/vt100-ug/chapter3.html
 *	- ncurses library: 
 *		https://en.wikipedia.org/wiki/Ncurses
 *	- Terminfo database: 
 *		https://en.wikipedia.org/wiki/Terminfo
 *	- Cursor Position:
 *		https://en.wikipedia.org/wiki/VT100
 *	- vim: 
 *		http://www.vim.org/
 *	- Feature test macro:
 *		https://sourceware.org/glibc/manual/
 *	- ekilo - Enhanced Kilo
 * 		https://github.com/antonio-foti/ekilo
 *	- ANSI escape code
 * 		https://en.wikipedia.org/wiki/ANSI_escape_code
 *
 * 12 Sept 2026: Finished step 130.
 * 14 Sept 2026: Finished step 141
 * 15 Sept 2026: Updated EditorConfig::SetStatusMessage to use '...'
 * 19 Sept 2026: FINISHED!
 * (* Does kilo handle nested comments? No, it doesn't. Maybe a todo? *)
 * Updated ABuffer so it uses a preallocated buffer.
 *)


(* =========== includes =========== *)


import iscntrl, isdigit, isspace,
	from "ctype.h"
import errno, EAGAIN, 
	from "errno.h"
import open, O_RDWR, O_CREAT, 
	from "fcntl.h"
import size_t 
	from "stddef.h"
import printf, perror, sscanf, snprintf, FILE, fopen, getline, fclose, 
	from "stdio.h"
import atexit, exit, realloc, free, malloc, 
	from "stdlib.h"
import memcpy, strlen, strdup, memmove, strerror, strstr, vsnprintf, memset, strchr,
	strrchr, strcmp, strncmp,
	from "string.h"
import ioctl, TIOCGWINSZ, 
	from "sys/ioctl.h"
import ssize_t, 
	from "sys/types.h"
import tcgetattr, tcsetattr, ECHO, TCSAFLUSH, ICANON, ISIG, IXON, IEXTEN, 
	ICRNL, OPOST, BRKINT, INPCK, ISTRIP, CS8, VMIN, VTIME, 
	from "termios.h"
import time_t, time, 
	from "time.h"
import STDIN_FILENO, STDOUT_FILENO, read, write, ftruncate, close, 
	from "unistd.h"
import va_list, va_start, va_end
	from "stdarg.h"


extern type Termios = struct termios
extern type Winsize = struct winsize


(* =========== Defines =========== *)


const KILO_VERSION: string = "0.0.2"
const KILO_TAB_STOP = 8
const KILO_QUIT_TIMES = 3
const STATUS_MSG_MAX = 256

define CTRL_KEY(k) ((k) & 0x1f)

type EditorKey = enum
	BACKSPACE = 127,
	ARROW_LEFT = 1000,
	ARROW_RIGHT,
	ARROW_UP,
	ARROW_DOWN,
	DEL_KEY,
	HOME_KEY,
	END_KEY,
	PAGE_UP,
	PAGE_DOWN,
end

type EditorHighlight = enum
	HL_NORMAL = 0,
	HL_COMMENT,
	HL_MLCOMMENT,
	HL_KEYWORD1,
	HL_KEYWORD2,
	HL_STRING,
	HL_NUMBER,
	HL_MATCH,
end

define HL_HIGHLIGHT_NUMBERS (1<<0)
define HL_HIGHLIGHT_STRINGS (1<<1)

type pchar = ^char
type ppchar = const ^pchar
type uchar = unsigned char
type puchar = ^uchar


(* =========== Data =========== *)


type EditorSyntax = struct
	filetype: pchar
	filematch: ppchar
	keywords: ppchar
	singleline_comment_start: pchar
	multiline_comment_start: pchar
	multiline_comment_end: pchar
	flags: integer
end
type pEditorSyntax = ^EditorSyntax


type ERow = struct
	idx: integer
	size: integer
	rsize: integer
	chars: pchar
	render: pchar
	hl: puchar
	hl_open_comment: integer
end
type pERow = ^ERow


type EditorConfig = struct
	cx: integer
	cy: integer
	rx: integer
	rowoff: integer
	coloff: integer
	screenrows: integer
	screencols: integer
	numrows: integer
	row: pERow
	dirty: integer
	filename: pchar
	statusmsg: array[STATUS_MSG_MAX+1] of char
	statusmsg_time: time_t
	syntax: pEditorSyntax
end
type pEditorConfig = ^EditorConfig


type fnCallback = procedure(E: pEditorConfig, buf: pchar, c: integer)


(* =========== Filetypes =========== *)


const C_HL_EXTENSIONS: pchar[] = { ".c", ".h", ".cpp", nil }
const C_HL_KEYWORDS: pchar[] = {
	"switch", "if", "while", "for", "break", "continue", "return", "else",
	"struct", "union", "typedef", "static", "enum", "class", "case",
	"int|", "long|", "double|", "float|", "char|", "unsigned|", "signed|",
	"void|", nil,
}

const MC_HL_EXTENSIONS: array of pchar = { ".mc", ".mh", nil }
// Note... kilo doesn't work with case insensitive keywords... maybe a todo?
const MC_HL_KEYWORDS: array of pchar = {
	"and|", "array", "as", "assert", "begin", "bound", "break",
	"by", "case", "cast", "const", "continue", "debug", "dec|", "default",
	"define", "defer", "div|", "do", "downto", "else", "elsif", "end", "ensure",
	"enum", "export", "extends", "extern", "false|", "for", "forward", "from",
	"function", "header", "if", "import", "in", "inc|", "invariant", "len|",
	"let", "loop", "mod|", "module", "nil|", "not|", "of", "opaque", "or|",
	"packed", "pointer", "procedure", "program", "record", "recursive", "ref",
	"repeat", "require", "return", "set", "sizeof|", "static", "struct", "switch",
	"then", "to", "true|", "type", "union", "until", "var", "while", "xor|",
	"template", nil,
}

var HLDB: array of EditorSyntax = {
	{
		"c",
		C_HL_EXTENSIONS,
		C_HL_KEYWORDS,
		"//", "/*", "*/",
		HL_HIGHLIGHT_NUMBERS | HL_HIGHLIGHT_STRINGS,
	},
	{
		"TMod-c",
		MC_HL_EXTENSIONS,
		MC_HL_KEYWORDS,
		"//", "(*", "*)",
		HL_HIGHLIGHT_NUMBERS | HL_HIGHLIGHT_STRINGS,
	},
}

define HLDB_ENTRIES (sizeof(HLDB) / sizeof(HLDB[0]))


(* =========== Prototypes =========== *)


procedure EditorConfig::setStatusMessage(ref E: EditorConfig, fmt: string, ...) forward
procedure EditorConfig::refreshScreen(ref E: EditorConfig) forward
function EditorConfig::prompt(ref E: EditorConfig, prompt: pchar, callback: fnCallback): pchar forward


(* =========== Terminal =========== *)


var g_orig_termios: Termios


procedure die(s: string)
begin
	write(STDOUT_FILENO, "\x1b[2J", 4)
	write(STDOUT_FILENO, "\x1b[H", 3)

	perror(s)
	write(STDOUT_FILENO, "\r\n", 2)
	exit(1)
end die


procedure disableRawMode()
begin
	if tcsetattr(STDIN_FILENO, TCSAFLUSH, @g_orig_termios) == -1 then
		die("tcsetattr")
	end
end disableRawMode


procedure enableRawMode()
begin
	var raw: Termios

	if tcgetattr(STDIN_FILENO, @g_orig_termios) == -1 then
		die("tcgetattr")
	end
	atexit(disableRawMode)			// Make sure raw mode gets disabled

	raw := g_orig_termios
	raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON)
	raw.c_oflag &= ~(OPOST)
	raw.c_cflag |= (CS8)
	raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG)
	raw.c_cc[VMIN] := 0
	raw.c_cc[VTIME] := 1

	if tcsetattr(STDIN_FILENO, TCSAFLUSH, @raw) == -1 then
		die("tcsetattr")
	end
end enableRawMode


function readKey(): integer
begin
	var nread: integer
	var c: char

	repeat
		nread := read(STDIN_FILENO, @c, 1)
		if nread == -1 and errno <> EAGAIN then
			die("read")
		end
	until nread == 1

	if c == '\x1b' then
		var seq: array[3] of char

		if read(STDIN_FILENO, @seq[0], 1) <> 1 then
			return '\x1b'
		end
		if read(STDIN_FILENO, @seq[1], 1) <> 1 then
			return '\x1b'
		end

		if seq[0] == '[' then
			if seq[1] >= '0' and seq[1] <= '9' then
				if read(STDIN_FILENO, @seq[2], 1) <> 1 then
					return '\x1b'
				end
				if seq[2] == '~' then
					switch seq[1] of
						case '1': return HOME_KEY
						case '3': return DEL_KEY
						case '4': return END_KEY
						case '5': return PAGE_UP
						case '6': return PAGE_DOWN
						case '7': return HOME_KEY
						case '8': return END_KEY
						else: ;
					end
				end
			else
				switch seq[1] of
					case 'A': return ARROW_UP
					case 'B': return ARROW_DOWN
					case 'C': return ARROW_RIGHT
					case 'D': return ARROW_LEFT
					case 'H': return HOME_KEY
					case 'F': return END_KEY
					else: ;
				end
			end
		elsif seq[0] == 'O' then
			switch seq[1] of
				case 'H': return HOME_KEY
				case 'F': return END_KEY
				else: ;
			end
		end

		return '\x1b'
	else
		return c
	end
end readKey


function getCursorPosition(var rows: integer, var cols: integer): integer
begin
	var buf: array[32] of char
	var i: cardinal = 0

	if write(STDOUT_FILENO, "\x1b[6n", 4) <> 4 then
		return -1
	end

	while i < sizeof(buf) - 1 do
		if read(STDIN_FILENO, @buf[i], 1) <> 1 then
			break
		end
		if buf[i] == 'R' then
			break
		end
		inc(i)
	end
	buf[i] := '\0'

	if buf[0] <> '\x1b' or buf[1] <> '[' then
		return -1
	end
	if sscanf(@buf[2], "%d;%d", @rows, @cols) <> 2 then
		return -1
	end

	return 0

end getCursorPosition


function getWindowSize(var rows: integer, var cols: integer): integer
begin
	var ws: Winsize

	if ioctl(STDOUT_FILENO, TIOCGWINSZ, @ws) == -1 or ws.ws_col == 0 then
		if write(STDOUT_FILENO, "\x1b[999C\x1b[999B", 12) <> 12 then
			return -1
		end
		return getCursorPosition(rows, cols)
	else
		cols := ws.ws_col
		rows := ws.ws_row
		return 0
	end
end getWindowSize


(* =========== Syntax Highlighting =========== *)


function is_separator(c: integer): integer 
begin
	return isspace(c) or c == '\0' or strchr(",.()+-/*=~%[];:<>", c) <> nil
end is_separator


function syntaxToColor(hl: integer): integer
begin
	switch hl of
		case HL_COMMENT, HL_MLCOMMENT: return 36		// cyan
		case HL_KEYWORD1: return 33		// yellow
		case HL_KEYWORD2: return 32		// green
		case HL_STRING: return 35		// magenta
		case HL_NUMBER: return 31		// red
		case HL_MATCH: return 34		// blue
		else: return 37					// white
	end
end syntaxToColor


(* =========== Row Operations =========== *)


recursive procedure ERow::updateSyntax(ref row: ERow, ref E: EditorConfig)
begin
	var i: integer = 0
	var prev_sep: integer = 1
	var in_string: integer = 0
	var in_comment: integer = (row.idx > 0 and E.row[row.idx - 1].hl_open_comment)

	row.hl := realloc(row.hl, row.rsize)
	memset(row.hl, HL_NORMAL, row.rsize)

	if E.syntax == nil then
		return
	end

	let keywords: ppchar = E.syntax.keywords

	let scs: pchar = E.syntax.singleline_comment_start
	let mcs: pchar = E.syntax.multiline_comment_start
	let mce: pchar = E.syntax.multiline_comment_end

	let scs_len: integer = scs ? strlen(scs) : 0
	let mcs_len: integer = mcs ? strlen(mcs) : 0
	let mce_len: integer = mce ? strlen(mce) : 0

	while i < row.rsize do
		var c: char = row.render[i]
		var prev_hl: uchar = (i > 0) ? row.hl[i - 1] : HL_NORMAL

		if scs_len and not in_string and not in_comment then
			if not strncmp(@row.render[i], scs, scs_len) then
				memset(@row.hl[i], HL_COMMENT, row.rsize - i)
				break
			end
		end

		if mcs_len and mce_len and not in_string then
			if in_comment then
				row.hl[i] := HL_MLCOMMENT
				if not strncmp(@row.render[i], mce, mce_len) then
					memset(@row.hl[i], HL_MLCOMMENT, mce_len)
					i += mce_len
					in_comment := 0
					prev_sep := 1
					continue
				else
					inc(i)
					continue
				end
			elsif not strncmp(@row.render[i], mcs, mcs_len) then
				memset(@row.hl[i], HL_MLCOMMENT, mcs_len)
				i += mcs_len
				in_comment := 1
				continue
			end
		end

		if E.syntax.flags & HL_HIGHLIGHT_STRINGS then
			if in_string then
				row.hl[i] := HL_STRING
				if c == '\\' and i + 1 < row.rsize then
					row.hl[i + 1] := HL_STRING
					i += 2
					continue
				end
				if c == in_string then
					in_string := 0
				end
				inc(i)
				prev_sep := 1
				continue
			else
				if c == '"' or c == '\'' then
					in_string := c
					row.hl[i] := HL_STRING
					inc(i)
					continue
				end
			end
		end

		if E.syntax.flags & HL_HIGHLIGHT_NUMBERS then
			if (isdigit(c) and (prev_sep or prev_hl == HL_NUMBER)) or
				(c == '.' and prev_hl == HL_NUMBER) then
				row.hl[i] := HL_NUMBER
				inc(i)
				prev_sep := 0
				continue
			end
		end

		if prev_sep then
			var j: integer = 0

			while keywords[j] <> nil do
				var klen: integer = strlen(keywords[j])
				var kw2: integer = keywords[j][klen - 1] == '|'

				if kw2 then
					dec(klen)
				end

				if not strncmp(@row.render[i], keywords[j], klen) and
						is_separator(row.render[i + klen]) then
					memset(@row.hl[i], kw2 ? HL_KEYWORD2 : HL_KEYWORD1, klen)
					i += klen
					break
				end
				inc(j)
			end
			if keywords[j] <> nil then
				prev_sep := 0
				continue
			end
		end

		prev_sep := is_separator(c)
		inc(i)
	end

	let changed: integer = (row.hl_open_comment <> in_comment)
	row.hl_open_comment := in_comment
	if changed and row.idx + 1 < E.numrows then
		E.row[row.idx + 1].updateSyntax(E)
	end
end ERow::updateSyntax


function ERow::cxToRx(ref row: ERow, cx: integer): integer
begin
	var rx: integer = 0
	var j: integer

	for j := 0 to cx-1 do
		if row.chars[j] == '\t' then
			rx += (KILO_TAB_STOP -1) - (rx % KILO_TAB_STOP)
		end
		inc(rx)
	end
	return rx
end ERow::cxToRx


function ERow::rxToCx(ref row: ERow, rx: integer): integer
begin
	var cur_rx: integer = 0
	var cx: integer = 0

	for cx := 0 to row.size-1 do
		if row.chars[cx] == '\t' then
			cur_rx += (KILO_TAB_STOP - 1) - (cur_rx mod KILO_TAB_STOP)
		end
		inc(cur_rx)

		if cur_rx > rx then
			return cx
		end
	end
	return cx
end ERow::rxToCx


procedure ERow::updateRow(ref row: ERow, ref E: EditorConfig)
begin
	var tabs: integer = 0
	var j: integer
	var idx: integer = 0

	for j := 0 to row.size-1 do
		if row.chars[j] == '\t' then 
			inc(tabs)
		end
	end

	free(row.render)		// Free does nothing if passed nil/NULL
	row.render := malloc(row.size + tabs * (KILO_TAB_STOP-1) + 1)
	assert(row.render <> nil)

	for j := 0 to row.size-1 do
		if row.chars[j] == '\t' then
			row.render[idx] := ' '
			inc(idx)
			while idx % KILO_TAB_STOP <> 0 do
				row.render[idx] := ' '
				inc(idx)
			end
		else
			row.render[idx] := row.chars[j]
			inc(idx)
		end
	end
	row.render[idx] := '\0'
	row.rsize := idx

	row.updateSyntax(E)
end ERow::updateRow

 
procedure ERow::freeRow(ref row: ERow)
begin
	free(row.render)
	row.render := nil
	free(row.chars)
	row.chars := nil
	free(row.hl)
	row.hl := nil
end ERow::freeRow


procedure ERow::insertChar(ref row: ERow, at: integer, c: integer, ref E: EditorConfig)
begin
	var idx: integer = at
	if idx < 0 or idx > row.size then
		idx := row.size
	end
	row.chars := realloc(row.chars, row.size + 2)
	memmove(@row.chars[idx + 1], @row.chars[idx], row.size - idx + 1)
	inc(row.size)
	row.chars[idx] := c
	row.updateRow(E)
end ERow::insertChar


procedure ERow::appendString(ref row: ERow, s: pchar, length: size_t, ref E: EditorConfig)
begin
	row.chars := realloc(row.chars, row.size + length + 1)
	memcpy(@row.chars[row.size], s, length)
	row.size += length
	row.chars[row.size] := '\0'
	row.updateRow(E)
end ERow::appendString


procedure ERow::delChar(ref row: ERow, at: integer, ref E: EditorConfig)
begin
	if at >= 0 and at < row.size then
		memmove(@row.chars[at], @row.chars[at + 1], row.size - at)
		dec(row.size)
		row.updateRow(E)
	end
end ERow::delChar


(* =========== Editor Operations =========== *)


procedure EditorConfig::selectSyntaxHighlight(ref E: EditorConfig)
begin
	var j: cardinal = 0

	E.syntax := nil
	if E.filename == nil then
		return
	end

	let ext: pchar = strrchr(E.filename, '.')

	for j := 0 to HLDB_ENTRIES -1 do
		var s: pEditorSyntax = @HLDB[j]
		var i: cardinal = 0

		while s.filematch[i] do
			var is_ext: integer = s.filematch[i][0] == '.'
			if (is_ext and ext and not strcmp(ext, s.filematch[i])) or
					(not is_ext and strstr(E.filename, s.filematch[i])) then
				var filerow: integer

				E.syntax := s
				for filerow := 0 to E.numrows-1 do
					E.row[filerow].updateSyntax(E)
				end

				return
			end
			inc(i)
		end
	end
end EditorConfig::selectSyntaxHighlight


procedure EditorConfig::insertRow(ref E: EditorConfig, at: integer, s: pchar, length: size_t)
begin
	var j: integer

	if at < 0 or at > E.numrows then
		return
	end

	E.row := realloc(E.row, sizeof(ERow) * (E.numrows + 1))
	memmove(@E.row[at + 1], @E.row[at], sizeof(ERow) * (E.numrows - at))
	for j := at + 1 to E.numrows do
		inc(E.row[j].idx)
	end

	E.row[at].idx := at

	E.row[at].size := length
	E.row[at].chars := malloc(length + 1)
	assert E.row[at].chars <> nil
	memcpy(E.row[at].chars, s, length)
	E.row[at].chars[length] := '\0'

	E.row[at].rsize := 0
	E.row[at].render := nil
	E.row[at].hl := nil
	E.row[at].hl_open_comment := 0
	E.row[at].updateRow(E)

	inc(E.numrows)
	inc(E.dirty)
end EditorConfig::insertRow


procedure EditorConfig::delRow(ref E: EditorConfig, at: integer)
begin
	var j: integer

	if at < 0 or at >= E.numrows then
		return
	end

	E.row[at].freeRow()
	memmove(@E.row[at], @E.row[at + 1], sizeof(ERow) * (E.numrows - at - 1))
	for j := at to E.numrows - 2 do
		dec(E.row[j].idx)
	end

	dec(E.numrows)
	inc(E.dirty)
end EditorConfig::delRow


procedure EditorConfig::insertChar(ref E: EditorConfig, c: integer)
begin
	if E.cy == E.numrows then
		E.insertRow(E.numrows, "", 0)
	end
	E.row[E.cy].insertChar(E.cx, c, E)
	inc(E.dirty)
	inc(E.cx)
end EditorConfig::insertChar


procedure EditorConfig::insertNewline(ref E: EditorConfig)
begin
	if E.cx == 0 then
		E.insertRow(E.cy, "", 0)
	else
		var row: pERow = @E.row[E.cy]

		E.insertRow(E.cy + 1, @row.chars[E.cx], row.size - E.cx)
		row := @E.row[E.cy]
		row.size := E.cx
		row.chars[row.size] := '\0'
		row.updateRow(E)
	end
	inc(E.cy)
	E.cx := 0
end EditorConfig::insertNewline


procedure EditorConfig::delChar(ref E: EditorConfig)
begin
	if E.cy == E.numrows then
		return
	end
	if E.cx == 0 and E.cy == 0 then
		return
	end

	let row: pERow = @E.row[E.cy]
	if E.cx > 0 then
		row.delChar(E.cx - 1, E)
		inc(E.dirty)
		dec(E.cx)
	else
		E.cx := E.row[E.cy - 1].size
		E.row[E.cy - 1].appendString(row.chars, row.size, E)
		inc(E.dirty)
		E.delRow(E.cy)
		dec(E.cy)
	end
end EditorConfig::delChar


(* =========== File I/O =========== *)


function EditorConfig::rowsToString(ref E: EditorConfig, var buflen: integer): pchar
begin
	var totlen: integer = 0
	var j: integer
	var buf: pchar = nil
	var p: pchar = nil

	for j := 0 to E.numrows -1 do
		totlen += E.row[j].size + 1
	end
	buflen := totlen

	buf := malloc(totlen)
	assert(buf <> nil)
	p := buf
	for j := 0 to E.numrows -1 do
		memcpy(p, E.row[j].chars, E.row[j].size)
		p += E.row[j].size
		p^ := '\n'
		inc(p)
	end

	return buf
end EditorConfig::rowsToString


procedure EditorConfig::open(ref E: EditorConfig, filename: string)
begin
	var fp: ^FILE = nil
	var line: pchar = nil
	var linecap: size_t = 0
	var linelen: ssize_t;

	free(E.filename)
	E.filename := strdup(filename)

	E.selectSyntaxHighlight()

	fp := fopen(filename, "r")
	if not fp then
		die("fopen")
	end
	defer fclose(fp)

	loop
		linelen := getline(@line, @linecap, fp)
		if linelen <> -1 then
			while linelen > 0 and (line[linelen - 1] == '\n' or
									line[linelen - 1] == '\r') do
				dec(linelen) 		// Strip trailing cr/lf
			end
			E.insertRow(E.numrows, line, linelen)
		else
			break
		end
	end
	free(line)
	E.dirty := 0
end EditorConfig::open


procedure EditorConfig::save(ref E: EditorConfig)
begin
	var errmsg: pchar = nil
	var length: integer = 0
	var buf: pchar = nil
	var fd: integer = 0

	if E.filename == nil then
		E.filename := E.prompt("Save as: %s", nil)
		if E.filename == nil then
			E.setStatusMessage("Save aborted")
			return
		end
		E.selectSyntaxHighlight()
	end

	buf := E.rowsToString(length)
	defer free(buf)

	fd := open(E.filename, O_RDWR | O_CREAT, 0644)
	if fd <> -1 then
		defer close(fd)

		if ftruncate(fd, length) <> -1 then
			if write(fd, buf, length) == length then
				// close(fd)
				// free(buf)
				E.dirty := 0
				E.setStatusMessage("%d bytes written to disk", length)
				return
			end
		end
		// close(fd)
	end
	// free(buf)
	errmsg := strerror(errno)
	if errmsg <> nil then
		E.setStatusMessage("Can't save! I/O error: %s", errmsg)
	end
end EditorConfig::save


(* =========== Find =========== *)


procedure EditorConfig::findCallback(ref E: EditorConfig, query: pchar, key: integer)
begin
	static var last_match: integer = -1
	static var direction: integer = 1
	static var saved_hl_line: integer = 0
	static var saved_hl: pchar = nil

	var i: integer
	var current: integer

	if saved_hl then
		memcpy(E.row[saved_hl_line].hl, saved_hl, E.row[saved_hl_line].rsize)
		free(saved_hl)
		saved_hl := nil
	end

	if key == '\r' or key == '\x1b' then
		last_match := -1
		direction := 1
		return
	elsif key == ARROW_RIGHT or key == ARROW_DOWN then
		direction := 1
	elsif key == ARROW_LEFT or key == ARROW_UP then
		direction := -1
	else
		last_match := -1
		direction := 1
	end

	if last_match == -1 then
		direction := 1
	end
	current := last_match

	for i := 0 to E.numrows-1 do
		var match: pchar = nil
		var row: pERow = nil

		current += direction
		if current == -1 then
			current := E.numrows - 1
		elsif current == E.numrows then
			current := 0
		end

		row := @E.row[current]
		match := strstr(row.render, query)

		if match <> nil then
			last_match := current
			E.cy := current
			E.cx := row.rxToCx(match - row.render)
			E.rowoff := E.numrows

			saved_hl_line := current
			saved_hl := malloc(row.rsize)
			memcpy(saved_hl, row.hl, row.rsize)
			memset(@row.hl[match - row.render], HL_MATCH, strlen(query))
			break
		end
	end
end EditorConfig::findCallback


procedure findCallback(ref E: EditorConfig, buf: pchar, c: integer)
begin
	E.findCallback(buf, c)
end


procedure EditorConfig::find(ref E: EditorConfig)
begin
	var saved_cx = E.cx
	var saved_cy = E.cy
	var saved_coloff = E.coloff
	var saved_rowoff = E.rowoff

	var query: pchar = E.prompt("Search: %s (Use ESC/Arrows/Enter)", findCallback)

	if query <> nil then
		free(query)
	else
		E.cx := saved_cx
		E.cy := saved_cy
		E.coloff := saved_coloff
		E.rowoff := saved_rowoff
	end
end EditorConfig::find


(* =========== Append Buffer =========== *)


type ABuffer = struct
	buffer: pchar
	length: integer
	capacity: integer
end

const ABUFFER_INIT_CAPACITY = 1024
const ABUFFER_INIT: ABuffer = {nil, 0, 0}


function ABuffer::new(): ABuffer
begin
	var ab: ABuffer = ABUFFER_INIT
	return ab
end ABuffer::new


procedure ABuffer::append(ref ab: ABuffer, s: string, length: integer)
begin
	let new_len = ab.length + length

	while new_len > ab.capacity do
		var new_buf: pchar = nil
		var new_capacity: integer

		if ab.capacity > 0 then
			new_capacity := ab.capacity * 2
		else
			new_capacity := ABUFFER_INIT_CAPACITY
		end

		// Check for overflow
		if (ab.capacity <> 0 and new_capacity div 2 <> ab.capacity) or new_capacity < ab.capacity then
			die("ABuffer::append")
		end

		new_buf := realloc(ab.buffer, new_capacity)
		if new_buf == nil then
			return
		end

		ab.buffer := new_buf
		ab.capacity := new_capacity
	end

	memcpy(@ab.buffer[ab.length], s, length)
	ab.length += length
end ABuffer::append


procedure ABuffer::free(ref ab: ABuffer)
begin
	if ab.buffer <> nil then
		free(ab.buffer)
		ab.buffer := nil
	end
end ABuffer::free


(* =========== Output =========== *)


procedure EditorConfig::scroll(ref E: EditorConfig)
begin
	E.rx := 0
	if E.cy < E.numrows then
		E.rx := E.row[E.cy].cxToRx(E.cx)
	end

	if E.cy < E.rowoff then
		E.rowoff := E.cy
	end
	if E.cy >= E.rowoff + E.screenrows then
		E.rowoff := E.cy - E.screenrows + 1
	end
	if E.rx < E.coloff then
		E.coloff := E.rx
	end
	if E.rx >= E.coloff + E.screencols then
		E.coloff := E.rx - E.screencols + 1
	end
end EditorConfig::scroll


procedure EditorConfig::drawRows(ref E: EditorConfig, ref ab: ABuffer)
begin
	var y: integer

	for y := 0 to E.screenrows-1 do
		var filerow: integer = y + E.rowoff
		if filerow >= E.numrows then
			if E.numrows == 0 and y == E.screenrows div 3 then
				var welcome: array[80] of char
				var welcomelen: integer = snprintf(welcome, sizeof(welcome),
					"Kilo Editor -- version %s", KILO_VERSION)
				var padding: integer

				if welcomelen > E.screencols then
					welcomelen := E.screencols
				end
				padding := (E.screencols - welcomelen) div 2
				if padding > 0 then
					ab.append("~", 1)
					dec(padding)
				end
				while padding > 0 do
					ab.append(" ", 1)
					dec(padding)
				end
				ab.append(welcome, welcomelen)
			else
				ab.append("~", 1)
			end
		else
			var length: integer = E.row[filerow].rsize - E.coloff
			var c: pchar = @E.row[filerow].render[E.coloff]
			var hl: puchar = @E.row[filerow].hl[E.coloff]
			var current_color: integer = -1
			var j: integer = 0

			if length < 0 then 
				length := 0
			elsif length > E.screencols then
				length := E.screencols
			end

			for j := 0 to length-1 do
				if iscntrl(c[j]) then
					var sym: char = (c[j] <= 26) ? '@' + c[j] : '?'

					ab.append("\x1b[7m", 4)
					ab.append(@sym, 1)
					ab.append("\x1b[m", 3)
					if current_color <> -1 then
						var buf: array[16] of char
						let clen: integer = snprintf(buf, sizeof(buf), "\x1b[%dm", current_color)
						ab.append(buf, clen)
					end
				elsif hl[j] == HL_NORMAL then
					if current_color <> -1 then
						ab.append("\x1b[39m", 5)
						current_color := -1
					end
					ab.append(@c[j], 1)
				else
					var color: integer = syntaxToColor(hl[j])

					if color <> current_color then
						var buf: array[16] of char
						var clen: integer = snprintf(buf, sizeof(buf), "\x1b[%dm", color)

						current_color := color
						ab.append(buf, clen)
					end
					ab.append(@c[j], 1)
				end
			end
			ab.append("\x1b[39m", 5)
		end

		ab.append("\x1b[K", 3)		// clear to end of line
		ab.append("\r\n", 2)
	end
end EditorConfig::drawRows


procedure EditorConfig::drawStatusBar(ref E: EditorConfig, ref ab: ABuffer)
begin
	var length: integer = 0
	var rlength: integer = 0
	var status: array[STATUS_MSG_MAX+1] of char
	var rstatus: array[STATUS_MSG_MAX+1] of char

	ab.append("\x1b[7m", 4)
	length := snprintf(status, sizeof(status), "%.20s - %d lines %s",
		E.filename ? E.filename : "[No Name]", E.numrows,
		E.dirty ? "(modified)" : "")
	rlength := snprintf(rstatus, sizeof(rstatus), "%s | %d/%d",
		E.syntax ? E.syntax.filetype : "no filetype", 
		E.cy + 1, E.numrows)
	if length > E.screencols then
		length := E.screencols
	end
	ab.append(status, length)

	while (length < E.screencols) do
		if E.screencols - length == rlength then
			ab.append(rstatus, rlength)
			break
		else
			ab.append(" ", 1)
			inc(length)
		end
	end
	ab.append("\x1b[m", 3)
	ab.append("\r\n", 2)
end EditorConfig::drawStatusBar


procedure EditorConfig::drawMessageBar(ref E: EditorConfig, ref ab: ABuffer)
begin
	var msglen: integer = strlen(E.statusmsg)

	ab.append("\x1b[K", 3)
	if msglen > E.screencols then
		msglen := E.screencols
	end
	if msglen and time(nil) - E.statusmsg_time < 5 then
		ab.append(E.statusmsg, msglen)
	end
end EditorConfig::drawMessageBar


procedure EditorConfig::refreshScreen(ref E: EditorConfig)
begin
	var buf: array[32] of char
	var ab: ABuffer = ABuffer::new()

	if getWindowSize(E.screenrows, E.screencols) == -1 then
		die("getWindowSize")
	end
	E.screenrows -= 2

	E.scroll()

	ab.append("\x1b[?25l", 6)			// hide cursor
	// ab.append("\x1b[2J", 4)			// clear screen
	ab.append("\x1b[H", 3)				// home cursor

	E.drawRows(ab)
	E.drawStatusBar(ab)
	E.drawMessageBar(ab)

	snprintf(buf, sizeof(buf), "\x1b[%d;%dH", (E.cy - E.rowoff) + 1,
											  (E.rx - E.coloff) + 1)
	ab.append(buf, strlen(buf))

	ab.append("\x1b[?25h", 6) 			// show cursor

	write(STDOUT_FILENO, ab.buffer, ab.length)

	ab.free()
end EditorConfig::refreshScreen


procedure EditorConfig::setStatusMessage(ref E: EditorConfig, fmt: string, ...)
begin
	var ap: va_list

	va_start(ap, fmt)
	vsnprintf(E.statusmsg, sizeof(E.statusmsg), fmt, ap)
	va_end(ap)
	E.statusmsg_time := time(nil)
end EditorConfig::setStatusMessage


(* =========== Input =========== *)


function EditorConfig::prompt(ref E: EditorConfig, prompt: pchar, callback: fnCallback): pchar
begin
	var bufsize: integer = STATUS_MSG_MAX
	var buf: pchar = malloc(bufsize+1)
	var buflen: integer = 0

	buf[0] := '\0'

	loop
		E.setStatusMessage(prompt, buf)
		E.refreshScreen()

		let c = readKey()
		if c == DEL_KEY or c == CTRL_KEY('h') or c == BACKSPACE then
			if buflen <> 0 then
				dec(buflen)
				buf[buflen] := '\0'
			end
		elsif c == '\x1b' then
			E.setStatusMessage("")
			if callback <> nil then
				callback(@E, buf, c)
			end
			free(buf)
			return nil
		elsif c == '\r' then
			if buflen <> 0 then
				E.setStatusMessage("")
				if callback <> nil then
					callback(@E, buf, c)
				end
				return buf
			end
		elsif not iscntrl(c) and c < 128 then
			let statuslen: integer = strlen(E.statusmsg)
			if buflen + statuslen < STATUS_MSG_MAX then
				buf[buflen] := c
				inc(buflen)
				buf[buflen] := '\0'
			end
		end

		if callback <> nil then
			callback(@E, buf, c)
		end
	end
end EditorConfig::prompt


procedure EditorConfig::moveCursor(ref E: EditorConfig, key: integer)
begin
	var row: pERow = (E.cy >= E.numrows) ? nil : @E.row[E.cy]
	switch key of 
		case ARROW_LEFT:
			if E.cx <> 0 then
				dec(E.cx)
			elsif E.cy > 0 then
				dec(E.cy)
				E.cx := E.row[E.cy].size
			end
		case ARROW_RIGHT:
			if row and E.cx < row.size then
				inc(E.cx)
			elsif row and E.cx == row.size then
				inc(E.cy)
				E.cx := 0
			end
		case ARROW_UP:
			if E.cy > 0 then
				dec(E.cy)
			end
		case ARROW_DOWN:
			if E.cy < E.numrows then
				inc(E.cy)
			end
		else:
			;
	end

	row := (E.cy >= E.numrows) ? nil : @E.row[E.cy]
	let rowlen: integer = row ? row.size : 0
	if E.cx > rowlen then
		E.cx := rowlen
	end
end EditorConfig::moveCursor


procedure EditorConfig::processKeypress(ref E: EditorConfig)
begin
	static var quit_times: integer = KILO_QUIT_TIMES
	var c: integer = readKey()

	switch c of
		case '\r':
			E.insertNewline()

		case CTRL_KEY('q'):
			if E.dirty > 0 and quit_times > 0 then
				E.setStatusMessage("WARNING!!! File has unsaved changes. Press Ctrl-Q %d more times to quit.", quit_times)
				dec(quit_times)
				return
			end
			write(STDOUT_FILENO, "\x1b[2J", 4)
			write(STDOUT_FILENO, "\x1b[H", 3)

			exit(0)

		case CTRL_KEY('s'):
			E.save()

		case HOME_KEY:
			E.cx := 0

		case END_KEY:
			if E.cy < E.numrows then
				E.cx := E.row[E.cy].size
			end

		// just showing that TMod-c keywords are case insensitive.
		CASE CTRL_KEY('f'):
			E.find()

		case BACKSPACE, CTRL_KEY('h'), DEL_KEY:
			if c == DEL_KEY then
				E.moveCursor(ARROW_RIGHT)
			end
			E.delChar()

		case PAGE_UP, PAGE_DOWN:
			begin
				var times: integer = E.screenrows;

				if c == PAGE_UP then
					E.cy := E.rowoff
				elsif c == PAGE_DOWN then
					E.cy := E.rowoff + E.screenrows - 1
					if E.cy > E.numrows then
						E.cy := E.numrows
					end
				end

				while dec(times) do
					E.moveCursor(c == PAGE_UP ? ARROW_UP : ARROW_DOWN)
				end
			end
		case ARROW_UP, ARROW_DOWN, ARROW_LEFT, ARROW_RIGHT:
			E.moveCursor(c)

		case CTRL_KEY('l'), '\x1b':
			;

		else:
			E.insertChar(c)
	end
	quit_times := KILO_QUIT_TIMES
end EditorConfig::processKeypress


(* =========== Initialization =========== *)


procedure initEditor(ref E: EditorConfig)
begin
	E.cx := 0
	E.cy := 0
	E.rx := 0
	E.rowoff := 0
	E.coloff := 0
	E.numrows := 0
	E.row := nil
	E.dirty := 0
	E.filename := nil
	E.statusmsg[0] := '\0'
	E.statusmsg_time := 0
	E.syntax := nil

	if getWindowSize(E.screenrows, E.screencols) == -1 then
		die("getWindowSize")
	end
	E.screenrows -= 2
end initEditor


begin
	var E: EditorConfig

	enableRawMode()
	initEditor(E)
	if argc >= 2 then
		E.open(argv[1])
	end

	E.setStatusMessage("HELP: Ctrl-S = save | Ctrl-Q = quit | Ctrl-F = find")

	loop
		E.refreshScreen()
		E.processKeypress()
	end

	return 0
end


(* msr/msr *)
