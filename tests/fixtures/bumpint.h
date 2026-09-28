/* Fixture C header for tests/fixtures/bumpint.mh (hand-written stub). */
#ifndef BUMPINT_H
#define BUMPINT_H

typedef struct TBump TBump;

static inline void bumpint(int *n)
{
	if (n != NULL) {
		*n = *n + 1;
	}
}

#endif
