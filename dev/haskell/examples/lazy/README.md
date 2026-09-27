# lazy (Haskell)

What Haskell is known for: purity and laziness. The list of every prime
and of every Fibonacci number, defined in a line each; only as much as
you take is ever worked out. (`Integer` has no size limit, so the
Fibonacci numbers can grow as big as you like.)

    make run

Try: in `ghci Main.hs`, `take 20 primes` and `length primes` (press
Ctrl+C: it never ends); write `squares = map (^2) [1..]` and take some.
Docs: Learn You a Haskell, "Starting Out": https://learnyouahaskell.github.io/
