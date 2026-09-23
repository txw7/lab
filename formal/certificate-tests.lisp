(defpackage :mini-kernel-certificate-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-certificate-tests)

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

(defun sample-certificate ()
  (mini-kernel:make-typing-certificate
   '()
   '(:lam (:const mini-kernel::nat ())
     (:app
      (:app (:const mini-kernel::refl ()) (:const mini-kernel::nat ()))
      (:var 0)))
   '(:pi (:const mini-kernel::nat ())
     (:app
      (:app
       (:app (:const mini-kernel::eq ()) (:const mini-kernel::nat ()))
       (:var 0))
      (:var 0)))
   :bootstrap-v1
   :checker-ids '(kl)
   :metadata '(:corpus demo-proof)))

(defun test-make-typing-certificate ()
  (let ((certificate (sample-certificate)))
    (is-equal 1 (mini-kernel:certificate-schema-version certificate))
    (is-equal :typing (mini-kernel:certificate-judgment-kind certificate))
    (is-equal :bootstrap-v1 (mini-kernel:certificate-env-digest certificate))))

(defun test-validate-certificate ()
  (is-true
   (mini-kernel:validate-certificate (sample-certificate))))

(defun test-check-certificate ()
  (let ((env (mini-kernel:make-bootstrap-env)))
    (is-true
     (mini-kernel:check-certificate
      env
      (sample-certificate)
      :expected-env-digest :bootstrap-v1))))

(defun test-negative-schema-version ()
  (let ((certificate (sample-certificate)))
    (setf (mini-kernel:certificate-schema-version certificate) 2)
    (signals-kernel-error
     (mini-kernel:validate-certificate certificate))))

(defun test-negative-config-digest ()
  (let ((certificate (sample-certificate)))
    (setf (mini-kernel:certificate-config-digest certificate) :wrong)
    (signals-kernel-error
     (mini-kernel:validate-certificate certificate))))

(defun test-negative-malformed-context ()
  (let ((certificate (sample-certificate)))
    (setf (mini-kernel:certificate-context certificate) '(not-a-term))
    (signals-kernel-error
     (mini-kernel:validate-certificate certificate))))

(defun test-negative-env-digest-mismatch ()
  (let ((env (mini-kernel:make-bootstrap-env)))
    (signals-kernel-error
     (mini-kernel:check-certificate
      env
      (sample-certificate)
      :expected-env-digest :not-bootstrap-v1))))

(defun find-family-bucket (report family)
  (find family report :key (lambda (bucket) (getf bucket :family)) :test #'eq))

(defun test-generated-corpus-report ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env
                         (mini-kernel:make-bootstrap-env)))
         (report (mini-kernel-corpus:generated-corpus-report
                  :env env
                  :reference-env reference-env))
         (beta-bucket (find-family-bucket report :beta))
         (add-bucket (find-family-bucket report :add))
         (var-bucket (find-family-bucket report :var))
         (lam-bucket (find-family-bucket report :lam))
         (pi-bucket (find-family-bucket report :pi))
         (let-bucket (find-family-bucket report :let))
         (missing-bucket (find-family-bucket report :missing))
         (malformed-bucket (find-family-bucket report :malformed)))
    (is-true report)
    (is-equal 8 (length report))
    (is-equal 2 (getf beta-bucket :total))
    (is-equal 2 (getf beta-bucket :valid-kl))
    (is-equal 1 (getf beta-bucket :accepted-kl))
    (is-equal 2 (getf add-bucket :total))
    (is-equal 2 (getf add-bucket :valid-kr))
    (is-equal 1 (getf add-bucket :accepted-kr))
    (is-equal 6 (getf var-bucket :total))
    (is-equal 6 (getf var-bucket :valid-kl))
    (is-equal 3 (getf var-bucket :accepted-kl))
    (is-equal 6 (getf var-bucket :valid-kr))
    (is-equal 3 (getf var-bucket :accepted-kr))
    (is-equal 4 (getf lam-bucket :total))
    (is-equal 2 (getf lam-bucket :accepted-kl))
    (is-equal 3 (getf pi-bucket :total))
    (is-equal 1 (getf pi-bucket :accepted-kr))
    (is-equal 4 (getf let-bucket :total))
    (is-equal 2 (getf let-bucket :accepted-kl))
    (is-equal 1 (getf missing-bucket :total))
    (is-equal 0 (getf missing-bucket :valid-kl))
    (is-equal 0 (getf missing-bucket :accepted-kl))
    (is-equal 0 (getf missing-bucket :valid-kr))
    (is-equal 0 (getf missing-bucket :accepted-kr))
    (is-equal 3 (getf malformed-bucket :total))
    (is-equal 0 (getf malformed-bucket :valid-kl))
    (is-equal 0 (getf malformed-bucket :accepted-kl))
    (is-equal 0 (getf malformed-bucket :valid-kr))
    (is-equal 0 (getf malformed-bucket :accepted-kr))))

(defun test-render-generated-corpus-report ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env
                         (mini-kernel:make-bootstrap-env)))
         (report-text (mini-kernel-corpus:render-generated-corpus-report
                       :env env
                       :reference-env reference-env)))
    (is-true (search "# Generated Corpus Report" report-text))
    (is-true (search "| `var` | 6 | 6 | 3 | 6 | 3 |" report-text))
    (is-true (search "| `missing` | 1 | 0 | 0 | 0 | 0 |" report-text))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "make-typing-certificate" #'test-make-typing-certificate)
            (cons "validate-certificate" #'test-validate-certificate)
            (cons "check-certificate" #'test-check-certificate)
            (cons "negative-schema-version" #'test-negative-schema-version)
            (cons "negative-config-digest" #'test-negative-config-digest)
            (cons "negative-malformed-context" #'test-negative-malformed-context)
            (cons "negative-env-digest-mismatch" #'test-negative-env-digest-mismatch)
            (cons "generated-corpus-report" #'test-generated-corpus-report)
            (cons "render-generated-corpus-report" #'test-render-generated-corpus-report)))
         (passed 0)
         (failed 0))
    (dolist (test tests)
      (if (run-test (car test) (cdr test))
          (incf passed)
          (incf failed)))
    (format t "~%passed: ~D failed: ~D~%" passed failed)
    (when (plusp failed)
      (fail-test "certificate test suite failed"))
    t))
