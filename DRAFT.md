# dont care

## except


custom exception types and handling mechanism based on:
- https://peterme.net/labelled-exceptions-for-smoother-error-handling.html
- https://nim-lang.org/araq/quirky_exceptions.html

features:
- function calls that can throw can be tagged using `|>` or `!>`
- tagged exceptions are pre-allocated
- uses quirky exceptions (a certain core developer will be very happy)

rationale:
- usability :: tagged exceptions enhance Nim's error handling story by allow users to "fine-tune" their raises by checking which proc threw an exception while keeping it
  convenient to use, a massive boost in productivity and an amazing feat that brings exceptions closer to rust-style `Result` typing that would be use for similar
  purposes of "error fine-tuning". While `Result` would force users to handle every error explicitly, tagged exceptions only enforce handling procs that were tagged,
  procs that arent are simply under the `NoLabel` tag, yet still handled as if the user would use normal exceptions.

- performance :: tagged exceptions can be preallocated, if any of `-d:preallocEC`, `{.push preallocEC.}` is set then raised exceptions reuse existing global buffers
  in order to save a heap allocation, which can be useful for many usecases: deterministic memory usage, 

next-gen, blazingly fast, iterator based std/sequtils alternative

this module reimplements popular functional utilities like map or filter as iterators which allows you 
to chain them with inline iterators like items, lines, keys/values, etc...
the iterators are inplace by d
in the future, it will also offers view and sink based slicing which reuse buffers and lambdas that can inline and stack allocate.

rationale:
there are many advantages in using functions instead of plain for-loops to work on containers but the support for
the functional paradigm in Nim is in my opinion, pretty subpar and i believe Nim deserves a better story, the issues:
- the sequtils module does not compose well, `iterable[T]` only compose with templates while map and co are procs so you cannot do `mySeq.items.filter(xxx)`
- it's also a performance footgun, each operation allocates and you often end up with worse performance than in python!
- by rewriting our functional friends to accept and return iterators, we can avoid allocating memory and choose the return type 
- the most popular functional programming library on Nim is zero-functional, the issue with it is that 
credit: 
beef331, timotheecour, swrge
downsides: 
unlike the standard implementation, this API is a bit more limited and you also pay a price for using it:      
- you cannot use `sugar.=>`
- there is no anaphoric templates like `mapIt; filterIt; xxxIt` (but you can make your own)
- massive amounts of templates and macros, your compile time will *suffer*.  
to replace `sugar.=>`, a `=>` is provided instead which offers better compatibility with generics and is zero-cost (inlined and stack based)
anaphoric templates are not provided because they are not typical in the functional world, 
users wanting to go the functional way in Nim are expected to use the `=>` syntax instead as part of the Principle of Least Surprise.
notes: 
- the `=>` syntax is not standalone
- side-effect free operation is not guaranteed
- use `dup` to avoid in-place function chaining, which is re-exported by this module
relevant compiler issue: https://github.com/nim-lang/RFCs/issues/397w
taken from beef: https://github.com/beef331/slicerator/blob/master/src/slicerator/itermacros.nim
modified to use timothee's zero-cost lambdas which have been modernized
TODO: 
- implement view-based slicing

