\ words.fs — Forth grows by defining words, even new kinds of words.
\
\ A colon definition makes a word out of other words. create ... does>
\ goes further: it makes a *defining* word, one that makes more words.
\ Here `unit` makes words like km and cm that each know their size in
\ millimetres, so lengths can be written the way you'd say them.
\ The stack comment ( in -- out ) says what each word takes and leaves.

: square ( n -- n*n )  dup * ;
: cube   ( n -- n*n*n )  dup square * ;

\ unit ( mm "name" -- ): make a word "name" that multiplies by mm.
: unit  create ,  does> @ * ;

   1 unit mm
  10 unit cm
1000 unit m
1000000 unit km

: show-mm ( n -- )  . ." mm" cr ;

.( 7 squared: ) 7 square . cr
.( 3 cubed: ) 3 cube . cr
.( 2 km + 350 m + 12 cm: ) 2 km 350 m + 12 cm + show-mm
.( how gforth sees `cube`: ) cr
see cube
bye
