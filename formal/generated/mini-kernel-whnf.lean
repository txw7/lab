import Formal.DeclarativeCore

open DeclarativeCore

namespace MiniKernelGeneratedWhnf

def reduceNatRec (args : List CoreTerm) : CoreTerm :=
  if args.length < 4 then
    List.foldl CoreTerm.app (CoreTerm.const ConstName.natRec) args
  else
    match args with
    | P :: z :: s :: n :: rest =>
        match whnf n with
        | CoreTerm.const ConstName.zero => List.foldl CoreTerm.app z rest
        | CoreTerm.app (CoreTerm.const ConstName.succ) k =>
            let recCall := List.foldl CoreTerm.app (CoreTerm.const ConstName.natRec) [P, z, s, k]
            whnf (List.foldl CoreTerm.app (CoreTerm.app (CoreTerm.app s k) recCall) rest)
        | n' => List.foldl CoreTerm.app (CoreTerm.const ConstName.natRec) (P :: z :: s :: n' :: rest)
    | _ => List.foldl CoreTerm.app (CoreTerm.const ConstName.natRec) args

def reduceEqRec (args : List CoreTerm) : CoreTerm :=
  if args.length < 6 then
    List.foldl CoreTerm.app (CoreTerm.const ConstName.eqRec) args
  else
    match args with
    | A :: a :: P :: pr :: rhs :: equality :: rest =>
        match whnf equality with
        | CoreTerm.app (CoreTerm.app (CoreTerm.const ConstName.refl) _) _ =>
            whnf (List.foldl CoreTerm.app pr rest)
        | equality' => List.foldl CoreTerm.app (CoreTerm.const ConstName.eqRec) (A :: a :: P :: pr :: rhs :: equality' :: rest)
    | _ => List.foldl CoreTerm.app (CoreTerm.const ConstName.eqRec) args

partial def whnf (t : CoreTerm) : CoreTerm :=
  match t with
  | CoreTerm.letE v A body => whnf (instantiate body v)
  | CoreTerm.app f a =>
      let rec collectApps : CoreTerm → List CoreTerm → CoreTerm × List CoreTerm
        | CoreTerm.app f a, args => collectApps f (a :: args)
        | head, args => (head, args)
      let (head, args) := collectApps t []
      let rec reduceHead : CoreTerm → List CoreTerm → CoreTerm
        | head, [] => head
        | CoreTerm.letE v A body, args => whnf (List.foldl CoreTerm.app (instantiate body v) args)
        | CoreTerm.lam A body, arg :: rest => whnf (List.foldl CoreTerm.app (instantiate body arg) rest)
        | CoreTerm.const ConstName.natRec, args => reduceNatRec args
        | CoreTerm.const ConstName.eqRec, args => reduceEqRec args
        | head, args => List.foldl CoreTerm.app head args
      reduceHead (whnf head) args
  | CoreTerm.const ConstName.add => whnf addValue
  | _ => t

partial def conv (ctx : Context) (lhs rhs : CoreTerm) : Bool :=
  match whnf lhs, whnf rhs with
  | CoreTerm.sort u, CoreTerm.sort v => u = v
  | CoreTerm.var k, CoreTerm.var l => k = l
  | CoreTerm.const c ls, CoreTerm.const c' ls' => c = c' && ls = ls'
  | CoreTerm.app f a, CoreTerm.app g b => conv ctx f g && conv ctx a b
  | CoreTerm.pi A B, CoreTerm.pi A' B' => conv ctx A A' && conv (A :: ctx) B B'
  | CoreTerm.lam A b, CoreTerm.lam A' b' => conv ctx A A' && conv (A :: ctx) b b'
  | _, _ => false

def checkSort (ctx : Context) (t : CoreTerm) : Nat :=
  match whnf (infer ctx t) with
  | CoreTerm.sort u => u
  | ty => panic! s!"expected sort, got {ty}"

partial def infer (ctx : Context) (t : CoreTerm) : CoreTerm :=
  match t with
  | CoreTerm.sort u => CoreTerm.sort (u + 1)
  | CoreTerm.var k => match lookup ctx k with | some A => A | none => panic! s!"unbound var {k}"
  | CoreTerm.const c ls => instantiateLevels (constType c) ls
  | CoreTerm.pi A B => CoreTerm.sort (max (checkSort ctx A) (checkSort (A :: ctx) B))
  | CoreTerm.lam A b => CoreTerm.pi A (infer (A :: ctx) b)
  | CoreTerm.app f a =>
      match whnf (infer ctx f) with
      | CoreTerm.pi A B => if check ctx a A then instantiate B a else panic! "argument type mismatch"
      | ty => panic! s!"application of non-function {ty}"
  | CoreTerm.letE v A body =>
      if check ctx v A then instantiate (infer (A :: ctx) body) v else panic! "let value type mismatch"

partial def check (ctx : Context) (t expected : CoreTerm) : Bool :=
  conv ctx (infer ctx t) expected

end MiniKernelGeneratedWhnf
