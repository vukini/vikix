/* stats.c: two functions exercise.c uses. Leave this file as it is. */

/* mean: the average of v[0..n-1]; 0 when n is 0. */
double mean(const double *v, int n)
{
    double sum = 0;
    for (int i = 0; i < n; i++)
        sum += v[i];
    return n > 0 ? sum / n : 0;
}

/* largest: the biggest of v[0..n-1]; n is at least 1. */
double largest(const double *v, int n)
{
    double big = v[0];
    for (int i = 1; i < n; i++)
        if (v[i] > big)
            big = v[i];
    return big;
}
