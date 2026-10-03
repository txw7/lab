;; Actual abstract phase-state projection. Proof construction only; all
;; definitions and resulting terms are rechecked by both original lab kernels.
(in-package :vm9-lab)

(defun core (form &optional names)
  "A tiny named-term constructor, not a checker or evaluator."
  (case (first form)
    (:v (let ((index (position (second form) names)))
          (unless index (fail "unbound proof variable: ~S" form))
          (k::mk-var index)))
    (:nat (nat))
    (:n (numeral (second form)))
    (:s (successor (core (second form) names)))
    (:eq (eqn (core (second form) names) (core (third form) names)))
    (:lam (k::mk-lam (core (third form) names)
                     (core (fourth form) (cons (second form) names))))
    (:pi (k::mk-pi (core (third form) names)
                   (core (fourth form) (cons (second form) names))))
    (:call (k::app* (k::mk-const (second form))
                   (mapcar (lambda (x) (core x names)) (cddr form))))
    (:apply (k::mk-app (core (second form) names) (core (third form) names)))
    (otherwise (fail "unknown proof constructor: ~S" form))))

(defun shift-law-family ()
  '(:lam c (:nat)
     (:pi r (:nat)
       (:eq (:call k::add (:v c) (:s (:v r)))
            (:s (:call k::add (:v c) (:v r)))))))

(defun shift-law-type ()
  (core '(:pi c (:nat) (:pi r (:nat)
           (:eq (:call k::add (:v c) (:s (:v r)))
                (:s (:call k::add (:v c) (:v r))))))))

(defun shift-law-proof ()
  (core
   `(:call k::nat-rec ,(shift-law-family)
      (:lam r (:nat) (:call k::refl (:nat) (:s (:v r))))
      (:lam c (:nat)
        (:lam ih (:pi r (:nat)
                   (:eq (:call k::add (:v c) (:s (:v r)))
                        (:s (:call k::add (:v c) (:v r)))))
          (:lam r (:nat)
            (:call cursor-succ-congruence
              (:call k::add (:v c) (:s (:v r)))
              (:s (:call k::add (:v c) (:v r)))
              (:apply (:v ih) (:v r)))))))))

(defun make-model-environment ()
  (let ((env (k::make-bootstrap-env)))
    (k::validate-environment env)
    (admit-model-definition env 'cursor-succ-congruence
                            (congruence-proof) (congruence-type))
    (admit-model-definition env 'phase-budget
      (core '(:lam c (:nat) (:lam r (:nat)
                (:eq (:call k::add (:v c) (:v r)) (:n 9)))))
      (k::mk-pi (nat) (k::mk-pi (nat) (k::mk-sort 0))))
    (admit-model-definition env 'phase-shift-law
                            (shift-law-proof) (shift-law-type))
    env))

(defun phase-preservation-type ()
  (core '(:pi c (:nat) (:pi r (:nat)
          (:pi invariant (:call phase-budget (:v c) (:s (:v r)))
            (:call phase-budget (:s (:v c)) (:v r)))))))

(defun phase-preservation-proof ()
  ;; Init: (cursor, remaining) = (0,9).
  ;; Next: (c,succ r) -> (succ c,r), emitting phase succ c.
  ;; Transport add(c,succ r)=9 along the proved equality
  ;; add(c,succ r)=succ(add(c,r))=add(succ c,r).
  (core '(:lam c (:nat) (:lam r (:nat)
          (:lam invariant (:call phase-budget (:v c) (:s (:v r)))
            (:call k::eq-rec (:nat)
              (:call k::add (:v c) (:s (:v r)))
              (:lam total (:nat)
                (:lam equality
                  (:eq (:call k::add (:v c) (:s (:v r))) (:v total))
                  (:eq (:v total) (:n 9))))
              (:v invariant)
              (:call k::add (:s (:v c)) (:v r))
              (:call phase-shift-law (:v c) (:v r))))))))

(defun model-certificates (env)
  (list
   (certificate env :vm9-phase-budget-init
                (k::refl-term (nat) (numeral 9))
                (app 'phase-budget (numeral 0) (numeral 9)))
   (certificate env :vm9-phase-budget-next-preserves
                (phase-preservation-proof) (phase-preservation-type))))
