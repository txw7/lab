(defpackage :mini-kernel-theorem-ir-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-theorem-ir-tests)

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

(defun theorem-example-claim ()
  (mini-kernel:make-theorem-claim
   :jd-substitution
   :parameters '(:max-depth 0 :max-context-size 1)
   :metadata '(:origin :theorem-ir-test)))

(defun weakening-example-claim ()
  (mini-kernel:make-theorem-claim
   :jd-weakening
   :parameters '(:max-depth 0 :max-context-size 1)
   :metadata '(:origin :theorem-ir-test :family :metatheory)))

(defun subject-reduction-example-claim ()
  (mini-kernel:make-theorem-claim
   :jd-subject-reduction
   :parameters '(:max-depth 1 :max-context-size 0)
   :metadata '(:origin :theorem-ir-test :family :metatheory)))

(defun theorem-example-fragment ()
  (mini-kernel:make-theorem-fragment
   (theorem-example-claim)
   (mini-kernel:make-theorem-evidence :fragment-certificate
                                      :checkedp t)
   :checker-ids '(:audit)
   :metadata '(:lane :theorem)))

(defun weakening-example-fragment ()
  (mini-kernel:make-theorem-fragment
   (weakening-example-claim)
   (mini-kernel:make-theorem-evidence
    :audit-witness
    :payload (mini-kernel:theorem-claim->witness-bundle (weakening-example-claim))
    :checkedp t)
   :checker-ids '(:audit)
   :metadata '(:lane :metatheory)))

(defun subject-reduction-example-fragment ()
  (mini-kernel:make-theorem-fragment
   (subject-reduction-example-claim)
   (mini-kernel:make-theorem-evidence
    :audit-witness
    :payload (mini-kernel:theorem-claim->witness-bundle (subject-reduction-example-claim))
    :checkedp t)
   :checker-ids '(:audit)
   :metadata '(:lane :metatheory)))

(defun relation-example-claim ()
  (mini-kernel:make-theorem-claim
   :jkl-jkr-equivalence
   :parameters '(:max-depth 0 :max-context-size 1 :carrier-mode :dense)
   :metadata '(:origin :theorem-ir-test :family :relation)))

(defun defir-relation-example-claim ()
  (mini-kernel:make-theorem-claim
   :jdefir-jkr-equivalence
   :parameters '(:max-depth 0 :max-context-size 1 :carrier-mode :dense)
   :metadata '(:origin :theorem-ir-test :family :relation)))

(defun soundness-example-claim ()
  (mini-kernel:make-theorem-claim
   :jkr-soundness
   :parameters '(:max-depth 0 :max-context-size 1 :carrier-mode :dense)
   :metadata '(:origin :theorem-ir-test :family :relation)))

(defun completeness-example-claim ()
  (mini-kernel:make-theorem-claim
   :jkr-fragment-completeness
   :parameters '(:max-depth 0 :max-context-size 1 :carrier-mode :dense)
   :metadata '(:origin :theorem-ir-test :family :relation)))

(defun relation-example-fragment ()
  (mini-kernel:make-theorem-fragment
   (relation-example-claim)
   (mini-kernel:make-theorem-evidence
    :audit-witness
    :payload (mini-kernel:theorem-claim->witness-bundle (relation-example-claim))
    :checkedp t)
   :checker-ids '(:audit)
   :metadata '(:lane :relation)))

(defun soundness-example-fragment ()
  (mini-kernel:make-theorem-fragment
   (soundness-example-claim)
   (mini-kernel:make-theorem-evidence
    :audit-witness
    :payload (mini-kernel:theorem-claim->witness-bundle (soundness-example-claim))
    :checkedp t)
   :checker-ids '(:audit)
   :metadata '(:lane :relation)))

(defun completeness-example-fragment ()
  (mini-kernel:make-theorem-fragment
   (completeness-example-claim)
   (mini-kernel:make-theorem-evidence
    :audit-witness
    :payload (mini-kernel:theorem-claim->witness-bundle (completeness-example-claim))
    :checkedp t)
   :checker-ids '(:audit)
   :metadata '(:lane :relation)))

(defun test-theorem-claim-validation ()
  (let ((claim (theorem-example-claim)))
    (is-equal :jd-substitution (mini-kernel:theorem-claim-obligation-id claim))
    (is-equal '(:max-depth 0 :max-context-size 1)
              (mini-kernel:theorem-claim-parameters
               (mini-kernel:validate-theorem-claim claim)))))

(defun test-theorem-fragment-certificate-roundtrip ()
  (let* ((claim (theorem-example-claim))
         (certificate (mini-kernel:theorem-claim->fragment-certificate claim)))
    (is-equal :jd-substitution
              (mini-kernel:theorem-fragment-certificate-obligation-id certificate))
    (is-true (mini-kernel:verify-theorem-fragment-certificate certificate))))

(defun test-check-theorem-claim ()
  (let ((result (mini-kernel:check-theorem-claim (theorem-example-claim))))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal :jd-substitution
              (getf (mini-kernel:backend-result-artifacts result) :obligation-id))))

(defun test-check-theorem-fragment ()
  (is-true (mini-kernel:check-theorem-fragment (theorem-example-fragment))))

(defun test-theorem-witness-bundle-roundtrip ()
  (let* ((claim (relation-example-claim))
         (bundle (mini-kernel:theorem-claim->witness-bundle claim)))
    (is-equal :jkl-jkr-equivalence
              (mini-kernel:theorem-witness-bundle-obligation-id bundle))
    (is-true (mini-kernel:verify-theorem-witness-bundle bundle))
    (is-equal 0 (length (mini-kernel:theorem-witness-bundle-failures bundle)))))

(defun test-jd-weakening-witness-bundle-roundtrip ()
  (let* ((claim (weakening-example-claim))
         (bundle (mini-kernel:theorem-claim->witness-bundle claim)))
    (is-equal :jd-weakening
              (mini-kernel:theorem-witness-bundle-obligation-id bundle))
    (is-true (mini-kernel:verify-theorem-witness-bundle bundle))
    (is-equal 0 (length (mini-kernel:theorem-witness-bundle-failures bundle)))))

(defun test-jd-subject-reduction-witness-bundle-roundtrip ()
  (let* ((claim (subject-reduction-example-claim))
         (bundle (mini-kernel:theorem-claim->witness-bundle claim)))
    (is-equal :jd-subject-reduction
              (mini-kernel:theorem-witness-bundle-obligation-id bundle))
    (is-true (mini-kernel:verify-theorem-witness-bundle bundle))
    (is-equal 0 (length (mini-kernel:theorem-witness-bundle-failures bundle)))))

(defun test-soundness-witness-bundle-roundtrip ()
  (let* ((claim (soundness-example-claim))
         (bundle (mini-kernel:theorem-claim->witness-bundle claim)))
    (is-equal :jkr-soundness
              (mini-kernel:theorem-witness-bundle-obligation-id bundle))
    (is-true (mini-kernel:verify-theorem-witness-bundle bundle))
    (is-equal 0 (length (mini-kernel:theorem-witness-bundle-failures bundle)))))

(defun test-completeness-witness-bundle-roundtrip ()
  (let* ((claim (completeness-example-claim))
         (bundle (mini-kernel:theorem-claim->witness-bundle claim)))
    (is-equal :jkr-fragment-completeness
              (mini-kernel:theorem-witness-bundle-obligation-id bundle))
    (is-true (mini-kernel:verify-theorem-witness-bundle bundle))
    (is-equal 0 (length (mini-kernel:theorem-witness-bundle-failures bundle)))))

(defun test-defir-equivalence-witness-bundle-roundtrip ()
  (let* ((claim (defir-relation-example-claim))
         (bundle (mini-kernel:theorem-claim->witness-bundle claim)))
    (is-equal :jdefir-jkr-equivalence
              (mini-kernel:theorem-witness-bundle-obligation-id bundle))
    (is-true (mini-kernel:verify-theorem-witness-bundle bundle))
    (is-equal 0 (length (mini-kernel:theorem-witness-bundle-failures bundle)))))

(defun test-defir-theorem-fragment-certificate-roundtrip ()
  (let* ((claim (defir-relation-example-claim))
         (certificate (mini-kernel:theorem-claim->fragment-certificate claim)))
    (is-equal :jdefir-jkr-equivalence
              (mini-kernel:theorem-fragment-certificate-obligation-id certificate))
    (is-true (mini-kernel:verify-theorem-fragment-certificate certificate))))

(defun test-check-theorem-fragment-audit-witness ()
  (is-true (mini-kernel:check-theorem-fragment (relation-example-fragment))))

(defun test-check-soundness-fragment-audit-witness ()
  (is-true (mini-kernel:check-theorem-fragment (soundness-example-fragment))))

(defun test-check-completeness-fragment-audit-witness ()
  (is-true (mini-kernel:check-theorem-fragment (completeness-example-fragment))))

(defun test-check-weakening-fragment-audit-witness ()
  (is-true (mini-kernel:check-theorem-fragment (weakening-example-fragment))))

(defun test-check-subject-reduction-fragment-audit-witness ()
  (is-true (mini-kernel:check-theorem-fragment
            (subject-reduction-example-fragment))))

(defun test-tampered-theorem-witness-bundle-rejected ()
  (let* ((claim (relation-example-claim))
         (bundle (mini-kernel:theorem-claim->witness-bundle claim))
         (tampered
           (mini-kernel::%make-theorem-witness-bundle
            :obligation-id (mini-kernel:theorem-witness-bundle-obligation-id bundle)
            :parameters (copy-list (mini-kernel:theorem-witness-bundle-parameters bundle))
            :checked (1+ (mini-kernel:theorem-witness-bundle-checked bundle))
            :entries (copy-tree (mini-kernel:theorem-witness-bundle-entries bundle))
            :failures (copy-tree (mini-kernel:theorem-witness-bundle-failures bundle))
            :config-digest (mini-kernel:theorem-witness-bundle-config-digest bundle)))
         (fragment
           (mini-kernel:make-theorem-fragment
            claim
            (mini-kernel:make-theorem-evidence
             :audit-witness
             :payload tampered
             :checkedp t)
            :checker-ids '(:audit))))
    (is-equal nil (mini-kernel:verify-theorem-witness-bundle tampered))
    (is-equal nil (mini-kernel:check-theorem-fragment fragment))))

(defun test-unsupported-obligation-rejected-for-certificate-lowering ()
  (signals-kernel-error
   (mini-kernel:theorem-claim->fragment-certificate
    (mini-kernel:make-theorem-claim :smt-bridge-normalization))))

(defun test-unchecked-theorem-fragment-does-not-check ()
  (let ((fragment
          (mini-kernel:make-theorem-fragment
           (theorem-example-claim)
           (mini-kernel:make-theorem-evidence :audit-witness :checkedp nil)
           :checker-ids '(:audit))))
    (is-equal nil (mini-kernel:check-theorem-fragment fragment))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "theorem-claim-validation" #'test-theorem-claim-validation)
            (cons "theorem-fragment-certificate-roundtrip"
                  #'test-theorem-fragment-certificate-roundtrip)
            (cons "check-theorem-claim" #'test-check-theorem-claim)
            (cons "check-theorem-fragment" #'test-check-theorem-fragment)
            (cons "theorem-witness-bundle-roundtrip"
                  #'test-theorem-witness-bundle-roundtrip)
            (cons "jd-weakening-witness-bundle-roundtrip"
                  #'test-jd-weakening-witness-bundle-roundtrip)
            (cons "jd-subject-reduction-witness-bundle-roundtrip"
                  #'test-jd-subject-reduction-witness-bundle-roundtrip)
           (cons "soundness-witness-bundle-roundtrip"
                 #'test-soundness-witness-bundle-roundtrip)
           (cons "completeness-witness-bundle-roundtrip"
                 #'test-completeness-witness-bundle-roundtrip)
           (cons "defir-equivalence-witness-bundle-roundtrip"
                 #'test-defir-equivalence-witness-bundle-roundtrip)
           (cons "defir-theorem-fragment-certificate-roundtrip"
                 #'test-defir-theorem-fragment-certificate-roundtrip)
           (cons "check-theorem-fragment-audit-witness"
                 #'test-check-theorem-fragment-audit-witness)
            (cons "check-weakening-fragment-audit-witness"
                  #'test-check-weakening-fragment-audit-witness)
            (cons "check-subject-reduction-fragment-audit-witness"
                  #'test-check-subject-reduction-fragment-audit-witness)
            (cons "check-soundness-fragment-audit-witness"
                  #'test-check-soundness-fragment-audit-witness)
            (cons "check-completeness-fragment-audit-witness"
                  #'test-check-completeness-fragment-audit-witness)
            (cons "tampered-theorem-witness-bundle-rejected"
                  #'test-tampered-theorem-witness-bundle-rejected)
            (cons "unsupported-obligation-rejected-for-certificate-lowering"
                  #'test-unsupported-obligation-rejected-for-certificate-lowering)
            (cons "unchecked-theorem-fragment-does-not-check"
                  #'test-unchecked-theorem-fragment-does-not-check)))
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
