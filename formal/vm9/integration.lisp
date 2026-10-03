;; Additive proposer and admission boundary. No replacement theorem checker.
(defpackage :vm9-lab
  (:use :cl)
  (:local-nicknames (:k :mini-kernel) (:kr :mini-kernel-reference)))
(in-package :vm9-lab)

(defparameter *lab-pin* "50b9430f0ef8c62caa0ef37d9cf54b942534a612")
(defparameter *external-tcb*
  '("rustc-8925ea358-source-to-mir" "kani-0.68-transformation-and-rust-model"
    "cbmc-6.11-cadical-result" "host-process-filesystem-integrity"
    "vm9-external-replay-checker-v1"))
(defparameter *residual-kinds*
  '(:normative-to-core :rust-to-core :verus-to-core :kani-to-core
    :whole-vm-composition :source-to-runtime :source-mutation-coverage
    :recursive-correspondence :independent-external-proof :child-interface-tcb
    :durability-replay :digest-convergence :downstream-admission-execution))
(defstruct residual-obligation kind source-ref target evidence-ref assumptions status)
(defstruct refinement-envelope schema inputs model-certificates residuals authority)

(defun fail (format-control &rest args) (apply #'error format-control args))
(defun app (name &rest args) (k::app* (k::mk-const name) args))
(defun nat () (k::nat-type))
(defun eqn (lhs rhs) (k::eq-term (nat) lhs rhs))
(defun successor (n) (k::succ-term n))
(defun numeral (n)
  (loop with term = (k::zero-term) repeat n do (setf term (successor term))
        finally (return term)))

(defun environment-identity (env)
  ;; The original certificate field accepts an arbitrary structural digest.
  ;; Use the FULL sorted environment, not an unauthenticated label or hash.
  (list :vm9-full-environment-v1 *lab-pin*
        (sort (loop for name being the hash-keys of env using (hash-value decl)
                    collect (list name (k::decl-kind decl) (k::decl-type decl)
                                  (k::decl-value decl) (k::decl-reduciblep decl)))
              #'string< :key (lambda (entry) (symbol-name (first entry))))))

(defun check-closed-certificate (env certificate)
  (unless (null (k::certificate-context certificate))
    (fail "local assumptions forbidden in native model certificate"))
  (let ((identity (environment-identity env)))
    (k::check-certificate env certificate :expected-env-digest identity
                         :checker-implementation (k::native-kernel-implementation))
    (kr::check-certificate (kr::make-reference-env env) certificate
                          :expected-env-digest identity))
  certificate)

(defun certificate (env id term type)
  (k::proof-fragment->certificate
   (k::make-proof-fragment
    (k::make-has-type-claim '() term type)
    (k::make-proof-evidence :lam :checkedp nil)
    :checker-ids '(k::kernel-check)
    :metadata (list :certificate-id id :scope :abstract-phase-budget-model))
   (environment-identity env)))

(defun admit-model-definition (env name term type)
  ;; No unchecked ENV-ADD: both unmodified owners recheck the term first.
  (check-closed-certificate env (certificate env name term type))
  (k::env-add env name (k::make-decl :kind :def :type type :value term :reduciblep t)))

(defun congruence-type ()
  (k::mk-pi (nat) (k::mk-pi (nat)
    (k::mk-pi (eqn (k::mk-var 1) (k::mk-var 0))
      (eqn (successor (k::mk-var 2)) (successor (k::mk-var 1)))))))

(defun congruence-proof ()
  ;; forall a b : Nat, Eq a b -> Eq (succ a) (succ b), using Eq recursor.
  (k::mk-lam (nat) (k::mk-lam (nat)
    (k::mk-lam (eqn (k::mk-var 1) (k::mk-var 0))
      (app 'k::eq-rec (nat) (k::mk-var 2)
        (k::mk-lam (nat)
          (k::mk-lam (eqn (k::mk-var 3) (k::mk-var 0))
            (eqn (successor (k::mk-var 4)) (successor (k::mk-var 1)))))
        (k::refl-term (nat) (successor (k::mk-var 2)))
        (k::mk-var 1) (k::mk-var 0))))))

(defun make-smoke-environment ()
  (let ((env (k::make-bootstrap-env)))
    (k::validate-environment env)
    (admit-model-definition env 'cursor-succ-congruence
                            (congruence-proof) (congruence-type))
    (admit-model-definition env 'prefix-count
      (k::mk-lam (nat) (app 'k::add (k::mk-var 0) (k::zero-term)))
      (k::mk-pi (nat) (nat)))
    env))

(defun prefix-count-type ()
  (k::mk-pi (nat) (eqn (app 'prefix-count (k::mk-var 0)) (k::mk-var 0))))

(defun prefix-count-proof ()
  ;; Induction over arbitrary Nat, not an enumerated solver pass.
  (app 'k::nat-rec
    (k::mk-lam (nat) (eqn (app 'prefix-count (k::mk-var 0)) (k::mk-var 0)))
    (k::refl-term (nat) (k::zero-term))
    (k::mk-lam (nat)
      (k::mk-lam (eqn (app 'prefix-count (k::mk-var 0)) (k::mk-var 0))
        (app 'cursor-succ-congruence (app 'prefix-count (k::mk-var 1))
             (k::mk-var 1) (k::mk-var 0))))))

(defun smoke-certificates (env)
  (list
   (certificate env :prefix-count-identity
                (prefix-count-proof) (prefix-count-type))
   (certificate env :nine-phase-count
                (k::mk-app (prefix-count-proof) (numeral 9))
                (eqn (app 'prefix-count (numeral 9)) (numeral 9)))
   (certificate env :next-cursor
                (k::mk-lam (nat) (k::refl-term (nat) (successor (app 'prefix-count (k::mk-var 0)))))
                (k::mk-pi (nat)
                  (eqn (app 'prefix-count (successor (k::mk-var 0)))
                       (successor (app 'prefix-count (k::mk-var 0))))))))

(defun make-residuals (source-ref evidence-ref)
  (mapcar
   (lambda (kind)
     (make-residual-obligation
      :kind kind :source-ref source-ref :evidence-ref evidence-ref
      :target (case kind
        (:normative-to-core "TLA/VM9 contracts refine this Nat cursor model")
        (:rust-to-core "actual run_tick and all state owners refine core model")
        (:verus-to-core "Verus proof and extraction map reify to core certificates")
        (:kani-to-core "bounded Kani result reifies to core certificates")
        (:whole-vm-composition "all VM9 phases/contracts/configurations compose")
        (:source-to-runtime "compiler/ABI/binary/host execution refines source")
        (:source-mutation-coverage "every authoritative source mutation and boundary has a semantic mapping")
        (:recursive-correspondence "H001/H002 and Goggles recursive reactor retain reversible source correspondence")
        (:independent-external-proof "independent Lean/Isabelle semantics and refinement proof binds the same subject")
        (:child-interface-tcb "every child authority has a proof/interface contract or explicit TCB identity")
        (:durability-replay "restart/crash/concurrency/reconciliation preserve logical effect identity")
        (:digest-convergence "internal/external state, transition, reactor, theorem and correspondence digests agree")
        (:downstream-admission-execution "closure is admitted by Canon before materialization and execution"))
      :assumptions (copy-list *external-tcb*) :status :open))
   *residual-kinds*))

(defun make-candidate (inputs)
  (let ((env (make-model-environment)))
    (make-refinement-envelope
      :schema :vm9-lab-refinement-v1 :inputs (copy-tree inputs)
      :model-certificates (model-certificates env)
      :residuals (make-residuals (getf inputs :source-ref) (getf inputs :evidence-ref))
      :authority :abstract-phase-model-only)))

(defun recheck-envelope (envelope expected-inputs)
  ;; Caller must supply independently verified current inputs, never the
  ;; envelope's own digest as its expected digest. replay.py supplies these.
  (unless (eq (refinement-envelope-schema envelope) :vm9-lab-refinement-v1)
    (fail "unknown envelope schema"))
  (unless (and (getf expected-inputs :source-ref) (getf expected-inputs :evidence-ref)
               (getf expected-inputs :binding-sha256)
               (equal (refinement-envelope-inputs envelope) expected-inputs))
    (fail "stale or mismatched input binding"))
  (unless (eq (refinement-envelope-authority envelope) :abstract-phase-model-only)
    (fail "unproved authority escalation"))
  (let* ((env (make-model-environment))
         (certificates (refinement-envelope-model-certificates envelope))
         (expected (model-certificates env))
         (residuals (refinement-envelope-residuals envelope)))
    (unless (and (= (length certificates) (length expected))
                 (equal (mapcar #'residual-obligation-kind residuals) *residual-kinds*))
      (fail "missing model claim or residual obligation"))
    (loop for actual in certificates for wanted in expected do
      (unless (equal (k::certificate-type actual) (k::certificate-type wanted))
        (fail "certificate statement substitution"))
      ;; IDs, metadata and checkedp are never read as logical authority.
      (check-closed-certificate env actual))
    (loop for residual in residuals
          for wanted in (make-residuals (getf expected-inputs :source-ref)
                                        (getf expected-inputs :evidence-ref)) do
      (unless (and (equal (residual-obligation-target residual)
                          (residual-obligation-target wanted)) (eq (residual-obligation-status residual) :open)
                   (equal (residual-obligation-assumptions residual) *external-tcb*)
                   (equal (residual-obligation-source-ref residual)
                          (getf expected-inputs :source-ref))
                   (equal (residual-obligation-evidence-ref residual)
                          (getf expected-inputs :evidence-ref)))
        (fail "residual proof/assumption/source laundering")))
    ;; Existing advisory store, never trusted declaration store.
    (let ((store (k::make-advisory-store)))
      (k::emit-advisory-artifact store 'k::model-check :report
        (list :authority :abstract-phase-model-only :source-ref (getf expected-inputs :source-ref)
              :native-checked 2 :reference-checked 2 :residuals residuals)
        '(:external-status :advisory :full-vm9-refinement :open))
      (values certificates store))))

(defun certificate->wire (c)
  (list :schema (k::certificate-schema-version c)
        :judgment (k::certificate-judgment-kind c)
        :context (k::certificate-context c) :term (k::certificate-term c)
        :type (k::certificate-type c) :environment (k::certificate-env-digest c)
        :config (k::certificate-config-digest c)))
(defun wire->certificate (wire)
  (unless (equal (loop for (key value) on wire by #'cddr collect key)
                 '(:schema :judgment :context :term :type :environment :config))
    (fail "noncanonical certificate fields"))
  (k::make-certificate
   :schema-version (getf wire :schema) :judgment-kind (getf wire :judgment)
   :context (getf wire :context) :term (getf wire :term) :type (getf wire :type)
   :env-digest (getf wire :environment) :config-digest (getf wire :config)
   :checker-ids '() :metadata '()))
(defun write-certificates (path certificates)
  (with-open-file (stream path :direction :output :if-exists :supersede)
    (with-standard-io-syntax
      (let ((*print-circle* nil))
        (write (mapcar #'certificate->wire certificates) :stream stream)))))
(defun read-certificates (path)
  (with-open-file (stream path)
    (with-standard-io-syntax
      (let* ((*read-eval* nil) (wire (read stream nil :missing)))
        (unless (eq (read stream nil :eof) :eof) (fail "trailing certificate data"))
        (mapcar #'wire->certificate wire)))))

(defun residual->wire (r)
  (list :kind (residual-obligation-kind r) :source (residual-obligation-source-ref r)
        :target (residual-obligation-target r) :evidence (residual-obligation-evidence-ref r)
        :assumptions (residual-obligation-assumptions r) :status (residual-obligation-status r)))
(defun wire->residual (w)
  (unless (equal (loop for (key value) on w by #'cddr collect key)
                 '(:kind :source :target :evidence :assumptions :status))
    (fail "noncanonical residual fields"))
  (make-residual-obligation :kind (getf w :kind) :source-ref (getf w :source)
   :target (getf w :target) :evidence-ref (getf w :evidence)
   :assumptions (getf w :assumptions) :status (getf w :status)))
(defun write-envelope (path envelope)
  (with-open-file (stream path :direction :output :if-exists :supersede)
    (with-standard-io-syntax
      (let ((*print-circle* nil))
        (write (list :schema (refinement-envelope-schema envelope)
                     :inputs (refinement-envelope-inputs envelope)
                     :certificates (mapcar #'certificate->wire (refinement-envelope-model-certificates envelope))
                     :residuals (mapcar #'residual->wire (refinement-envelope-residuals envelope))
                     :authority (refinement-envelope-authority envelope)) :stream stream)))))
(defun read-envelope (path)
  (let ((text (uiop:read-file-string path)))
    (when (or (> (length text) 2097152) (find #\# text))
      (fail "oversized or dispatch-reader envelope forbidden"))
    (with-input-from-string (stream text)
      (with-standard-io-syntax
        (let* ((*read-eval* nil) (w (read stream nil :missing)))
          (unless (eq (read stream nil :eof) :eof) (fail "trailing envelope data"))
          (unless (equal (loop for (key value) on w by #'cddr collect key)
                         '(:schema :inputs :certificates :residuals :authority))
            (fail "noncanonical envelope fields"))
          (make-refinement-envelope :schema (getf w :schema) :inputs (getf w :inputs)
           :model-certificates (mapcar #'wire->certificate (getf w :certificates))
           :residuals (mapcar #'wire->residual (getf w :residuals))
           :authority (getf w :authority)))))))
