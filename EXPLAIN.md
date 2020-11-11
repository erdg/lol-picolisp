# Explanation Station

#### The Gist
Layers and layers of macros that implement a lispy version of the FORTH programming language, the internals of which are completely ridiculous.

### Utilities
The file starts with a few utility functions.

'macro!' offers a non-splicing complement to `^` in 'macro'. NOTE - this has nothing to do with the impressive `defmacro!` from Let Over Lambda.

```
: (macro! (let X _(+ 2 3) (* X X))) )
-> 25
```

It uses a naive code walker to look for underscore characters, evaluate the following atom or list and insert the result in its place. It does this by transforming `_( ... )` to `^(list ( ... ))` and passing it to `macro`. `macro` then splices _that_ in, but because it was `list`ed, the net effect is 'placing' and not 'splicing'. So `macro!` rewrites the code that is passed to it so that `macro` understands it, all for a bit of syntax sugar. Sure makes the code look sweet though :rofl:

`groups-of` (`group` from [On Lisp](http://www.paulgraham.com/onlisp.html) and `flat` are pretty self explanatory.
```
: (groups-of 2 '(1 2 3 4 5 6))
-> ((1 2) (3 4) (5 6))

: (flat '(1 2 (3 4 (5)) 6))
-> (1 2 3 4 5 6)
```

`\\` is the [sharp-backquote](https://letoverlambda.com/index.cl/guest/chap6.html#sec_2)
read macro from Let Over Lambda. It is named `\\` in PicoLisp because obviously `#` and backquote are out, and who knew you could name a function `\\`?!

>Another way to think about sharp-backquote is that it is to list interpolation as the [`text`] function is to string interpolation. Just as [`text`] lets us use a template with slots that are to be filled with the values of separate arguments, sharp-backquote lets us separate the structure of the list interpolation from the values we want to splice in.
>
> -- Let Over Lambda (p. 158)

```
: (mapcar '`(\\ (@1 'empty)) '(Var1 Var2 Var3))
-> ((Var1 'empty) (Var2 'empty) (Var3 'empty))

: ('`(\\ (((@2)) @3 (@1 @1))) 'A 'B 'C)
-> (((B)) C (A A))
```

### Dlambda
> Dlambda is designed to be passed a [transient] symbol as the first argument. Depending on which [transient] symbol was used, dlambda will execute a corresponding piece of code.
>
> -- Let Over Lambda (p. 149)

`d!` is the PL translation of [dlambda](https://letoverlambda.com/index.cl/guest/chap5.html#sec_7).

```
: (def 'D
   (d!
      ("add" (X Y) (+ X Y))
      ("sub" (X Y) (- X Y)) ) )
-> D
```
The `d!` macro creates dispatching functions by "expanding" into a case statement.
```
: (pretty D)
-> ("Args"
      (case (car "Args")
         ("add"
            ... )
         ("sub"
            ... ) ) )
```
When called with a `"keyword"` it dispatches the matching function with the supplied arguments.
```
: (D "add" 2 3)
-> 5

: (D "sub" 16 9)
-> 7
```
`d!` also inherits the default clause `T` from the `case` statement.
```
: (def 'D
   (d!
      ("supercool" () "Wow, dlambda functions are super cool!")
      (T () "No arguments. Boring.") ) )
# D redefined
-> D

: (D "supercool")
-> "Wow, dlambda functions are super cool!"

: (D)
-> "No arguments. Boring"
```

We could imagine making a counter as a "dlambda with state". This can be done by wrapping the dlambda in a `job` environment.
```
: (de d!-with-state @
   (job '((Cnt . 0))
      (macro  # apply dlambda to rest args
         ((d!
            ("inc" (X) (inc 'Cnt X))
            ("dec" (X) (dec 'Cnt X))
            ("reset" () (zero Cnt)) )
          ^(rest) ) ) ) )
-> d!-with-state

(d!-with-state "inc" 7)
-> 7

(d!-with-state "inc" 3)
-> 10

(d!-with-state "dec" 5)
-> 5

(d!-with-state "reset")
-> 0
```

### The Pandoric Macros
> The idea behind [the Pandoric Macros] is to _open closures_, allowing their otherwise closed-over lexical variables to be accessed externally.
>
> -- Let Over Lambda (p. 189)

The [Pandoric Macros](https://letoverlambda.com/index.cl/guest/chap6.html#sec_7)
are some of my favorite from Let Over Lambda.

### plambda
`p!` is the PL translation of `plambda`. A plambda is basically a "dlambda with state", with a little "inter-closure protocol" bolted on.

>#### a note on implementation differences
>PicoLisp and Common Lisp are very different languages. Due to the differences of scoping / binding and extent, we use PicoLisp's `job` environments to mimic lexical scope and indefinate extent, as found in Common Lisp. `:keyword` symbols are used in Common Lisp to dispatch different plamda actions. PicoLisp doesn't have those, so `"transient"` symbols are used instead.

```
# two different ways to p!

# as a read macro within a @-args function
: (de ptest1 @
   `(let Cnt 0
      (p! (X) (Cnt)
         (inc 'Cnt X) ) ) )
-> ptest1

# as an anonymous p!... unless you name it with 'def' or 'setq'
: (setq ptest2
   (let Cnt 0
      (*p! (X) (Cnt)
         (inc 'Cnt X) ) ) )
-> (@ (job '((Cnt . 0) ...) ( ... )))  # what the what?!

: (pretty ptest2)
-> (@ ...)
```
A `p!` form is a simply a `@`-args function (closure?) that contains a `job` environment whose variables can be accessed via `"getp"` and `"setp"`. `d!` is responsible for dispatching on variable access, or defaults to applying the plambda function (`This` anaphor, captured by `p!` during `job` environment creation) to the arguments it was passed.
```
: (do 3 (ptest1 3))
-> 9

: (do 2 (ptest2 13))
-> 26

: (ptest1 "getp" 'Cnt)
-> 9

: (ptest2 "setp" 'Cnt 8)
-> 8

: (ptest2 3)
-> 11

: (ptest2 "getp" 'Cnt)
-> 11

: (ptest2 "getp" 'This)
-> ((X) (inc 'Cnt X))

# recode the function
: (ptest2 "setp" 'This '((X) (dec 'Cnt X)))
-> ((X) (dec 'Cnt X))

# now it decrements the count
: (ptest2 3)
-> 8
```

### with-p!
`with-p!` is the PL translation of `with-pandoric`. `with-p!` allows to access variables within a p! environment/closure.
```
: (with-p! (Cnt) ptest2
   (setp Cnt 37) )
-> 37

: (ptest2 4)
-> 33

# recode function from anywhere
: (with-p! (This) ptest2
   (setp This '((X Y) (inc 'Cnt (* X Y)))) )  # increment count by product of two numbers
-> ((X Y) (inc 'Cnt (* X Y)))

: (ptest 4 5)
-> 53
```
`with-p!` is a PL `macro` that "expands" into a `let` statement. The let-bindings are created by `with-p!-env`. `with-p!-env` uses the `make` / `link` idiom to build a list of variables gathered from the supplied plambda form. `with-p!-env` also injects the anaphors `Self` and `setp` so we can conveniently access and modify the plambda closure.

In case you haven't read the entirety of On Lisp and Let Over Lambda yet, here's the crash course in Anaphora.

> In natural language, an anaphor is an expression which refers back in the conversation. The most common anaphor in English is probably “it,” as in “Get the wrench and put it on the table.” Anaphora are a great convenience in everyday language [...] but they don’t appear much in programming languages. For the most part, this is good. Anaphoric expressions are often genuinely ambiguous, and present-day programming languages are not designed to handle ambiguity.
>
> However, it is possible to introduce a very limited form of anaphora into Lisp programs without causing ambiguity. An anaphor, it turns out, is a lot like a captured symbol. We can use anaphora in programs by designating certain symbols to serve as pronouns, and then writing macros intentionally to capture these symbols.
>
> -- On Lisp (p. 189-190)

Don't be afraid - as PicoLisp programmers, we are used to anaphora in our programs! `@` serves as an anaphor for many of the flow and logic functions. In most cases, the `@` result can be translated to English as "it."
```
   # read a file line by line
   (in "file.txt"
      (while (line)        # is there another line?
         (process @) ) )   # process it
```

So `with-p!` captures the symbols `Self` and `setp`, and binds them to the current plambda form and `setp` function, respectively, so they can be used as pronouns (and verbs).

>#### another note on implementation differences
>In Let Over Lambda the `Self` anaphor is captured by the `plambda` macro, as opposed to the PL version where it's captured by the `with-p!` macro. The treatment of pandoric variables is very different between the two versions. In Let Over Lambda, `defsetf` and `setf` are used to set generalized  variables. This doesn't make sense for PicoLisp, so `setp` was created.

`setp` serves as the pandoric complement to `setq`.

`setp`, the symbol captured by `with-p!`, is, as far as I can tell, the PicoLisp equivalent of a symbol-macro, like those created in Common Lisp with `symbol-macrolet`. If we look at the code for `with-p!-env`, the symbol `setp` is bound to a literal copy of a function `set-with-p!`. Looking at the code for `set-with-p!`, we can see that it is a macro that "expands" to a `(Self "setp" ...)` call. Remember that `Self` is the anaphor for the current plambda closure of `with-p!`.

Something like the following happens as we descend through the layers of macros.
```
   (with-p! (Cnt) ptest2
      (setp Cnt 37) )

   # 'with-p!' captures 'Self', so the 'setp' symbol-macro expands into

   (Self "setp" 'Cnt 37)

   # which is a regular plambda call

   (ptest2 "setp" 'Cnt 37)

   # which is just a dlambda with state

   ((@ (job '((Cnt . 9) (This . ((X) ...))) (d! ("setp" ...) ...))) (list "setp" 'Cnt 37))

   # which is just a function that dispatches on it args

   (apply '((Sym Val) (set Sym Val)) (list 'Cnt 37))

   # to (in this case) update the state (contained in a 'job' enviroment)

   (set 'Cnt 37)
```

Note that because `setp` expects the anaphor `Self` to be in its calling environment, it can only be used within `with-p!` (and `with-p!s`) forms.

### with-p!s
`with-p!s` is an extension of `with-p!` that takes the concept of "anaphor capture and injection" to the next level. `with-p!s` allows multiple plambda closures to be accessed within a single call.

```
# access duplicate parameters with [Var]$[N] anaphora
: (with-p!s [ (Cnt) ptest1
              (Cnt) ptest2 ]
      (list Cnt$1 Cnt$2) )
-> (9 53)

# P![N] anaphora for the listed plambda closures
: (with-p!s [ (Cnt) ptest1
              (Cnt) ptest2 ]
      (list
         (P!1 1)        # increment count of ptest1
         (P!2 2 3) )    # increment count of ptest2 by 6 (* 2 3)
-> (10 59)

# This[N] anaphora to access functions within the listed plambda closures
: (with-p!s [ (This) ptest1
              (This) ptest2 ]
      # swap closure functions
      (setp This1 This2)
      (setp This2 This1) )
-> ((X) (inc 'Cnt X))

: (ptest1 4 5)          # increment count of ptest1 by 20 (* 4 5)
-> 30

: (ptest2 1)            # increment conte of ptest2
-> 60
```
Like `with-p!` and `with-p!-env`, the heavy lifting for `with-p!s` is done by the function `with-p!s-env`. `with-p!s-env` processes its args to create a giant let binding with a bunch of handy anaphors included. It mostly serves as an example of what can be done with anaphors and how we can use lisp to create our own programming constructs with any behavior we can imagine. The `with-p!s-env` source code has helpful comments, if you're interested in the specifics of the implementation.


### pm
Let's be real here - underneath the plambdas and the macros and the anaphora, what we're really doing is creating yet another way of object oriented programming in lisp. Just what the world needs! Let's take it all the way.

`pm` is the PL translation `defpan`. It allows to define pandoric methods that operate on any plambda closure that exposes the right variables. Let's say we have an important calculation that needs to be periodically done on our counters.
```
: (pm important-calculation () (Cnt) (* Cnt 7))
-> important-calculation

: (important-calculation ptest1)
-> 210

: (important-calculation ptest2)
-> 420
```
Internally, `pm` is a macro that wraps a `with-p!` form in a `de` form. Note that `pm` is not a true nested macro because the inner `macro` call is evaluated when it is placed  in the outer `macro`s "expansion".

### typ!
`typ!` allows to create new (proto)types of pandoric objects.
```
# the canonical "shapes" example
: (typ! p-rectangle
      X Y DX DY )
-> p-rectangle
```
`typ!` is a macro-writing macro. Behold the awe-inspiring nested macros in the definition! :exploding_head: `typ!` calls expand into `de` call that is itself a `macro` that, when called, will expand into a plambda form with all the variable slots filled in. This becomes clear when we look at the expansion of the above `(typ! p-rectangle ...)` call.
```
   # 'typ!' expansion
   (de p-rectangle (X Y DX DY)
      (macro!
         (let [X  _ X      # coords
               Y  _ Y
               DX _ DX     # width
               DY _ DY]    # height
            (*p! () (X Y DX DY))) ) )
```
So now we a function `p-rectangle` that when called, creates a rectangle object (which is really just a plambda form). Let's create a p-rectangle.
```
: (def 'pr1 (p-rectangle 0 0 5 10))
-> pr1
```
This call expands into
```
   (def 'pr1
      (let [X 0 Y 0 DX 5 DY 10]
         (*p! () (X Y DX DY)) ) )
```
a plambda form (with no `This` function). We can add p-rectangle methods with `pm`.
```
: (pm coords () (X Y)
   (list X Y) )
-> coords

# NOTE - 'setp' and 'self' are available in 'pm' methods
# because 'pm' is just a wrapper over 'with-p!'
: (pm move (A B) (X Y)
   (prog
      (setp X (+ X A))
      (setp Y (+ Y B))
      (coords Self) ) )
-> move

: (pm area () (DX DY)
   (* DX DY) )
-> area

: (pm perimeter () (DX DY)
   (* 2 (+ DX DY)) )
-> perimeter
```
And now we can play with pandoric rectangles!
```
: (move pr1 7 8)
-> (7 8)

: (move pr1 3 -9)
-> (10 -1)

: (area pr1)
-> 50
```
With all the pieces of our new closure / object oriented programming system in place, we're ready to build a toy language.

### LOLFORTH
Unfortunately, I'm not going to explain the LOLFORTH implementation as thoroughly as the previous code. The final chapter of [Let Over Lambda](https://letoverlambda.com/) is just that. If you've enjoyed this so far, consider buying Doug's Book. It's super cool. I'll leave you with a teaser quote that offers a brief explanation of the forth programming language. The text has been [tweaked] as needed to reflect the PicoLisp version we are discussing here.

> One of the characteristic features of forth is its direct access to the stack data structures used by your program both to pass parameters to subroutines and to keep track of your execution because - unlike most programming languages - it separates these two uses of the stack data structure into two stacks you can fool with. In a typical C implementation, the parameters of a function call and its so-called _return address_ are stored it a single, variable-sized _stack frame_ for every function invocation. In forth, they are two different stacks called the parameter stack and the return stack, which are represented as our abstract registers `pstack` and `rstack`. We use the  PicoLisp functions `push` and `pop`, meaning these stacks are implemented with cons cell linked lists [...].
>
> The abstract register `pc` is an abbreviation for _program counter_, a pointer to the code we are currently executing. [...]
>
> Another building block of forth is its concept of a _dictionary_. The forth dictionary is a singly linked list of forth _words_, which are similar to lisp functions. Words are represented with a [pandoric `typ!`]. [...] The [`Name`] slot is for a symbol used to lookup the word in the dictionary. Notice that the forth dictionary is not stored alphabetically, but instead chronologically. When we add new word we append them onto the end of the dictionary so that when we traverse the dictionary the latest defined words are examined first. The last element of our dictionary is always stored in the abstract register `dict`. To traverse the dictionary, we start with `dict` and follow the [`Prev`] pointer of the word structures, which either point to the previously defined word or to [`NIL`] if we are at the last word.
>
> -- Let Over Lambda (p. 287-288)

But I will show you how to use LOLFORTH. First we need a forth image to work with, created with `new-forth`.
```
: (def 'F (new-forth))
-> F
```
`go-forth` is the macro that drives our interaction with our forth interpreter.
```
: (go-forth F           # the forth image
      2 3 * print )     # the forth code
6                       # prints 6
-> ok                   # and we're done
```
So what happened? Let's do it again in slow-motion. First we push two numbers onto the parameter stack.
```
: (go-forth F 2 3)
-> 3
```
Remember that our forth image `F` is a massive plambda closure, so we can inspect its content.
```
: (F "getp" 'pstack)
-> (3 2)
```
Just as we expected.
```
: (go-forth F *)
-> ok

: (F "getp" 'pstack)
-> (6)
```
The forth word `*` pops two parameters from the pstack, multiplies them and pushes the result back on the pstack.
```
: (get-forth-thread F '*)
-> (NIL (push 'pstack (* (pop 'pstack) (pop 'pstack))) (setq pc (cdr pc)))

: (go-forth F print)
6
-> ok
```
The function `get-forth-thread` will return the code that is executed when the given forth word is encountered. `get-forth-words` will list the forth words in the current forth image's `dict`.
```
: (get-forth-words F)
-> (tuck 2drop nip ...)
```
New forth words can be added to a forth image with the words `:`, `;` and `name`.
```
: (go-forth F
   : dup * ; 'square name )
-> ok

: (go-forth F 8 square print)
64
-> ok

: (go-forth F
   : square square ; 'quartic name )
-> ok

: (go-forth F
   8 quartic print )
4096
-> ok

: (pretty (get-forth-thread F 'square))

# slightly reformatted for easier parsing
(
   (NIL                             # 'dup' thread
      (push 'pstack (car pstack))
      (setq pc (cdr pc)) )
   (NIL                             # '*' thread
      (push 'pstack
         (* (pop 'pstack) (pop 'pstack)) )
      (setq pc (cdr pc)) ) )

: (pretty (get-forth-thread F 'quartic))
(
   (                                            # first 'square' thread
      (NIL
         (push 'pstack (car pstack))
         (setq pc (cdr pc)) )
      (NIL
         (push 'pstack
            (* (pop 'pstack) (pop 'pstack)) )
         (setq pc (cdr pc)) ) )
   (                                            # second 'square' thread
      (NIL
         (push 'pstack (car pstack))
         (setq pc (cdr pc)) )
      (NIL
         (push 'pstack
            (* (pop 'pstack) (pop 'pstack)) )
         (setq pc (cdr pc)) ) ) )
```
The flow of code/data through our forth interpreter is something like the following.
```
   # 'go-forth' is a convenience macro wrapper

   (go-forth F . Words)                       <---
                                                  \
   # the forth image is a plambda form            |
                                                  |
   (F Word)                                       |
                                                  |
   # which looks up the forth word in the         |
   # 'dict'                                       |
                                                  | loop until program counter
   (forth-lookup Word)                            | and the return stack are both
                                                  | empty
   # which triggers either                        |
                                                  |
   (handle-found) | (handle-not-found)            |
                                                  |
   # which either compiles in a forth word        |
   # to the current thread and/or continues       |
   # on with forth execution                      |
                                                  /
   (forth-compile-in) | (forth-inner-interpreter)
```

And now for the grand finale!
```
: (go-forth F
   : begin
         dup 1 < if drop exit then
         dup print
         1 -
      again
   ; 'countdown name )
-> ok

: (go-forth F 5 countdown)
5
4
3
2
1
-> ok

# same but different
: (go-forth F
   : begin
         dup 1 >= if
            dup print
            1 -
            |_ swap _| again
         then
      drop
   ; 'countdown-for-teh-hax0rz name )
-> ok

: (go-forth F 5 countdown-for-teh-hax0rz)
5
4
3
2
1
-> ok
```
You are now an expert at lisp _and_ forth meta-programming :exploding_head:

There's a bunch of other code that I'll quickly mention. Macros to write forth primitives so we can bootstrap a forth standard library and continue adding new words in forth, some fancy lisp macros to convert lisp functions to forth words so we don't have to do too much work, code to install the primitives and standard library to the forth image, etc.

The best part?
```
: F
-> ... giant wall of text ...

: (pretty F)
-> ... another giant wall of spaced out text ...
```
Now scroll up a bit... and scroll some more - as mentioned before, the _entire_ LOLFORTH system is one giant `job` environment / closure. Even better - the forth `dict` is a singly linked list of these job environments / closures. One forth word points to the previous, chains of words nested to hell and back, held together by a bunch of ridiculous macros. And somehow it all works. :rofl: :rofl: :rofl:
