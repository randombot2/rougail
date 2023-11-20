## extended/customized std/option adapted from rust
## 

{.push raises: [], inline.}

from std/options import Option, UnpackDefect, isSome, isNone, some, none, get, unsafeGet
import macros, std/genasts
import typedefs

#####/////////////////////////#####
#####// Generic Combinators //#####
#####/////////////////////////#####

proc map*[T, U](self: sink Option[T], cb: Callable[T, U]): Option[U] {.effectsOf: cb.} =
  ## Applies a `cb` function to the value of the `Option` and returns an `Option` containing the new value.
  case self.isSome
  of true:  some[U](cb(self.unsafeGet))
  of false: none(U)

proc map_or*[T, U](self: sink Option[T], default: U, cb: Callable[T, U]): U {.effectsOf: cb.} =
  case self.isSome
  of true:  cb(self.unsafeGet)
  of false: default

proc map_or_else*[T, U](self: sink Option[T], default: U, cb: Callable[T, U]): U {.effectsOf: cb.} =
  case self.isSome
  of true:  cb(self.unsafeGet)
  of false: default

proc filter*[T](self: sink Option[T], cb: Callable[T, bool]): Option[T] {.effectsOf: cb.} =
  ## Returns None if the option is None, otherwise calls predicate with the wrapped value and returns:
  ## - Some(T) if predicate returns true (where t is the wrapped value), and
  ## - None if predicate returns false.
  if self.isSome and not cb(self.val):
    result = none(T)
  else:
    result = self


proc flatten*[T](self: Option[Option[T]]): Option[T] {.inline.} =
  case self.isSome
  of true:  self.unsafeGet
  of false: none(T)

proc zip*[T; U](self: sink Option[T], opt: sink Option[U]): Option[(T, U)] =
  case (self.isSome, opt.isSome)
  of (true, true): some (self.unsafeGet, opt.unsafGet)
  else: none (T, U)

proc unzip*[T; U](self: sink Option[(T, U)]): (Option[T], Option[U]) =
  if self.isSome:
    (self.unsafeGet[0], self.unsafeGet[1])
  else:
    (none(T), none(U))

#####//////////////////////////////////////////////////////#####
#####// Boolean operations on the values, eager and lazy //#####
#####//////////////////////////////////////////////////////#####

proc `and`*[T](self, opt: sink Option[T]): Option[T] =
  ## Returns `None` if `self` is `None`, otherwise returns `opt`.
  case self.isSome
    of true:  opt
    of false: none T

proc and_then*[T, U](self: sink Option[T], cb: Callable[T, Option[U]]): Option[U] {.effectsOf: cb.} =
  ## A renamed version of the std/option's `flatMap` where `self` and the argument of `cb` can be consumed.
  ## If the `Option` has no value, `none(U)` will be returned.
  flatten self.map(cb)

proc `or`*[T](self, opt: sink Option[T]): Option[T] =
  ## Returns `self` if it contains a value, otherwise returns `opt`.
  case self.isSome
    of true:  self
    of false: opt

proc or_else[T](self: sink Option[T], cb: Callable[T, bool]): Option[T] {.effectsOf: cb.} = discard "unimplemented"

proc `xor`*[T](self, opt: sink Option[T]): Option[T]  =
  ## Returns some(T) if exactly one of `self` and `opt` isSome() is true, otherwise returns none(T).
  if self.isSome and opt.isNone:
    result = self
  elif self.isNone and opt.isSome:
    result = opt
  else:
    result = none(T)


#####/////////////////////////#####
#####//  dot-like chaining  //#####
#####/////////////////////////#####

converter toBool*(option: ExistentialOption[bool]): bool =
  Option[bool](option).isSome and Option[bool](option).unsafeGet

converter toOption*[T](option: ExistentialOption[T]): Option[T] =
  Option[T](option)

proc toExistentialOption*[T](option: Option[T]): ExistentialOption[T] =
  ExistentialOption[T](option)

proc toOpt*[T](value: sink Option[T]): Option[T] =
  ## Procedure with overload to automatically convert something to an option if
  ## it's not already an option.
  value

proc toOpt*[T](value: sink T): Option[T] =
  ## Procedure with overload to automatically convert something to an option if
  ## it's not already an option.
  some(value)

macro `?.`*[T](option: Option[T], statements: untyped): untyped =
  let opt = genSym(nskLet)
  var
    injected = statements
    firstBarren = statements
  if firstBarren.kind in {nnkCall, nnkDotExpr, nnkCommand}:
    # This edits the tree that injected points to
    while true:
      if firstBarren[0].kind notin {nnkCall, nnkDotExpr, nnkCommand}:
        firstBarren[0] = nnkDotExpr.newTree(
          newCall(bindSym("unsafeGet"), opt), firstBarren[0])
        break
      firstBarren = firstBarren[0]
  else:
    injected = nnkDotExpr.newTree(
      newCall(bindSym("unsafeGet"), opt), firstBarren)

  result = quote do:
    (proc (): auto  =
      let `opt` = `option`
      if `opt`.isSome:
        when compiles(`injected`) and not compiles(some(`injected`)):
          `injected`
        else:
          return toExistentialOption(toOpt(`injected`))
    )()
    

#####/////////////////////////#####
#####// optional operators  //#####
#####/////////////////////////#####

template `!`*[T](option: Option[T]): T =
  ## Returns the value of an Option when you're absolutely sure that it
  ## contains value. Using `!` on an Option without a value raises a Defect.
  option.get

template `->?`*[T,U](option: Option[T], expr: Option[U]): Option[U] =
  if option.isSome:
    expr
  else:
    U.none

template `->?`*[T,U](option: Option[T], expr: U): Option[U] =
  option ->? expr.some

template `->?`*[T,U,V](options: (Option[T], Option[U]), expr: Option[V]): Option[V] =
  if options[0].isSome and options[1].isSome:
    expr
  else:
    V.none

template `->?`*[T,U,V](options: (Option[T], Option[U]), expr: V): Option[V] =
  options ->? expr.some


proc `|?`*[T](option: Option[T], fallback: T): T {.inline.} =
  ## Use the `|?` operator to supply a fallback value when an Option does not hold a value.
  if option.isSome:
    option.unsafeGet()
  else:
    fallback

#####/////////////////////////#####
#####//  lifted operators   //#####
#####/////////////////////////#####

Option.liftUnary(`-`)
Option.liftUnary(`+`)
Option.liftUnary(`@`)
Option.liftBinary(`[]`)
Option.liftBinary(`*`)
Option.liftBinary(`/`)
Option.liftBinary(`div`)
Option.liftBinary(`mod`)
Option.liftBinary(`shl`)
Option.liftBinary(`shr`)
Option.liftBinary(`+`)
Option.liftBinary(`-`)
Option.liftBinary(`&`)
Option.liftBinary(`<=`)
Option.liftBinary(`<`)
Option.liftBinary(`>=`)
Option.liftBinary(`>`)

#####/////////////////////////#####
#####//         etc         //#####
#####/////////////////////////#####

proc expect*[T](self: sink Option[T], m = ""): T {.raises:[UnpackDefect].} =
  ## Returns the contained some(value), consuming the self value. This is like `get` but more handy.
  ## - If the value is a none(T) this function panics with a message.
  ## - `expect` should be used to describe the reason you expect the Option should be Some.
  if self.isSome:
    result = self.unsafeGet
  else:
    raise (ref UnpackDefect)(msg = m)