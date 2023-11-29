## extended/customized std/option and nim-result adapted from rust (mostly) with sink optimizations.
## 

{.push raises: [], inline.}

import macros, std/genasts
import ../typedefs


type
  Result*[T, E] = object  
    case has: bool
    of false:
      e: E
    of true:
      v: T
  


# ----- Internal Helpers ----- #

template defstr(def, orelse: string): string =
  if def.len == 0:
    orelse
  else:
    def

proc fatalResult*(m: string) {.noreturn, noinline.} =
  raise (ref UnpackDefect)(msg: m)


template assertOk*(self: Result) =
  mixin raiseResultDefect
  if not self.has:
    when self.E isnot void:
      raiseResultDefect("Trying to access a result value with err", self.e)
    else:
      raiseResultDefect("Trying to access a result value with err")

template withAssertOk(self: Result, body: untyped): untyped =
  mixin raiseResultDefect
  case self.has
  of false:
    raiseResultDefect("Trying to access a result value with err")    
  else:
    body

proc replace[T](dest: var T, src: sink T): T =
  ## like `swap` but returns the swapped value 
  # TODO: 
  # - should go in some other module
  swap(dest, src)
  result = dest



#####/////////////////////////#####
#####////// Result API //////#####
#####/////////////////////////#####


# ----- Basic API ----- #



proc isOk*(self: Result): bool = 
  self.has

proc ok*[T, E](R: typedesc[Result[T, E]]; val: sink T): Result[T, E] =
  ## Return a result with a success and value.
  ## Example: `Result[int, string].ok(42)`
  R(has: true, v: val)

proc ok*[_, E](R: typedesc[Result[void, E]]): Result[void, E] =
  ## Return a result as success.
  R(has: true)

proc ok*[_, E](self: var Result[void, E]) =
  ## Set a result to success.
  ## Example: `result.ok()`
  self = ok[void, E](typeof(self))

proc ok*[T, E](self: var Result[T, E]; val: sink T) =
  ## Set the result to success and update value.
  ## Example: `result.ok(42)`
  self = ok[T, E](typeof(self), val)



proc isErr*(self: Result): bool = 
  self.has.not

proc err*[T, E](R: typedesc[Result[T, E]]; err: sink E): Result[T, E] =
  ## Return a result with an error.
  ## Example: `Result[int, string].err("uh-oh")`
  R(has: false, e: err)

proc err*[T, _](R: typedesc[Result[T, void]]): Result[T, void] =
  ## Return a result as error.
  R(has: false)

proc err*[T, _](self: var Result[T, void]) =
  ## Set the result as an error
  ## Example: `result.err()`
  self = err[T, void](typeof(self))

proc err*[T, E](self: var Result[T, E]; err: sink E) =
  ## Set the result as an error.
  ## Example: `result.err("uh-oh")`
  self = err[T, E](typeOf(self), err)




proc get*[T: not void, E](self: Result[T, E]): lent T =
  ## Fetch value of result if set, or raise Defect
  if self.has:
    result = self.v
  else:
    raise newException(UnpackDefect, "Can't obtain a value from a error")

proc get*[T: not void, E](self: var Result[T, E]): var T =
  ## Fetch value of result if set, or raise Defect
  if self.has:
    return self.v
  else:
    raise newException(UnpackDefect, "Can't obtain a value from a error")

proc get*[T: not void, E](self: Result[T, E], otherwise: T): lent T =
  ## Fetch value of result if set, or raise Defect
  if self.has:
    result = self.v
  else:
    result = otherwise

proc get*[T: not void, E](self: var Result[T, E], otherwise: T): var T =
  ## Fetch value of result if set, or raise Defect
  if self.has:
    return self.v
  else:
    return otherwise


# ----- Generic Combinators ----- #

proc map*[T, R, E](
    self: sink Result[T, E]; 
    fn: Callable[T, R]
  ): Result[R, E] {.effectsOf: fn.} =
  case self.has
  of true:
    when R is void:
      fn(self.val)
      result.ok()
    else:
      result.ok fn(self.val)
  of false:
    when E is void:
      result.err()
    else:
      result.err self.err

proc map_or*[T, R: not void, E](
    self: sink Result[T, E]; 
    fn: Callable[T, R];
    default: R
  ): R {.effectsOf: fn.} =
  case self.has
  of true:  fn(self.val)
  of false: default

proc map_or_else*[T, R, E](
    self: sink Result[T, E];
    fn: Callable[T, R];
    default: Callable[void, R]
  ): R {.effectsOf: fn.} =
  case self.has
  of true:  fn(self.val)
  of false: default()

proc `or`*[T, E: not void](self, res: sink Result[T, E]): Result[T, E] =
  case self.has
  of true:  self
  of false: res

proc or_else[T, E](
    self: sink Result[T, E];
    cb: Callable[T, Result[T, E]]
  ): Result[T, E] {.effectsOf: cb.} = 
  case self.has
  of true:  self
  of false: cb(self.err)

proc `and`*[T, E: not void](self, res: sink Result[T, E]): Result[T, E] =
  case self.has
  of true:  res
  of false: self

proc and_then*[T, R, E](
    self: sink Result[T, E];
    fn: Callable[T, Result[R, E]]
  ): Result[R, E] {.effectsOf: fn.} =
  case self.has
  of true:
    when R is void:
      return fn()
    else:
      return fn(self.val)
  of false:
    when E is void:
      result.err()
    else:
      result.err(self.err)


# ---- Exceptions ---- #
func unpackRaise[E](e: E; s: string): UnpackError[E] {.noinline, nimcall.} =
  ## capturing ResultError...
  UnpackError[E](error: e, msg: s)


template toException[E](err: E): UnpackError[E] =
  mixin `$`
  mixin unpackRaise
  when compiles($err):
    unpackRaise(err, "Result isErr: " & $err)
  else:
    unpackRaise(err, "Result isErr")

template raiseResultError[T, E](self: Result[T, E]) =
  mixin toException
  mixin err
  when E is ref Exception:
    if self.error.isNil: # for example Result.default()!
      raise ResultError[void](msg: "Result isErr; no exception.")
    else:
      raise self.error
  else:
    raise self.error.toException

proc expect*[T, E](self: sink Result[T, E], m: string): lent T {.raises:[UnpackDefect], discardable.} =
  case self.has
  of true:
    when T isnot void:
      self.val
  of false:
    raise (ref UnpackDefect)(msg: m)

#[
proc tryValue*[T, E](self: sink Result[T, E], m: sink string = ""): lent T {.raises:[UnpackError], discardable.} =
  ## Like `expect`, but raises a `CatchableError` instead of a `Defect`
  case self.has
  of true:
    when T isnot void:
      self.val
  of false:
    when E is ref Exception:
      if self.err.isNil:
        raise (ref UnpackError[void])(msg: defstr(m, "Trying to access value with err (nil)"))
      else:
        raise self.err
    elif 
    
template tryCatch*(body: typed): Result[type(body), ref CatchableError] =
  ## Catch exceptions for body and store them in the Result
  type R = Result[type(body), ref CatchableError]
  try:
    when type(body) is void:
      body
      R.ok()
    else:
      R.ok(body)
  except CatchableError as e:
    R.err(e)
]#


# --- Operators --- #

func `==`*(a, b: Result): bool {.inline.} =
  if a.has == b.has:
    if a.has: return a.v == b.v
    else:     return a.e == b.e
  else:
    false

proc `$`*[T: not void; E](self: Result[T, E]): string =
  ## Returns string representation of `self`
  if self.has: "Ok(" & $self.v & ")"
  else: "Err(" & $self.e & ")"

proc `$`*[E](self: Result[void, E]): string =
  ## Returns string representation of `self`
  if self.has: "Ok()"
  else: "Err(" & $self.e & ")"



#####/////////////////////////#####
#####////// Option API ///////#####
#####/////////////////////////#####
from std/options import Option, isSome, isNone, get, none, some, `==`, `$`
export Option, isSome, isNone, get, none, some, `==`, `$`
import std/importutils; privateAccess(Option);



# ----- Generic Combinators and other FP utilities ----- #

proc map*[T, U](self: sink Option[T], cb: Callable[T, U]): Option[U] {.effectsOf: cb.} =
  ## Applies a `cb` function to the value of the `Option` and returns an `Option` containing the new value.
  case self.isSome
  of true:  some[U](cb(self.val))
  of false: none(U)

proc map_or*[T, R](self: sink Option[T],
    cb: Callable[T, R];
    default: R
  ): R {.effectsOf: cb.} =
  ## Returns the provided default result (if none), or applies a function to the contained value (if any).
  case self.isSome
  of true:  cb(self.val)
  of false: default

proc map_or_else*[T, R](self: sink Option[T];
    cb: Callable[T, R];
    default: Callable[void, R]
  ): R {.effectsOf: cb.} =
  ## Computes a default function result (if none), or applies a different function to the contained value (if any).
  case self.isSome
  of true:  cb(self.val)
  of false: default()

proc `or`*[T](self, opt: sink Option[T]): Option[T] =
  ## Returns `self` if it contains a value, otherwise returns `opt`.
  case self.isSome
  of true:  self
  of false: opt
  
proc `xor`*[T](self, opt: sink Option[T]): Option[T]  =
  ## Returns some(T) if exactly one of `self` and `opt` isSome() is true, otherwise returns none(T).
  if self.isSome and opt.isNone:
    result = self
  elif self.isNone and opt.isSome:
    result = opt
  else:
    result = none(T)

proc or_else[T](self: sink Option[T], cb: Callable[void, Option[T]]): Option[T] {.effectsOf: cb.} = 
  ## Returns `self` if it contains a value, otherwise calls `cb` and returns it's result.
  case self.isSome
  of true:  self
  of false: cb()

proc `and`*[T](self, opt: sink Option[T]): Option[T] =
  ## Returns `None` if `self` is `None`, otherwise returns `opt`.
  case self.isSome
  of true:  opt
  of false: none T

proc and_then*[T, R](self: sink Option[T], cb: Callable[T, Option[R]]): Option[R] {.effectsOf: cb.} =
  ## A renamed version of the std/option's `flatMap` where `self` and the argument of `cb` can be consumed.
  ## If the `Option` has no value, `none(R)` will be returned.
  mixin flatten
  flatten self.map(cb)

proc filter*[T](self: sink Option[T], cb: Callable[T, bool]): Option[T] {.effectsOf: cb.} =
  ## Returns None if the option is None, otherwise calls predicate with the wrapped value and returns:
  ## - Some(T) if predicate returns true (where t is the wrapped value), and
  ## - None if predicate returns false.
  if self.isSome and not cb(self.val):
    result = none(T)
  else:
    result = self

proc flatten*[T](self: Option[Option[T]]): Option[T] =
  case self.isSome
  of true:  self.val
  of false: none(T)

proc zip*[T; R](self: sink Option[T], opt: sink Option[R]): Option[(T, R)] =
  if self.isSome and opt.isSome:
    some (self.val, opt.val)
  else: 
    none typedesc[(T, R)]

proc unzip*[T; R](self: sink Option[(T, R)]): (Option[T], Option[R]) =
  if self.isSome:
    (self.val[0], self.val[1])
  else:
    (none(T), none(R))

proc take*[T](self: sink Option[T]): Option[T] =
  ## Takes the value out of the option, leaving a None in its place.
  ## is a no-op if `self` is already `None`
  replace(result, none(T))

proc take_if*[T](self: sink Option[T], pred: Callable[T, bool]): Option[T] =
  case self.isSome and pred(self.val)
  of true:  take(self)
  of false: self

proc expect*[T](self: sink Option[T], m = ""): T {.raises:[UnpackDefect], discardable.} =
  ## Returns the contained some(value), consuming the self value. This is like `get` but more handy.
  ## - If the value is a none(T) this function panics with a message.
  ## - `expect` should be used to describe the reason you expect the Option should be Some.
  case self.isSome
  of true:
    self.val
  of false:
    raise (ref UnpackDefect)(msg: m)



#####/////////////////////////#####
#####//    sanity checks    //#####
#####/////////////////////////#####
when isMainModule:
  echo some("stuff").expect("works")
  

