import Formal.DeclarativeCore

namespace Test
open DeclarativeCore

theorem test_shift_instantiate (C a : CoreTerm) :
  shift 1 0 (instantiate C a) = instantiate (shift 1 1 C) (shift 1 0 a) := by
  unfold instantiate
  induction C generalizing a with
  | sort u =>
      simp [subst, shift, shiftIndex]
  | var k =>
      by_cases hk : k = 0
      · subst hk
        simp [subst, shift, shiftIndex]
      · have hk' : 0 < k := Nat.pos_of_ne_zero hk
        simp [subst, shift, shiftIndex, hk, hk']
  | const c =>
      simp [subst, shift, shiftIndex]
  | app C₁ C₂ ih₁ ih₂ =>
      simpa [instantiate, shift, subst] using congrArg₂ CoreTerm.app (ih₁ a) (ih₂ a)
  | lam A t ihA iht =>
      have hA : shift 1 0 (subst 0 (shift 1 0 a) A) =
          subst 0 (shift 1 0 (shift 1 0 a)) (shift 1 1 A) := by
        simpa [shiftIndex] using ihA a
      have ht :
          shift 1 1
            (subst 1 (shift 1 0 (shift 1 0 a)) t) =
          subst 1 (shift 1 0 (shift 1 0 (shift 1 0 a))) (shift 1 2 t) := by
        simpa [shiftIndex] using (iht (shift 1 0 (shift 1 0 a)))
      simp [instantiate, shift, subst, hA, ht]
  | pi A B ihA ihB =>
      have hA : shift 1 0 (subst 0 (shift 1 0 a) A) =
          subst 0 (shift 1 0 (shift 1 0 a)) (shift 1 1 A) := by
        simpa [shiftIndex] using ihA a
      have hB :
          shift 1 1
            (subst 1 (shift 1 0 (shift 1 0 a)) B) =
          subst 1 (shift 1 0 (shift 1 0 (shift 1 0 a))) (shift 1 2 B) := by
        simpa [shiftIndex] using (ihB (shift 1 0 (shift 1 0 a)))
      simp [instantiate, shift, subst, hA, hB]
  | letE v A t ihv ihA iht =>
      have hv : shift 1 0 (subst 0 (shift 1 0 a) v) =
          subst 0 (shift 1 0 (shift 1 0 a)) (shift 1 1 v) := by
        simpa [shiftIndex] using ihv a
      have hA : shift 1 0 (subst 0 (shift 1 0 a) A) =
          subst 0 (shift 1 0 (shift 1 0 a)) (shift 1 1 A) := by
        simpa [shiftIndex] using ihA a
      have ht :
          shift 1 1 (subst 1 (shift 1 0 (shift 1 0 a)) t) =
          subst 1 (shift 1 0 (shift 1 0 (shift 1 0 a))) (shift 1 2 t) := by
        simpa [shiftIndex] using (iht (shift 1 0 (shift 1 0 a)))
      simp [instantiate, shift, subst, hv, hA, ht]

theorem test_shift_instantiate_under (C a : CoreTerm) :
  shift 1 1 (instantiate C a) = instantiate (shift 1 2 C) (shift 1 1 a) := by
  unfold instantiate
  induction C generalizing a with
  | sort u =>
      simp [subst, shift, shiftIndex]
  | var k =>
      by_cases hk : k = 0
      · subst hk
        simp [subst, shift, shiftIndex]
      · have hk' : 0 < k := Nat.pos_of_ne_zero hk
        simp [subst, shift, shiftIndex, hk, hk']
  | const c =>
      simp [subst, shift, shiftIndex]
  | app C₁ C₂ ih₁ ih₂ =>
      simpa [instantiate, shift, subst] using congrArg₂ CoreTerm.app (ih₁ a) (ih₂ a)
  | lam A t ihA iht =>
      have hA : shift 1 1 (subst 0 (shift 1 0 a) A) =
          subst 0 (shift 1 1 (shift 1 1 a)) (shift 1 2 A) := by
        simpa [shiftIndex] using ihA (shift 1 0 a)
      have ht :
          shift 1 2
            (subst 1 (shift 1 1 (shift 1 1 a)) t) =
          subst 1 (shift 1 1 (shift 1 1 (shift 1 1 a))) (shift 1 3 t) := by
        simpa [shiftIndex] using (iht (shift 1 1 (shift 1 0 a)))
      simp [instantiate, shift, subst, hA, ht]
  | pi A B ihA ihB =>
      have hA : shift 1 1 (subst 0 (shift 1 0 a) A) =
          subst 0 (shift 1 1 (shift 1 1 a)) (shift 1 2 A) := by
        simpa [shiftIndex] using ihA (shift 1 0 a)
      have hB :
          shift 1 2
            (subst 1 (shift 1 1 (shift 1 1 a)) B) =
          subst 1 (shift 1 1 (shift 1 1 (shift 1 1 a))) (shift 1 3 B) := by
        simpa [shiftIndex] using (ihB (shift 1 1 (shift 1 0 a)))
      simp [instantiate, shift, subst, hA, hB]
  | letE v A t ihv ihA iht =>
      have hv : shift 1 1 (subst 0 (shift 1 0 a) v) =
          subst 0 (shift 1 1 (shift 1 1 a)) (shift 1 2 v) := by
        simpa [shiftIndex] using ihv (shift 1 0 a)
      have hA : shift 1 1 (subst 0 (shift 1 0 a) A) =
          subst 0 (shift 1 1 (shift 1 1 a)) (shift 1 2 A) := by
        simpa [shiftIndex] using ihA (shift 1 0 a)
      have ht :
          shift 1 2
            (subst 1 (shift 1 1 (shift 1 1 a)) t) =
          subst 1 (shift 1 1 (shift 1 1 (shift 1 1 a))) (shift 1 3 t) := by
        simpa [shiftIndex] using (iht (shift 1 1 (shift 1 0 a)))
      simp [instantiate, shift, subst, hv, hA, ht]

end Test
