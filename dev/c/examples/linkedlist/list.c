/* list.c — a linked list: C's pointers and memory, by hand.
 *
 * Each node lives on the heap (malloc) and points at the next one. We push
 * a few numbers on the front, reverse the list in place by turning the
 * pointers round, then free every node. `make check` runs it under
 * valgrind, which reports any memory we forgot to free.
 */
#include <stdio.h>
#include <stdlib.h>

struct node {
    int value;
    struct node *next;
};

/* A new node in front of LIST; returns the new front. */
static struct node *push(struct node *list, int value)
{
    struct node *n = malloc(sizeof *n);
    if (!n) { perror("malloc"); exit(1); }
    n->value = value;
    n->next = list;
    return n;
}

/* The same nodes, in the opposite order: each next pointer turned round. */
static struct node *reverse(struct node *list)
{
    struct node *done = NULL;
    while (list) {
        struct node *next = list->next;
        list->next = done;
        done = list;
        list = next;
    }
    return done;
}

static void print(const char *label, const struct node *list)
{
    printf("%-9s", label);
    for (; list; list = list->next)
        printf(" %d", list->value);
    printf("\n");
}

/* Every node back to the system. Try deleting this call: valgrind notices. */
static void free_list(struct node *list)
{
    while (list) {
        struct node *next = list->next;
        free(list);
        list = next;
    }
}

int main(void)
{
    struct node *list = NULL;
    for (int i = 1; i <= 5; i++)
        list = push(list, i * i);
    print("pushed:", list);
    list = reverse(list);
    print("reversed:", list);
    free_list(list);
    return 0;
}
