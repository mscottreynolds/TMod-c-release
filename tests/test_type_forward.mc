program test_type_forward()

import size_t from "stddef.h"
import strlen from "string.h"
import printf from "stdio.h"


type TString forward

type FCString = function(s: TString): const ^char
type FLength  = function(s: TString): size_t

type TString = struct
	value: const ^char
	length: size_t
end

function TString::new(p: const ^char): TString
begin
	var s: TString = {p, 0}
	s.length := strlen(p)
	return s
end

function TString::length(s: TString): size_t
begin
	return s.length
end

function TString::cstring(s: TString): const ^char
begin
	return s.value
end

begin
	var s: TString = TString::new("Hello")
	printf("s.length=%zu\n", s.length())
	printf("s.cstring=%s\n", s.cstring())
end
