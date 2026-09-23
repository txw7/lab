import Formal.DeclarativeCore

namespace Test
open DeclarativeCore

example :
  shift 1 0 (instantiate (CoreTerm.lam natTy (CoreTerm.var 2)) (CoreTerm.var 0)) ≠
    instantiate (shift 1 1 (CoreTerm.lam natTy (CoreTerm.var 2))) (shift 1 0 (CoreTerm.var 0)) := by
  decide

end Test
