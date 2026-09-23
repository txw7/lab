import Formal.DeclarativeCore
namespace Test
open DeclarativeCore

-- helper theorem for the target in this file
 theorem test_shift_instantiate (C a : CoreTerm) :
  shift 1 0 (instantiate C a) = instantiate (shift 1 1 C) (shift 1 0 a) := by
  unfold instantiate
  induction C generalizing a <;> simp [shift, subst, Nat.succ_eq_add_one, shiftIndex]
  · -- var
    intro k
    by_cases hk : k = 0
    · subst hk
      simp [shift, shiftIndex]
    · have hk' : 0 < k := Nat.pos_of_ne_zero hk
      simp [subst, shift, hk, hk', Nat.succ_eq_add_one, shiftIndex]

