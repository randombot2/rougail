## extended/customized std/option adapted from rust (mostly)
## 

{.push raises: [], inline.}

import macros, std/genasts
import ../typedefs

#####/////////////////////////#####
#####/////// typedefs ////////#####
#####/////////////////////////#####

type
    UnpackDefect* = object of Defect
  
    ResultError*[E] = object of ValueError
      err*: E
  
    Result*[T, E] = object  
      case has: bool
      of false:
        when E is not void: 
          err: E
        else: discard
      of true:
        when T is not void: 
          val: T
        else: discard

    Option*[T] = Result[T, void] # Custom Optional type: it's just a `Result` alias. can be converted to the "real" Option


#####/////////////////////////#####
#####// option/result impl ///#####
#####/////////////////////////#####

####### result api ########
template ok*[T: not void, E](R: type Result[T, E], x: T): R =
  ## Initialize a result with a success and value
  ## Example: `Result[int, string].ok(42)`
  R(has: true, val: x)

template ok*[E](R: type Result[void, E]): R =
  ## Initialize a result with a success and value
  ## Example: `Result[void, string].ok()`
  R(has: true)

template ok*[T: not void, E](self: var Result[T, E], x: typed) =
  ## Set the result to success and update value
  ## Example: `result.ok(42)`
  self = ok(type self, x)

template ok*[E](self: var Result[void, E]) =
  ## Set the result to success and update value
  ## Example: `result.ok()`
  self = (type self).ok()

template ok*(v: auto): auto = 
  ok(typeof(result), v)

template ok*(): auto = 
  ok(typeof(result))

template err*[T; E: not void](R: type Result[T, E], x: typed): R =
  ## Initialize the result to an error
  ## Example: `Result[int, string].err("uh-oh")`
  R(has: false, err: x)

template err*[T](R: type Result[T, cstring], x: string): R =
  ## Initialize the result to an error
  ## Example: `Result[int, string].err("uh-oh")`
  const s = x # avoid dangling cstring pointers
  R(has: false, err: cstring(s))

template err*[T](R: type Result[T, void]): R =
  ## Initialize the result to an error
  ## Example: `Result[int, void].err()`
  R(has: false)

template err*[T; E: not void](self: var Result[T, E], x: untyped) =
  ## Set the result as an error
  ## Example: `result.err("uh-oh")`
  self = err(type self, x)

template err*[T](self: var Result[T, cstring], x: string) =
  const s = x # Make sure we don't return a dangling pointer
  self = err(type self, cstring(s))

template err*[T](self: var Result[T, void]) =
  ## Set the result as an error
  ## Example: `result.err()`
  self = err(type self)

template err*(v: auto): auto = 
  err(typeof(result), v)

template err*(): auto = 
  err(typeof(result))

func value*[T, E](self: Result[T, E]): lent T {.inline.} =
  ## Fetch value of result if set, or raise Defect
  ## Exception bridge mode: raise given Exception instead
  ## See also: Option.get
  case self.has
  of true:
    when T isnot void:
      self.val
    else: discard
  of false:
    raise (ref UnpackDefect)(msg: "Trying to unpack a Result which doesn't have a value")

proc value*[T: not void, E](self: var Result[T, E]): var T {.inline.} =
  ## Fetch value of result if set, or raise Defect
  ## Exception bridge mode: raise given Exception instead
  ## See also: Option.get
  case self.has
  of true:
      result = (addr self.val)[]
  of false:
    raise (ref UnpackDefect)(msg: "Trying to unpack a Result which doesn't have a value") 

template isOk*(self: Result): bool = 
  self.has

template isErr*(self: Result): bool = 
  self.has.not



####### option api ########
proc isSome*[T](self: Option[T]): bool {.inline.} = self.isOk
proc isNone*[T](self: Option[T]): bool {.inline.} = self.isErr

proc some*[T](val: sink T): Option[T] {.inline.} =
  ## Returns an `Option` that has the value `val`.
  Option[T](has: true, val: val)

proc none*(T: typedesc): Option[T] {.inline.} =
  ## Returns an `Option` for this type that has no value.
  discard

proc none*[T]: Option[T] {.inline.} =
  ## Alias for `none(T) <#none,typedesc>`_.
  none(T)

template get*[T, E](self: Result[T, E]): lent T =
  mixin value
  self.value

proc `==`*[T, E](a, b: Result[T, E]): bool {.inline.} =
  when T is SomePointer:
    a.val == b.val 
  else:
    (a.isSome and b.isSome and a.val == b.val) or (a.isNone and b.isNone)


#####/////////////////////////#####
#####// Generic Combinators //#####
#####/////////////////////////#####


proc map*[T, E, R](self: sink Result[T, E], cb: Callable[T, R]): Result[R, E] {.effectsOf: cb.} =
  ## Applies a `cb` function to the value of the `Option` and returns an `Option` containing the new value.
  case self.isSome
  of true:  result.ok(cb(self.get))
  of false: none(R)

proc map_or*[T, R](self: sink Option[T], default: R, cb: Callable[T, R]): R {.effectsOf: cb.} =
  ## Returns the provided default result (if none), or applies a function to the contained value (if any).
  case self.isSome
  of true:  cb(self.get)
  of false: default

proc map_or_else*[T, R](self: sink Option[T], default: Callable[void, R], cb: Callable[T, R]): R {.effectsOf: cb.} =
  ## Computes a default function result (if none), or applies a different function to the contained value (if any).
  case self.isSome
  of true:  cb(self.get)
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
  of true:  self.get
  of false: none(T)

proc zip*[T; R](self: sink Option[T], opt: sink Option[R]): Option[(T, R)] =
  case (self.isSome, opt.isSome)
  of (true, true): some (self.get, opt.unsafGet)
  else: none (T, R)

proc unzip*[T; R](self: sink Option[(T, R)]): (Option[T], Option[R]) =
  if self.isSome:
    (self.get[0], self.get[1])
  else:
    (none(T), none(R))

#####//////////////////////////////////////////////////////#####
#####// Boolean operations on the values, eager and lazy //#####
#####//////////////////////////////////////////////////////#####

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


#####/////////////////////////#####
#####//  dot-like chaining  //##### // might need to patch that, i mean wdf
#####/////////////////////////#####

# converter toBool*(option: ExistentialOption[bool]): bool =
#   Option[bool](option).isSome and Option[bool](option).get
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
#           newCall(bindSym("get"), opt), firstBarren[0])
#         break
#       firstBarren = firstBarren[0]
#   else:
#     injected = nnkDotExpr.newTree(
#       newCall(bindSym("get"), opt), firstBarren)
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
#####// optional operators  //#####
#####/////////////////////////#####




proc `|?`*[T](option: sink Option[T], fallback: sink T): T  =
  ## Use the `|?` operator to supply a fallback value when an Option does not hold a value.
  if option.isSome:
    option.get()
  else:
    fallback



#####/////////////////////////#####
#####//         etc         //#####
#####/////////////////////////#####

proc replace[T](dest: var T, src: sink T): T =
  ## like `swap` but returns the swapped value 
  # TODO: should go in some other module
  swap(dest, src)
  result = dest
  

proc expect*[T](self: sink Option[T], m = ""): T {.raises:[UnpackDefect], discardable.} =
  ## Returns the contained some(value), consuming the self value. This is like `get` but more handy.
  ## - If the value is a none(T) this function panics with a message.
  ## - `expect` should be used to describe the reason you expect the Option should be Some.
  if self.isSome:
    self.get
  else:
    raise (ref UnpackDefect)(msg: m)

proc take*[T](self: sink Option[T]): Option[T] =
  ## Takes the value out of the option, leaving a None in its place.
  ## is a no-op if `self` is already `None`
  replace(result, none(T))

# proc take_if*[T](self: sink Option[T], pred: Callable[T, bool]): Option[T] =
#   case self.isSome

  
  
  
  


#####/////////////////////////#####
#####//    sanity checks    //#####
#####/////////////////////////#####
when isMainModule:
  echo some("stuff").expect("works")