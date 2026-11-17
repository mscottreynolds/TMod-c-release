#ifndef MODC_MODULE_asmethod_H
#define MODC_MODULE_asmethod_H

typedef struct Pair Pair;
typedef struct Pair {
	integer x;
	integer y;
} Pair;

static inline integer Pair__sum(Pair p)
{
	return p.x + p.y;
}

#endif /* MODC_MODULE_asmethod_H */
