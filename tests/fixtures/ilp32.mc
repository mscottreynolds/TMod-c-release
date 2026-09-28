module ilp32()

(*
 * Stand-in for tmodc.ilp32 until item 15.
 * Everyday integer/cardinal/real 32. Lean .h -- do not replace with tmodc -H.
 *)

export type integer = integer 32
export type cardinal = cardinal 32
export type real = real 32
export type string = const ^char

begin
end ilp32
