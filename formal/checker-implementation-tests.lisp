(defpackage :mini-kernel-checker-implementation-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-checker-implementation-tests)

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

(defun %certificate-status (env certificate &key implementation)
  (handler-case
      (progn
        (mini-kernel:check-certificate
         env
         certificate
         :expected-env-digest :bootstrap-v1
         :checker-implementation implementation)
        :accepted)
    (mini-kernel::kernel-error ()
      :rejected)))

(defun test-with-kernel-implementation-dispatches-primitives ()
  (let* ((program (mini-kernel:ingest-declarativecore-def-program))
         (implementation
           (mini-kernel:make-ingested-lean-def-kernel-implementation program))
         (term '(:lam (:const mini-kernel::nat ()) (:var 1))))
    (is-equal (mini-kernel:kernel-implementation-id
               (mini-kernel:native-kernel-implementation))
              :native)
    (is-equal (mini-kernel:shift 1 0 term)
              (mini-kernel:with-kernel-implementation (implementation)
                (mini-kernel:shift 1 0 term)))
    (is-equal (mini-kernel:subst-top '(:const mini-kernel::zero ()) term)
              (mini-kernel:with-kernel-implementation (implementation)
                (mini-kernel:subst-top '(:const mini-kernel::zero ()) term)))
    (is-equal (mini-kernel::ctx-lookup '((:const mini-kernel::nat ()) (:sort 0)) 0)
              (mini-kernel:with-kernel-implementation (implementation)
                (mini-kernel::ctx-lookup '((:const mini-kernel::nat ()) (:sort 0)) 0)))))

(defun test-check-certificate-agrees-under-ingested-implementation ()
  (let* ((program (mini-kernel:ingest-declarativecore-def-program))
         (implementation
           (mini-kernel:make-ingested-lean-def-kernel-implementation program))
         (env (mini-kernel:make-bootstrap-env)))
    (dolist (entry (mini-kernel-corpus:accepted-certificates))
      (let ((certificate (mini-kernel-corpus:corpus-entry-certificate entry)))
        (is-equal
         (%certificate-status env certificate)
         (%certificate-status env certificate :implementation implementation))))
    (dolist (entry (mini-kernel-corpus:rejected-certificates))
      (let ((certificate (mini-kernel-corpus:corpus-entry-certificate entry)))
        (is-equal
         (%certificate-status env certificate)
         (%certificate-status env certificate :implementation implementation))))))

(defun test-check-certificate-agrees-under-reference-implementation ()
  (let* ((implementation
           (mini-kernel:make-reference-kernel-implementation))
         (env (mini-kernel:make-bootstrap-env)))
    (dolist (entry (mini-kernel-corpus:accepted-certificates))
      (let ((certificate (mini-kernel-corpus:corpus-entry-certificate entry)))
        (is-equal
         (%certificate-status env certificate)
         (%certificate-status env certificate :implementation implementation))))
    (dolist (entry (mini-kernel-corpus:rejected-certificates))
      (let ((certificate (mini-kernel-corpus:corpus-entry-certificate entry)))
        (is-equal
         (%certificate-status env certificate)
         (%certificate-status env certificate :implementation implementation))))))

(defun test-check-certificate-agrees-under-ingested-whnf-implementation ()
  (let* ((implementation
           (mini-kernel:make-ingested-lean-whnf-kernel-implementation))
         (env (mini-kernel:make-bootstrap-env)))
    (dolist (entry (mini-kernel-corpus:accepted-certificates))
      (let ((certificate (mini-kernel-corpus:corpus-entry-certificate entry)))
        (is-equal
         (%certificate-status env certificate)
         (%certificate-status env certificate :implementation implementation))))
    (dolist (entry (mini-kernel-corpus:rejected-certificates))
      (let ((certificate (mini-kernel-corpus:corpus-entry-certificate entry)))
        (is-equal
         (%certificate-status env certificate)
         (%certificate-status env certificate :implementation implementation))))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "with-kernel-implementation-dispatches-primitives"
                  #'test-with-kernel-implementation-dispatches-primitives)
            (cons "check-certificate-agrees-under-ingested-implementation"
                  #'test-check-certificate-agrees-under-ingested-implementation)
            (cons "check-certificate-agrees-under-ingested-whnf-implementation"
                  #'test-check-certificate-agrees-under-ingested-whnf-implementation)
            (cons "check-certificate-agrees-under-reference-implementation"
                  #'test-check-certificate-agrees-under-reference-implementation)))
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
