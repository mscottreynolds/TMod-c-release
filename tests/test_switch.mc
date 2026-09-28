program test_switch()

import printf from "stdio.h"


begin
	var c :char = 'a'

	while c < 'h' do
		switch c of
			case 'a': printf("case is a\n")
			case 'b': printf("case is b\n")
			case 'c': printf("case is c\n")
			case 'd', 'e', 'f': printf("case is d, e, or f\n")
			else: printf("case is something else\n");
		end
		inc(c)
	end
end
