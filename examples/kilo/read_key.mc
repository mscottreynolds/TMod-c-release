program read_key(): integer
(**
 * read_key.mc
 * From "Build Your Own Text Editor" at https://viewsourcecode.org/snaptoken/kilo/index.html.
 *
 * Author of this file: M. Scott Reynolds
 * Start date: 7 September 2026
 * Language: TMod-c
 * 
 * An experiment to follow a tutor for a program in C yet write it in TMod-c to explore 
 * TMod-c's current features.
 *
 * This just reads they keyboard and prints the codes returned.
 *)


(* =========== includes =========== *)


import iscntrl 
	from "ctype.h"
import errno, EAGAIN, 
	from "errno.h"
import printf, perror, sscanf, snprintf, 
	from "stdio.h"
import atexit, exit, realloc, free, 
	from "stdlib.h"
import memcpy, strlen, 
	from "string.h"
import ioctl, TIOCGWINSZ, 
	from "sys/ioctl.h"
import tcgetattr, tcsetattr, ECHO, TCSAFLUSH, ICANON, ISIG, IXON, IEXTEN, 
	ICRNL, OPOST, BRKINT, INPCK, ISTRIP, CS8, VMIN, VTIME, 
	from "termios.h"
import STDIN_FILENO, STDOUT_FILENO, read, write, 
	from "unistd.h"


extern type TTermios = struct termios
extern type TWinsize = struct winsize


(* =========== Defines =========== *)


define CTRL_KEY(k) ((k) & 0x1f)

type EditorKey = enum
	ARROW_LEFT = 1000,
	ARROW_RIGHT,
	ARROW_UP,
	ARROW_DOWN,
	PAGE_UP,
	PAGE_DOWN,
end


(* =========== Data =========== *)


type TEditorConfig = struct
	cx: integer
	cy: integer
	screenrows: integer
	screencols: integer
	orig_termios: TTermios

end

var E: TEditorConfig


(* =========== Terminal =========== *)


procedure die(s: const ^char)
begin
	write(STDOUT_FILENO, "\x1b[2J", 4)
	write(STDOUT_FILENO, "\x1b[H", 3)

	perror(s)
	write(STDOUT_FILENO, "\r\n", 2)
	exit(1)
end die


procedure disableRawMode()
begin
	if tcsetattr(STDIN_FILENO, TCSAFLUSH, @E.orig_termios) == -1 then
		die("tcsetattr")
	end
end disableRawMode


procedure enableRawMode()
begin
	var raw: TTermios

	if tcgetattr(STDIN_FILENO, @E.orig_termios) == -1 then
		die("tcgetattr")
	end
	atexit(disableRawMode)			// Make sure raw mode gets disabled

	raw := E.orig_termios
	raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON)
	raw.c_oflag &= ~(OPOST)
	raw.c_cflag |= (CS8)
	raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG)
	// raw.c_cc[VMIN] := 0
	// raw.c_cc[VTIME] := 1

	if tcsetattr(STDIN_FILENO, TCSAFLUSH, @raw) == -1 then
		die("tcsetattr")
	end
end enableRawMode


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
	var ws: TWinsize

	if ioctl(STDOUT_FILENO, TIOCGWINSZ, @ws) == -1 or ws.ws_col == 0 then
		if (write(STDOUT_FILENO, "\x1b[999C\x1b[999B", 12) <> 12) then
			return -1
		end
		return getCursorPosition(rows, cols)
	else
		cols := ws.ws_col
		rows := ws.ws_row
		return 0
	end
end getWindowSize


(* =========== Initialization =========== *)


procedure initEditor()
begin
	E.cx := 0
	E.cy := 0

	if getWindowSize(E.screenrows, E.screencols) == -1 then
		die("getWindowSize")
	end
end initEditor


begin
	printf("Hello. Type Ctrl-q to quit.\r\n")
	defer printf("Goodbye\r\n")

	enableRawMode()
	initEditor()
	printf("Window size: %d x %d\r\n", E.screencols, E.screenrows)

#ifndef JUST_TESTING
#define JUST_TESTING
	printf("HELLO JUST_TESTING.\r\n")
#endif

	loop
		var c: char = '\0'
		if read(STDIN_FILENO, @c, 1) == -1 and errno <> EAGAIN then
			die("read")
		end
		if iscntrl(c) then
			printf("%d\r\n", c)
		else
			printf("%d ('%c')\r\n", c, c)
		end
		if c == CTRL_KEY('q') then
			break
		end
	end

	return 0
end


(* msr/msr *)
