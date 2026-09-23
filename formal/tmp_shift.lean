import Formal.DeclarativeCore

namespace Test
open DeclarativeCore

theorem test_shift_under (C a : CoreTerm) :
  shift 1 1 (instantiate C a) = instantiate (shift 1 2 C) (shift 1 1 a) := by
  unfold instantiate
  simp [shift]

end Test
