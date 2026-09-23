(defpackage :mini-kernel-proof-ir-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-proof-ir-tests)

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

(defmacro signals-kernel-error (form)
  `(handler-case
       (progn
         ,form
         (fail-test "expected kernel error from ~S" ',form))
     (mini-kernel::kernel-error () t)))

(defun run-test (name thunk)
  (handler-case
      (progn
        (funcall thunk)
        (format t "ok   ~A~%" name)
        t)
    (error (condition)
      (format t "FAIL ~A~%  ~A~%" name condition)
      nil)))

(defun proof-example-fragment ()
  (mini-kernel:make-proof-fragment
   (mini-kernel:make-has-type-claim
    '()
    '(:const mini-kernel::zero ())
    '(:const mini-kernel::nat ())
    :metadata '(:origin :proof-ir-test))
   (mini-kernel:make-proof-evidence :const
                                    :payload '(:name mini-kernel::zero)
                                    :checkedp t)
   :checker-ids '(:jd :jkr :jkl)
   :metadata '(:lane :kernel)))

(defun test-claim-validation ()
  (let ((claim (mini-kernel:make-defeq-claim
                '((:const mini-kernel::nat ()))
                '(:var 0)
                '(:var 0))))
    (is-equal :defeq (mini-kernel:proof-claim-kind claim))
    (is-equal '((:const mini-kernel::nat ()))
              (mini-kernel:proof-claim-context
               (mini-kernel:validate-proof-claim claim)))))

(defun test-fragment-roundtrip-to-certificate ()
  (let* ((fragment (proof-example-fragment))
         (certificate (mini-kernel:proof-fragment->certificate fragment :bootstrap-v1)))
    (is-equal :typing (mini-kernel:certificate-judgment-kind certificate))
    (is-equal '(:const mini-kernel::zero ())
              (mini-kernel:certificate-term certificate))
    (is-equal :has-type
              (getf (mini-kernel:certificate-metadata certificate) :claim-kind))
    (is-equal :const
              (getf (mini-kernel:certificate-metadata certificate) :evidence-kind))))

(defun test-proof-fragment-check-kl-and-kr ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (fragment (proof-example-fragment))
         (certificate (mini-kernel:proof-fragment->certificate fragment :bootstrap-v1)))
    (is-true
     (mini-kernel:check-proof-fragment env fragment :expected-env-digest :bootstrap-v1))
    (is-true
     (mini-kernel-reference:check-certificate
      reference-env certificate :expected-env-digest :bootstrap-v1))))

(defun test-proof-claim-judgment-bridge ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (claim (mini-kernel:make-has-type-claim
                 '()
                 '(:const mini-kernel::zero ())
                 '(:const mini-kernel::nat ()))))
    (is-equal :typing
              (mini-kernel:kernel-judgment-judgment-kind
               (mini-kernel:proof-claim->kernel-judgment claim)))
    (is-true (mini-kernel:j-d-proof-claim env claim))
    (is-true (mini-kernel:j-kr-proof-claim reference-env claim))
    (is-true (mini-kernel:j-kl-proof-claim env claim))))

(defun test-proof-fragment-judgment-bridge ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (fragment (proof-example-fragment)))
    (is-true (mini-kernel:j-d-proof-fragment env fragment))
    (is-true (mini-kernel:j-kr-proof-fragment reference-env fragment))
    (is-true (mini-kernel:j-kl-proof-fragment env fragment))))

(defun test-unchecked-fragment-does-not-bridge ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (fragment
           (mini-kernel:make-proof-fragment
            (mini-kernel:make-has-type-claim
             '()
             '(:const mini-kernel::zero ())
             '(:const mini-kernel::nat ()))
            (mini-kernel:make-proof-evidence :const
                                             :payload '(:name mini-kernel::zero)
                                             :checkedp nil)
            :checker-ids '(:jd :jkr :jkl))))
    (is-equal nil (mini-kernel:j-d-proof-fragment env fragment))
    (is-equal nil (mini-kernel:j-kr-proof-fragment reference-env fragment))
    (is-equal nil (mini-kernel:j-kl-proof-fragment env fragment))))

(defun test-wf-context-claim-judgment-bridge ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (claim (mini-kernel:make-wf-ctx-claim
                 (list '(:const mini-kernel::nat ())
                       '(:const mini-kernel::nat ())))))
    (is-equal :wf-ctx
              (mini-kernel:kernel-judgment-judgment-kind
               (mini-kernel:proof-claim->kernel-judgment claim)))
    (is-true (mini-kernel:j-d-proof-claim env claim))
    (is-true (mini-kernel:j-kr-proof-claim reference-env claim))
    (is-true (mini-kernel:j-kl-proof-claim env claim))))

(defun test-wf-context-fragment-judgment-bridge ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (fragment
           (mini-kernel:make-proof-fragment
            (mini-kernel:make-wf-ctx-claim
             (list '(:const mini-kernel::nat ())
                   '(:const mini-kernel::nat ())))
            (mini-kernel:make-proof-evidence :wf-cons :checkedp t)
            :checker-ids '(:jd :jkr :jkl))))
    (is-true (mini-kernel:j-d-proof-fragment env fragment))
    (is-true (mini-kernel:j-kr-proof-fragment reference-env fragment))
    (is-true (mini-kernel:j-kl-proof-fragment env fragment))))

(defun test-ill-formed-context-rejected-by-judgment-bridge ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (claim (mini-kernel:make-wf-ctx-claim
                 (list '(:const mini-kernel::zero ())))))
    (is-equal nil (mini-kernel:j-d-proof-claim env claim))
    (is-equal nil (mini-kernel:j-kr-proof-claim reference-env claim))
    (is-equal nil (mini-kernel:j-kl-proof-claim env claim))))

(defun test-defeq-claim-judgment-bridge ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (claim (mini-kernel:make-defeq-claim
                 '()
                 '(:app (:lam (:const mini-kernel::nat ()) (:var 0))
                   (:const mini-kernel::zero ()))
                 '(:const mini-kernel::zero ()))))
    (is-equal :defeq
              (mini-kernel:kernel-judgment-judgment-kind
               (mini-kernel:proof-claim->kernel-judgment claim)))
    (is-true (mini-kernel:j-d-proof-claim env claim))
    (is-true (mini-kernel:j-kr-proof-claim reference-env claim))
    (is-true (mini-kernel:j-kl-proof-claim env claim))))

(defun test-defeq-fragment-judgment-bridge ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (fragment
           (mini-kernel:make-proof-fragment
            (mini-kernel:make-defeq-claim
             '()
             '(:app (:lam (:const mini-kernel::nat ()) (:var 0))
               (:const mini-kernel::zero ()))
             '(:const mini-kernel::zero ()))
            (mini-kernel:make-proof-evidence :defeq-step :checkedp t)
            :checker-ids '(:jd :jkr :jkl))))
    (is-true (mini-kernel:j-d-proof-fragment env fragment))
    (is-true (mini-kernel:j-kr-proof-fragment reference-env fragment))
    (is-true (mini-kernel:j-kl-proof-fragment env fragment))))

(defun test-nonconvertible-defeq-rejected-by-judgment-bridge ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (claim (mini-kernel:make-defeq-claim
                 '()
                 '(:const mini-kernel::zero ())
                 '(:app (:const mini-kernel::succ ())
                   (:const mini-kernel::zero ())))))
    (is-equal nil (mini-kernel:j-d-proof-claim env claim))
    (is-equal nil (mini-kernel:j-kr-proof-claim reference-env claim))
    (is-equal nil (mini-kernel:j-kl-proof-claim env claim))))

(defun test-step-claim-judgment-bridge ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (claim (mini-kernel:make-step-claim
                 '(:app (:lam (:const mini-kernel::nat ()) (:var 0))
                   (:const mini-kernel::zero ()))
                 '(:const mini-kernel::zero ()))))
    (is-equal :step
              (mini-kernel:kernel-judgment-judgment-kind
               (mini-kernel:proof-claim->kernel-judgment claim)))
    (is-true (mini-kernel:j-d-proof-claim env claim))
    (is-true (mini-kernel:j-kr-proof-claim reference-env claim))
    (is-true (mini-kernel:j-kl-proof-claim env claim))))

(defun test-step-fragment-judgment-bridge ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (fragment
           (mini-kernel:make-proof-fragment
            (mini-kernel:make-step-claim
             '(:let (:const mini-kernel::zero ())
               (:const mini-kernel::nat ())
               (:var 0))
             '(:const mini-kernel::zero ()))
            (mini-kernel:make-proof-evidence :defeq-step :checkedp t)
            :checker-ids '(:jd :jkr :jkl))))
    (is-true (mini-kernel:j-d-proof-fragment env fragment))
    (is-true (mini-kernel:j-kr-proof-fragment reference-env fragment))
    (is-true (mini-kernel:j-kl-proof-fragment env fragment))))

(defun test-nonstep-reduct-rejected-by-judgment-bridge ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (claim (mini-kernel:make-step-claim
                 '(:app (:lam (:const mini-kernel::nat ()) (:var 0))
                   (:const mini-kernel::zero ()))
                 '(:app (:const mini-kernel::succ ())
                   (:const mini-kernel::zero ())))))
    (is-equal nil (mini-kernel:j-d-proof-claim env claim))
    (is-equal nil (mini-kernel:j-kr-proof-claim reference-env claim))
    (is-equal nil (mini-kernel:j-kl-proof-claim env claim))))

(defun test-non-typing-claim-rejected-for-certificate-lowering ()
  (let ((fragment
          (mini-kernel:make-proof-fragment
           (mini-kernel:make-step-claim
            '(:app (:lam (:const mini-kernel::nat ()) (:var 0))
              (:const mini-kernel::zero ()))
            '(:const mini-kernel::zero ()))
           (mini-kernel:make-proof-evidence :defeq-step :checkedp t)
           :checker-ids '(:jd))))
    (signals-kernel-error
     (mini-kernel:proof-fragment->certificate fragment :bootstrap-v1))))

(defun test-invalid-evidence-kind-rejected ()
  (signals-kernel-error
   (mini-kernel:make-proof-evidence :bogus :payload nil)))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "claim-validation" #'test-claim-validation)
            (cons "fragment-roundtrip-to-certificate" #'test-fragment-roundtrip-to-certificate)
            (cons "proof-fragment-check-kl-and-kr" #'test-proof-fragment-check-kl-and-kr)
            (cons "proof-claim-judgment-bridge" #'test-proof-claim-judgment-bridge)
            (cons "proof-fragment-judgment-bridge" #'test-proof-fragment-judgment-bridge)
            (cons "unchecked-fragment-does-not-bridge"
                  #'test-unchecked-fragment-does-not-bridge)
            (cons "wf-context-claim-judgment-bridge"
                  #'test-wf-context-claim-judgment-bridge)
            (cons "wf-context-fragment-judgment-bridge"
                  #'test-wf-context-fragment-judgment-bridge)
            (cons "ill-formed-context-rejected-by-judgment-bridge"
                  #'test-ill-formed-context-rejected-by-judgment-bridge)
            (cons "defeq-claim-judgment-bridge"
                  #'test-defeq-claim-judgment-bridge)
            (cons "defeq-fragment-judgment-bridge"
                  #'test-defeq-fragment-judgment-bridge)
            (cons "nonconvertible-defeq-rejected-by-judgment-bridge"
                  #'test-nonconvertible-defeq-rejected-by-judgment-bridge)
            (cons "step-claim-judgment-bridge"
                  #'test-step-claim-judgment-bridge)
            (cons "step-fragment-judgment-bridge"
                  #'test-step-fragment-judgment-bridge)
            (cons "nonstep-reduct-rejected-by-judgment-bridge"
                  #'test-nonstep-reduct-rejected-by-judgment-bridge)
            (cons "non-typing-claim-rejected-for-certificate-lowering"
                  #'test-non-typing-claim-rejected-for-certificate-lowering)
            (cons "invalid-evidence-kind-rejected" #'test-invalid-evidence-kind-rejected)))
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
