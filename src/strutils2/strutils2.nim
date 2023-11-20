# https://github.com/fsh/strides

## 
## strutils reimplementation based on `openArray[char]`, `sink/lent`, `Option[T]`, whatever 👻 ...
import std/options

proc find*(s, sub: openArray[char]): int {.inline.} =
  ## Returns the first index of `item` in `a` or -1 if not found. This requires
  ## appropriate `items` and `==` operations to work.
  result = 0
  for i in items(a):
    if i == item: return
    inc(result)
  result = -1

func contains*(s, sub: openArray[char]): bool {.inline.} =
  ## Same as `find(s, sub) >= 0`.
  ##
  ## See also:
  ## * `find func<#find,string,string,Natural,int>`_
  result = find(s, sub) >= 0