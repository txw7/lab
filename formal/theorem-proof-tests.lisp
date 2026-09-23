(defpackage :mini-kernel-theorem-proof-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-theorem-proof-tests)

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

(defun proof-example-fragment ()
  (mini-kernel:make-proof-fragment
   (mini-kernel:make-has-type-claim
    '()
    '(:const mini-kernel::zero ())
    '(:const mini-kernel::nat ())
    :metadata '(:origin :theorem-proof-test))
   (mini-kernel:make-proof-evidence :const
                                    :payload '(:name mini-kernel::zero)
                                    :checkedp t)
   :checker-ids '(:jkl)))

(defun theorem-example-fragment ()
  (mini-kernel:make-theorem-fragment
   (mini-kernel:make-theorem-claim
    :jkl-jkr-equivalence
    :parameters '(:max-depth 0 :max-context-size 1 :carrier-mode :dense)
    :metadata '(:origin :theorem-proof-test))
   (mini-kernel:make-theorem-evidence
    :audit-witness
    :payload (mini-kernel:theorem-claim->witness-bundle
              (mini-kernel:make-theorem-claim
               :jkl-jkr-equivalence
               :parameters '(:max-depth 0 :max-context-size 1 :carrier-mode :dense)))
    :checkedp t)
   :checker-ids '(:audit)))

(defun soundness-theorem-fragment ()
  (mini-kernel:make-theorem-fragment
   (mini-kernel:make-theorem-claim
    :jkr-soundness
    :parameters '(:max-depth 0 :max-context-size 1 :carrier-mode :dense)
    :metadata '(:origin :theorem-proof-test))
   (mini-kernel:make-theorem-evidence
    :audit-witness
    :payload (mini-kernel:theorem-claim->witness-bundle
              (mini-kernel:make-theorem-claim
               :jkr-soundness
               :parameters '(:max-depth 0 :max-context-size 1 :carrier-mode :dense)))
    :checkedp t)
   :checker-ids '(:audit)))

(defun weakening-theorem-fragment ()
  (mini-kernel:make-theorem-fragment
   (mini-kernel:make-theorem-claim
    :jd-weakening
    :parameters '(:max-depth 0 :max-context-size 1)
    :metadata '(:origin :theorem-proof-test))
   (mini-kernel:make-theorem-evidence
    :audit-witness
    :payload (mini-kernel:theorem-claim->witness-bundle
              (mini-kernel:make-theorem-claim
               :jd-weakening
               :parameters '(:max-depth 0 :max-context-size 1)))
    :checkedp t)
   :checker-ids '(:audit)))

(defun substitution-theorem-fragment ()
  (mini-kernel:make-theorem-fragment
   (mini-kernel:make-theorem-claim
    :jd-substitution
    :parameters '(:max-depth 0 :max-context-size 1)
    :metadata '(:origin :theorem-proof-test))
   (mini-kernel:make-theorem-evidence
    :audit-witness
    :payload (mini-kernel:theorem-claim->witness-bundle
              (mini-kernel:make-theorem-claim
               :jd-substitution
               :parameters '(:max-depth 0 :max-context-size 1)))
    :checkedp t)
   :checker-ids '(:audit)))

(defun subject-reduction-theorem-fragment ()
  (mini-kernel:make-theorem-fragment
   (mini-kernel:make-theorem-claim
    :jd-subject-reduction
    :parameters '(:max-depth 1 :max-context-size 0)
    :metadata '(:origin :theorem-proof-test))
   (mini-kernel:make-theorem-evidence
    :audit-witness
    :payload (mini-kernel:theorem-claim->witness-bundle
              (mini-kernel:make-theorem-claim
               :jd-subject-reduction
               :parameters '(:max-depth 1 :max-context-size 0)))
    :checkedp t)
   :checker-ids '(:audit)))

(defun test-proof-fragment-derivation ()
  (let* ((fragment (proof-example-fragment))
         (conclusion (mini-kernel:proof-claim->proposition
                      :j-kl
                      (mini-kernel:proof-fragment-claim fragment)))
         (statement (mini-kernel:make-theorem-statement
                     :id :kernel-zero-has-nat
                     :premises '()
                     :conclusion conclusion))
         (derivation (mini-kernel:make-proof-fragment-derivation :j-kl fragment)))
    (is-true (mini-kernel:check-theorem-derivation statement derivation))
    (is-equal conclusion
              (mini-kernel:infer-theorem-derivation-proposition statement derivation))))

(defun test-theorem-fragment-derivation ()
  (let* ((fragment (theorem-example-fragment))
         (conclusion (mini-kernel:theorem-claim->proposition
                      (mini-kernel:theorem-fragment-claim fragment)))
         (statement (mini-kernel:make-theorem-statement
                     :id :relation-example
                     :premises '()
                     :conclusion conclusion))
         (derivation (mini-kernel:make-theorem-fragment-derivation fragment)))
    (is-true (mini-kernel:check-theorem-derivation statement derivation))
    (is-equal conclusion
              (mini-kernel:infer-theorem-derivation-proposition statement derivation))))

(defun test-premise-derivation ()
  (let* ((fragment (proof-example-fragment))
         (premise (mini-kernel:proof-claim->proposition
                   :j-kl
                   (mini-kernel:proof-fragment-claim fragment)))
         (statement (mini-kernel:make-theorem-statement
                     :id :premise-example
                     :premises (list premise)
                     :conclusion premise))
         (derivation (mini-kernel:make-premise-derivation 0)))
    (is-true (mini-kernel:check-theorem-derivation statement derivation))))

(defun test-and-intro-and-elim ()
  (let* ((kernel-fragment (proof-example-fragment))
         (theorem-fragment (theorem-example-fragment))
         (kernel-prop (mini-kernel:proof-claim->proposition
                       :j-kl
                       (mini-kernel:proof-fragment-claim kernel-fragment)))
         (theorem-prop (mini-kernel:theorem-claim->proposition
                        (mini-kernel:theorem-fragment-claim theorem-fragment)))
         (conjunction (list :and kernel-prop theorem-prop))
         (statement (mini-kernel:make-theorem-statement
                     :id :and-example
                     :premises '()
                     :conclusion conjunction))
         (derivation
           (mini-kernel:make-and-intro-derivation
            (mini-kernel:make-proof-fragment-derivation :j-kl kernel-fragment)
            (mini-kernel:make-theorem-fragment-derivation theorem-fragment)))
         (left-statement (mini-kernel:make-theorem-statement
                          :id :and-left
                          :premises '()
                          :conclusion kernel-prop))
         (left-derivation (mini-kernel:make-and-elim-left-derivation derivation))
         (right-statement (mini-kernel:make-theorem-statement
                           :id :and-right
                           :premises '()
                           :conclusion theorem-prop))
         (right-derivation (mini-kernel:make-and-elim-right-derivation derivation)))
    (is-true (mini-kernel:check-theorem-derivation statement derivation))
    (is-true (mini-kernel:check-theorem-derivation left-statement left-derivation))
    (is-true (mini-kernel:check-theorem-derivation right-statement right-derivation))))

(defun test-bad-derivation-rejected ()
  (let* ((kernel-fragment (proof-example-fragment))
         (theorem-fragment (theorem-example-fragment))
         (kernel-prop (mini-kernel:proof-claim->proposition
                       :j-kl
                       (mini-kernel:proof-fragment-claim kernel-fragment)))
         (theorem-prop (mini-kernel:theorem-claim->proposition
                        (mini-kernel:theorem-fragment-claim theorem-fragment)))
         (statement (mini-kernel:make-theorem-statement
                     :id :bad-example
                     :premises '()
                     :conclusion kernel-prop))
         (derivation (mini-kernel:make-theorem-fragment-derivation theorem-fragment)))
    (is-equal nil (mini-kernel:check-theorem-derivation statement derivation))
    (is-equal theorem-prop
              (mini-kernel:infer-theorem-derivation-proposition statement derivation))))

(defun test-ingested-lean-krcheck-sound-via-relation-fragment ()
  (let* ((fragment (proof-example-fragment))
         (theorem-fragment (soundness-theorem-fragment))
         (statement
           (mini-kernel:instantiate-lean-theorem-statement
            :declarativecore-krcheck-sound
            :gamma '()
            :term '(:const mini-kernel::zero ())
            :type '(:const mini-kernel::nat ())))
         (premise (mini-kernel:make-proof-fragment-derivation :j-kr fragment))
         (derivation
           (mini-kernel:make-apply-relation-fragment-derivation theorem-fragment premise)))
    (is-true (mini-kernel:check-theorem-derivation statement derivation))
    (is-equal (mini-kernel:theorem-statement-conclusion statement)
              (mini-kernel:infer-theorem-derivation-proposition statement derivation))))

(defun test-ingested-lean-weakening-via-theorem-fragment ()
  (let* ((term '(:const mini-kernel::zero ()))
         (type '(:const mini-kernel::nat ()))
         (binder-type '(:const mini-kernel::nat ()))
         (premise-fragment
           (mini-kernel:make-proof-fragment
            (mini-kernel:make-has-type-claim '() term type)
            (mini-kernel:make-proof-evidence :const
                                             :payload '(:name mini-kernel::zero)
                                             :checkedp t)
            :checker-ids '(:jd)))
         (theorem-fragment (weakening-theorem-fragment))
         (statement
           (mini-kernel:instantiate-lean-theorem-statement
            :declarativecore-weakening
            :gamma '()
            :a binder-type
            :term term
            :type type))
         (derivation
           (mini-kernel:make-apply-theorem-fragment-derivation
            theorem-fragment
            (list (mini-kernel:make-proof-fragment-derivation :j-d premise-fragment))
            :conclusion (mini-kernel:theorem-statement-conclusion statement))))
    (is-true (mini-kernel:check-theorem-derivation statement derivation))
    (is-equal (mini-kernel:theorem-statement-conclusion statement)
              (mini-kernel:infer-theorem-derivation-proposition statement derivation))))

(defun test-ingested-lean-substitution-via-theorem-fragment ()
  (let* ((binder-type '(:const mini-kernel::nat ()))
         (term '(:var 0))
         (type '(:const mini-kernel::nat ()))
         (replacement '(:const mini-kernel::zero ()))
         (body-fragment
           (mini-kernel:make-proof-fragment
            (mini-kernel:make-has-type-claim
             (list binder-type)
             term
             type)
            (mini-kernel:make-proof-evidence :var
                                             :payload '(:index 0)
                                             :checkedp t)
            :checker-ids '(:jd)))
         (replacement-fragment
           (mini-kernel:make-proof-fragment
            (mini-kernel:make-has-type-claim '() replacement binder-type)
            (mini-kernel:make-proof-evidence :const
                                             :payload '(:name mini-kernel::zero)
                                             :checkedp t)
            :checker-ids '(:jd)))
         (theorem-fragment (substitution-theorem-fragment))
         (statement
           (mini-kernel:instantiate-lean-theorem-statement
            :declarativecore-substitution
            :gamma '()
            :a binder-type
            :term term
            :type type
            :replacement replacement))
         (derivation
           (mini-kernel:make-apply-theorem-fragment-derivation
            theorem-fragment
            (list (mini-kernel:make-proof-fragment-derivation :j-d body-fragment)
                  (mini-kernel:make-proof-fragment-derivation :j-d replacement-fragment))
            :conclusion (mini-kernel:theorem-statement-conclusion statement))))
    (is-true (mini-kernel:check-theorem-derivation statement derivation))
    (is-equal (mini-kernel:theorem-statement-conclusion statement)
              (mini-kernel:infer-theorem-derivation-proposition statement derivation))))

(defun test-ingested-lean-subject-reduction-via-theorem-fragment ()
  (let* ((term '(:app
                 (:lam (:const mini-kernel::nat ())
                  (:var 0))
                 (:const mini-kernel::zero ())))
         (type '(:const mini-kernel::nat ()))
         (reduct '(:const mini-kernel::zero ()))
         (typing-fragment
           (mini-kernel:make-proof-fragment
            (mini-kernel:make-has-type-claim '() term type)
            (mini-kernel:make-proof-evidence :app
                                             :payload '(:origin :beta-redex)
                                             :checkedp t)
            :checker-ids '(:jd)))
         (step-fragment
           (mini-kernel:make-proof-fragment
            (mini-kernel:make-step-claim term reduct)
            (mini-kernel:make-proof-evidence :axiom
                                             :payload '(:origin :beta-step)
                                             :checkedp t)
            :checker-ids '(:jd)))
         (theorem-fragment (subject-reduction-theorem-fragment))
         (statement
           (mini-kernel:instantiate-lean-theorem-statement
            :declarativecore-subject-reduction
            :gamma '()
            :term term
            :type type
            :reduct reduct))
         (derivation
           (mini-kernel:make-apply-theorem-fragment-derivation
            theorem-fragment
            (list (mini-kernel:make-proof-fragment-derivation :j-d typing-fragment)
                  (mini-kernel:make-proof-fragment-derivation :j-d step-fragment))
            :conclusion (mini-kernel:theorem-statement-conclusion statement))))
    (is-true (mini-kernel:check-theorem-derivation statement derivation))
    (is-equal (mini-kernel:theorem-statement-conclusion statement)
              (mini-kernel:infer-theorem-derivation-proposition statement derivation))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "proof-fragment-derivation" #'test-proof-fragment-derivation)
            (cons "theorem-fragment-derivation" #'test-theorem-fragment-derivation)
            (cons "premise-derivation" #'test-premise-derivation)
            (cons "and-intro-and-elim" #'test-and-intro-and-elim)
            (cons "ingested-lean-weakening-via-theorem-fragment"
                  #'test-ingested-lean-weakening-via-theorem-fragment)
            (cons "ingested-lean-substitution-via-theorem-fragment"
                  #'test-ingested-lean-substitution-via-theorem-fragment)
            (cons "ingested-lean-subject-reduction-via-theorem-fragment"
                  #'test-ingested-lean-subject-reduction-via-theorem-fragment)
            (cons "ingested-lean-krcheck-sound-via-relation-fragment"
                  #'test-ingested-lean-krcheck-sound-via-relation-fragment)
            (cons "bad-derivation-rejected" #'test-bad-derivation-rejected)))
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
