import Formal.DeclarativeCore
namespace Test
open DeclarativeCore

example (k : Nat) : 0 < k + 1 + 1 + 1 + 1 := by
  exact Nat.succ_pos (k + 1 + 1 + 1)

example (k : Nat) : shift 1 (k + 1 + 1 + 1 + 1) (CoreTerm.var 0) = CoreTerm.var 0 := by
  have h : 0 < k + 1 + 1 + 1 + 1 := Nat.succ_pos (k + 1 + 1 + 1)
  simp [shift, shiftIndex, h]

end Test
