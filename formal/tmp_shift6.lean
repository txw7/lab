import Formal.DeclarativeCore
namespace Test
open DeclarativeCore

example (k : Nat) : shift 1 k addValue = addValue := by
  have h4 : 0 < k + 1 + 1 + 1 + 1 := Nat.succ_pos (k + 1 + 1 + 1)
  simp [addValue, natTy, succTerm, shift, shiftIndex, h4]

end Test
