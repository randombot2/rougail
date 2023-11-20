import typedefs
import std/[genasts, enumerate]
import std/macros 

#var place = block:
#    var mem = zerodefault(Place)
#    for i, x in enumerate mem.tagged.mitems:
#        new(x)
#        mem.unused.incl(i)
#    move mem

#proc rc*(exception: (ref CatchableError)): int =
#  ## i have no clue what the following obscure rc hack is about
#  cast[ptr RefHeader](cast[uint64](exception) - uint64(sizeof(pointer)) - uint64(sizeof(RefHeader)))[].rc
#
#proc desym(n: NimNode) =
#  for i, x in n:
#    if x.kind == nnkSym:
#      n[i] = ident($x)
#    else:
#      desym(x)
#
#macro replaceRaise{raise constr}(constr: typed) =
#  let constr = constr[1]
#  echo constr.treeRepr
#  let baseConstr = constr.copyNimTree()
#  baseConstr[0] = newCall("typeof", postfix(nnkObjConstr.newTree(baseConstr[0]), "[]"))
#  desym(baseConstr)
#  echo baseConstr.treeRepr
#  result = genast(baseConstr,theType = constr[0], constr):
#    {.noRewrite.}:
#      when sizeof(theType()[]) <= sizeof(RCachableError):
#        var exception: (ref CatchableError)
#        for x in place.unused:
#          exception = (ref CatchableError)(place.tagged[x])
#        if exception != nil:
#          let 
#            refTyp = default(typeof(constr))
#            typInfo = refTyp.getTypeInfo()
#            base = baseConstr
#          copyMem(cast[pointer](cast[uint64](exception) - uint64 sizeof(pointer)), typInfo.addr, sizeof(pointer))
#          copyMem(cast[pointer](exception), base.addr, sizeof(base))
#          raise theType(exception)
#        else:
#          for i, x in place.tagged:
#            if i notin place.unused:
#              echo rc((ref CatchableError)(x))
#          raise constr
#      else:
#        raise constr
#  echo result.repr
#



macro buildEnum(x: static seq[string]): untyped =
  result = nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      newIdentNode("Label"),
      newEmptyNode(),
      nnkEnumTy.newTree(
        newEmptyNode(),
        newIdentNode("NoLabel")
      )
    )
  )
  for label in x:
    result[0][2].add newIdentNode(label)

macro Try*(body: untyped, branches: varargs[untyped]): untyped =
  {.hint[XDeclaredButNotUsed]:off.}
  let
    labels = genSym(nskVar)
    raisedLabel = genSym(nskVar)
    
  
  result = genast(labels, raisedLabel):
    block:
      var
        labels {.compileTime.}: seq[string]
        raisedLabel = -1
  
  let res = genast(raisedLabel, labels, body):
      template tryAndLabel(talBody, idx: untyped): untyped =
        try:
          talBody
        except:
          raisedLabel = idx
          raise
        
      macro label(x, labBody: untyped): untyped =
        var idx = labels.find(x.strVal)
        if idx == -1:
          idx = labels.len
          labels.add x.strVal
        getAst(tryAndLabel(labBody, idx))
      template `!>`(pBody, x: untyped): untyped = 
        label(x, pBody)
      body
  
  result[1].add nnkTryStmt.newTree(res)
  
  for branch in branches:
    var branch = branch
    var labelDefs = genast(labels, raisedLabel):
      buildEnum(labels)
      
      template getLabel(): untyped =
        Label(raisedLabel + 1)  

    branch[^1].insert(0, labelDefs)
    result[1][^1].add branch
  


