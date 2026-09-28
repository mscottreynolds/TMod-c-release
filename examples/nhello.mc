program nhello()

(**
 * ncurses hello world.
 *
 * To run:
 * `tmodc nhello.mc -C`
 * `cc nhello.c -lncurses -o nhello`
 * `./nhello`
 *)

import initscr, printw, refresh, getch, endwin from "ncurses.h"

begin
	initscr()
	printw("Hello World !!!")
	refresh()
	getch()
	endwin()
end

(* msr/msr *)
