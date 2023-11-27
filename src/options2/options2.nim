## extended/customized std/option adapted from rust (mostly)
## 

{.push raises: [], inline.}

import macros, std/genasts
import ../typedefs


# ----- Internal Helpers ----- #


proc fatalResult*(m: string) {.noreturn, noinline.} =
  raise (ref UnpackDefect)(msg: m)

template assertOk*(self: Result) =
  if not self.isOk:
    when self.E isnot void:
      raiseResultDefect("Trying to access value with err Result", self.err)
    else:
      raiseResultDefect("Trying to access value with err Result")

proc replace[T](dest: var T, src: sink T): T =
  ## like `swap` but returns the swapped value 
  # TODO: should go in some other module
  swap(dest, src)
  result = dest



#####/////////////////////////#####
#####////// Result API //////#####
#####/////////////////////////#####


# ----- Basic API ----- #


proc isOk*(self: Result): bool = 
  self.has
  
proc isErr*(self: Result): bool = 
  not self.has

proc `$`*[T: not void; E](self: Result[T, E]): string =
  ## Returns string representation of `self`
  if self.isOk: "Ok(" & $self.val & ")"
  else: "Err(" & $self.err & ")"

proc `$`*[E](self: Result[void, E]): string =
  ## Returns string representation of `self`
  if self.isOk: "Ok()"
  else: "Err(" & $self.err & ")"

proc ok*[T, E](R: type Result[T, E], val: T): R =
  ## Initialize a result with a success and value
  ## Example: `Result[int, string].ok(42)`
  return R(has: true, val: val)

proc ok*[T, E](self: var Result[T, E], val: T) =
  ## Set the result to success and update value
  ## Example: `result.ok(42)`
  self = ok(type self, val)

proc ok*(v: auto): auto = 
  return ok(typeof(result), v)

proc err*[T, E](R: type Result[T, E], err: T): R =
  ## Initialize the result to an error
  ## Example: `Result[int, string].err("uh-oh")`
  return R(has: false, err: err)

proc err*[T](R: type Result[T, cstring], str: string): R =
  ## Initialize the result to an error
  ## Example: `Result[int, string].err("uh-oh")`
  const s = str # ?
  R(has: false, err: cstring(s))

proc err*[T](R: type Result[T, void]): R =
  return R(has: false)

proc err*[T, E](self: var Result[T, E], err: E) =
  ## Set the result as an error
  ## Example: `result.err("uh-oh")`
  self = err(type self, err)

proc err*[T](self: var Result[T, cstring], str: string) =
  const s = str # Make sure we don't return a dangling pointer
  self = err(type self, cstring(s))

proc err*[T](self: var Result[T, void]) =
  ## Set the result as an error
  ## Example: `result.err()`
  self = err(type self)

proc err*(e: auto): auto = 
  return err(typeof(result), e)


proc unsafeGet*[T, E](self: var Result[T, E]): var T =
  ## Fetch value of result if set, undefined behavior if unset
  ## See also: Option.unsafeGet
  assert isOk(self)
  result = self.val

proc unsafeGet*[T, E](self: Result[T, E]): lent T =
  ## Fetch value of result if set, undefined behavior if unset
  ## See also: Option.unsafeGet
  assert isOk(self)
  result = self.val

proc val*[T: not void, E](self: Result[T, E]): lent T =
  ## Fetch value of result if set, or raise Defect
  assertOk(self)
  self.val

proc val*[T: not void, E](self: var Result[T, E]): var T =
  ## Fetch value of result if set, or raise Defect
  assertOk(self)
  self.val

proc expect*[T: not void, E](self: Result[T, E], m: string): lent T {.raises:[UnpackDefect], discardable.} =
  if self.isOk:
    self.val
  else:
    raise (ref UnpackDefect)(msg: m)



# ----- Generic Combinators ----- #

proc map*[T, R, E](
    self: sink Result[T, E]; 
    fn: Callable[T, R]
  ): Result[R, E] {.effectsOf: fn.} =
  case self.isOk
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
  case self.isOk
  of true:  fn(self.val)
  of false: default

proc map_or_else*[T, R, E](
    self: sink Result[T, E];
    fn: Callable[T, R];
    default: Callable[void, R]
  ): R {.effectsOf: fn.} =
  case self.isOk
  of true:  fn(self.val)
  of false: default()

proc `and`*[T, E: not void](self, res: sink Result[T, E]): Result[T, E] =
  case self.isOk
  of true:  res
  of false: self

proc and_then*[T, R, E](
    self: sink Result[T, E];
    fn: Callable[T, Result[R, E]]
  ): Result[R, E] {.effectsOf: fn.} =
  case self.isOk
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

proc `or`*[T, E: not void](self, res: sink Result[T, E]): Result[T, E] =
  case self.isOk
  of true:  self
  of false: res

proc or_else[T, E](
    self: sink Result[T, E];
    cb: Callable[T, Result[T, E]]
  ): Result[T, E] {.effectsOf: cb.} = 
  case self.isOk
  of true:  self
  of false: cb(self.err)




#####/////////////////////////#####
#####////// Option API ///////#####
#####/////////////////////////#####
from std/options import Option, isSome, isNone, get, none, some, `==`, `$`
export Option, isSome, isNone, get, none, some, `==`, `$`
import std/importutils; privateAccess(Option)



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
    none (T, R)

proc unzip*[T; R](self: sink Option[(T, R)]): (Option[T], Option[R]) =
  if self.isSome:
    (self.val[0], self.val[1])
  else:
    (none(T), none(R))

proc `and`*[T](self, opt: sink Option[T]): Option[T] =
  ## Returns `None` if `self` is `None`, otherwise returns `opt`.
  case self.isSome
    of true:  opt
    of false: none T

proc and_then*[T, R](self: sink Option[T], cb: Callable[T, Option[R]]): Option[R] {.effectsOf: cb.} =
  ## A renamed version of the std/option's `flatMap` where `self` and the argument of `cb` can be consumed.
  ## If the `Option` has no value, `none(R)` will be returned.
  flatten self.map(cb)

proc `or`*[T](self, opt: sink Option[T]): Option[T] =
  ## Returns `self` if it contains a value, otherwise returns `opt`.
  case self.isSome
  of true:  self
  of false: opt

proc or_else[T](self: sink Option[T], cb: Callable[void, Option[T]]): Option[T] {.effectsOf: cb.} = 
  ## Returns `self` if it contains a value, otherwise calls `cb` and returns it's result.
  case self.isSome
  of true:  self
  of false: cb()

proc `xor`*[T](self, opt: sink Option[T]): Option[T]  =
  ## Returns some(T) if exactly one of `self` and `opt` isSome() is true, otherwise returns none(T).
  if self.isSome and opt.isNone:
    result = self
  elif self.isNone and opt.isSome:
    result = opt
  else:
    result = none(T)

proc expect*[T](self: sink Option[T], m = ""): T {.raises:[UnpackDefect], discardable.} =
  ## Returns the contained some(value), consuming the self value. This is like `get` but more handy.
  ## - If the value is a none(T) this function panics with a message.
  ## - `expect` should be used to describe the reason you expect the Option should be Some.
  if self.isSome:
    self.val
  else:
    raise (ref UnpackDefect)(msg: m)

proc take*[T](self: sink Option[T]): Option[T] =
  ## Takes the value out of the option, leaving a None in its place.
  ## is a no-op if `self` is already `None`
  replace(result, none(T))

proc take_if*[T](self: sink Option[T], pred: Callable[T, bool]): Option[T] =
  case self.isSome and pred(self.val)
  of true:  take(self)
  of false: self

#####/////////////////////////#####
#####//  dot-like chaining  //##### // might need to patch that, i mean wdf
#####/////////////////////////#####

# converter toBool*(option: ExistentialOption[bool]): bool =
#   Option[bool](option).isSome and Option[bool](option).val
# 
# converter toOption*[T](option: ExistentialOption[T]): Option[T] =
#   Option[T](option)
# 
# proc toExistentialOption*[T](option: Option[T]): ExistentialOption[T] =
#   ExistentialOption[T](option)
# 
# proc toOpt*[T](value: sink Option[T]): Option[T] =
#   ## Procedure with overload to automatically convert something to an option if
#   ## it's not already an option.
#   value
# 
# proc toOpt*[T](value: sink T): Option[T] =
#   ## Procedure with overload to automatically convert something to an option if
#   ## it's not already an option.
#   some(value)
# 
# macro `?.`*[T](option: Option[T], statements: untyped): untyped =
#   let opt = genSym(nskLet)
#   var
#     injected = statements
#     firstBarren = statements
#   if firstBarren.kind in {nnkCall, nnkDotExpr, nnkCommand}:
#     # This edits the tree that injected points to
#     while true:
#       if firstBarren[0].kind notin {nnkCall, nnkDotExpr, nnkCommand}:
#         firstBarren[0] = nnkDotExpr.newTree(
#           newCall(bindSym("val"), opt), firstBarren[0])
#         break
#       firstBarren = firstBarren[0]
#   else:
#     injected = nnkDotExpr.newTree(
#       newCall(bindSym("val"), opt), firstBarren)
# 
#   result = quote do:
#     (proc (): auto  =
#       let `opt` = `option`
#       if `opt`.isSome:
#         when compiles(`injected`) and not compiles(some(`injected`)):
#           `injected`
#         else:
#           return toExistentialOption(toOpt(`injected`))
#     )()
    
  


#####/////////////////////////#####
#####//    sanity checks    //#####
#####/////////////////////////#####
when isMainModule:
  echo some("stuff").expect("works")

