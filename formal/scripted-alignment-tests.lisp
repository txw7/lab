(defpackage :mini-kernel-scripted-alignment-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-scripted-alignment-tests)

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

(defun test-run-scripted-alignment-pass ()
  (let* ((result (mini-kernel:run-scripted-alignment-pass))
         (artifacts (mini-kernel:backend-result-artifacts result))
         (steps (getf artifacts :steps))
         (step-names (mapcar (lambda (step) (getf step :name)) steps)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal 12 (length steps))
    (is-equal '(:generate-lean-theorem-artifact
                :ingest-lean-theorem-artifact
                :generate-lean-whnf-program
                :ingest-declarativecore-def-program
                :ingest-mini-kernel-whnf-program
                :theorem-statement-parity
                :def-parity
                :whnf-def-parity
                :conv-def-parity
                :checker-path-parity
                :reference-checker-path-parity
                :theorem-claim-checks)
              step-names)
    (dolist (step steps)
      (is-equal :accepted (getf step :status)))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "run-scripted-alignment-pass"
                  #'test-run-scripted-alignment-pass)))
         (passed 0)
         (failed 0))
    (dolist (test tests)
      (if (run-test (car test) (cdr test))
          (incf passed)
          (incf failed)))
    (format t "~%passed: ~D failed: ~D~%" passed failed)
    (when (plusp failed)
      (fail-test "test suite failed"))
    t))
