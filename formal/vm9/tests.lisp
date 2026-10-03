(load (merge-pathnames "load-lab.lisp" *load-truename*))
(load (merge-pathnames "integration.lisp" *load-truename*))
(load (merge-pathnames "phase-model.lisp" *load-truename*))
(in-package :vm9-lab)
(defparameter *passed* 0)
(defparameter *test-inputs*
 '(:source-ref "txw7/egress-runtime@fff7e693323343326c2bdc79fda9da6bbcaa198c"
   :evidence-ref "sha256:251903a5b5f24ae1b663bd640ce8912a0422237b253655ffcccd1dc695034613"
   :binding-sha256 "test-only-binding"))
(defun test-ok (name thunk)
  (funcall thunk) (incf *passed*) (format t "PASS ~A~%" name))
(defun test-reject (name change)
  (let ((candidate (make-candidate *test-inputs*)))
    (funcall change candidate)
    (let ((rejected (handler-case (progn (recheck-envelope candidate *test-inputs*) nil)
                      (error () t))))
      (unless rejected (fail "negative unexpectedly passed: ~A" name))
      (incf *passed*) (format t "PASS reject ~A~%" name))))
(defun first-cert (c) (first (refinement-envelope-model-certificates c)))
(defun first-residual (c) (first (refinement-envelope-residuals c)))
(test-ok :native-and-reference
 (lambda () (recheck-envelope (make-candidate *test-inputs*) *test-inputs*)))
(test-reject :unproved-term
 (lambda (c) (setf (k::certificate-term (first-cert c)) (k::zero-term))))
(test-reject :metadata-laundering
 (lambda (c) (setf (k::certificate-term (first-cert c)) (k::zero-term)
                   (k::certificate-checker-ids (first-cert c)) '(:kani :verus :proved)
                   (k::certificate-metadata (first-cert c)) '(:checkedp t :status :proved))))
(test-reject :environment-digest
 (lambda (c) (setf (k::certificate-env-digest (first-cert c)) :bootstrap-v1)))
(test-reject :configuration-digest
 (lambda (c) (setf (k::certificate-config-digest (first-cert c)) '(:config-id :pi1))))
(test-reject :local-assumption
 (lambda (c) (setf (k::certificate-context (first-cert c)) (list (k::certificate-type (first-cert c)))
                   (k::certificate-term (first-cert c)) (k::mk-var 0))))
(test-reject :global-assumption
 (lambda (c) (setf (k::certificate-term (first-cert c)) (k::mk-const 'external-kani-axiom))))
(test-reject :statement-substitution
 (lambda (c) (setf (k::certificate-type (first-cert c)) (nat)
                   (k::certificate-term (first-cert c)) (k::zero-term))))
(test-reject :missing-certificate
 (lambda (c) (pop (refinement-envelope-model-certificates c))))
(test-reject :authority-escalation
 (lambda (c) (setf (refinement-envelope-authority c) :proved)))
(test-reject :residual-erasure
 (lambda (c) (pop (refinement-envelope-residuals c))))
(test-reject :assumption-erasure
 (lambda (c) (setf (residual-obligation-assumptions (first-residual c)) nil)))
(test-reject :assumption-substitution
 (lambda (c) (setf (residual-obligation-assumptions (first-residual c)) '("trusted"))))
(test-reject :residual-promotion
 (lambda (c) (setf (residual-obligation-status (first-residual c)) :proved)))
(test-reject :residual-source-substitution
 (lambda (c) (setf (residual-obligation-source-ref (first-residual c)) "latest")))
(test-reject :residual-target-substitution
 (lambda (c) (setf (residual-obligation-target (first-residual c)) "already true")))
(test-reject :stale-input
 (lambda (c) (setf (refinement-envelope-inputs c) '(:source-ref "new" :evidence-ref "old"))))
(test-ok :independent-false-equation-rejected
 (lambda ()
   (let* ((env (make-model-environment))
          (bad (certificate env :false (k::refl-term (nat) (numeral 1))
                            (eqn (numeral 1) (numeral 2)))))
     (unless (handler-case (progn (check-closed-certificate env bad) nil) (error () t))
       (fail "native checker accepted false equality")))))
(format t "VM9 TESTS PASSED ~D~%" *passed*)
(defun reject-core-claim (name term type)
  (test-ok name
    (lambda ()
      (let ((env (make-model-environment)))
        (unless (handler-case (progn (check-closed-certificate env (certificate env name term type)) nil)
                  (error () t))
          (fail "mutant core claim accepted: ~A" name))))))
(reject-core-claim :skip-phase
 (phase-preservation-proof)
 (core '(:pi c (:nat) (:pi r (:nat)
         (:pi invariant (:call phase-budget (:v c) (:s (:v r)))
           (:call phase-budget (:s (:s (:v c))) (:v r)))))))
(reject-core-claim :repeat-phase
 (phase-preservation-proof)
 (core '(:pi c (:nat) (:pi r (:nat)
         (:pi invariant (:call phase-budget (:v c) (:s (:v r)))
           (:call phase-budget (:v c) (:v r)))))))
(reject-core-claim :wrong-initial-budget
 (k::refl-term (nat) (numeral 9))
 (app 'phase-budget (numeral 0) (numeral 8)))
(format t "VM9 TOTAL TESTS PASSED ~D~%" *passed*)
