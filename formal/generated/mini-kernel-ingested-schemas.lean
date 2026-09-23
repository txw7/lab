import Formal.DeclarativeCore

open DeclarativeCore

namespace MiniKernelGenerated

/-! MINI-KERNEL-THEOREM (:ID :DECLARATIVECORE-WEAKENING :MODULE
                         "Formal.DeclarativeCore" :NAME "weakening"
                         :SOURCE-KIND :AXIOM :OBLIGATION-ID :JD-WEAKENING
                         :PARAMETER-KEYS (:GAMMA :A :TERM :TYPE)) -/
axiom weakening
  {Γ : Context} {A t T : CoreTerm} :
  HasType Γ t T →
  HasType (A :: Γ) (shift 1 0 t) (shift 1 0 T)

/-! MINI-KERNEL-THEOREM (:ID :DECLARATIVECORE-SUBSTITUTION :MODULE
                         "Formal.DeclarativeCore" :NAME "substitution"
                         :SOURCE-KIND :AXIOM :OBLIGATION-ID :JD-SUBSTITUTION
                         :PARAMETER-KEYS (:GAMMA :A :TERM :TYPE :REPLACEMENT)) -/
axiom substitution
  {Γ : Context} {A t T u : CoreTerm} :
  HasType (A :: Γ) t T →
  HasType Γ u A →
  HasType Γ (instantiate t u) (instantiate T u)

/-! MINI-KERNEL-THEOREM (:ID :DECLARATIVECORE-SUBJECT-REDUCTION :MODULE
                         "Formal.DeclarativeCore" :NAME "subjectReduction"
                         :SOURCE-KIND :AXIOM :OBLIGATION-ID
                         :JD-SUBJECT-REDUCTION :PARAMETER-KEYS
                         (:GAMMA :TERM :TYPE :REDUCT)) -/
axiom subjectReduction
  {Γ : Context} {t u T : CoreTerm} :
  HasType Γ t T →
  Step t u →
  HasType Γ u T

/-! MINI-KERNEL-THEOREM (:ID :DECLARATIVECORE-KRCHECK-SOUND :MODULE
                         "Formal.DeclarativeCore" :NAME "krCheck_sound"
                         :SOURCE-KIND :THEOREM :OBLIGATION-ID :JKR-SOUNDNESS
                         :PARAMETER-KEYS (:GAMMA :TERM :TYPE)) -/
theorem krCheck_sound
  {Γ : Context} {t T : CoreTerm} :
  KRCheck Γ t T →
  HasType Γ t T := by
  intro h
  exact h

end MiniKernelGenerated
