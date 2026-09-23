namespace Formal

open Nat

inductive Term where
  | bvar : Nat -> Term
  | sort : Nat -> Term
  | const : String -> Term
  | app : Term -> Term -> Term
  | lam : Term -> Term -> Term
  | pi : Term -> Term -> Term
  | letE : Term -> Term -> Term -> Term
deriving DecidableEq, Repr

abbrev Subst := Nat -> Term

mutual

def shift (d : Nat) (cutoff : Nat) : Term -> Term
  | Term.bvar k =>
      if cutoff <= k then
        Term.bvar (k + d)
      else
        Term.bvar k
  | Term.sort u => Term.sort u
  | Term.const c => Term.const c
  | Term.app f a => Term.app (shift d cutoff f) (shift d cutoff a)
  | Term.lam A b => Term.lam (shift d cutoff A) (shift d (cutoff + 1) b)
  | Term.pi A B => Term.pi (shift d cutoff A) (shift d (cutoff + 1) B)
  | Term.letE v A b => Term.letE (shift d cutoff v) (shift d cutoff A) (shift d (cutoff + 1) b)

def up (sigma : Subst) : Subst
  | 0 => Term.bvar 0
  | n + 1 => shift 1 0 (sigma n)

def instantiate (sigma : Subst) : Term -> Term
  | Term.bvar k => sigma k
  | Term.sort u => Term.sort u
  | Term.const c => Term.const c
  | Term.app f a => Term.app (instantiate sigma f) (instantiate sigma a)
  | Term.lam A b => Term.lam (instantiate sigma A) (instantiate (up sigma) b)
  | Term.pi A B => Term.pi (instantiate sigma A) (instantiate (up sigma) B)
  | Term.letE v A b => Term.letE (instantiate sigma v) (instantiate sigma A) (instantiate (up sigma) b)

end

mutual
  inductive ClosedN : Nat -> Term -> Prop where
    | bvar {n k} : k < n -> ClosedN n (Term.bvar k)
    | sort {n u} : ClosedN n (Term.sort u)
    | const {n c} : ClosedN n (Term.const c)
    | app {n f a} : ClosedN n f -> ClosedN n a -> ClosedN n (Term.app f a)
    | lam {n A b} : ClosedN n A -> ClosedN (n + 1) b -> ClosedN n (Term.lam A b)
    | pi {n A B} : ClosedN n A -> ClosedN (n + 1) B -> ClosedN n (Term.pi A B)
    | letClosed {n v A b} :
        ClosedN n v -> ClosedN n A -> ClosedN (n + 1) b -> ClosedN n (Term.letE v A b)
end

theorem shift_zero : forall t : Term, forall cutoff : Nat, shift 0 cutoff t = t := by
  intro t
  induction t with
  | bvar k =>
      intro cutoff
      simp [shift]
  | sort u =>
      intro cutoff
      simp [shift]
  | const c =>
      intro cutoff
      simp [shift]
  | app f a ihf iha =>
      intro cutoff
      simp [shift, ihf cutoff, iha cutoff]
  | lam A b ihA ihb =>
      intro cutoff
      simp [shift, ihA cutoff, ihb (cutoff + 1)]
  | pi A B ihA ihB =>
      intro cutoff
      simp [shift, ihA cutoff, ihB (cutoff + 1)]
  | letE v A b ihv ihA ihb =>
      intro cutoff
      simp [shift, ihv cutoff, ihA cutoff, ihb (cutoff + 1)]

theorem up_closed_eq_bvar : forall {n sigma k},
  (forall i, i < n -> sigma i = Term.bvar i) ->
  k < n + 1 ->
  up sigma k = Term.bvar k := by
  intro n sigma k hs hk
  cases k with
  | zero =>
      simp [up]
  | succ k =>
      have hk' : k < n := by
        simpa using hk
      simp [up, hs k hk', shift, Nat.zero_le]

theorem instantiate_closedN_id {n t sigma} :
  ClosedN n t ->
  (forall i, i < n -> sigma i = Term.bvar i) ->
  instantiate sigma t = t := by
  intro hcl hs
  induction hcl generalizing sigma with
  | bvar hk =>
      simp [instantiate, hs _ hk]
  | sort =>
      simp [instantiate]
  | const =>
      simp [instantiate]
  | app hf ha ihf iha =>
      simp [instantiate, ihf hs, iha hs]
  | lam hA hb ihA ihb =>
      simp [instantiate, ihA hs, ihb (fun i hi => up_closed_eq_bvar (sigma := sigma) (k := i) hs hi)]
  | pi hA hB ihA ihB =>
      simp [instantiate, ihA hs, ihB (fun i hi => up_closed_eq_bvar (sigma := sigma) (k := i) hs hi)]
  | letClosed hv hA hb ihv ihA ihb =>
      simp [instantiate, ihv hs, ihA hs, ihb (fun i hi => up_closed_eq_bvar (sigma := sigma) (k := i) hs hi)]

theorem shift_instantiate_closed : forall {n t sigma},
  ClosedN n t ->
  (forall i, i < n -> sigma i = Term.bvar i) ->
  instantiate sigma t = t := by
  intro n t sigma hcl hs
  exact instantiate_closedN_id hcl hs

theorem shift_instantiate_under_closed : forall {n t sigma},
  ClosedN (n + 1) t ->
  (forall i, i < n -> sigma i = Term.bvar i) ->
  instantiate (up sigma) t = t := by
  intro n t sigma hcl hs
  apply instantiate_closedN_id hcl
  intro i hi
  exact up_closed_eq_bvar hs hi

end Formal
