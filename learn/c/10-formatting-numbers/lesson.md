# 10 · Formatting numbers: a project

Turning a number into text is a small program with every edge C has: digits come out backwards, the minus sign is extra, the most negative number has no positive twin, and the buffer it goes into has a size you mustn't go past.

`example.c` does it two ways. `to_decimal` takes the last digit with `% 10` and drops it with `/ 10`, then turns the digits round; `snprintf` does the formatting itself, and never writes more than the size it's given:

<!-- output: ./example -->
```text
to_decimal: 9876543210
snprintf into 6 chars: "12345", the whole was 7 chars
```

`snprintf` cut 1234567 to fit 6 chars (5 digits and the `'\0'`), and said the whole would have been 7: compare that with the size, and you know it was cut.

## The project

`exercise.c` is `with_commas`: `-1234567` becomes `"-1,234,567"`. It returns the length, or -1 and an empty `out` when it doesn't fit. As in lesson 08, write the purpose and the examples before the body; `LLONG_MIN` is the one that needs thought, because `-LLONG_MIN` doesn't fit in a `long long`. The check writes into buffers of exactly the right size, and one char too small.
