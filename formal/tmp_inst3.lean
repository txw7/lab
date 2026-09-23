import Formal.DeclarativeCore

namespace Test
open DeclarativeCore

 theorem test_shift_instantiate (C a : CoreTerm) :
  shift 1 0 (instantiate C a) = instantiate (shift 1 1 C) (shift 1 0 a) := by
  induction C generalizing a with
  | sort u =>
      simp [instantiate, shift, subst]
  | var k =>
      by_cases hk : k = 0
      · subst hk
        simp [instantiate, shift, subst, shiftIndex]
      · have hk' : 0 < k := Nat.pos_of_ne_zero hk
        simp [instantiate, shift, subst, hk, hk', shiftIndex]
  | const c =>
      simp [instantiate, shift, subst]
  | app C₁ C₂ ih₁ ih₂ =>
      simpa [instantiate, shift, subst] using And.intro (ih₁ a) (ih₂ a)
  | lam A t ihA iht =>
      have hA := ihA a
      have ht := iht a
      simpa [instantiate, shift, subst] using And.intro hA ht
  | pi A B ihA ihB =>
      have hA := ihA a
      have hB := ihB a
      simpa [instantiate, shift, subst] using And.intro hA hB
  | letE v A t ihv ihA iht =>
      have hv := ihv a
      have hA := ihA a
      have ht := iht a
      simpa [instantiate, shift, subst] using And.intro (And.intro hv hA) ht

end Test
