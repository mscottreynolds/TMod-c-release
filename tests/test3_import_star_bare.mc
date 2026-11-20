program test3_import_star_bare()

import * from fixtures.starpack

begin
	assert answer() == 42
end
