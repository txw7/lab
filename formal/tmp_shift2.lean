import Formal.DeclarativeCore

namespace Test
open DeclarativeCore

example (k : Nat) : shift 1 k addValue = addValue := by
  simp [addValue, shift, shiftIndex]

end Test
