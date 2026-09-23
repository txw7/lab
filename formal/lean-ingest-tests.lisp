(defpackage :mini-kernel-lean-ingest-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-lean-ingest-tests)

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

(defun %artifact-path ()
  (let* ((base (make-pathname :name nil :type nil
                              :defaults (or *load-truename*
                                            *compile-file-truename*
                                            *default-pathname-defaults*))))
    (merge-pathnames "generated/mini-kernel-ingested-schemas.lean" base)))

(defun %generate-and-ingest ()
  (let ((path (%artifact-path)))
    (mini-kernel:generate-lean-theorem-artifact path)
    (mini-kernel:ingest-lean-theorem-artifact path)))

(defun %artifact-source (artifact)
  (with-open-file (stream (mini-kernel:lean-ingest-artifact-path artifact)
                          :direction :input)
    (let ((buffer (make-string (file-length stream))))
      (read-sequence buffer stream)
      buffer)))

(defun %soundness-theorem-fragment ()
  (mini-kernel:make-theorem-fragment
   (mini-kernel:make-theorem-claim
    :jkr-soundness
    :parameters '(:max-depth 0 :max-context-size 1 :carrier-mode :dense))
   (mini-kernel:make-theorem-evidence
    :audit-witness
    :payload (mini-kernel:theorem-claim->witness-bundle
              (mini-kernel:make-theorem-claim
               :jkr-soundness
               :parameters '(:max-depth 0 :max-context-size 1 :carrier-mode :dense)))
    :checkedp t)
   :checker-ids '(:audit)))

(defun %weakening-theorem-fragment ()
  (mini-kernel:make-theorem-fragment
   (mini-kernel:make-theorem-claim
    :jd-weakening
    :parameters '(:max-depth 0 :max-context-size 1))
   (mini-kernel:make-theorem-evidence
    :audit-witness
    :payload (mini-kernel:theorem-claim->witness-bundle
              (mini-kernel:make-theorem-claim
               :jd-weakening
               :parameters '(:max-depth 0 :max-context-size 1)))
    :checkedp t)
   :checker-ids '(:audit)))

(defun %substitution-theorem-fragment ()
  (mini-kernel:make-theorem-fragment
   (mini-kernel:make-theorem-claim
    :jd-substitution
    :parameters '(:max-depth 0 :max-context-size 1))
   (mini-kernel:make-theorem-evidence
    :audit-witness
    :payload (mini-kernel:theorem-claim->witness-bundle
              (mini-kernel:make-theorem-claim
               :jd-substitution
               :parameters '(:max-depth 0 :max-context-size 1)))
    :checkedp t)
   :checker-ids '(:audit)))

(defun %subject-reduction-theorem-fragment ()
  (mini-kernel:make-theorem-fragment
   (mini-kernel:make-theorem-claim
    :jd-subject-reduction
    :parameters '(:max-depth 1 :max-context-size 0))
   (mini-kernel:make-theorem-evidence
    :audit-witness
    :payload (mini-kernel:theorem-claim->witness-bundle
              (mini-kernel:make-theorem-claim
               :jd-subject-reduction
               :parameters '(:max-depth 1 :max-context-size 0)))
    :checkedp t)
   :checker-ids '(:audit)))

(defun test-generate-lean-artifact ()
  (let* ((artifact (%generate-and-ingest))
         (source (%artifact-source artifact)))
    (is-true (search "axiom weakening" source))
    (is-true (search "axiom substitution" source))
    (is-true (search "axiom subjectReduction" source))
    (is-true (search "theorem krCheck_sound" source))))

(defun test-ingest-lean-artifact-catalog ()
  (let* ((artifact (%generate-and-ingest))
         (schema (mini-kernel:find-ingested-lean-theorem-schema
                  artifact
                  :declarativecore-weakening)))
    (is-true schema)
    (is-equal 4 (length (mini-kernel:list-ingested-lean-theorem-schemas artifact)))
    (is-equal "Formal.DeclarativeCore" (mini-kernel:lean-theorem-schema-module schema))
    (is-equal "weakening" (mini-kernel:lean-theorem-schema-name schema))))

(defun test-direct-vs-ingested-statement-parity ()
  (let ((artifact (%generate-and-ingest)))
    (is-true
     (mini-kernel:check-ingested-lean-statement-parity
      artifact
      :declarativecore-weakening
      :gamma '()
      :a '(:const mini-kernel::nat ())
      :term '(:const mini-kernel::zero ())
      :type '(:const mini-kernel::nat ())))
    (is-true
     (mini-kernel:check-ingested-lean-statement-parity
      artifact
      :declarativecore-substitution
      :gamma '()
      :a '(:const mini-kernel::nat ())
      :term '(:var 0)
      :type '(:const mini-kernel::nat ())
      :replacement '(:const mini-kernel::zero ())))
    (is-true
     (mini-kernel:check-ingested-lean-statement-parity
      artifact
      :declarativecore-subject-reduction
      :gamma '()
      :term '(:app
              (:lam (:const mini-kernel::nat ()) (:var 0))
              (:const mini-kernel::zero ()))
      :type '(:const mini-kernel::nat ())
      :reduct '(:const mini-kernel::zero ())))
    (is-true
     (mini-kernel:check-ingested-lean-statement-parity
      artifact
      :declarativecore-krcheck-sound
      :gamma '()
      :term '(:const mini-kernel::zero ())
      :type '(:const mini-kernel::nat ())))))

(defun test-prove-ingested-lean-statements ()
  (let* ((artifact (%generate-and-ingest))
         (zero '(:const mini-kernel::zero ()))
         (nat '(:const mini-kernel::nat ()))
         (binder-type nat)
         (weakening-statement
           (mini-kernel:instantiate-ingested-lean-theorem-statement
            artifact
            :declarativecore-weakening
            :gamma '()
            :a binder-type
            :term zero
            :type nat))
         (weakening-derivation
           (mini-kernel:make-apply-theorem-fragment-derivation
            (%weakening-theorem-fragment)
            (list
             (mini-kernel:make-proof-fragment-derivation
              :j-d
              (mini-kernel:make-proof-fragment
               (mini-kernel:make-has-type-claim '() zero nat)
               (mini-kernel:make-proof-evidence :const
                                                :payload '(:name mini-kernel::zero)
                                                :checkedp t)
               :checker-ids '(:jd))))
            :conclusion (mini-kernel:theorem-statement-conclusion
                         weakening-statement)))
         (substitution-statement
           (mini-kernel:instantiate-ingested-lean-theorem-statement
            artifact
            :declarativecore-substitution
            :gamma '()
            :a binder-type
            :term '(:var 0)
            :type nat
            :replacement zero))
         (substitution-derivation
           (mini-kernel:make-apply-theorem-fragment-derivation
            (%substitution-theorem-fragment)
            (list
             (mini-kernel:make-proof-fragment-derivation
              :j-d
              (mini-kernel:make-proof-fragment
               (mini-kernel:make-has-type-claim (list binder-type) '(:var 0) nat)
               (mini-kernel:make-proof-evidence :var :payload '(:index 0) :checkedp t)
               :checker-ids '(:jd)))
             (mini-kernel:make-proof-fragment-derivation
              :j-d
              (mini-kernel:make-proof-fragment
               (mini-kernel:make-has-type-claim '() zero binder-type)
               (mini-kernel:make-proof-evidence :const
                                                :payload '(:name mini-kernel::zero)
                                                :checkedp t)
               :checker-ids '(:jd))))
            :conclusion (mini-kernel:theorem-statement-conclusion
                         substitution-statement)))
         (beta-term '(:app
                      (:lam (:const mini-kernel::nat ()) (:var 0))
                      (:const mini-kernel::zero ())))
         (reduct zero)
         (reduction-statement
           (mini-kernel:instantiate-ingested-lean-theorem-statement
            artifact
            :declarativecore-subject-reduction
            :gamma '()
            :term beta-term
            :type nat
            :reduct reduct))
         (reduction-derivation
           (mini-kernel:make-apply-theorem-fragment-derivation
            (%subject-reduction-theorem-fragment)
            (list
             (mini-kernel:make-proof-fragment-derivation
              :j-d
              (mini-kernel:make-proof-fragment
               (mini-kernel:make-has-type-claim '() beta-term nat)
               (mini-kernel:make-proof-evidence :app
                                                :payload '(:origin :beta-redex)
                                                :checkedp t)
               :checker-ids '(:jd)))
             (mini-kernel:make-proof-fragment-derivation
              :j-d
              (mini-kernel:make-proof-fragment
               (mini-kernel:make-step-claim beta-term reduct)
               (mini-kernel:make-proof-evidence :axiom
                                                :payload '(:origin :beta-step)
                                                :checkedp t)
               :checker-ids '(:jd))))
            :conclusion (mini-kernel:theorem-statement-conclusion
                         reduction-statement)))
         (soundness-statement
           (mini-kernel:instantiate-ingested-lean-theorem-statement
            artifact
            :declarativecore-krcheck-sound
            :gamma '()
            :term zero
            :type nat))
         (soundness-derivation
           (mini-kernel:make-apply-relation-fragment-derivation
            (%soundness-theorem-fragment)
            (mini-kernel:make-proof-fragment-derivation
             :j-kr
             (mini-kernel:make-proof-fragment
              (mini-kernel:make-has-type-claim '() zero nat)
              (mini-kernel:make-proof-evidence :const
                                               :payload '(:name mini-kernel::zero)
                                               :checkedp t)
              :checker-ids '(:jkr))))))
    (is-true (mini-kernel:check-theorem-derivation
              weakening-statement
              weakening-derivation))
    (is-true (mini-kernel:check-theorem-derivation
              substitution-statement
              substitution-derivation))
    (is-true (mini-kernel:check-theorem-derivation
              reduction-statement
              reduction-derivation))
    (is-true (mini-kernel:check-theorem-derivation
              soundness-statement
              soundness-derivation))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "generate-lean-artifact" #'test-generate-lean-artifact)
            (cons "ingest-lean-artifact-catalog" #'test-ingest-lean-artifact-catalog)
            (cons "direct-vs-ingested-statement-parity"
                  #'test-direct-vs-ingested-statement-parity)
            (cons "prove-ingested-lean-statements"
                  #'test-prove-ingested-lean-statements)))
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
