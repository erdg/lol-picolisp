## The Gist of It
Layers and layers of macros that implement a lispy version of the FORTH programming language, the internals of which are completely ridiculous.

### Utilities
The file starts with a few utility functions.

'macro!' offers a non-splicing complement to `^` in 'macro'. NOTE - this has nothing to do with the impressive `defmacro!` from Let Over Lambda.
```
: (macro! (let X _(+ 2 3) (* X X))) )
-> 25
```
It uses a naive code walker to look for underscore characters and insert the result of evaluating the following list in its place. It does this by transforming `_( ... )` to `^(list ( ... ))` and passing it to `macro`. `macro` then splices _that_ in, but it was `list`ed, so the net effect is 'placing' and not 'splicing'. So `macro!` rewrites the code that is passed to it so that `macro` understands it, all for a bit of syntax sugar. Sure makes the code look sweet though lol.

`groups-of` (`group` from PG's On Lisp) and `flat` (the PicoLisp version of
`flatten` from On Lisp) are pretty self explanatory.
```
: (groups-of 2 '(1 2 3 4 5 6))
-> ((1 2) (3 4) (5 6))

: (flat '(1 2 (3 4 (5)) 6))
-> (1 2 3 4 5 6)
```

The function `\\` is the [sharp-backquote](https://letoverlambda.com/index.cl/guest/chap6.html#sec_2)
read macro from Let Over Lambda.
```
: (macro!
     '(let _(mapcan '`(\\ (@1 @2)) '(A B C) (1 2 3))
        (do-something) ) )
-> (let (A 1 B 2 C 3) (do something))
```
While this is a convoluted example for such a simple result, `\\` allows some very cool techniques used in LOLFORTH later.

### Dlambda
`d!` is [dlambda](https://letoverlambda.com/index.cl/guest/chap5.html#sec_7)
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
`p!` is the PL translation of `plambda`. A 'plambda' is basically a "dlambda with state", with a little "interclosure protocol" bolted on.

>#### a note on implementation differences
>PicoLisp and Common Lisp are very different languages. Due to the differences of scoping / binding and extent, we must use PicoLisp's `job` environments to mimic lexical scope with indefinate extent, as found in Common Lisp. But when it comes down to it, both `plambda` and `p!` create reusable chunks of code with lexical variables that can be exported to the global environment and consumed as needed via `with-pandoric` / `with-p!` and `with-p!s`. Also note that `:keywords` are used in Common Lisp to dispatch different plamda actions. PicoLisp doesn't have those, so transient symbols are used instead, eg. `"keyword"`.

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
-> (@ (job '((Cnt . 0)) ( ... )))  # what the what?!

: (pretty ptest2)
-> (@ ...)
```
A `p!` form is a simply a `@`-args function (closure?) that contains a `job` environment whose variables can be accessed via `"getp"` and `"setp"`. `d!` is responsible for dispatching on variable access, or defaults to applying the 'p!' function (`This` anaphor, captured by `p!` during `job` environment creation) to the arguments it was passed.
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
`with-p!` is a PL `macro` that "expands" into a `let` statement. The let-bindings are created by `with-p!-env`. `with-p!-env` uses the `make` / `link` PL idiom to build a list of variables gathered from the supplied plambda form. `with-p!-env` also injects the anaphors `Self` and `setp` so we can conveniently access and modify the plambda closure.

In case you haven't read the entirety of On Lisp and Let Over Lambda, here's the crash course in Anaphora.

>In natural language, an anaphor is an expression which refers back in the conversation. The most common anaphor in English is probably “it,” as in “Get the wrench and put it on the table.” Anaphora are a great convenience in everyday language [...] but they don’t appear much in programming languages. For the most part, this is good. Anaphoric expressions are often genuinely ambiguous, and present-day programming languages are not designed to handle ambiguity.  However, it is possible to introduce a very limited form of anaphora into Lisp programs without causing ambiguity. An anaphor, it turns out, is a lot like a captured symbol. We can use anaphora in programs by designating certain symbols to serve as pronouns, and then writing macros intentionally to capture these symbols.
> -- On Lisp (p. 189-190)

So `with-p!` captures the symbols `Self` and `setp`, and binds them to the current plambda form and `setp` function, respectively, so they can be used as pronouns (and verbs).

>#### another note on implementation differences
>In Let Over Lambda the `Self` anaphor is captured by the `plambda` macro, as opposed to the PL version where it's captured by the `with-p!` macro. The treatment of pandoric variables is very different between the two versions. In Let Over Lambda, `defsetf` and `setf` are used to set generalized  variables. This doesn't make sense for PicoLisp, so `setp` was created.

`setp` serves as the pandoric complement to `setq`

`setp`, the symbol captured by `with-p!`, is, as far as I can tell, is the PicoLisp equivalent of a symbol-macro, like those created in Common Lisp with `symbol-macrolet`. If we look at the code for `with-p!-env`, the symbol `setp` is bound to a literal copy of a function `set-with-p!`. Looking at the code for `set-with-p!`, we can see that it is a macro that "expands" to a `(Self "setp" ...)` call. Remember that `Self` is the anaphor for the current plambda closure of `with-p!`. So the above
```
   (with-p! (Cnt) ptest2
      (setp Cnt 37) )
```
is eventually executed as
```
   (ptest2 "setp" 'Cnt 37)
```
Note that because `setp` needs the anaphor `Self` to be in its "expansion", it can only be used within `with-p!` (and `with-p!s`) forms.

#### with-p!s
`with-p!s` is an extension of `with-p!` that takes the concept of
"anaphor capture and injection" to the next level.

#### pm
`pm` is `defpan`.

#### typ!
`typ!` is a macro-writing macro that allows to create new types of pandoric
objects. This was my own creation and really puts the "LOL" in "LOLFORTH".

### LOLFORTH
