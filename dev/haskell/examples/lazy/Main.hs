-- Main.hs — laziness: lists that never end.
--
-- Haskell works out a value only when something needs it. So a list can
-- be infinite: every prime, every Fibonacci number. Nothing runs forever,
-- because only the part you take is ever computed.
module Main (main) where

-- Every prime: 2, then each odd number no smaller prime divides.
-- primes is defined in terms of itself; laziness makes that work.
primes :: [Int]
primes = 2 : filter isPrime [3, 5 ..]
  where
    isPrime n = all (\p -> n `mod` p /= 0) (takeWhile (\p -> p * p <= n) primes)

-- Every Fibonacci number: the list, added to its own tail.
fibs :: [Integer]
fibs = 0 : 1 : zipWith (+) fibs (tail fibs)

main :: IO ()
main = do
  putStrLn ("first 10 primes:         " ++ show (take 10 primes))
  putStrLn ("the 1000th prime:        " ++ show (primes !! 999))
  putStrLn ("first 15 Fibonacci:      " ++ show (take 15 fibs))
  putStrLn ("the 100th Fibonacci:     " ++ show (fibs !! 100))
  putStrLn ("first Fibonacci > 10^20: " ++ show (head (dropWhile (<= 10 ^ (20 :: Int)) fibs)))
