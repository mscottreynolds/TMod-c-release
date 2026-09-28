MODULE test_TestFor()

IMPORT printf FROM "stdio.h"


PROCEDURE WriteInt(i: int, n: int)
BEGIN
	VAR x: int = 0;
	FOR x := 1 TO n DO
		printf("%d ", i);
	END
	printf("\n");
END

PROCEDURE Process(k: int)
BEGIN
	printf("k = %d\n", k);
END

EXPORT FUNCTION main(): int
BEGIN
	VAR i, j, k: int

	FOR i := 1 TO 10 DO
		WriteInt(i, 4);
	END;

	FOR j := 20 TO 0 BY -5 DO
		printf("j = %d\n", j);
	END;

	LET low: int = 1;
	LET high: int = 15;

	FOR k := low TO high BY 3 DO
		Process(k); 
	END;

	return 0;
END

BEGIN
END test_TestFor
