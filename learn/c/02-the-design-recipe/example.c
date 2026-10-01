/* example.c: the design recipe, all six steps, for one small function.
 *
 * The steps are in order on purpose: each one is checked before the
 * next, so you're never debugging a whole function at once. */
#include <assert.h>
#include <stdio.h>

/* 1. Data definition: what the values mean.
 *    A percentage is an int from 0 to 100. */

/* 2. Signature and purpose: what goes in, what comes out, in one sentence.
 *    clamp: the int x, moved into the range lo..hi if it's outside it
 *    (lo <= hi). */
int clamp(int x, int lo, int hi);

/* 3. Examples, as asserts: written before the body, so they say what
 *    the function is for, not what it happens to do. */
static void examples(void)
{
    assert(clamp(50, 0, 100) == 50);    /* inside: unchanged */
    assert(clamp(-7, 0, 100) == 0);     /* below: up to lo */
    assert(clamp(250, 0, 100) == 100);  /* above: down to hi */
    assert(clamp(0, 0, 100) == 0);      /* the edges count as inside */
    assert(clamp(100, 0, 100) == 100);
}

/* 4. Template: the shape of the body, from the data (here: three cases).
 * 5. Body: the template, filled in. */
int clamp(int x, int lo, int hi)
{
    if (x < lo)
        return lo;
    if (x > hi)
        return hi;
    return x;
}

/* 6. Run it, under the sanitizers: the examples pass, and nothing
 *    undefined happened on the way. */
int main(void)
{
    examples();
    printf("clamp(250, 0, 100) = %d\n", clamp(250, 0, 100));
    printf("all examples pass\n");
    return 0;
}
