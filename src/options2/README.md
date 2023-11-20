# options2 

Extention of the `std/options` API, bringing powerful rust-like combinators, `questionable` operators, and more in a single module.

## combinators

currently, the Nim ecosystem use a very limited usecase of `Option[T]`. The lack of combinators and the push for imperative coding in the Nim community has limited the full potential of optional types.

Using combinators allows the programmer to express powerful idioms which is inspired by rust's own API, using `sink` optimization for performance and Nim's friendly syntax and semantics for ease of use (eg. no need for `as_mut/as_ref` shenanigans).

## lifted operators



## new features:
- `Option[T]`
Optional types can be combined with the `options2` API for powerful and expressive chaining, specific overloads are made that returns `Option[T]` in order to support this usecase.


## more:
this module implements the `std/strutils` API and is therefore compatible with it, but it comes with additional utilities that can be used:

- `Stack Strings`
`string` in Nim is typically allocated on the heap, which allows flexible usage like resizing at runtime and reallocating if necessary which is convenient enough for normal usecases. This module includes the `stackstrings` nimble package which is basically sugar over `array[Size, char]`. This allows programmers to allocate strings on the stack just like they would with `string` which is faster than allocating on the heap but this mean the capacity of the stack is fixed and cannot be modified at runtime. Exceeding the capacity will crash the program so this must be used with great care, if used properly this can lead to some performance boosts.