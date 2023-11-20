# NOTE: using balls seems to prevent compiling valid code somehow, investigate later

import ../vendor/balls/balls
import ../src/sequtils2
import strformat

import std/[options, tables, sets]

from std/strutils import isUpperAscii, isLowerAscii, toUpperAscii, split

const
  nums = [1,2,3,4,5]
  ints = [-2, -1, 1, 3, -4, 5]
  chars = ['a', '.', 'b', 'C', 'z', 'd']
  strs = ["foo", "BAR", "Niklaus", "deadbeef"]
  text = "Epicurus sought tranquility through simplicity and pleasure."

suite "Iterator adaptors":
  test "map":
    # abs is {.inline.}
    check ints.items.map(proc(x:int):int = abs(x)).collect() == @[2, 1, 1, 3, 4, 5]
    check chars.items.map(toUpperAscii).collect() == @['A', '.', 'B', 'C', 'Z', 'D']
    check strs.items.map(toUpperAscii).collect() == @["FOO", "BAR", "NIKLAUS", "DEADBEEF"]

    check ints.items.mapIt(abs(it)).collect() == @[2, 1, 1, 3, 4, 5]
    check chars.items.mapIt(char(it.ord + 1)).collect() == @['b', '/', 'c', 'D', '{', 'e']
    check strs.items.mapIt((var s = it; s.setLen(1); s)).collect() == @["f", "B", "N", "d"]

  test "filter":
    check ints.items.filter(proc(x:int):bool = x > 0).collect() == @[1, 3, 5]
    check chars.items.filter(proc(x:char):bool = x in {'a'..'z'}).collect() == @['a', 'b', 'z', 'd']
    check strs.items.filter(proc(x:string):bool = x.len == 3).collect() == @["foo", "BAR"]

    check ints.items.filterIt(it mod 2 == 0).collect() == @[-2, -4]
    check chars.items.filterIt(it notin {'a'..'d'}).collect() == @['.', 'C', 'z']
    check strs.items.filterIt(it.len > 7).collect() == @["deadbeef"]

  test "group":
    check ints.items.group(2).collect() == @[(-2, -1), (1, 3), (-4, 5)]
    # partial tails are dropped
    check ints.items.group(4).collect() == @[(-2, -1, 1, 3)]
    check chars.items.group(6).collect() == @[('a', '.', 'b', 'C', 'z', 'd')]

  test "skip":
    check ints.items.skip(3).collect() == @[3, -4, 5]
    check chars.items.skip(6).collect() == newSeq[char](0)
    check strs.items.skip(0).collect() == @strs

  test "skipWhile":
    #check ints.items.skipWhile(proc(x:int):bool = x < 0).collect() == @[1, 3, -4, 5] :::::::::::: TODO: skipWhile fails the test
    check ints.items.skipWhileIt(it < 0).collect() == @[1, 3, -4, 5]

 
test "take":
  check ints.items.take(3).collect() == @[-2, -1, 1]
  # more than items in the iterator
  check chars.items.take(6).collect() == @chars
  # take zero items
  check strs.items.take(0).collect() == newSeq[string](0)
test "takeWhile":
  check ints.items.takeWhile(proc(x:int):bool = x < 0).collect() == @[-2, -1]
  check ints.items.takeWhileIt(it < 0).collect() == @[-2, -1]
test "stepBy":
  check ints.items.stepBy(2).collect() == @[-2, 1, -4]
  # check text.items.stepBy(5).foldIt("", (acc.add(it); acc)) == "Ero qtr ly s" [foldIt doesnt make it compile]
  # first element is always returned
  check chars.items.stepBy(9000).collect() == @['a']
test "enumerate":
  check ints.items.enumerate.collect(seq[(int, int)]) == @[(0, -2), (1, -1), (2, 1), (3, 3), (4, -4), (5, 5)]
test "flatten":
  iterator splat(s: string): string = (for w in s.split(): yield w) # hack
  let wordEndBytes = text.splat.mapIt(it[^2..^1]).flatten().mapIt(ord(it).byte).collect(set[byte])
  check wordEndBytes == {46.byte, 100, 101, 103, 104, 110, 115, 116, 117, 121}

suite "Iterator consumers":
  test "fold":
    func appended(acc: sink seq[string]; it:int): seq[string] =
      result = acc
      result.add($it)
    proc grow(acc: var seq[string]; it:int) =
      acc.add($it)

    #check ints.items.fold(@["acc"], appended) == @["acc", "-2", "-1", "1", "3", "-4", "5"]
    #check ints.items.fold(@["acc"], grow) == @["acc", "-2", "-1", "1", "3", "-4", "5"]
    check chars.items.foldIt({'@'}, (acc.incl(it); acc)) == {'.', '@', 'C', 'a', 'b', 'd', 'z'}
    #let t = chars.items.enumerate.foldIt(initTable[char, int](), (acc[it[1]]=it[0]; acc))
    #check t['d'] == 5

  test "collect to seq":
    check ints.items.collect() == @ints
    check chars.items.collect() == @chars
    check strs.items.collect() == @strs

  test "collect to specific containers":
    check text.items.collect(set[char]) == {' ', '.', 'E', 'a', 'c', 'd', 'e', 'g', 'h', 'i', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'y'}
    check ints.items.collect(seq[int]) == @[-2, -1, 1, 3, -4, 5]
    check strs.items.collect(HashSet[string]) == toHashSet(strs)
    check chars.items.collect(string) == "a.bCzd"

  test "min-max":
    check ints.items.min() == -4
    check chars.items.min() == '.'
    check strs.items.min() == "BAR"

    check ints.items.max() == 5
    check chars.items.max() == 'z'
    check strs.items.max() == "foo"

  test "count":
    check ints.items.count() == 6
    check chars.items.count() == 6
    check strs.items.count() == 4

  test "sum":
    check ints.items.sum() == 2

  test "product":
    check ints.items.product() == -120

  test "any-all":
    check ints.items.anyIt(it > 1) == true
    check chars.items.anyIt(it.isUpperAscii)
    check chars.items.any(isLowerAscii)
    check chars.items.allIt(it in  {'.', 'C', 'a'..'z'})
    check chars.items.all(isLowerAscii) == false
    # empty iterator returns true
    check "".items.allIt(it == '!')

  test "find":
    check ints.items.find(proc(x:int):bool = x > 1) == some(3)
    check ints.items.findIt(it < -2) == some(-4)
    check strs.items.find(proc(x:string):bool = x.items.all(isUpperAscii)) == some("BAR")
    check strs.items.findIt(it == "Dijkstra").isNone()
    check chars.items.find(proc(x:char):bool = x.ord > 'y'.ord) == some('z')

  test "position":
    check ints.items.position(proc(x:int):bool = x > -1) == some(2)
    check ints.items.positionIt(it == 1) == some(2)
    check strs.items.position(proc(x:string):bool = x.items.all(isUpperAscii)) == some(1)
    check strs.items.positionIt(it == "Dijkstra").isNone()
    check chars.items.position(proc(x:char):bool = x.ord > 'y'.ord) == some(4)

  test "nth":
    check ints.items.nth(0) == some(-2)
    check chars.items.nth(6) == none(char)
    check strs.items.nth(1) == some("BAR")
    check text.items.enumerate.filterIt(it[1] in {'x'..'z'}).nth(0) == some((26, 'y'))

suite "Runnable Examples":
  block:
    ## [tmap]       map/mapIt semcheck
    check nums.items.mapIt(it * 2).collect() == @[2, 4, 6, 8, 10],
      fmt"result = {nums.items.group(3).collect}"

    check nums.items.map(proc(x: int): int = x * x).collect() == @[1, 4, 9, 16, 25],
      fmt"result = {nums.items.group(3).collect}"


  block:
    ## [tfilter]    filter/filterIt semcheck
    check nums.items.filterIt(it mod 2 == 0).collect() == @[2, 4],
      fmt"result = {nums.items.group(3).collect}"

    check nums.items.filter(proc(x: int): bool = x mod 2 == 0).collect() == @[2, 4],
      fmt"result = {nums.items.group(3).collect}"

  block:
    ## [tgroup]     group semcheck
    check nums.items.group(3).collect() == @[(1, 2, 3), (4, 5, 6)], 
      fmt"result = {nums.items.group(3).collect}"

  block:
    ## [tskip]      skip/skipWhile/skipWhileIt semcheck
    check nums.items.skip(2).collect() == @[3, 4, 5],
      fmt"result = {nums.items.group(3).collect}"

    check nums.items.skipWhile(proc(x: int): bool = x < 3).collect() == @[3, 4, 5],
      fmt"result = {nums.items.group(3).collect}"

    check nums.items.skipWhileIt(it < 3).collect() == @[3, 4, 5],
      fmt"result = {nums.items.group(3).collect}"


  block:
    ## [ttake]      take/takeWhile/takeWhileIt semcheck
    check nums.items.take(3).collect() == @[1, 2, 3]
    check nums.items.takeWhile(proc(x: int): bool = x < 4).collect() == @[1, 2, 3]
    check nums.items.takeWhileIt(it < 4).collect() == @[1, 2, 3]

  block:
    ## [tstepby]    stepby semcheck
    check nums.items.stepBy(2).collect() == @[1, 4, 5]

  block:
    ## [tenumerate] enumerate semcheck
    let letters = ["Alpha", "Beta", "Gamma"]
    check letters.items.enumerate().collect() == @[(0, "Alpha"), (1, "Beta"), (2, "Gamma")]

  block:
    ## [tflatten]  flatten semcheck
    let nested = [@[1, 2, 3], @[4, 5], @[6]]
    let flattened = nested.items.flatten.collect()
    check flattened == @[1, 2, 3, 4, 5, 6]

  block:
    ## [tfold]     fold semcheck
    var product = nums.items.fold(1, proc(acc: var int; it: int) = acc *= it)
    var sum = nums.items.foldIt(1, acc + it)
    var ssum = nums.items.fold(0, proc(acc: sink int; it: int): int = acc + it)
    check (product, sum, ssum) == (120, 16, 15)

  block:
    ## [tsum]      sum semcheck
    check nums.items.sum() == 15

  block:
    ## [tproduct]  product semcheck
    check nums.items.product() == 120

  block:
    ## [tany]      any/anyIt semcheck
    check nums.items.any(proc(x: int): bool = x > 3) == true
    check nums.items.anyIt(it > 3)
    check "".items.anyIt(it is char) == false

  block:
    ## [tall]      all/allIt semcheck   
    check nums.items.all(proc(x: int): bool = x < 10) == true
    check "".items.all(proc(x: char): bool = x == '!') == true
    check nums.items.allIt(it < 10) == true
    check "".items.allIt(it == '!') == true


  block:
    ## [tposition] position/positionIt semcheck
    check nums.items.position(proc(x: int): bool = x == 3) == some(2)
    check nums.items.positionIt(it == 4) == some(3)


  block:
    ## [tnth]      nth() semcheck 
    let thirdElement = nums.items.nth(2)
    check thirdElement == some(3)
    let sixthElement = nums.items.nth(5)
    check sixthElement.isNone()
  
  block:
    ## [tfind]     find/findIt semcheck
    check nums.items.find(proc(x: int): bool = x > 3) == some(4)
    check nums.items.findIt(it == 3) == some(3)


  block:
    ## [tcomplex1] Find the first element in a sequence of the transformed initial numbers that is bigger than 35.
    # Note: using `Slice[int].items` instead of `CountUp`.
    check (-25..25).items.mapIt(it * 10 div 7).findIt(it > 35) == none(int)

  block:
    ## [tcomplex2] Filter a table of philosophers by country of origin, compose a sentence and join each to a string.
    let philosophers: Table[string, string] = {
      "Plato": "Greece", "Aristotle": "Greece", "Socrates": "Greece",
      "Confucius": "China", "Descartes": "France"}.toTable()
    const phrase = "$1 is a famous philosopher from $2."

    let facts = philosophers.pairs()
                  .filterIt(it[1] != "Greece")
                  .mapIt([it[0], it[1]])
                  .mapIt(phrase % it)
                  .foldIt("", acc & it & '\n')

    check facts == """Confucius is a famous philosopher from China. Descartes is a famous philosopher from France."""

  block:
    ## [tcomplex3] Find expensive stocks, convert the company name to uppercase and collect to a custom container type.
    let stocks: Table[string, tuple[symbol:string, price:float]] = {
      "Pineapple": (symbol: "PAPL", price: 148.32),
      "Foogle": (symbol: "FOOGL", price: 2750.62),
      "Visla": (symbol: "VSLA", price: 609.89),
      "Mehzon": (symbol: "MHZN", price: 3271.92),
      "Picohard": (symbol: "PCHD", price: 265.51),
    }.toTable()

    let shoutExpensive = stocks.pairs()
                            .mapIt((name: it[0], price:it[1].price))
                            .filterIt(it.price > 1000.0)
                            .mapIt(it.name).map(toUpperAscii)
                            .collect(HashSet[string])

    check shoutExpensive == ["FOOGLE", "MEHZON"].toHashSet()