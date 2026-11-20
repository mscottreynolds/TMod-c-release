#ifndef MODC_FIXTURE_starpack_H
#define MODC_FIXTURE_starpack_H

typedef struct fixtures_starpack__Point {
	integer x;
	integer y;
} fixtures__starpack__Point;

static inline integer fixtures__starpack__answer(void)
{
	return 42;
}

static inline integer fixtures__starpack__Point__getX(fixtures__starpack__Point p)
{
	return p.x;
}

static inline integer fixtures__starpack(void)
{
	return 7;
}

#endif
