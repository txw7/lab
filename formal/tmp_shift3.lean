import Formal.DeclarativeCore

namespace Test
open DeclarativeCore

example (k : Nat) : shift 1 k (succTerm (CoreTerm.var 0)) = succTerm (CoreTerm.var 0) := by
  have hk : 0 < k := by
    omega
  simp [succTerm, shift, shiftIndex, hk]

end Test
