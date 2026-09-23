import Formal.DeclarativeCore

namespace Test
open DeclarativeCore

example (k : Nat) : shift 1 k addValue = addValue := by
  have h1 : 0 < k + 1 := Nat.succ_pos _
  have h2 : 0 < k + 1 + 1 := by
    exact Nat.succ_pos _
  have h3 : 0 < k + 1 + 1 + 1 := by
    exact Nat.succ_pos _
  have h4 : 0 < k + 1 + 1 + 1 + 1 := by
    exact Nat.succ_pos _
  simp [addValue, shift, shiftIndex, h1, h2, h3, h4]

end Test
