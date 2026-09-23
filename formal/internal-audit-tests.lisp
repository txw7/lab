(defpackage :mini-kernel-internal-audit-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-internal-audit-tests)

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

(defun test-core-closedn-p ()
  (is-true (mini-kernel:core-closedn-p 0 '(:sort 0)))
  (is-true (mini-kernel:core-closedn-p 1 '(:var 0)))
  (is-equal nil (mini-kernel:core-closedn-p 0 '(:var 0))))

(defun test-enumerate-bounded-core-terms ()
  (let ((terms (mini-kernel:enumerate-bounded-core-terms :depth 0 :binders 1)))
    (is-true (member '(:var 0) terms :test #'equal))
    (is-true (member '(:const mini-kernel::nat ()) terms :test #'equal))
    (is-true (member '(:sort 0) terms :test #'equal))))

(defun test-run-shift-closure-audit ()
  (let ((result (mini-kernel:run-shift-closure-audit :max-depth 1 :max-binders 2 :delta 1)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-true (plusp (getf (mini-kernel:backend-result-artifacts result) :checked)))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-run-subst-irrelevance-audit ()
  (let ((result (mini-kernel:run-subst-irrelevance-audit :max-depth 1 :max-binders 2)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-true (plusp (getf (mini-kernel:backend-result-artifacts result) :checked)))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-run-smt-normalization-audit ()
  (let ((result (mini-kernel:run-smt-normalization-audit)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-run-jd-substitution-audit ()
  (let ((result (mini-kernel:run-jd-substitution-audit :max-depth 0 :max-context-size 1)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal :jd-substitution
              (getf (mini-kernel:backend-result-artifacts result) :obligation-id))
    (is-true (typep (getf (mini-kernel:backend-result-artifacts result) :witness)
                    'mini-kernel:theorem-witness))
    (is-true (typep (getf (mini-kernel:backend-result-artifacts result) :fragment-certificate)
                    'mini-kernel:theorem-fragment-certificate))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-jd-substitution-fragment-certificate ()
  (let ((certificate (mini-kernel:emit-jd-substitution-fragment-certificate
                      :max-depth 0
                      :max-context-size 1)))
    (is-equal :jd-substitution
              (mini-kernel:theorem-fragment-certificate-obligation-id certificate))
    (is-equal :accepted
              (mini-kernel:theorem-fragment-certificate-status certificate))
    (is-true (plusp (mini-kernel:theorem-fragment-certificate-checked certificate)))
    (is-true (mini-kernel:verify-jd-substitution-fragment-certificate certificate))))

(defun test-run-jd-weakening-audit ()
  (let ((result (mini-kernel:run-jd-weakening-audit :max-depth 0 :max-context-size 1)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal :jd-weakening
              (getf (mini-kernel:backend-result-artifacts result) :obligation-id))
    (is-true (typep (getf (mini-kernel:backend-result-artifacts result) :witness)
                    'mini-kernel:theorem-witness))
    (is-true (typep (getf (mini-kernel:backend-result-artifacts result) :fragment-certificate)
                    'mini-kernel:theorem-fragment-certificate))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-jd-weakening-fragment-certificate ()
  (let ((certificate (mini-kernel:emit-jd-weakening-fragment-certificate
                      :max-depth 0
                      :max-context-size 1)))
    (is-equal :jd-weakening
              (mini-kernel:theorem-fragment-certificate-obligation-id certificate))
    (is-equal :accepted
              (mini-kernel:theorem-fragment-certificate-status certificate))
    (is-true (plusp (mini-kernel:theorem-fragment-certificate-checked certificate)))
    (is-true (mini-kernel:verify-jd-weakening-fragment-certificate certificate))))

(defun test-jd-subject-reduction-fragment-certificate ()
  (let ((certificate (mini-kernel:emit-jd-subject-reduction-fragment-certificate
                      :max-depth 0
                      :max-context-size 1)))
    (is-equal :jd-subject-reduction
              (mini-kernel:theorem-fragment-certificate-obligation-id certificate))
    (is-equal :accepted
              (mini-kernel:theorem-fragment-certificate-status certificate))
    (is-true (plusp (mini-kernel:theorem-fragment-certificate-checked certificate)))
    (is-true (mini-kernel:verify-jd-subject-reduction-fragment-certificate certificate))))

(defun test-run-jd-subject-reduction-audit ()
  (let ((result (mini-kernel:run-jd-subject-reduction-audit :max-depth 0 :max-context-size 1)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal :jd-subject-reduction
              (getf (mini-kernel:backend-result-artifacts result) :obligation-id))
    (is-true (plusp (getf (mini-kernel:backend-result-artifacts result) :checked)))
    (is-true (typep (getf (mini-kernel:backend-result-artifacts result) :fragment-certificate)
                    'mini-kernel:theorem-fragment-certificate))
    (is-true (typep (getf (mini-kernel:backend-result-artifacts result) :witness)
                    'mini-kernel:theorem-witness))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-kernel-spec-object ()
  (is-equal '(:sort :var :const :app :lam :pi :let)
            (getf mini-kernel:*kernel-spec* :core-terms))
  (is-equal '(:typing)
            (getf mini-kernel:*kernel-spec* :certificate-judgments))
  (is-true (mini-kernel:find-theorem-obligation :jkr-soundness))
  (is-true (mini-kernel:find-theorem-obligation :jkl-jkr-equivalence))
  (is-true (mini-kernel:find-theorem-obligation :jdefir-jkr-equivalence))
  (is-true (mini-kernel:find-theorem-obligation :stage1-jl-jr-equivalence))
  (is-true (mini-kernel:find-theorem-obligation :stage1-jr-soundness))
  (is-true (mini-kernel:find-theorem-obligation :smt-bridge-normalization))
  (is-true (mini-kernel:find-theorem-obligation :smt-bridge-boolean-unsat))
  (is-true (mini-kernel:find-theorem-obligation :smt-bridge-bitvector-unsat))
  (is-true (mini-kernel:find-theorem-obligation :smt-bridge-int-unsat))
  (is-true (mini-kernel:find-theorem-obligation :smt-bridge-affine-int-contradiction))
  (is-true (mini-kernel:find-theorem-obligation :smt-obligation-catalog)))

(defun test-kernel-core-and-bridge-registries ()
  (let* ((algorithms (mini-kernel:list-kernel-core-algorithms))
         (bridge-laws (mini-kernel:list-bridge-laws))
         (shift (mini-kernel:find-kernel-core-algorithm :shift))
         (whnf (mini-kernel:find-kernel-core-algorithm :whnf))
         (check (mini-kernel:find-kernel-core-algorithm :check)))
    (is-true (>= (length algorithms) 14))
    (is-equal :binding (mini-kernel:kernel-core-algorithm-layer shift))
    (is-equal :reduction (mini-kernel:kernel-core-algorithm-layer whnf))
    (is-equal :typing (mini-kernel:kernel-core-algorithm-layer check))
    (is-equal :jkr-soundness
              (mini-kernel:kernel-core-algorithm-theorem-target check))
    (is-equal 5 (length bridge-laws))
    (dolist (bridge-id '(:smt-bridge-normalization
                         :smt-bridge-boolean-unsat
                         :smt-bridge-bitvector-unsat
                         :smt-bridge-int-unsat
                         :smt-bridge-affine-int-contradiction))
      (let* ((bridge (mini-kernel:find-bridge-law bridge-id))
             (obligation (mini-kernel:find-smt-obligation-class
                          (mini-kernel:bridge-law-obligation-class-id bridge))))
        (is-true bridge)
        (is-true obligation)
        (is-equal :jsmt (mini-kernel:bridge-law-source-lane bridge))
        (is-equal :kernel-side-condition
                  (mini-kernel:bridge-law-target-lane bridge))
        (is-equal (mini-kernel:bridge-law-result-polarity bridge)
                  (mini-kernel:smt-obligation-class-polarity obligation))
        (is-equal (mini-kernel:bridge-law-side-predicate bridge)
                  (mini-kernel:smt-obligation-class-side-condition obligation))
        (is-equal (mini-kernel:bridge-law-projector bridge)
                  (mini-kernel:smt-obligation-class-projector obligation))))))

(defun test-smt-core-registry ()
  (let* ((algorithms (mini-kernel:list-smt-core-algorithms))
         (normalize (mini-kernel:find-smt-core-algorithm :normalize-smt-term))
         (bitblast (mini-kernel:find-smt-core-algorithm :bitblast-smt-term))
         (solve (mini-kernel:find-smt-core-algorithm :solve-cnf-dpll))
         (solve-assumptions
           (mini-kernel:find-smt-core-algorithm :solve-cnf-under-assumptions-dpll))
         (unsat-core (mini-kernel:find-smt-core-algorithm :smt-cnf-unsat-core))
         (normalization-bridge (mini-kernel:find-bridge-law :smt-bridge-normalization)))
    (is-true (>= (length algorithms) 12))
    (is-equal :term-semantics (mini-kernel:smt-core-algorithm-layer normalize))
    (is-equal :lowering (mini-kernel:smt-core-algorithm-layer bitblast))
    (is-equal :decision (mini-kernel:smt-core-algorithm-layer solve))
    (is-equal :decision (mini-kernel:smt-core-algorithm-layer solve-assumptions))
    (is-equal :fragment-audited (mini-kernel:smt-core-algorithm-status unsat-core))
    (is-equal :smt-bridge-normalization
              (mini-kernel:smt-core-algorithm-theorem-target normalize))
    (is-equal :smt-bridge-normalization
              (mini-kernel:bridge-law-theorem-target normalization-bridge))
    (is-true (mini-kernel:find-smt-core-algorithm :compile-boolean-core-to-cnf))
    (is-true (mini-kernel:find-smt-core-algorithm
              :compile-boolean-core-to-cnf-with-assumptions))
    (is-true (mini-kernel:find-smt-core-algorithm :compile-smt-to-cnf))
    (is-true (mini-kernel:find-smt-core-algorithm :compile-smt-to-cnf-with-assumptions))))

(defun test-admitted-obligation-class-registry ()
  (let ((classes (mini-kernel:list-admitted-obligation-classes)))
    (is-equal 5 (length classes))
    (dolist (id '(:o-normalization-equivalence
                  :o-closed-boolean-unsat
                  :o-closed-bitvector-unsat
                  :o-closed-int-unsat
                  :o-affine-int-contradiction))
      (let* ((entry (mini-kernel:find-admitted-obligation-class id))
             (class (mini-kernel:find-smt-obligation-class
                     (mini-kernel:admitted-obligation-class-smt-obligation-class-id entry)))
             (bridge (mini-kernel:find-bridge-law
                      (mini-kernel:admitted-obligation-class-theorem-target entry))))
        (is-true entry)
        (is-true class)
        (is-true bridge)
        (is-equal :jsmt (mini-kernel:admitted-obligation-class-source-lane entry))
        (is-equal :kernel-side-condition
                  (mini-kernel:admitted-obligation-class-target-lane entry))
        (is-equal (mini-kernel:admitted-obligation-class-result-polarity entry)
                  (mini-kernel:smt-obligation-class-polarity class))
        (is-equal (mini-kernel:admitted-obligation-class-side-predicate entry)
                  (mini-kernel:smt-obligation-class-side-condition class))
        (is-equal (mini-kernel:admitted-obligation-class-projector entry)
                  (mini-kernel:smt-obligation-class-projector class))
        (is-equal (mini-kernel:admitted-obligation-class-theorem-target entry)
                  (mini-kernel:bridge-law-theorem-target bridge))))))

(defun test-theorem-bridge-binding-registry ()
  (let ((bindings (mini-kernel:list-theorem-bridge-bindings)))
    (is-equal 5 (length bindings))
    (dolist (theorem-id '(:smt-bridge-normalization
                          :smt-bridge-boolean-unsat
                          :smt-bridge-bitvector-unsat
                          :smt-bridge-int-unsat
                          :smt-bridge-affine-int-contradiction))
      (let* ((binding (mini-kernel:find-theorem-bridge-binding theorem-id))
             (theorem (mini-kernel:find-theorem-obligation theorem-id))
             (admitted (and binding
                            (mini-kernel:find-admitted-obligation-class
                             (mini-kernel:theorem-bridge-binding-admitted-obligation-id
                              binding)))))
        (is-true binding)
        (is-true theorem)
        (is-true admitted)
        (is-equal theorem-id
                  (mini-kernel:theorem-bridge-binding-theorem-obligation-id binding))
        (is-equal (mini-kernel:theorem-bridge-binding-result-polarity binding)
                  (mini-kernel:admitted-obligation-class-result-polarity admitted))))))

(defun test-admitted-obligation-bridge-entrypoint ()
  (let ((normalization-formula
          (mini-kernel:smt-eq
           (mini-kernel:smt-bvadd (mini-kernel:smt-bv-lit 4 1)
                                  (mini-kernel:smt-bv-lit 4 2))
           (mini-kernel:smt-bv-lit 4 3)))
        (boolean-formula
          '(:and (:= (:bv-lit 1 0) (:bv-lit 1 1))
                 (:bool t)))
        (bitvector-formula
          '(:and (:= (:bv-lit 2 1) (:bv-lit 2 2))
                 (:= (:bv-lit 1 0) (:bv-lit 1 0))))
        (int-formula
          '(:and (:= (:int-lit 1) (:int-lit 1))
                 (:int-lt (:int-lit 2) (:int-lit 1))))
        (affine-int-formula
          '(:and (:int-ge (:var x (:Int)) (:int-lit 0))
                 (:int-lt (:var x (:Int)) (:int-lit 0)))))
    (is-true (mini-kernel:j-smt-admitted-obligation-bridge
              :o-normalization-equivalence normalization-formula))
    (is-true (mini-kernel:j-smt-admitted-obligation-bridge
              :o-closed-boolean-unsat boolean-formula))
    (is-true (mini-kernel:j-smt-admitted-obligation-bridge
              :o-closed-bitvector-unsat bitvector-formula))
    (is-true (mini-kernel:j-smt-admitted-obligation-bridge
              :o-closed-int-unsat int-formula))
    (is-true (mini-kernel:j-smt-admitted-obligation-bridge
              :o-affine-int-contradiction affine-int-formula))
    (is-equal
     (mini-kernel:project-admitted-obligation
      :o-closed-boolean-unsat boolean-formula)
     (mini-kernel:project-smt-obligation :closed-boolean-unsat boolean-formula))
    (is-equal
     (mini-kernel:admitted-obligation-side-condition
      :o-closed-bitvector-unsat bitvector-formula)
     (mini-kernel:smt-obligation-side-condition :closed-bitvector-unsat bitvector-formula))
    (is-equal
     (mini-kernel:admitted-obligation-side-condition
      :o-closed-int-unsat int-formula)
     (mini-kernel:smt-obligation-side-condition :closed-int-unsat int-formula))
    (is-equal
     (mini-kernel:admitted-obligation-side-condition
      :o-affine-int-contradiction affine-int-formula)
     (mini-kernel:smt-obligation-side-condition :affine-int-contradiction affine-int-formula))))

(defun test-executable-closure-backlog ()
  (let* ((backlog (mini-kernel:executable-closure-backlog))
         (summary (getf backlog :summary))
         (entry (mini-kernel:find-closure-backlog-entry :smt-obligation-catalog))
         (subst-entry (mini-kernel:find-closure-backlog-entry :jd-substitution))
         (weak-entry (mini-kernel:find-closure-backlog-entry :jd-weakening))
         (reduction-entry (mini-kernel:find-closure-backlog-entry :jd-subject-reduction)))
    (is-true entry)
    (is-true subst-entry)
    (is-true weak-entry)
    (is-equal :fragment-audited
              (mini-kernel:closure-backlog-entry-current-status subst-entry))
    (is-equal :fragment-audited
              (mini-kernel:closure-backlog-entry-current-status weak-entry))
    (is-equal :fragment-audited
              (mini-kernel:closure-backlog-entry-current-status reduction-entry))
    (is-equal :fragment-audited
              (mini-kernel:closure-backlog-entry-current-status entry))
    (is-equal :smt-bridge-affine-int-contradiction
              (mini-kernel:closure-backlog-entry-blocking-dependency entry))
    (is-true (>= (getf summary :total) 12))
    (is-true (>= (getf summary :fragment-audited) 11))
    (is-true (plusp (getf summary :fragment-audited)))))

(defun test-judgment-relations ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (judgment (mini-kernel:make-typing-judgment
                    '()
                    '(:const mini-kernel::zero ())
                    '(:const mini-kernel::nat ()))))
    (is-true (mini-kernel:j-d env judgment))
    (is-true (mini-kernel:j-kr reference-env judgment))
    (is-true (mini-kernel:j-kl env judgment))))

(defun test-smt-judgment-bridge ()
  (let ((formula (mini-kernel:smt-eq
                  (mini-kernel:smt-bvadd (mini-kernel:smt-bv-lit 4 1)
                                         (mini-kernel:smt-bv-lit 4 2))
                  (mini-kernel:smt-bv-lit 4 3))))
    (is-true (mini-kernel:normalization-side-condition formula))
    (is-true (mini-kernel:j-smt-normalization-bridge formula))))

(defun test-run-jd-jkr-equivalence-audit ()
  (let ((result (mini-kernel:run-jd-jkr-equivalence-audit :max-depth 0 :max-context-size 1)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-true (typep (getf (mini-kernel:backend-result-artifacts result) :fragment-certificate)
                    'mini-kernel:theorem-fragment-certificate))
    (is-true (> (getf (mini-kernel:backend-result-artifacts result) :checked) 113))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-run-jkr-jkl-equivalence-audit ()
  (let ((result (mini-kernel:run-jkr-jkl-equivalence-audit :max-depth 0 :max-context-size 1)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-true (typep (getf (mini-kernel:backend-result-artifacts result) :fragment-certificate)
                    'mini-kernel:theorem-fragment-certificate))
    (is-true (> (getf (mini-kernel:backend-result-artifacts result) :checked) 113))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-run-kernel-spec-kr-kl-audit ()
  (let* ((suite (mini-kernel:make-default-kernel-spec-suite))
         (result (mini-kernel:run-kernel-spec-kr-kl-audit suite))
         (artifacts (mini-kernel:backend-result-artifacts result))
         (summary (getf artifacts :summary)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal '(:kernel-spec-kr-kl-audit)
              (mini-kernel:backend-result-evidence result))
    (is-equal 24 (getf artifacts :checked))
    (is-equal 4 (getf artifacts :suite-size))
    (is-equal 24 (getf summary :total))
    (is-equal 24 (getf summary :matched))
    (is-equal 0 (getf summary :mismatched))
    (is-equal '() (getf artifacts :failures))))

(defun test-run-kernel-spec-kr-kl-defir-audit ()
  (let* ((suite (mini-kernel:make-default-kernel-spec-suite))
         (result (mini-kernel:run-kernel-spec-kr-kl-defir-audit suite))
         (artifacts (mini-kernel:backend-result-artifacts result))
         (summary (getf artifacts :summary)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal '(:kernel-spec-kr-kl-defir-audit)
              (mini-kernel:backend-result-evidence result))
    (is-equal 24 (getf artifacts :checked))
    (is-equal 4 (getf artifacts :suite-size))
    (is-equal 24 (getf summary :total))
    (is-equal 24 (getf summary :matched))
    (is-equal 0 (getf summary :mismatched))
    (is-equal '() (getf artifacts :failures))))

(defun test-jd-jkr-soundness-fragment-certificate ()
  (let ((certificate (mini-kernel:emit-jd-jkr-soundness-fragment-certificate
                      :max-depth 0 :max-context-size 1)))
    (is-equal :jkr-soundness
              (mini-kernel:theorem-fragment-certificate-obligation-id certificate))
    (is-equal :accepted (mini-kernel:theorem-fragment-certificate-status certificate))
    (is-true (plusp (mini-kernel:theorem-fragment-certificate-checked certificate))
             )
    (is-true (mini-kernel:verify-jd-jkr-soundness-fragment-certificate certificate))))

(defun test-run-stage1-jr-jl-equivalence-audit ()
  (let ((result (mini-kernel:run-stage1-jr-jl-equivalence-audit)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal :stage1-jl-jr-equivalence
              (getf (mini-kernel:backend-result-artifacts result) :obligation-id))
    (is-true (plusp (getf (mini-kernel:backend-result-artifacts result) :checked)))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-run-stage1-jr-soundness-audit ()
  (let ((result (mini-kernel:run-stage1-jr-soundness-audit)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal :stage1-jr-soundness
              (getf (mini-kernel:backend-result-artifacts result) :obligation-id))
    (is-true (plusp (getf (mini-kernel:backend-result-artifacts result) :checked)))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-run-jd-jkr-completeness-audit ()
  (let ((result (mini-kernel:run-jd-jkr-completeness-audit :max-depth 0 :max-context-size 1)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal :jkr-fragment-completeness
              (getf (mini-kernel:backend-result-artifacts result) :obligation-id))
    (is-true (typep (getf (mini-kernel:backend-result-artifacts result) :fragment-certificate)
                    'mini-kernel:theorem-fragment-certificate))
    (is-true (> (getf (mini-kernel:backend-result-artifacts result) :checked) 113))
    (is-true (typep (getf (mini-kernel:backend-result-artifacts result) :witness)
                    'mini-kernel:theorem-witness))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-jd-jkr-completeness-fragment-certificate ()
  (let ((certificate (mini-kernel:emit-jd-jkr-completeness-fragment-certificate
                      :max-depth 0 :max-context-size 1)))
    (is-equal :jkr-fragment-completeness
              (mini-kernel:theorem-fragment-certificate-obligation-id certificate))
    (is-equal :accepted (mini-kernel:theorem-fragment-certificate-status certificate))
    (is-true (plusp (mini-kernel:theorem-fragment-certificate-checked certificate))
             )
    (is-true (mini-kernel:verify-jd-jkr-fragment-completeness-fragment-certificate certificate))))

(defun test-jkr-jkl-equivalence-fragment-certificate ()
  (let ((certificate (mini-kernel:emit-jkr-jkl-equivalence-fragment-certificate
                      :max-depth 0 :max-context-size 1)))
    (is-equal :jkl-jkr-equivalence
              (mini-kernel:theorem-fragment-certificate-obligation-id certificate))
    (is-equal :accepted (mini-kernel:theorem-fragment-certificate-status certificate))
    (is-true (plusp (mini-kernel:theorem-fragment-certificate-checked certificate))
             )
    (is-true (mini-kernel:verify-jkr-jkl-equivalence-fragment-certificate certificate))))

(defun test-jkr-defir-equivalence-fragment-certificate ()
  (let ((certificate (mini-kernel:emit-jkr-defir-equivalence-fragment-certificate
                      :max-depth 0 :max-context-size 1)))
    (is-equal :jdefir-jkr-equivalence
              (mini-kernel:theorem-fragment-certificate-obligation-id certificate))
    (is-equal :accepted (mini-kernel:theorem-fragment-certificate-status certificate))
    (is-true (plusp (mini-kernel:theorem-fragment-certificate-checked certificate)))
    (is-true (mini-kernel:verify-jkr-defir-equivalence-fragment-certificate certificate))))

(defun test-run-smt-normalization-bridge-audit ()
  (let ((result (mini-kernel:run-smt-normalization-bridge-audit)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal :smt-bridge-normalization
              (getf (mini-kernel:backend-result-artifacts result) :obligation-id))
    (is-true (typep (getf (mini-kernel:backend-result-artifacts result) :witness)
                    'mini-kernel:theorem-witness))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-run-smt-boolean-unsat-bridge-audit ()
  (let ((result (mini-kernel:run-smt-boolean-unsat-bridge-audit)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal :smt-bridge-boolean-unsat
              (getf (mini-kernel:backend-result-artifacts result) :obligation-id))
    (is-true (typep (getf (mini-kernel:backend-result-artifacts result) :witness)
                    'mini-kernel:theorem-witness))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-run-smt-bitvector-unsat-bridge-audit ()
  (let ((result (mini-kernel:run-smt-bitvector-unsat-bridge-audit)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal :smt-bridge-bitvector-unsat
              (getf (mini-kernel:backend-result-artifacts result) :obligation-id))
    (is-true (typep (getf (mini-kernel:backend-result-artifacts result) :witness)
                    'mini-kernel:theorem-witness))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-run-smt-int-unsat-bridge-audit ()
  (let ((result (mini-kernel:run-smt-int-unsat-bridge-audit)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal :smt-bridge-int-unsat
              (getf (mini-kernel:backend-result-artifacts result) :obligation-id))
    (is-true (typep (getf (mini-kernel:backend-result-artifacts result) :witness)
                    'mini-kernel:theorem-witness))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-run-smt-affine-int-contradiction-bridge-audit ()
  (let ((result (mini-kernel:run-smt-affine-int-contradiction-bridge-audit)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal :smt-bridge-affine-int-contradiction
              (getf (mini-kernel:backend-result-artifacts result) :obligation-id))
    (is-true (typep (getf (mini-kernel:backend-result-artifacts result) :witness)
                    'mini-kernel:theorem-witness))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-run-smt-obligation-catalog-audit ()
  (let ((result (mini-kernel:run-smt-obligation-catalog-audit)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal :smt-obligation-catalog
              (getf (mini-kernel:backend-result-artifacts result) :obligation-id))
    (is-true (typep (getf (mini-kernel:backend-result-artifacts result) :witness)
                    'mini-kernel:theorem-witness))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-find-theorem-audit-runner ()
  (is-true (functionp (mini-kernel:find-theorem-audit-runner :jkr-soundness)))
  (is-equal nil (mini-kernel:find-theorem-audit-runner :missing-obligation)))

(defun test-run-theorem-obligation-audit ()
  (let ((result (mini-kernel:run-theorem-obligation-audit
                 :jkr-soundness :max-depth 0 :max-context-size 1)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal :jkr-soundness
              (getf (mini-kernel:backend-result-artifacts result) :obligation-id))
    (is-true (typep (getf (mini-kernel:backend-result-artifacts result) :witness)
                    'mini-kernel:theorem-witness))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-run-jdefir-theorem-obligation-audit ()
  (let ((result (mini-kernel:run-theorem-obligation-audit
                 :jdefir-jkr-equivalence :max-depth 0 :max-context-size 1)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal :jdefir-jkr-equivalence
              (getf (mini-kernel:backend-result-artifacts result) :obligation-id))
    (is-true (typep (getf (mini-kernel:backend-result-artifacts result) :witness)
                    'mini-kernel:theorem-witness))
    (is-true (typep (getf (mini-kernel:backend-result-artifacts result) :fragment-certificate)
                    'mini-kernel:theorem-fragment-certificate))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-evaluate-metakernel-closure ()
  (let ((result (mini-kernel:evaluate-metakernel-closure
                 :obligation-ids '(:jkr-soundness :jkl-jkr-equivalence
                                   :jdefir-jkr-equivalence
                                   :stage1-jl-jr-equivalence
                                   :stage1-jr-soundness
                                   :smt-bridge-normalization
                                   :smt-bridge-boolean-unsat
                                   :smt-bridge-bitvector-unsat
                                   :smt-bridge-int-unsat
                                   :smt-bridge-affine-int-contradiction
                                   :smt-obligation-catalog)
                 :max-depth 0
                 :max-context-size 1)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))
    (is-equal 11 (length (getf (mini-kernel:backend-result-artifacts result) :results)))))

(defun test-find-metakernel-closure-profile ()
  (is-true (mini-kernel:find-metakernel-closure-profile :quick))
  (is-true (mini-kernel:find-metakernel-closure-profile :strengthened))
  (is-true (mini-kernel:find-metakernel-closure-profile :relational-strengthened))
  (is-equal nil (mini-kernel:find-metakernel-closure-profile :missing-profile)))

(defun test-evaluate-metakernel-closure-profile ()
  (let ((result (mini-kernel:evaluate-metakernel-closure-profile :quick)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal :quick
              (getf (mini-kernel:backend-result-artifacts result) :profile-id))
    (is-equal 15
              (length (getf (mini-kernel:backend-result-artifacts result) :results)))
    (is-equal 15
              (getf (getf (mini-kernel:backend-result-artifacts result) :summary)
                    :accepted))
    (is-equal 0
              (getf (getf (mini-kernel:backend-result-artifacts result) :summary)
                    :rejected))))

(defun test-relational-strengthened-closure-profile-shape ()
  (let ((profile (mini-kernel:find-metakernel-closure-profile :relational-strengthened)))
    (is-true profile)
    (is-true (member '(:jkr-soundness :max-depth 1 :max-context-size 1 :carrier-mode :dense)
                     profile :test #'equal))
    (is-true (member '(:jkr-fragment-completeness :max-depth 1 :max-context-size 1 :carrier-mode :dense)
                     profile :test #'equal))
    (is-true (member '(:jkl-jkr-equivalence :max-depth 1 :max-context-size 1 :carrier-mode :dense)
                     profile :test #'equal))
    (is-true (member '(:jdefir-jkr-equivalence :max-depth 1 :max-context-size 1 :carrier-mode :dense)
                     profile :test #'equal))))

(defun test-evaluate-relational-strengthened-closure-profile ()
  (let* ((result (mini-kernel:evaluate-metakernel-closure-profile :relational-strengthened))
         (summary (getf (mini-kernel:backend-result-artifacts result) :summary)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal :relational-strengthened
              (getf (mini-kernel:backend-result-artifacts result) :profile-id))
    (is-equal 15 (getf summary :accepted))
    (is-equal 0 (getf summary :rejected))
    (is-true (>= (getf summary :checked-total) 2000))))

(defun test-run-kr-kl-disagreement-audit ()
  (let ((result (mini-kernel:run-kr-kl-disagreement-audit :max-depth 0 :max-context-size 1)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-run-kr-defir-disagreement-audit ()
  (let ((result (mini-kernel:run-kr-defir-disagreement-audit :max-depth 0 :max-context-size 1)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-run-jkr-defir-equivalence-audit ()
  (let ((result (mini-kernel:run-jkr-defir-equivalence-audit :max-depth 0
                                                             :max-context-size 1)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-true (plusp (getf (mini-kernel:backend-result-artifacts result) :checked)))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun test-run-whnf-agreement-audit ()
  (let ((result (mini-kernel:run-whnf-agreement-audit :max-depth 1 :max-binders 1)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal '() (getf (mini-kernel:backend-result-artifacts result) :failures))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "core-closedn-p" #'test-core-closedn-p)
            (cons "enumerate-bounded-core-terms" #'test-enumerate-bounded-core-terms)
            (cons "kernel-spec-object" #'test-kernel-spec-object)
            (cons "kernel-core-and-bridge-registries"
                  #'test-kernel-core-and-bridge-registries)
            (cons "smt-core-registry" #'test-smt-core-registry)
            (cons "admitted-obligation-class-registry"
                  #'test-admitted-obligation-class-registry)
            (cons "theorem-bridge-binding-registry"
                  #'test-theorem-bridge-binding-registry)
            (cons "admitted-obligation-bridge-entrypoint"
                  #'test-admitted-obligation-bridge-entrypoint)
            (cons "executable-closure-backlog" #'test-executable-closure-backlog)
            (cons "judgment-relations" #'test-judgment-relations)
            (cons "smt-judgment-bridge" #'test-smt-judgment-bridge)
            (cons "run-jd-jkr-equivalence-audit" #'test-run-jd-jkr-equivalence-audit)
            (cons "jd-jkr-soundness-fragment-certificate"
                  #'test-jd-jkr-soundness-fragment-certificate)
            (cons "run-jd-jkr-completeness-audit" #'test-run-jd-jkr-completeness-audit)
            (cons "jd-jkr-completeness-fragment-certificate"
                  #'test-jd-jkr-completeness-fragment-certificate)
            (cons "run-jkr-jkl-equivalence-audit" #'test-run-jkr-jkl-equivalence-audit)
            (cons "run-kernel-spec-kr-kl-audit" #'test-run-kernel-spec-kr-kl-audit)
            (cons "run-kernel-spec-kr-kl-defir-audit"
                  #'test-run-kernel-spec-kr-kl-defir-audit)
            (cons "jkr-jkl-equivalence-fragment-certificate"
                  #'test-jkr-jkl-equivalence-fragment-certificate)
            (cons "jkr-defir-equivalence-fragment-certificate"
                  #'test-jkr-defir-equivalence-fragment-certificate)
            (cons "run-stage1-jr-jl-equivalence-audit"
                  #'test-run-stage1-jr-jl-equivalence-audit)
            (cons "run-stage1-jr-soundness-audit"
                  #'test-run-stage1-jr-soundness-audit)
            (cons "run-smt-normalization-bridge-audit" #'test-run-smt-normalization-bridge-audit)
            (cons "run-smt-boolean-unsat-bridge-audit"
                  #'test-run-smt-boolean-unsat-bridge-audit)
            (cons "run-smt-bitvector-unsat-bridge-audit"
                  #'test-run-smt-bitvector-unsat-bridge-audit)
            (cons "run-smt-int-unsat-bridge-audit"
                  #'test-run-smt-int-unsat-bridge-audit)
            (cons "run-smt-affine-int-contradiction-bridge-audit"
                  #'test-run-smt-affine-int-contradiction-bridge-audit)
            (cons "run-smt-obligation-catalog-audit"
                  #'test-run-smt-obligation-catalog-audit)
            (cons "find-theorem-audit-runner" #'test-find-theorem-audit-runner)
            (cons "run-theorem-obligation-audit" #'test-run-theorem-obligation-audit)
            (cons "run-jdefir-theorem-obligation-audit"
                  #'test-run-jdefir-theorem-obligation-audit)
            (cons "evaluate-metakernel-closure" #'test-evaluate-metakernel-closure)
            (cons "find-metakernel-closure-profile" #'test-find-metakernel-closure-profile)
            (cons "evaluate-metakernel-closure-profile" #'test-evaluate-metakernel-closure-profile)
            (cons "relational-strengthened-closure-profile-shape"
                  #'test-relational-strengthened-closure-profile-shape)
            (cons "evaluate-relational-strengthened-closure-profile"
                  #'test-evaluate-relational-strengthened-closure-profile)
            (cons "run-jd-substitution-audit" #'test-run-jd-substitution-audit)
            (cons "jd-substitution-fragment-certificate"
                  #'test-jd-substitution-fragment-certificate)
            (cons "run-jd-weakening-audit" #'test-run-jd-weakening-audit)
            (cons "jd-weakening-fragment-certificate"
                  #'test-jd-weakening-fragment-certificate)
            (cons "jd-subject-reduction-fragment-certificate"
                  #'test-jd-subject-reduction-fragment-certificate)
            (cons "run-jd-subject-reduction-audit" #'test-run-jd-subject-reduction-audit)
            (cons "run-shift-closure-audit" #'test-run-shift-closure-audit)
            (cons "run-subst-irrelevance-audit" #'test-run-subst-irrelevance-audit)
            (cons "run-smt-normalization-audit" #'test-run-smt-normalization-audit)
            (cons "run-kr-kl-disagreement-audit" #'test-run-kr-kl-disagreement-audit)
            (cons "run-kr-defir-disagreement-audit" #'test-run-kr-defir-disagreement-audit)
            (cons "run-jkr-defir-equivalence-audit" #'test-run-jkr-defir-equivalence-audit)
            (cons "run-whnf-agreement-audit" #'test-run-whnf-agreement-audit)))
         (passed 0)
         (failed 0))
    (dolist (test tests)
      (if (run-test (car test) (cdr test))
          (incf passed)
          (incf failed)))
    (format t "~%passed: ~D failed: ~D~%" passed failed)
    (when (plusp failed)
      (fail-test "internal audit test suite failed"))
    t))
