-- Main.hs — the ten most common words in a text file.
--
-- A word is a run of letters, compared in lower case. The whole program
-- is one pipeline of pure functions: lower-case the text, split it into
-- words, count them in a Map, sort, take ten. Only reading the file and
-- printing are IO.
--
--   cabal run wordfreq -- text.txt
module Main (main) where

import Data.Char (isAsciiLower, toLower)
import Data.List (sortBy)
import Data.Ord (Down (..), comparing)
import qualified Data.Map.Strict as Map
import System.Environment (getArgs)
import System.Exit (exitWith, ExitCode (..))
import Text.Printf (printf)

-- Split into runs of letters a-z, dropping everything else.
wordsOf :: String -> [String]
wordsOf s = case dropWhile (not . isAsciiLower) s of
  "" -> []
  s' -> let (w, rest) = span isAsciiLower s' in w : wordsOf rest

-- The higher count first; the same count in alphabetical order.
top :: Int -> [String] -> [(String, Int)]
top n = take n . sortBy (comparing (\(w, c) -> (Down c, w)))
      . Map.toList . Map.fromListWith (+) . map (\w -> (w, 1))

main :: IO ()
main = do
  args <- getArgs
  case args of
    [path] -> do
      text <- readFile path
      mapM_ (\(w, c) -> printf "%4d %s\n" c w) (top 10 (wordsOf (map toLower text)))
    _ -> putStrLn "usage: wordfreq FILE" >> exitWith (ExitFailure 2)
