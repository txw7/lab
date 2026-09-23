(in-package :lab.rh-workbench)

(defun %test-assert (condition control &rest args)
  (unless condition
    (error (apply #'format nil control args))))

(defun run-rh-workbench-tests ()
  (register-rh-workbench)
  (let* ((claim (rh-first-contact-claim))
         (target (lab.theorem-workbench:find-target *rh-first-contact-target-id*))
         (problem (lab.theorem-workbench:compile-target target :representation :gaussian-heat-view)))
    (%test-assert (typep claim 'lab.math:math-claim) "RH target is not MathClaimV1")
    (%test-assert (eq :open (lab.math:math-claim-status claim)) "RH target must remain open")
    (%test-assert (member :search-synthetic-counterexample *rh-operator-families* :test #'eq)
                  "RH operator catalog is incomplete")
    (%test-assert (typep problem 'lab.math:math-proof-problem)
                  "RH target did not compile to MathProofProblemV1")
    (%test-assert (eq :gaussian-heat-view (lab.math:math-proof-problem-representation problem))
                  "RH representation mismatch")
    (let ((bridge (lab.math:compile-math-search-formal-bridge
                   :candidate-ref (lab.math:math-claim-id claim)
                   :math-claim claim
                   :operator-ref :contact-differentiate
                   :source-state-ref "search-state:test")))
      (%test-assert (eq :unsupported (lab.math:math-search-formal-bridge-status bridge))
                    "RH claim must remain open until a valid Lab projection law exists")))
  t)
