/* wordfreq.c — the ten most common words in a text file.
 *
 * A word is a run of letters, compared in lower case. The words go in a
 * growing array, found again by a plain search: simple, and fast enough
 * for a speech. qsort then orders them, most common first.
 *
 *   ./wordfreq text.txt
 */
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct entry {
    char *word;
    int count;
};

static struct entry *words;     /* the words seen so far */
static size_t nwords, capacity;

/* Count one more of WORD: a new entry the first time, +1 after that. */
static void count(const char *word)
{
    for (size_t i = 0; i < nwords; i++)
        if (strcmp(words[i].word, word) == 0) {
            words[i].count++;
            return;
        }
    if (nwords == capacity) {
        capacity = capacity ? capacity * 2 : 64;
        words = realloc(words, capacity * sizeof *words);
        if (!words) { perror("realloc"); exit(1); }
    }
    words[nwords].word = strdup(word);
    words[nwords].count = 1;
    nwords++;
}

/* For qsort: the higher count first; the same count in alphabetical order. */
static int by_count(const void *a, const void *b)
{
    const struct entry *x = a, *y = b;
    if (x->count != y->count)
        return y->count - x->count;
    return strcmp(x->word, y->word);
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        fprintf(stderr, "usage: %s FILE\n", argv[0]);
        return 2;
    }
    FILE *in = fopen(argv[1], "r");
    if (!in) { perror(argv[1]); return 1; }

    char word[256];
    size_t len = 0;
    int c;
    while ((c = fgetc(in)) != EOF) {
        c = tolower(c);
        if (c >= 'a' && c <= 'z') {
            if (len < sizeof word - 1)
                word[len++] = (char)c;
        } else if (len > 0) {          /* the end of a word */
            word[len] = '\0';
            count(word);
            len = 0;
        }
    }
    if (len > 0) { word[len] = '\0'; count(word); }
    fclose(in);

    qsort(words, nwords, sizeof *words, by_count);
    for (size_t i = 0; i < nwords && i < 10; i++)
        printf("%4d %s\n", words[i].count, words[i].word);

    for (size_t i = 0; i < nwords; i++)
        free(words[i].word);
    free(words);
    return 0;
}
