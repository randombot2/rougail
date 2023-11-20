# rougail

## Overview

This is a collection of utilities, mostly taken from other people's codes and then modified to suit my needs. This also allows my applications to have as few dependencies as possible, which is always a plus. Some of the code in this library are prone to become their own Nimble packages or upsteamed as contributions in the future.

I try to closely follow these principles: 

- Credit the original code authors.
- Modernize the code, add comments and make it more manageable, etc...
- Follow the zero-overhead principle: "don't pay for what you don't use". 
- Prioritize high-performance libraries and efficient templates/macros.

## Features

`rougail` is my personal library that encompass my vision of Nim's future, all the latest, hypest and greatest tech that I could find at the moment have been incorporated in it.
I also try to not rely on Nimble too much and use `git clone` for vendoring. Of the many things in this library, the most notable ones are:

- std/json API-compatible, `simdjson` based json de/serialiasation with the possibility to turn the json parser into a `JsonNode` when needed.
- Composable, zero-cost iterators and lambdas that are inlined and can be turned into closures at will that can express powerful FP idioms.
- Preallocated, tagged exceptions that has all the advantages of `Result` and convenience of `try/except` at minimal cost.
- CPS based `async/await` and `Future[T]` based on `io_uring` and `nim-sys`.


## Credits

- [mratsim](https://github.com/mratsim) for making the [constantine](https://github.com/mratsim/constantine) threadpool.
- [beef331](https://github.com/beef331) for making [slicerator](https://github.com/beef331/slicerator) and for his work in the Nim compiler
- [PMunch](https://github.com/PMunch/) for [optionutils](https://github.com/PMunch/nim-optionsutils)

and more ...