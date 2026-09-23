(defpackage :mini-kernel-stage1-concept-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-stage1-concept-tests)

(define-condition test-failure (error)
  ((message :initarg :message :reader test-failure-message))
  (:report (lambda (condition stream)
             (princ (test-failure-message condition) stream))))

(defun fail-test (format-string &rest args)
  (error 'test-failure :message (apply #'format nil format-string args)))

(defmacro is-true (form)
  `(unless ,form
     (fail-test "expected truthy form: ~S" ',form)))

(defmacro is-equal (expected form)
  `(let ((expected-value ,expected)
         (actual-value ,form))
     (unless (equal expected-value actual-value)
       (fail-test "expected ~S, got ~S from ~S"
                  expected-value
                  actual-value
                  ',form))))

(defun run-test (name thunk)
  (handler-case
      (progn
        (funcall thunk)
        (format t "ok   ~A~%" name)
        t)
    (error (condition)
      (format t "FAIL ~A~%  ~A~%" name condition)
      nil)))

(defun test-ingest-stage1-concept-file ()
  (let ((program (mini-kernel:ingest-stage1-concept-file)))
    (is-equal 3 (length (mini-kernel:stage1-program-forms program)))
    (is-equal 3 (length (mini-kernel:stage1-program-scenarios program)))
    (is-true (mini-kernel:stage1-program-wf-p program))
    (is-equal '(:compile-form :compile-atom :compile-closure :compile-application)
              (mini-kernel:stage1-program-helper-set program))))

(defun test-stage1-find-scenario ()
  (let* ((program (mini-kernel:ingest-stage1-concept-file))
         (scenario (mini-kernel:stage1-find-scenario program :c1-to-c2-to-c3)))
    (is-true scenario)
    (is-equal :c1-to-c2-to-c3
              (mini-kernel:stage1-scenario-name scenario))
    (is-equal "FORMS-C2"
              (symbol-name (mini-kernel:stage1-scenario-source scenario)))))

(defun test-stage1-promotion-summaries ()
  (let* ((program (mini-kernel:ingest-stage1-concept-file))
         (summaries (mini-kernel:stage1-promotion-summaries
                     program :c0-to-c1-to-c2-to-c3)))
    (is-equal 3 (length summaries))
    (is-equal "C1" (symbol-name (getf (first summaries) :compiler)))
    (is-equal "FORMS-C1" (symbol-name (getf (first summaries) :descriptor)))
    (is-equal "C2" (symbol-name (getf (second summaries) :compiler)))
    (is-equal "FORMS-C2" (symbol-name (getf (second summaries) :descriptor)))
    (is-equal "C3" (symbol-name (getf (third summaries) :compiler)))
    (is-equal nil (getf (third summaries) :next-form))))

(defun test-check-stage1-concept-closure ()
  (let ((result (mini-kernel:check-stage1-concept-closure)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))
    (is-equal 3 (getf (mini-kernel:backend-result-artifacts result) :checked))))

(defun test-emit-stage1-concept-bundle ()
  (let* ((bundle (mini-kernel:emit-stage1-concept-bundle))
         (certs (mini-kernel:stage1-concept-bundle-property-certificates bundle))
         (first-cert (first certs))
         (claim (mini-kernel:stage1-property-certificate-claim first-cert))
         (agreement (first (mini-kernel:stage1-concept-bundle-agreement-certificates bundle))))
    (is-equal :stage1-concept-check
              (mini-kernel:stage1-concept-bundle-checker-lane bundle))
    (is-true (> (length certs) 5))
    (is-equal :wf-program
              (mini-kernel:stage1-property-certificate-property-id first-cert))
    (is-equal :accepted
              (mini-kernel:stage1-property-certificate-status first-cert))
    (is-equal :wf-program
              (mini-kernel:stage1-claim-property-id claim))
    (is-equal :stage1-runtime
              (mini-kernel:stage1-claim-subject claim))
    (is-equal (mini-kernel:stage1-claim-summary claim)
              (getf (mini-kernel:certificate-metadata agreement) :claim))))

(defun test-verify-stage1-concept-bundle ()
  (let* ((bundle (mini-kernel:emit-stage1-concept-bundle))
         (result (mini-kernel:verify-stage1-concept-bundle bundle)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-admit-stage1-concept-program ()
  (let ((result (mini-kernel:admit-stage1-concept-program)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal :accepted
              (mini-kernel:backend-result-status
               (getf (mini-kernel:backend-result-artifacts result) :verification)))))

(defun test-reject-tampered-stage1-concept-bundle ()
  (let* ((bundle (mini-kernel:emit-stage1-concept-bundle))
         (tampered (copy-structure bundle))
         (certs (copy-list (mini-kernel:stage1-concept-bundle-property-certificates bundle)))
         (first-cert (copy-structure (first certs))))
    (setf (mini-kernel:stage1-property-certificate-status first-cert) :rejected
          (car certs) first-cert
          (mini-kernel:stage1-concept-bundle-property-certificates tampered) certs)
    (let ((result (mini-kernel:verify-stage1-concept-bundle tampered)))
      (is-equal :rejected (mini-kernel:backend-result-status result))
      (is-true (plusp (length (getf (mini-kernel:backend-result-artifacts result)
                                    :failures)))))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "ingest-stage1-concept-file" #'test-ingest-stage1-concept-file)
            (cons "stage1-find-scenario" #'test-stage1-find-scenario)
            (cons "stage1-promotion-summaries" #'test-stage1-promotion-summaries)
            (cons "check-stage1-concept-closure" #'test-check-stage1-concept-closure)
            (cons "emit-stage1-concept-bundle" #'test-emit-stage1-concept-bundle)
            (cons "verify-stage1-concept-bundle" #'test-verify-stage1-concept-bundle)
            (cons "admit-stage1-concept-program" #'test-admit-stage1-concept-program)
            (cons "reject-tampered-stage1-concept-bundle"
                  #'test-reject-tampered-stage1-concept-bundle)))
         (passed 0)
         (failed 0))
    (dolist (test tests)
      (if (run-test (car test) (cdr test))
          (incf passed)
          (incf failed)))
    (format t "~%passed: ~D failed: ~D~%" passed failed)
    (when (plusp failed)
      (fail-test "stage1 concept test suite failed"))
    t))
