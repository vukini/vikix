/* words.h: what words.c offers. Both .c files include it, so a change
 * here means both have to be compiled again. */
#ifndef WORDS_H
#define WORDS_H

/* count_words: how many words s has (runs of anything but spaces). */
int count_words(const char *s);

#endif
