Program test_comments()

import printf from "stdio.h"

// This is a single line comment

/* This
   is a 
   multiline c-style comment */

(* This is a Pascal style 
	(* which can be nested *)
	style multiline comment *)

/** This is a document comment, C style. */
(** This is a document comment, Pascal style. *)


begin
	printf("Hello comments.\n")
end
