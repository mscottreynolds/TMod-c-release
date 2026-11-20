program test3_import_star_as_qual()

import * as st from fixtures.starpack

begin
	assert fixtures.starpack.answer() == 42
end

