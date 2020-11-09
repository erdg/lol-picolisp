[de lol-tests ()

### d! tests
(def 'd!-test
   (d!
      ("this" () 'this-thing)
      ("that" () 'that-thang)
      (T () 'default) ) )

(test 'this-thing (d!-test "this"))
(test 'that-thang (d!-test "that"))
(test 'default (d!-test))

(test 9
   (let X 3
      ((d! ("doubleX" () (* X 2)) ("squareX" () (* X X)))
         "squareX") ) )

(test 6
   (let X 3
      ((d! ("doubleX" () (* X 2)) ("squareX" () (* X X)))
         "doubleX") ) )

(test 15
   (let [X 3 D! (d! ("doubleX" () (* X 2)) ("squareX" () (* X X)))]
      (+ (D! "doubleX") (D! "squareX")) ) )

#### this is essentially a 'p!' form
(de d!-with-state @
   (job '((State . NIL) (Cnt . 0))
      (macro
         ((d!
            ("getp" (Sym) (val Sym))
            ("setp" (Sym Val) (set Sym Val)) )
         ^(rest) ) ) ) )

(d!-with-state "setp" 'Cnt 3)
(test 3 (d!-with-state "getp" 'Cnt))
(d!-with-state "setp" 'State "ON")
(test "ON" (d!-with-state "getp" 'State))
###


### *p! tests
(test 30
   (let (X 2 P! (*p! (N) (X) (inc 'X N)))
      (P! 2)  # -> 4
      (with-p! (X) P!
         (setp X (+ X 26)) ) # -> 30
      (P! "getp" 'X) ) )

(test 30
   (let X 2
      (let P! (*p! (N) (X) (inc 'X N))
         (P! 2)  # -> 4
         (with-p! (X) P!
            (setp X (+ X 26)) ) # -> 30
         (P! "getp" 'X) ) ) )
###

# pd! tests
(de pd!-test @
   `(let (X 0 Y 0)
      (pd! (X Y)
         ("incX" () (inc 'X))
         ("incY" () (inc 'Y))
         (T () (list X Y)) ) ) )

(pd!-test "incX")
(pd!-test "incY")
(pd!-test "incY")

(test (1 2) (pd!-test))

# call fn from anywhere
(test 5
   (prog
      (with-p! (This X) pd!-test
         (do 4 (setp X (This "incX"))) )
      (pd!-test "getp" 'X) ) )

# redundant
(de pd!-env-test @
   `(let X 0
      (let Y 0
         (pd! (X Y)
            ("incX" () (inc 'X))
            ("incY" () (inc 'Y))
            ("reset" () (setq X 0 Y 0))
            (T () (list X Y)) ) ) ) )

(test 1 (pd!-env-test "incX"))
(test 1 (pd!-env-test "incY"))
(test 2 (pd!-env-test "incX"))
(test (2 1) (pd!-env-test))
###

### p! tests
(de p!-test @
   `(let X 0
      (p! (N) (X)
         (inc 'X N) ) ) )

(test 3 (p!-test 3))
# : (p!-test 3)
# -> 3

(test 13 (p!-test 10))
# : (p!-test 10)
# -> 13

(with-p! (X) p!-test  # p! over anonymous d!
   ((d!
      ("inc" () (setp X (inc 'X)))
      ("dec" () (setp X (dec 'X))) )
    "dec" ) )

# : (p!-test "getp" 'X)
# -> 12
(test 12 (p!-test "getp" 'X))

(with-p! (This) p!-test (setp This '((N) (inc 'X (* 2 N)))))
# -> ((N) (inc 'X (* 2 N)))

# : (p!-test 10)
# -> 32
(p!-test 10)
(test 32 (p!-test "getp" 'X))

# : (p!-test "getp" 'This)
# -> ((N) (inc 'X (* 2 N)))
(test '((N) (inc 'X (* 2 N))) (p!-test "getp" 'This))

(recode-p! p!-test
   '((N) (inc 'X (* 3 N))) )

(p!-test 7)  # -> 53
(test 53 (p!-test "getp" 'X))
###

###
  (de p!-env-test @
     `(let X 2
        (p! (N) (X)
           (inc 'X N)) ) )

(p!-env-test 2)
# : (p!-env-test 2)
# -> 4
(test 4 (p!-env-test "getp" 'X))


(test 13
   (with-p! (X) p!-env-test
      (setp X (+ X 9)) ) )
# : (with-p! (X) p!-env-test
#      (setp X (+ X 9)) )
# -> 13

(test 13 (p!-env-test "getp" 'X))
# : (p!-env-test "getp" 'X)
# -> 13
###


###
(de p!-over-d!-test @
   (job '((Self . `(let X 0 (list '@ (p! () (X))))))  # this was the first '*p!' (anonymous p!)
      (with-p! (X) Self
         (if (member (car (rest)) '("getp" "setp"))
            (cond
               ((= (car @) "getp") X)
               ((= (car @) "setp") (setp X (last (rest)))) )
            (macro
               ('`(d!
                     ("inc"   () (setp X (inc 'X)))
                     ("dec"   () (setp X (dec 'X)))
                     ("reset" () (setp X 0)) )
                  ^(rest)) ) ) ) ) )

(test 1 (p!-over-d!-test "inc"))
# : (p!-over-d!-test "inc")
# -> 1

(test 6 (do 5 (p!-over-d!-test "inc")))
# : (do 5 (p!-over-d!-test "inc"))
# -> 6

(test 5 (p!-over-d!-test "dec"))
# : (p!-over-d!-test "dec")
# -> 5

(test 17 (p!-over-d!-test "setp" 'X 17))
# : (p!-over-d!-test "setp" 'X 17)
# -> 17

(test 16 (p!-over-d!-test "dec"))
# : (p!-over-d!-test "dec")
# -> 16
###
###
(def '*p!-test
   (let X 2
      (*p! (N) (X) (inc 'X N)) ) )

(*p!-test 2)

(test 4 (*p!-test "getp" 'X))

(test 13
   (with-p! (X) *p!-test
      (setp X (+ X 9)) ) )
# : (with-p! (X) p!-env-test
#      (setp X (+ X 9)) )
# -> 13
###

### nested 'with-p!'s - prototype for 'with-p!s'
(test (15 8)
   (let (X 2 Y 3)
      (let [P1 (*p! (N) (X) (inc 'X N))
            P2 (*p! (N) (Y) (inc 'Y N))]
         (with-p! (X) P1
            (with-p! (Y) P2
               (P1 (+ (P2 5) 5))
               (list
                  (P1 "getp" 'X)
                  (P2 "getp" 'Y)) ) ) ) ) )

(de pdtest2 @
   `(let [X 1 Y 2 Z 3]
      (pd! (X Y Z)
         ("incAll" () (inc 'X) (inc 'Y) (inc 'Z))
         ("incX" (N) (inc 'X N))
         ("incY" (N) (inc 'Y N))
         ("incZ" (N) (inc 'Z N))
         ("sum"   () (+ X Y Z))
         ("reset" () (zero X Y Z))
         (T () (t (prinl "X = " X ", Y = " Y ", Z = " Z))) ) ) )

# NEW WITH-P!S TESTS
(test (53 1)
   (with-p!s [(X) p!-test
              (Y) pd!-env-test ]
      (list X Y) ) )

# test 'This[N]' anaphors
(test '((N) (inc 'X (* 3 N)))
   (with-p!s [(This X) p!-test
              (This Y) pd!-env-test ]
      This1 ) )

(test
   (list
      '((N)
         (+ (inc 'X N) (inc 'Y (* 2 N))))
      '((N)
         (+ (inc 'Y (* 3 N)) (inc 'Z (* 4 N)))) )
   (let X 1
      (let Y 2
         (let Z 3
            (let [some-p! (*p! (N) (X Y) (+ (inc 'X N) (inc 'Y (* 2 N))))
                  some-other-p! (*p! (N) (Y Z) (+ (inc 'Y (* 3 N)) (inc 'Z (* 4 N))))]
               (with-p!s [(This) some-p!
                          (This) some-other-p!]
                  (list This1 This2) ) ) ) ) ) )

# test 'P![N]' anaphors
(test 62
   (prog
      (with-p!s [(This X) p!-test]
         (P!1 3) )
      (p!-test "getp" 'X) ) )

(test (11 111 1111)
   (let (X 1 Y 101 Z 1101)
      (let [p!-1 (*p! (N) (X) (inc 'X N))
            p!-2 (*p! (N) (Y) (inc 'Y N))
            p!-3 (*p! (N) (Z) (inc 'Z N))]
         (with-p!s  [(This X) p!-1  # -> P!1
                     (This Y) p!-2  # -> P!2
                     (This Z) p!-3] # -> P!3
            (mapc '((P) (P 10)) '(P!1 P!2 P!3))
            (mapcar '((P V) (P "getp" V)) '(P!1 P!2 P!3) '(X Y Z))) ) ) )

# test '[Var]$[N]' anaphors
(test (2 12)
   (let (X 1 Y 2)
      (let p!-1 (*p! (N) (X Y) (+ (inc 'X N) (inc 'Y (* 2 N))))
         (let (Y 12 Z 13)
            (let p!-2 (*p! (N) (Y Z) (+ (inc 'Y (* 3 N)) (inc 'Z (* 4 N))))
               (with-p!s [(X Y) p!-1
                          (Y Z) p!-2]
                  (list Y$1 Y$2) ) ) ) ) ) )

(test (22 22 33)
   (let X 0
      (let [p!-1 (*p! (N) (X) (inc 'X N))
            p!-2 (*p! (N) (X) (inc 'X (* 2 N)))
            p!-3 (*p! (N) (X) (inc 'X (* 3 N))) ]
         (with-p!s  [(X) p!-1  # -> P!1
                     (X) p!-2  # -> P!2
                     (X) p!-3] # -> P!3
            (do 2 (setp X$1 (P!1 11)))
            (setp X$2 (P!2 11))
            (setp X$3 (P!3 11)) )
         (list (p!-1 "getp" 'X) (p!-2 "getp" 'X) (p!-3 "getp" 'X)) ) ) )

(test (22 22 33)
   (let (X 0 Y 0)
      (let [p!-1 (*p! (N) (X) (inc 'X N))
            p!-2 (*p! (N) (Y) (inc 'Y (* 2 N)))
            p!-3 (*p! (N) (X) (inc 'X (* 3 N))) ]
         (with-p!s  [(X) p!-1  # -> P!1
                     (Y) p!-2  # -> P!2
                     (X) p!-3] # -> P!3
            (do 2 (setp X$1 (P!1 11)))
            (setp Y (P!2 11))
            (setp X$3 (P!3 11)) )
         (list (p!-1 "getp" 'X) (p!-2 "getp" 'Y) (p!-3 "getp" 'X)) ) ) )

# test 'setp' within 'with-p!s'
(test (22 1212)
   (let (X 1 Y 2)
      (let p!-1 (*p! (N) (X Y) (+ (inc 'X N) (inc 'Y (* 2 N))))
         (let (Y 12 Z 13)
            (let p!-2 (*p! (N) (Y Z) (+ (inc 'Y (* 3 N)) (inc 'Z (* 4 N))))
               (with-p!s [(X Y) p!-1
                          (Y Z) p!-2]
                  (setp Y$1 22)
                  (setp Y$2 1212) )
               (list (p!-1 "getp" 'Y) (p!-2 "getp" 'Y)) ) ) ) ) )

# pandoric rectangle object
(de p-rectangle (X Y DX DY)
   (macro!
      (let [X  _ X
            Y  _ Y
            DX _ DX
            DY _ DY]
         (*p! () (X Y DX DY))) ) )

# NOTE - this was the first 'typ!'. '(typ! p-rectangle X Y DX DY)' expands
# into the above definition.

(pm coords () (X Y)
   (list X Y) )

(pm move (A B) (X Y)
   (prog
      (setp X (+ X A))
      (setp Y (+ Y B))
      (coords Self) ) )

(pm area () (DX DY)
   (* DX DY) )

(pm perimeter () (DX DY)
   (* 2 (+ DX DY)) )

###

(def 'pr1 (p-rectangle 0 0 20 30))

(move pr1 7 8)

(move pr1 3 -9)

(test (10 -1) (coords pr1))

(test 100 (perimeter pr1))

###

(de p-rectangle% (X Y DX DY)
   (macro!
      (let [X  _ X
            Y  _ Y
            DX _ DX
            DY _ DY]
         (*pd! (X Y DX DY)
            ("coords" () (list X Y))
            ("move" (A B)
               (prog
                  (inc 'X A)
                  (inc 'Y B)
                  (This "coords") ) )
            ("area" () (* DX DY))
            ("perimeter" () (* 2 (+ DX DY))) ) ) ) )

(def 'pr2 (p-rectangle% 0 0 47 82))

(test 3854 (pr2 "area"))
(test 3854 (area pr2))

###

(typ! panrectangle X Y DX DY)
(def 'pr3 (panrectangle 1 1 20 30))
(test 600 (area pr3))
(test (2 2) (move pr3 1 1))

###

(pd!-env-test "reset")
(test (0 0) (pd!-env-test))

# make sure the global env stays clean
(test T
   (fully '((X) (= NIL X))
       (list State Cnt X Y Z Y$1 Y$2 This This1 This2 This3 D! P! P!1 P!2 P!3 p!-1 p!-2 p!-3 Self setp) ) )

(off pr1 pr2 pr3 d!-test d!-with-state p!-test p!-env-test p!-over-d!-test pd!-test *p!-test)
# and it's good to go
(t (prinl "pandoric -- passed all tests"))

### FORTH TESTS

(let F (new-forth)

   # primitive test
   (go-forth F 2 3 *)
   (test (6) (F "getp" 'pstack))
   (F "setp" 'pstack NIL)

   # basic memory and vars
   (go-forth F 14 'N !)
   (F "setp" 'pstack NIL)
   (go-forth F 'N @)
   (test (14) (F "getp" 'pstack))
   (F "setp" 'pstack NIL)

   # user defined functions
   (go-forth F : dup * ; 'square name)
   (go-forth F 8 square)
   (test (64) (F "getp" 'pstack))
   (F "setp" 'pstack NIL)

   (t (prinl "LOLFORTH -- PASSED ALL TESTS"))
)

]
