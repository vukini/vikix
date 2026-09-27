\ wordfreq.fs — the ten most common words in a text file.
\
\ A word is a run of letters, compared in lower case. Forth has no hash
\ table, but it has one built in all the same: the dictionary, where it
\ keeps its own words. So each word of the text becomes a Forth word in
\ a wordlist of its own, holding its count; looking a word up is Forth's
\ own fast search. An insertion sort puts the most common first.
\
\   gforth wordfreq.fs text.txt

wordlist constant counted          \ the words seen so far, as Forth words

1000 constant max-entries
create entries  max-entries 3 cells * allot   \ each: name address, length, count address
variable #entries

: entry ( n -- addr )  3 cells * entries + ;

\ A new Forth word named by the string, in `counted`, holding a count of 1.
\ nextname gives the next defining word (here create) its name.
: new-word ( c-addr u -- )
  #entries @ max-entries = abort" too many different words"
  2dup #entries @ entry 2!          \ remember the name (it stays in the text)
  get-current >r  counted set-current
  nextname create here 1 ,          \ the count lives in the word's body
  r> set-current
  #entries @ entry 2 cells + !
  1 #entries +! ;

: count-word ( c-addr u -- )
  2dup counted search-wordlist if
    nip nip >body 1 swap +!         \ seen before: its body holds the count
  else
    new-word
  then ;

: letter? ( c -- f )  [char] a [char] z 1+ within ;

\ Lower-case the text in place, then count each run of letters. start
\ holds where the current word began, or 0 between words.
variable start
: count-words ( c-addr u -- )
  2dup bounds ?do  i c@ toupper bl or  i c!  loop   \ bl or: A-Z becomes a-z
  2dup + >r                         \ the end, for a word the text ends with
  0 start !
  bounds ?do
    i c@ letter? if
      start @ 0= if i start ! then
    else
      start @ ?dup if  i over - count-word  0 start !  then
    then
  loop
  r> start @ ?dup if tuck - count-word else drop then ;

\ Sorting: the higher count first; the same count in alphabetical order.
: count@ ( n -- u )  entry 2 cells + @ @ ;
: name@ ( n -- c-addr u )  entry 2@ ;
: before? ( i j -- f )
  over count@ over count@ 2dup <> if > nip nip exit then 2drop
  name@ rot name@ 2swap compare 0< ;   \ i's name first?
: swap-entries ( i j -- )
  entry swap entry 3 0 do
    over @ over @  3 pick !  over !  cell+ swap cell+ swap
  loop 2drop ;
\ Move entry j back until the one before it belongs before it.
: sift ( j -- )
  begin dup 0> while dup dup 1- before? while
    dup dup 1- swap-entries 1-
  repeat then drop ;
: sort-entries ( -- )  #entries @ 1 ?do i sift loop ;

: main ( -- )
  next-arg dup 0= if 2drop ." usage: gforth wordfreq.fs FILE" cr bye then
  slurp-file count-words
  sort-entries
  #entries @ 10 min 0 ?do
    i count@ 4 .r space  i name@ type cr
  loop ;

main bye
