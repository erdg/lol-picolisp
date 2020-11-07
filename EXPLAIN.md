### Utilities
The file starts with a few utility functions.

'macro!' offers the non-splicing complement to `^` in 'macro'.
```
: (macro! (let X _(+ 2 3) (* X X))) )
-> 25
```
```
: (macro!
     (macro!
        (let X _'_(+ 3 _(+ 4 5)) X) ) ) )
-> 12
```

'groups-of' ('group' from PG's On Lisp) and 'flat' (the PicoLisp version of
'flatten' from On Lisp) are pretty self explanatory.
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


### Dlambda
`d!` is [dlambda](https://letoverlambda.com/index.cl/guest/chap5.html#sec_7)

### Pandoric Macros
The [Pandoric Macros](https://letoverlambda.com/index.cl/guest/chap6.html#sec_7)
are some of my favorite from Let Over Lambda.

> The idea behind [the Pandoric Macros] is to _open closures_, allowing their otherwise closed-over lexical variables to be accessed externally.
>
> -- Let Over Lambda (p. 189)

`p!` is `plambda`

`with-p!` is `with-pandoric`

`with-p!s` is an extension of `with-pandoric` that takes the concept of
"anaphor capture and injection" to the next level.

`pm` is `defpan`.

`typ!` is a macro-writing macro that allows to create new types of pandoric
objects. This was my own creation and really puts the "LOL" in "LOLFORTH".

### LOLFORTH