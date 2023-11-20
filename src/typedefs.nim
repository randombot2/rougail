from std/options import Option

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

const preallocEC* {.intdefine.}: int = 300

type
    Iterator*[T] = (iterator: T) or (iterator: lent T)

    ExistentialOption*[T] = distinct Option[T]

    Callable*[T; R] = (proc(x: sink T): R {.closure.}) | (proc(x: sink T): R {.nimcall.}) | (proc(x: sink T): R {.inline.}) 
    
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