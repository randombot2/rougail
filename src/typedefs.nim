
#### 
#### type definitions for rougail
#### 


#### 
#### Documentation :: Result
#### 




## Result equivalences with other types

# - `Result[void, void] == bool`:
# Neither value nor error information, it either worked or didn't. Most
# often used for procedures with side effects. Compatible with `bool`.

# - `Result[T, void] == Option[T]`:
# Returned a value if it worked, else tell the caller it failed. Most often
# used for simple computations. Compatible with `Option[T]`.

# - `Result[T, E]` where E is object or enum or cstring:
# Returned a value if it worked, or a statically known piece of information
# when it didn't - most often used when a function can fail in more than one way.

# `Result[T, ref E]`
#
# Returning a `ref E` allows introducing dynamically typed error
# information, similar to exceptions.











# ############################################################
#
#                        Constants
#
# ############################################################

const preallocEC* {.intdefine.}: int = 300

# ############################################################
#
#                        Concepts
#
# ############################################################

type          
    Addable* = concept var x, type T
      x.add(T)

    Includable* = concept var x, type T
      x.incl(T)
        
    Pushable* = concept var x, type T
      x.push(T)
    
    Iterable*[T] = concept c
      for x in items(c):  typeof(x) is T
      for x in mitems(c): typeof(x) is var T
      c.len is int
  
# ############################################################
#
#                        Typedefs
#
# ############################################################

when (NimMajor, NimMinor) >= (1, 1):
  type
    SomePointer* = ref | ptr | pointer | proc
else:
  type
    SomePointer* = ref | ptr | pointer

type
    Iterator*[T] = (iterator: T) or (iterator: lent T)


    Callable*[T; R] = (proc(x: sink T): R {.closure.}) | (proc(x: sink T): R {.nimcall.}) | (proc(x: sink T): R {.inline.}) 
    
    BranchPair*[T] = object
        then*, otherwise*: T

    ## Abstract class for all exceptions that can be tagged and preallocated.
    RCachableError* {.acyclic.} = object of CatchableError
        data*: array[sizeof(CatchableError) * 3, byte] # preallocated refs

    Place* = object
        tagged*: array[preallocEC, (ref RCachableError)]
        unused*: set[0..preallocEC] 

    RefHeader* = object # https://github.com/nim-lang/Nim/blob/devel/lib/system/arc.nim
        rc*: int
        when defined(gcOrc):
            rootIdx: int
        when defined(nimArcDebug) or defined(nimArcIds):
            refId: int







