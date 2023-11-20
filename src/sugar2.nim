import std/macros
import std/[sugar, with] 


template dup*[T](val: sink T, calls: varargs[untyped]): T =
    ## Turns an `in-place`:idx: algorithm into one that works on
    ## a copy and returns this copy, without modifying its input.
    ##
    ## This macro also allows for (otherwise in-place) function chaining.
    var dupResult = val
    dupResult.with(calls)
    dupResult


macro `as`*(forLoop: ForLoopStmt): untyped =
    ## named for-loops that can be `break`able
    ## credits: elegantbeef
    let name = forLoop[^2][^1]
    result = forLoop.copyNimTree
    result[^2] = result[^2][^2]
    result = newBlockStmt(name, result)
    

proc `!`*[T](a, b: sink T): BranchPair[T] {.inline.} = BranchPair[T](then: a, otherwise: b)

template `?`*[T](cond: bool; p: BranchPair[T]): T =
  (if cond: p.then else: p.otherwise)
