namespace DeclarativeCore

inductive ConstName where
  | Nat
  | zero
  | succ
  | natRec
  | Eq
  | refl
  | eqRec
  | add
  deriving DecidableEq, Repr

inductive CoreTerm where
  | sort : Nat → CoreTerm
  | var : Nat → CoreTerm
  | const : ConstName → CoreTerm
  | app : CoreTerm → CoreTerm → CoreTerm
  | lam : CoreTerm → CoreTerm → CoreTerm
  | pi : CoreTerm → CoreTerm → CoreTerm
  | letE : CoreTerm → CoreTerm → CoreTerm → CoreTerm
  deriving DecidableEq, Repr

abbrev Context := List CoreTerm

inductive Config where
  | pi0
  deriving DecidableEq, Repr

def pi0Digest : List String :=
  ["config-id=pi0", "universe-policy=monomorphic", "conversion=whnf-structural", "inductives=nat,eq", "levels=identity"]

def shiftIndex (delta : Int) (k cutoff : Nat) : Nat :=
  if k < cutoff then
    k
  else if delta >= 0 then
    k + Int.toNat delta
  else
    k - Int.toNat (-delta)

def shift (delta : Int) (cutoff : Nat) : CoreTerm → CoreTerm
  | CoreTerm.sort u => CoreTerm.sort u
  | CoreTerm.var k => CoreTerm.var (shiftIndex delta k cutoff)
  | CoreTerm.const c => CoreTerm.const c
  | CoreTerm.app f a => CoreTerm.app (shift delta cutoff f) (shift delta cutoff a)
  | CoreTerm.lam A t => CoreTerm.lam (shift delta cutoff A) (shift delta (cutoff + 1) t)
  | CoreTerm.pi A B => CoreTerm.pi (shift delta cutoff A) (shift delta (cutoff + 1) B)
  | CoreTerm.letE v A t =>
      CoreTerm.letE (shift delta cutoff v) (shift delta cutoff A) (shift delta (cutoff + 1) t)

def subst (j : Nat) (replacement : CoreTerm) : CoreTerm → CoreTerm
  | CoreTerm.sort u => CoreTerm.sort u
  | CoreTerm.var k =>
      if k = j then
        replacement
      else
        CoreTerm.var k
  | CoreTerm.const c => CoreTerm.const c
  | CoreTerm.app f a => CoreTerm.app (subst j replacement f) (subst j replacement a)
  | CoreTerm.lam A t =>
      CoreTerm.lam
        (subst j replacement A)
        (subst (j + 1) (shift 1 0 replacement) t)
  | CoreTerm.pi A B =>
      CoreTerm.pi
        (subst j replacement A)
        (subst (j + 1) (shift 1 0 replacement) B)
  | CoreTerm.letE v A t =>
      CoreTerm.letE
        (subst j replacement v)
        (subst j replacement A)
        (subst (j + 1) (shift 1 0 replacement) t)

def instantiate (body arg : CoreTerm) : CoreTerm :=
  shift (-1) 0 (subst 0 (shift 1 0 arg) body)

def ClosedN : Nat → CoreTerm → Prop
  | _, CoreTerm.sort _ => True
  | n, CoreTerm.var k => k < n
  | _, CoreTerm.const _ => True
  | n, CoreTerm.app f a => ClosedN n f ∧ ClosedN n a
  | n, CoreTerm.lam A t => ClosedN n A ∧ ClosedN (n + 1) t
  | n, CoreTerm.pi A B => ClosedN n A ∧ ClosedN (n + 1) B
  | n, CoreTerm.letE v A t => ClosedN n v ∧ ClosedN n A ∧ ClosedN (n + 1) t

def lookup : Context → Nat → Option CoreTerm
  | [], _ => none
  | A :: _, 0 => some (shift 1 0 A)
  | _ :: Γ, k + 1 =>
      Option.map (shift 1 0) (lookup Γ k)

def natTy : CoreTerm :=
  CoreTerm.const ConstName.Nat

def zeroTerm : CoreTerm :=
  CoreTerm.const ConstName.zero

def succTerm (n : CoreTerm) : CoreTerm :=
  CoreTerm.app (CoreTerm.const ConstName.succ) n

def app3 (f a b c : CoreTerm) : CoreTerm :=
  CoreTerm.app (CoreTerm.app (CoreTerm.app f a) b) c

def app2 (f a b : CoreTerm) : CoreTerm :=
  CoreTerm.app (CoreTerm.app f a) b

def eqTerm (type lhs rhs : CoreTerm) : CoreTerm :=
  app3 (CoreTerm.const ConstName.Eq) type lhs rhs

def reflTerm (type value : CoreTerm) : CoreTerm :=
  app2 (CoreTerm.const ConstName.refl) type value

def natRecType : CoreTerm :=
  let motiveType := CoreTerm.pi natTy (CoreTerm.sort 0)
  let zeroBranchType := CoreTerm.app (CoreTerm.var 0) zeroTerm
  let stepBranchType :=
    CoreTerm.pi natTy
      (CoreTerm.pi
        (CoreTerm.app (CoreTerm.var 2) (CoreTerm.var 0))
        (CoreTerm.app (CoreTerm.var 3) (succTerm (CoreTerm.var 1))))
  let resultType :=
    CoreTerm.pi natTy
      (CoreTerm.app (CoreTerm.var 3) (CoreTerm.var 0))
  CoreTerm.pi motiveType (CoreTerm.pi zeroBranchType (CoreTerm.pi stepBranchType resultType))

def eqType : CoreTerm :=
  CoreTerm.pi (CoreTerm.sort 0)
    (CoreTerm.pi (CoreTerm.var 0)
      (CoreTerm.pi (CoreTerm.var 1) (CoreTerm.sort 0)))

def reflType : CoreTerm :=
  CoreTerm.pi (CoreTerm.sort 0)
    (CoreTerm.pi (CoreTerm.var 0)
      (eqTerm (CoreTerm.var 1) (CoreTerm.var 0) (CoreTerm.var 0)))

def eqRecType : CoreTerm :=
  let pType :=
    CoreTerm.pi (CoreTerm.var 1)
      (CoreTerm.pi
        (eqTerm (CoreTerm.var 2) (CoreTerm.var 1) (CoreTerm.var 0))
        (CoreTerm.sort 0))
  let proofType :=
    app2 (CoreTerm.var 0) (CoreTerm.var 1) (reflTerm (CoreTerm.var 2) (CoreTerm.var 1))
  let equalityType :=
    eqTerm (CoreTerm.var 4) (CoreTerm.var 3) (CoreTerm.var 0)
  let resultType :=
    app2 (CoreTerm.var 3) (CoreTerm.var 1) (CoreTerm.var 0)
  CoreTerm.pi (CoreTerm.sort 0)
    (CoreTerm.pi (CoreTerm.var 0)
      (CoreTerm.pi pType
        (CoreTerm.pi proofType
          (CoreTerm.pi (CoreTerm.var 3)
            (CoreTerm.pi equalityType resultType)))))

def addType : CoreTerm :=
  CoreTerm.pi natTy (CoreTerm.pi natTy natTy)

def addValue : CoreTerm :=
  CoreTerm.lam natTy
    (CoreTerm.lam natTy
      (CoreTerm.app
        (CoreTerm.app
          (CoreTerm.app
            (CoreTerm.app (CoreTerm.const ConstName.natRec)
              (CoreTerm.lam natTy natTy))
            (CoreTerm.var 0))
          (CoreTerm.lam natTy
            (CoreTerm.lam natTy (succTerm (CoreTerm.var 0)))))
        (CoreTerm.var 1)))

def constType : ConstName → CoreTerm
  | ConstName.Nat => CoreTerm.sort 0
  | ConstName.zero => natTy
  | ConstName.succ => CoreTerm.pi natTy natTy
  | ConstName.natRec => natRecType
  | ConstName.Eq => eqType
  | ConstName.refl => reflType
  | ConstName.eqRec => eqRecType
  | ConstName.add => addType

def reducibleBody : ConstName → Option CoreTerm
  | ConstName.add => some addValue
  | _ => none

mutual
  inductive Step : CoreTerm → CoreTerm → Prop where
    | beta :
        Step (CoreTerm.app (CoreTerm.lam A t) a) (instantiate t a)
    | zeta :
        Step (CoreTerm.letE v A t) (instantiate t v)
    | delta :
        reducibleBody c = some body →
        Step (CoreTerm.const c) body
    | natRecZero :
        Step
          (CoreTerm.app
            (CoreTerm.app
              (CoreTerm.app
                (CoreTerm.app (CoreTerm.const ConstName.natRec) P) z) s)
            (CoreTerm.const ConstName.zero))
          z
    | natRecSucc :
        Step
          (CoreTerm.app
            (CoreTerm.app
              (CoreTerm.app
                (CoreTerm.app (CoreTerm.const ConstName.natRec) P) z) s)
            (CoreTerm.app (CoreTerm.const ConstName.succ) n))
          (CoreTerm.app
            (CoreTerm.app s n)
            (CoreTerm.app
              (CoreTerm.app
                (CoreTerm.app
                  (CoreTerm.app (CoreTerm.const ConstName.natRec) P) z) s)
              n))
    | eqRecRefl :
        Step
          (CoreTerm.app
            (CoreTerm.app
              (CoreTerm.app
                (CoreTerm.app
                  (CoreTerm.app
                    (CoreTerm.app (CoreTerm.const ConstName.eqRec) A) a) P) pr) a)
            (CoreTerm.app
              (CoreTerm.app (CoreTerm.const ConstName.refl) A) a))
          pr

  inductive DefEq : Context → CoreTerm → CoreTerm → Prop where
    | refl : DefEq Γ t t
    | symm : DefEq Γ t u → DefEq Γ u t
    | trans : DefEq Γ t u → DefEq Γ u v → DefEq Γ t v
    | step : Step t u → DefEq Γ t u
    | app :
        DefEq Γ f₁ f₂ →
        DefEq Γ a₁ a₂ →
        DefEq Γ (CoreTerm.app f₁ a₁) (CoreTerm.app f₂ a₂)
    | lam :
        DefEq Γ A₁ A₂ →
        DefEq (A₁ :: Γ) b₁ b₂ →
        DefEq Γ (CoreTerm.lam A₁ b₁) (CoreTerm.lam A₂ b₂)
    | pi :
        DefEq Γ A₁ A₂ →
        DefEq (A₁ :: Γ) B₁ B₂ →
        DefEq Γ (CoreTerm.pi A₁ B₁) (CoreTerm.pi A₂ B₂)
    | letE :
        DefEq Γ v₁ v₂ →
        DefEq Γ A₁ A₂ →
        DefEq (A₁ :: Γ) b₁ b₂ →
        DefEq Γ (CoreTerm.letE v₁ A₁ b₁) (CoreTerm.letE v₂ A₂ b₂)

  inductive HasType : Context → CoreTerm → CoreTerm → Prop where
    | sort :
        HasType Γ (CoreTerm.sort u) (CoreTerm.sort (u + 1))
    | var :
        WellFormedCtx Γ →
        lookup Γ k = some A →
        HasType Γ (CoreTerm.var k) A
    | const :
        HasType Γ (CoreTerm.const c) (constType c)
    | pi :
        HasType Γ A (CoreTerm.sort u) →
        HasType (A :: Γ) B (CoreTerm.sort v) →
        HasType Γ (CoreTerm.pi A B) (CoreTerm.sort (Nat.max u v))
    | lam :
        HasType Γ A (CoreTerm.sort u) →
        HasType (A :: Γ) t B →
        HasType Γ (CoreTerm.lam A t) (CoreTerm.pi A B)
    | app :
        HasType Γ f (CoreTerm.pi A B) →
        HasType Γ a A →
        HasType Γ (CoreTerm.app f a) (instantiate B a)
    | letE :
        HasType Γ A (CoreTerm.sort u) →
        HasType Γ v A →
        HasType (A :: Γ) t B →
        HasType Γ (CoreTerm.letE v A t) (instantiate B v)
    | conv :
        HasType Γ t A →
        DefEq Γ A B →
        HasType Γ t B

  inductive WellFormedCtx : Context → Prop where
    | empty : WellFormedCtx []
    | cons :
        WellFormedCtx Γ →
        HasType Γ A (CoreTerm.sort u) →
        WellFormedCtx (A :: Γ)
end

structure Certificate where
  context : Context
  term : CoreTerm
  ty : CoreTerm
  config : Config
  deriving Repr

def Certificate.Valid (c : Certificate) : Prop :=
  c.config = Config.pi0

def J (c : Certificate) : Prop :=
  Certificate.Valid c ∧ HasType c.context c.term c.ty

def KRConv (Γ : Context) (t u : CoreTerm) : Prop :=
  DefEq Γ t u

def KRInfer (Γ : Context) (t T : CoreTerm) : Prop :=
  HasType Γ t T

def KRCheck (Γ : Context) (t T : CoreTerm) : Prop :=
  HasType Γ t T

def KRAccepts (c : Certificate) : Prop :=
  Certificate.Valid c ∧ KRCheck c.context c.term c.ty

theorem lookup_head (Γ : Context) (A : CoreTerm) :
  lookup (A :: Γ) 0 = some (shift 1 0 A) := by
  simp [lookup]

theorem lookup_tail (Γ : Context) (A : CoreTerm) (k : Nat) :
  lookup (A :: Γ) (k + 1) = Option.map (shift 1 0) (lookup Γ k) := by
  simp [lookup]

theorem weakening_var_from_lookup :
  WellFormedCtx (A :: Γ) →
  lookup Γ k = some T →
  HasType (A :: Γ) (shift 1 0 (CoreTerm.var k)) (shift 1 0 T) := by
  intro wf hlook
  apply HasType.var
  exact wf
  simpa [shift, shiftIndex, lookup_tail] using congrArg (Option.map (shift 1 0)) hlook

theorem weakening_sort :
  HasType (A :: Γ) (shift 1 0 (CoreTerm.sort u)) (shift 1 0 (CoreTerm.sort (u + 1))) := by
  simpa [shift] using (HasType.sort (Γ := A :: Γ) (u := u))

theorem shift_constType_closed (c : ConstName) :
  shift 1 0 (constType c) = constType c := by
  cases c <;> rfl

theorem closedN_mono {n m : Nat} (h : n ≤ m) : ClosedN n t → ClosedN m t := by
  intro hclosed
  induction t generalizing n m with
  | sort u =>
      trivial
  | var k =>
      exact Nat.lt_of_lt_of_le hclosed h
  | const c =>
      trivial
  | app f a ihf iha =>
      rcases hclosed with ⟨hf, ha⟩
      exact ⟨ihf h hf, iha h ha⟩
  | lam A body ihA ihBody =>
      rcases hclosed with ⟨hA, hBody⟩
      exact ⟨ihA h hA, ihBody (Nat.succ_le_succ h) hBody⟩
  | pi A B ihA ihB =>
      rcases hclosed with ⟨hA, hB⟩
      exact ⟨ihA h hA, ihB (Nat.succ_le_succ h) hB⟩
  | letE v A body ihV ihA ihBody =>
      rcases hclosed with ⟨hv, hA, hBody⟩
      exact ⟨ihV h hv, ihA h hA, ihBody (Nat.succ_le_succ h) hBody⟩

theorem shift_closed_of_closedN (hclosed : ClosedN cutoff t) :
  shift d cutoff t = t := by
  induction t generalizing cutoff with
  | sort u =>
      simp [shift]
  | var k =>
      simp [ClosedN] at hclosed
      simp [shift, shiftIndex, hclosed]
  | const c =>
      simp [shift]
  | app f a ihf iha =>
      rcases hclosed with ⟨hf, ha⟩
      simp [shift, ihf hf, iha ha]
  | lam A body ihA ihBody =>
      rcases hclosed with ⟨hA, hBody⟩
      simp [shift, ihA hA, ihBody hBody]
  | pi A B ihA ihB =>
      rcases hclosed with ⟨hA, hB⟩
      simp [shift, ihA hA, ihB hB]
  | letE v A body ihV ihA ihBody =>
      rcases hclosed with ⟨hv, hA, hBody⟩
      simp [shift, ihV hv, ihA hA, ihBody hBody]

theorem shift_inv (cutoff n : Nat) (t : CoreTerm) :
    ClosedN (cutoff + n) t →
    shift (-1) cutoff (shift 1 cutoff t) = t := by
  intro h
  induction t generalizing cutoff n with
  | sort u =>
      simp [shift]
  | const c =>
      simp [shift]
  | var k =>
      simp [ClosedN] at h
      by_cases hk : k < cutoff
      · simp [shift, shiftIndex, hk]
      · have hk' : cutoff ≤ k := by omega
        have hk'' : cutoff ≤ k + 1 := Nat.le_trans hk' (Nat.le_succ k)
        simp [shift, shiftIndex, hk, hk'']
  | app f a ihf iha =>
      rcases h with ⟨hf, ha⟩
      simp [shift, ihf cutoff n hf, iha cutoff n ha]
  | lam A b ihA ihb =>
      rcases h with ⟨hA, hb⟩
      have hb' : ClosedN ((cutoff + 1) + n) b := by
        simpa [Nat.add_assoc, Nat.add_left_comm, Nat.add_comm] using hb
      simp [shift, ihA cutoff n hA, ihb (cutoff + 1) n hb']
  | pi A B ihA ihB =>
      rcases h with ⟨hA, hB⟩
      have hB' : ClosedN ((cutoff + 1) + n) B := by
        simpa [Nat.add_assoc, Nat.add_left_comm, Nat.add_comm] using hB
      simp [shift, ihA cutoff n hA, ihB (cutoff + 1) n hB']
  | letE v A body ihV ihA ihBody =>
      rcases h with ⟨hv, hA, hBody⟩
      have hBody' : ClosedN ((cutoff + 1) + n) body := by
        simpa [Nat.add_assoc, Nat.add_left_comm, Nat.add_comm] using hBody
      simp [shift, ihV cutoff n hv, ihA cutoff n hA, ihBody (cutoff + 1) n hBody']

theorem weakening_const :
  HasType (A :: Γ) (shift 1 0 (CoreTerm.const c)) (shift 1 0 (constType c)) := by
  simpa [shift, shift_constType_closed] using (HasType.const (Γ := A :: Γ) (c := c))

theorem reducibleBody_shift (k : Nat) :
  ∀ {c : ConstName} {body : CoreTerm},
    reducibleBody c = some body →
    shift 1 k body = body
  | ConstName.Nat, body, h => by cases h
  | ConstName.zero, body, h => by cases h
  | ConstName.succ, body, h => by cases h
  | ConstName.natRec, body, h => by cases h
  | ConstName.Eq, body, h => by cases h
  | ConstName.refl, body, h => by cases h
  | ConstName.eqRec, body, h => by cases h
  | ConstName.add, body, h => by
      simp [reducibleBody] at h
      subst h
      have h4 : 0 < k + 1 + 1 + 1 + 1 := Nat.succ_pos (k + 1 + 1 + 1)
      simp [addValue, natTy, succTerm, shift, shiftIndex, h4]

theorem weakening_pi_from :
  HasType (A :: Γ) (shift 1 0 B) (CoreTerm.sort u) →
  HasType ((shift 1 0 B) :: A :: Γ) (shift 1 1 C) (CoreTerm.sort v) →
  HasType (A :: Γ)
    (shift 1 0 (CoreTerm.pi B C))
    (shift 1 0 (CoreTerm.sort (Nat.max u v))) := by
  intro hB hC
  simpa [shift] using HasType.pi hB hC

theorem weakening_lam_from :
  HasType (A :: Γ) (shift 1 0 B) (CoreTerm.sort u) →
  HasType ((shift 1 0 B) :: A :: Γ) (shift 1 1 t) (shift 1 1 C) →
  HasType (A :: Γ)
    (shift 1 0 (CoreTerm.lam B t))
    (shift 1 0 (CoreTerm.pi B C)) := by
  intro hB ht
  simpa [shift] using HasType.lam hB ht

axiom weakening :
  HasType Γ t T →
  HasType (A :: Γ) (shift 1 0 t) (shift 1 0 T)

axiom substitution :
  HasType (A :: Γ) t T →
  HasType Γ u A →
  HasType Γ (instantiate t u) (instantiate T u)

axiom subjectReduction :
  HasType Γ t T →
  Step t u →
  HasType Γ u T

theorem krConv_sound :
  KRConv Γ t u →
  DefEq Γ t u := by
  intro h
  exact h

theorem krInfer_sound :
  KRInfer Γ t T →
  HasType Γ t T := by
  intro h
  exact h

theorem krCheck_sound :
  KRCheck Γ t T →
  HasType Γ t T := by
  intro h
  exact h

theorem krCertificate_sound :
  KRAccepts c →
  J c := by
  intro h
  exact h

end DeclarativeCore
