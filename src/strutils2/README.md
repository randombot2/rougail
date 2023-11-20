# strutils2 

reimplementation based on `openArray[char]`, `sink/lent`, `Option[T]`, and more 👻 ...

## optimizations

- `openArray[T]`: 
also called a "slice" in other languages, it's a language feature that allow programmers to send collections like `seq/array/string` to procedures as zero-cost slices.
using them as proc arguments for `strutils` means reducing copies and should improve performance, but also reduce the need to duplicate procs that work on specific types which improves code maintainability.

- `sink/lent`: 
Nim's implementation of move semantics; annotating proc arguments and return values with `sink/lent` can improve performance further.


## new features:
- `Option[T]`:
Optional types can be combined with the `options2` API for powerful and expressive chaining, specific overloads are made that returns `Option[T]` in order to support this usecase.
- 

## more:
this module implements the `std/strutils` API and is therefore compatible with it, but it comes with additional utilities that can be used:
- `Stack Strings`:
`string` in Nim is typically allocated on the heap, which allows flexible usage like resizing at runtime and reallocating if necessary which is convenient enough for normal usecases. This module includes the `stackstrings` nimble package which is basically sugar over `array[Size, char]`. This allows programmers to allocate strings on the stack just like they would with `string` which is faster than allocating on the heap but this mean the capacity of the stack is fixed and cannot be modified at runtime. Exceeding the capacity will crash the program so this must be used with great care, if used properly this can lead to some performance boosts.