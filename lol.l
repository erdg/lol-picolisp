###### utility functions!

### macro! - 'macro' with exciting new features!
#
# - expressions following the symbol '_' are evaluated and placed (not
#   spliced) in the "expansion"
#
# NOTE - this has nothing to do with 'defmacro!' from Let Over Lambda
#
(de macro! @Lst
   (macro
      (macro
         ^(_walk @Lst) ) ) )

# (macro!

(de _walk (X)
   (recur (X Acc)
      (ifn X
         (flip Acc)
         (if (pair (car X))
            (if (atom (cdr @))
               (recurse (cdr X) (cons (car X) Acc))
               (recurse (cdr X) (cons (recurse (car X) NIL) Acc)) )
            (case (car X)
               # eval and place result in expansion
               ("_" (recurse (cddr X) (cons (list 'list (cadr X)) '^ Acc)) )
               (T   (recurse (cdr X) (cons (car X) Acc))) ) ) ) ) )

# 'group' from On Lisp by Paul Graham
(de groups-of (N Src)
   (if (=0 N) (err "zero length"))
   # hack to account for off by 1
   (inc 'N)
   (recur (Src Acc)
      (let Rest (nth Src N)
         (if (pair Rest)
            (recurse Rest (cons (head (- N 1) Src) Acc))
            (flip (cons Src Acc)) ) ) ) )
# : (groups-of 2 '(1 2 3 4 5 6))
# -> ((1 2) (3 4) (5 6))

(de flat (L) (fish atom L))
# : (flat '(1 2 (3 4 (5)) 6))
# -> (1 2 3 4 5 6)

###

###### LOL PicoLisp

# The following code is a(s) direct (of a) translation (as possible) of the
# Common Lisp code from Doug Hoyte's wonderful book, Let Over Lambda. The
# guiding principle here has been:
#
#    It's important to use 'macro' as much as possible to make code
#    super cool and mind-bending like Common Lisp ;P
#
# The resulting code is not efficient (nor is it idiomatic picolisp). That
# said, I find it to be a faithful and fun translation of Doug's code, and
# certainly good for a couple of laughs.

####

###
# the 'sharp-backquote' read-macro (https://letoverlambda.com/index.cl/guest/chap6.html#sec_2)
(de \\ Lst
   (let [(@Lst) Lst]
      (fill
         '((^(at-syms @Lst))
            (fill
               '@Lst) ) ) ) )

# @1 ... @N
(de at-syms (Lst)
   (by
      '((X) (stem (chop X) "@"))
      sort
      (filter '((X) (and (pre? "@" (pack X)) (> (length @) 1)))
         (uniq
            (flat Lst) ) ) ) )
###

##### the pandoric macros!

### d! (dlambda) - a dispatching fn
#
(de d! "Ds"
   (macro
      '("Args"
         (case (car "Args")
            ^(make
               (for "D" "Ds"
                  (link
                     (list (car "D")
                        (macro
                           '(apply '(^(cdr "D")) (cdr "Args")) ) ) ) ) ) ) ) ) )
###

### p! (plambda) - a read macro used within a "@-args" 'de' form, e.g.
#
#  (de ptest @
#     `(let X 2
#        (p! (N) (X)
#           (inc 'X N)) ) )
#
# that defines pandoric environments/functions.
#
# NOTE - make sure pandoric vars are also within the '`' read-macro
#
# variables in the 'cadr' of a 'p!' form ("Pargs" below) are gathered from the
# surrounding lexical environment and exported, accessible via 'with-p!(s)'.
#
(de p! Lst
   (let [("Args" "Pargs" . Body) Lst]
      (macro!
         '(job '[^(p!-env->job "Pargs") _(cons 'This "Args" Body)]
            (macro
               ('`(d! ("getp" (Sym) (val Sym))
                      ("setp" (Sym Val) (set Sym Val))
                      (T ()  (This _'^ (rest))) )
                  _'^ (rest) ) ) ) ) ) )

(de p!-env->job (Lst)
   (make
      (for "L" Lst
         (link
            (or
               (assoc "L" (env))
               (list  "L") ) ) ) ) )
###

### *p! - anonymous p!
#
(de *p! Lst
   (let [("Args" "Pargs" . Body) Lst]
      (macro!
         (list '@
            (p! _"Args" _"Pargs" ^ Body) ) ) ) )
###

### with-p! - access pandoric variables from anywhere
#
#  (with-p! (X Y) p!-form
#     (setp X 4)
#     (setp Y (do-something)) )
#
(de with-p! Lst
   (let [("Syms" "P!" . Body) Lst]
      (macro
         (let [^(with-p!-env)]
            ^ Body ) ) ) )

(de with-p!-env ()
   (make
      (link 'Self "P!")
      (link 'setp (lit set-with-p!))
      (for "S" "Syms"
         (ifn (= "S" 'This)
            (link "S" ("P!" "getp" "S"))
            (link 'This (cons 'quote ("P!" "getp" 'This))) ) ) ) )
###

### with-p!s - combine p! environments
#
#  : (with-p!s [(This X Y) p!-1
#               (This Y Z) p!-2 ]
#       ... )
#
#  -> (let [P!1 p!-1  This1 _  X _  Y$1 _  P!2 p!-2  This2 _  Y$2 _  Z _ ]
#         ... )
#
(de with-p!s Lst
   (let [("P!s" . Body) Lst]
      (macro
         (let [^(with-p!s-env "P!s")]
            ^ Body ) ) ) )

(de with-p!s-env (P!s)
   (make
      (link 'setp (lit set-with-p!s))  # define 'setp' in 'with-p!s'
      (use P!        # current p!
         (let [N 0   # current p! number for 'P![N]','This[N]' and '[Var]$[N]' anaphors
               Boxes (groups-of 2 P!s)
               Dups  # vars referenced from multiple p!s
                  (delete 'This  # 'This' processed separately (not 100% on this yet)
                     (uniq
                        (fish atom
                           (filter '((L) (>= (length L) 2))
                              (by name group (fish atom P!s))))))
               P!Tab '() ]  # 'P!Table' used by 'setp' to look up parent 'p!' for a (possibly anaphoric) symbol
            (for Box Boxes
               (let [(Pargs P) Box]
                  (use P!T  # P!Tab entry
                     (prog
                        # do p!-form -> P![N]
                        (setq P! P)
                        (link (any (pack "P!" (inc 'N))) P)  # -> e.g. '(P!1 first-p!-arg)
                        # do p! vars
                        (for "Sym" Pargs
                           (if (= "Sym" 'This)
                              # This -> This[N]
                              (prog
                                 (link (any (pack 'This N)) (cons 'quote (P! "getp" "Sym")))
                                 (queue 'P!T (cons (any (pack "P!" N)) (any (pack 'This N)))) )  # e.g. (P!1 . This1) -> P!Tab
                              (if (member "Sym" Dups)
                                 # Var -> Var$[N]
                                 (prog
                                    (link (any (pack "Sym" "$" N)) (P! "getp" "Sym"))
                                    (queue 'P!T (cons (any (pack "P!" N)) (any (pack "Sym" "$" N)))) )  # (P!1 . Y$1) -> P!Tab
                                 # Var
                                 (prog
                                    (link "Sym" (P! "getp" "Sym"))
                                    (queue 'P!T (cons (any (pack "P!" N)) "Sym")) ) ) ) ) )  # (P!1 . X) -> P!Tab
                     (setq P!Tab (append P!T P!Tab)) ) ) )  # -> '((P!1 . X) (P!1 . Y$1) (P!2 . Y$2) (P!2 . Z))
            (link 'P!Table (cons 'quote (group P!Tab))) ) ) ) )  # -> '((P!1 X Y$1) (P!2 Y$2 Z))
###

### setp - modify p!-vars in 'with-p!(s)' forms

# in 'with-p!' forms
(de set-with-p! Lst
   (let [(@Sym . Rest) Lst]
      (macro
         (Self "setp" '@Sym ^ Rest) ) ) )

# in 'with-p!s' forms
(de set-with-p!s Lst
   (let [(@Sym . Rest) Lst]
      (macro!
         ( _(car
               (find
                  '((P) (member @Sym P))
                  P!Table ) )
          "setp"
          _(Var$N->Var @Sym)
          ^ Rest) ) ) )

(de Var$N->Var (Sym)
   (cons 'quote
      (any
         (caar
            (split (chop (pack Sym)) "$") ) ) ) )
###

# misc abstraction
(de recode-p! (Box New)
   (with-p! (This) Box
      (setp This New) ) )

### pd! - pandoric dispatchers!
#
# (let X 2
#    (pd! (X)
#       ("inc"   () (inc 'X))
#       ("dec"   () (dec 'X))
#       ("reset" () (setq X 0)) ) )
#
(de pd! Lst
   (let [("Pargs" . Body) Lst]
      (macro!
         '(job '[^(p!-env->job "Pargs")
                 _(cons 'This
                    (macro!
                       '(@
                          (macro
                             ((d! ("getp" (Sym) (val Sym))
                                  ("setp" (Sym Val) (set Sym Val))
                                  ^ Body )
                              _'^ (rest) ) ) ) ) ) ]
            (apply This (rest)) ) ) ) )
###

### *pd! - anonymous pd!
#
(de *pd! Lst
   (let [("Pargs" . Body) Lst]
      (macro!
         (list '@
            (pd! _"Pargs" ^ Body) ) ) ) )
###

### pm - define pandoric method
#
(de pm Lst
   (let [("Nm" "Args" "Pargs" . Body) Lst]
      (macro!
         (de _"Nm" (Self ^ "Args")
            _(if "Pargs"
               (macro!
                  '(with-p! _"Pargs" Self
                     ^ Body ) )
               (macro '(prog ^ Body) ) ) ) ) ) )

# typ! - create a new type of pandoric object!
(de typ! Lst
   (let [("Nm" . Args) Lst]
      (macro!
         (de _ "Nm" (^ Args)
            (macro!
               (let [^(mapcan '`(\\ (@1 _'_ @1)) Args)]
                  (*p! () (^ Args)) ) ) ) ) ) )

# : (typ! panrectangle X Y DX DY)
# -> panrectangle
# : (def 'pr1 (panrectangle 1 1 20 30))
# -> pr1
# : (pm area () (DX DY) (* DX DY))
# -> area
# : (area pr1)
# -> 600
###

# (load "pandoric-tests.l")
# (pandoric-tests)

###### LOLFORTH

# The rest of this file defines a simple forth, implemented with the ridiculous
# function / macros above. The forth image is one big 'job' environment. The
# forth dictionary is implemented as a nested chain of job environments
# (created via 'typ!' -> '*p!'). Somehow it all works.

(setq forth-registers
   (quote
      pstack
      rstack
      pc
      dict
      compiling ) )

(typ! forth-word
   Name
   Prev
   Immediate
   Thread )

(de forth-lookup (Word Last)
   (if Last
      (if (= (Last "getp" 'Name) Word)
         Last
         (forth-lookup Word (Last "getp" 'Prev)) ) ) )

# cons threaded code
(de forth-inner-interpreter ()
   (loop
      (T (and (not pc) (not rstack)) 'ok)
      (cond
         ((fun? (car pc))
            # HACK - stupid picolisp numbers thinking they are functions
            (ifn (atom (car pc))
               ((car pc))
               (push 'pstack (car pc))
               (setq pc (cdr pc)) ) )
         ((pair (car pc))
            (push 'rstack (cdr pc))
            (setq pc (car pc)) )
         ((not pc)
            (setq pc (pop 'rstack)) )
         (T
            (push 'pstack (car pc))
            (setq pc (cdr pc)) ) ) ) )

# NOTE - should implement 'alet' for an exact translation from LOL, but
# 'prog1' will work for now.
(de new-forth ()
   (prog1
      # @ <- create new forth image
      (macro
         (let [^(make (for R forth-registers (link R NIL)))]
            (forth-install-prims)
            (*p! (V) (^ forth-registers)
               (let Word (forth-lookup V dict)
                  (if Word
                     (forth-handle-found)
                     (forth-handle-not-found) ) ) ) ) )
      # install stdlib
      (macro (go-forth @ ^ forth-stdlib)) ) )

(de forth-handle-found ()
   (if (and compiling (not (Word "getp" 'Immediate)))
      (forth-compile-in (Word "getp" 'Thread))
      (prog
         (setq pc (list (Word "getp" 'Thread)))
         (forth-inner-interpreter) ) ) )

(de forth-handle-not-found ()
   (cond
      ((and (pair V) (= (car V) 'quote))
         (if compiling
            (forth-compile-in (cadr V))
            (push 'pstack (cdr V)) ) )
      ((and (pair V) (= (car V) 'postpone))
         (let Word (forth-lookup (cadr V) dict)
            (ifn Word (err "Postpone failed"))
            (forth-compile-in (Word "getp" 'Thread)) ) )
      ((sym? V)
         (err "Word not found") )
      (T
         (if compiling
            (forth-compile-in V)
            (push 'pstack V) ) ) ) )

(de forth-compile-in (@V)
   (macro
      (dict "setp" 'Thread
         (conc (dict "getp" 'Thread) (list '@V))) ) )

# FORTH REPL
#
# : (go-forth F 3 dup * print)
# 9
# -> ok
#
(de go-forth ("Forth" . Words)
   (macro
      (for W '(^(mapcar '`(\\ '@1) Words))
         ("Forth" W) ) ) )

 # dummy function to access file to e.g. add new primitives or stdlib words
(de forth ())

# FORTH PRIMITIVES
(de def-forth-naked-prim @Code
   (macro
      (push 'forth-prim-forms '@Code) ) )

(de def-forth-prim Code
   (macro
      (def-forth-naked-prim
         ^ Code
         (setq pc (cdr pc)) ) ) )

(setq forth-prim-forms NIL)

# (X) lisp fn -> forth primitive
(de forth-unary-word-definer Words
   (macro
      (prog
         ^(mapcar
            '`(\\
               (def-forth-prim @1 NIL
                  (push 'pstack (@1 (pop 'pstack))) ) )
            Words ) ) ) )

# (X Y) lisp fn -> forth primitive
(de forth-binary-word-definer Words
   (macro
      (prog
         ^(mapcar
            '`(\\
               (def-forth-prim @1 NIL
                  (let "Top" (pop 'pstack)
                     (push 'pstack (@1 (pop 'pstack) "Top")) ) ) )
            Words ) ) ) )

(de forth-install-prims ()
   (macro
      (prog
         ^(mapcar
            '`(\\
               (let Thread (lit '(NIL ^(cddr @1)))
                  (setq dict
                     (forth-word
                        (cons 'quote (car '@1))
                        (cons 'quote dict)
                        ^(list (cadr @1))
                        Thread ) ) ) )
            forth-prim-forms ) ) ) )

# definitions
(def-forth-naked-prim branch-if NIL
   (setq pc (if (pop 'pstack)
               (cadr pc)
               (cddr pc) ) ) )

(def-forth-naked-prim compile NIL
   (dict "setp" 'Thread
      (conc
         (dict "getp" 'Thread)
         (list (cadr pc)) ) )
   (setq pc (cddr pc)) )

(def-forth-prim here NIL
   (push 'pstack (tail 1 (dict "getp" 'Thread))) )

(def-forth-prim nop NIL)

(def-forth-prim * NIL
   (push 'pstack (* (pop 'pstack) (pop 'pstack))) )

(def-forth-prim drop NIL
   (pop 'pstack) )

(def-forth-prim dup NIL
   (push 'pstack (car pstack)) )

(def-forth-prim over NIL
   (push 'pstack (cadr pstack)) )

(def-forth-prim swap NIL
   (rot pstack 2) )

(def-forth-prim print NIL
   (println (pop 'pstack)) )

(def-forth-prim >r NIL
   (push 'rstack (pop 'pstack)) )

(def-forth-prim r> NIL
   (push 'pstack (pop 'rstack)) )

###
# NOTE - can't use forth brackets because picolisp "super parens"
(def-forth-prim |_ T    # [
   (setq compiling NIL) )

(def-forth-prim _| NIL  # ]
   (setq compiling T) )
###

(def-forth-prim create NIL
   (setq dict (forth-word NIL (cons 'quote dict) NIL NIL)) )

(def-forth-prim name NIL
   (dict "setp" 'Name (pop 'pstack)) )

(def-forth-prim immediate NIL
   (dict "setp" 'Immediate T) )

(def-forth-prim @ NIL
   (push 'pstack (car (pop 'pstack))) )

(def-forth-prim ! NIL
   (let Location (pop 'pstack)
      (set Location (pop 'pstack)) ) )

(forth-unary-word-definer
   not car cdr cadr caddr cadddr )

(forth-binary-word-definer
   = == + - / < > <= >= )

### END FORTH PRIMITIVES

### FORTH STANDARD LIBRARY
(setq forth-stdlib NIL)

(de forth-stdlib-add @All
   (macro
      (setq
         forth-stdlib
         (conc forth-stdlib '@All) ) ) )

(forth-stdlib-add
   create _| dup * |_ 'square name )

(forth-stdlib-add
   create _| create _| |_ ': name )

(forth-stdlib-add
   : (postpone |_) |_ '; name immediate )

(forth-stdlib-add
   : r> drop ; 'exit name )

(forth-stdlib-add
   :
      compile nop
      here swap !
   ; 'then name immediate )

(forth-stdlib-add
   :
      compile 'T
      compile branch-if
      compile nop
      here swap
      compile nop
      here swap !
   ; 'else name immediate )

(forth-stdlib-add
   : compile nop here ; 'begin name immediate )

(forth-stdlib-add
   :
      compile 'T
      compile branch-if
      compile nop
      here !
   ; 'again name immediate )

(forth-stdlib-add
   :
      compile not
      compile branch-if
      compile nop
      here
   ; 'if name immediate )

(forth-stdlib-add
   : over over ; '2dup name )

(forth-stdlib-add
   : swap drop ; 'nip name )

(forth-stdlib-add
   : drop drop ; '2drop name )

(forth-stdlib-add
   : swap over ; 'tuck name )

### END FORTH STANDARD LIBRARY

### FORTH IMAGE INTROSPECTION
(de get-forth-thread ("Forth" Word)
   (let D ("Forth" "getp" 'dict)
      (until (= (D "getp" 'Name) Word)
         (setq D (D "getp" 'Prev)) )
      (D "getp" 'Thread) ) )

(de get-forth-words ("F")
   (let D ("F" "getp" 'dict)
      (make
         (link (D "getp" 'Name))
         (while (setq D(D "getp" 'Prev))
            (link (D "getp" 'Name)) ) ) ) )

### TESTS

(let F (new-forth)
   (go-forth F 1 2 3 + +)
   (test (6) (F "getp" 'pstack))
   (F "setp" 'pstack NIL)
   (go-forth F 14 'N !)
   (F "setp" 'pstack NIL)
   (go-forth F 'N @)
   (test (14) (F "getp" 'pstack))
   (F "setp" 'pstack NIL)
   (test 'ok
      (go-forth F
         : begin
            dup 1 >= if
               dup print
               1 -
               |_ swap _| again
               then
            drop
         ; 'countdown-for-teh-hax0rz name
         '"countdown-for-teh-hax0rz coded in forth!" print
         4 countdown-for-teh-hax0rz ) )
   (t (prinl "LOLFORTH -- PASSED ALL TESTS"))
)
