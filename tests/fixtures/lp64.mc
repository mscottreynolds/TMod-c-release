module lp64()
(*
 * Stand-in for tmodc.lp64 until item 15 (include/tmodc/ + search).
 * integer/cardinal/real 64. Lean .h - do not replace with tmodc -H.
 *)
 
export type integer = integer 64
export type cardinal = cardinal 64
export type real = real 64
export type string = const ^char

begin
end lp64
