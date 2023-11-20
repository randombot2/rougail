import criterion
import std/strutils

proc atoi(s: cstring): cint {.importc, header: "<stdlib.h>".}

{.boundChecks:off.}
proc fastAtoi(str: cstring): int =
  var
    val = 0
    c: char
    i = 0
  while true:
    c = str[i]
    if c == '\0':
      break
    val = val * 10 + int(c) - int('0')
    inc i
  result = val
{.boundChecks:on.}

let cfg = newDefaultConfig()
benchmark(cfg):
  iterator bench(): (string, int) =
    yield ("0", 0)
    yield ("231", 231)
    yield ("123434093", 123434093)


  func atoi() {.measure.} =
    for val, expect in bench():
      let got = atoi(val)
      doAssert got == expect

  func custom_atoi() {.measure.} = # faster than atoi and parseInt with -d:danger and -d:release !
    for val, expect in bench():
      let got = fastAtoi(val)
      doAssert got == expect

  func from_strutils() {.measure.} =
    for val, expect in bench():
      let got = parseInt(val)
      doAssert got == expect
  