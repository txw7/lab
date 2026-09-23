(in-package :mini-kernel)

;; Loaded before certificate machinery; declare the configuration variable so
;; the judgment layer can refer to the frozen digest without compile-time noise.
(defvar *current-config-digest*)

(defstruct kernel-judgment
  context
  term
  type
  config
  judgment-kind)

(defstruct smt-judgment
  formula
  config
  expected-status)

(defstruct smt-obligation-class
  id
  polarity
  statement
  fragment-predicate
  side-condition
  projector)

(defstruct theorem-obligation
  id
  lane
  relation
  statement
  witness-kind)

(defstruct theorem-counterexample
  obligation-id
  lane
  relation
  payload)

(defstruct theorem-witness
  obligation-id
  lane
  relation
  checked
  payload)

(defstruct theorem-fragment-certificate
  obligation-id
  parameters
  checked
  payload-digest
  status
  config-digest)

(defstruct kernel-core-algorithm
  id
  layer
  status
  theorem-target
  callable
  note)

(defstruct bridge-law
  id
  obligation-class-id
  source-lane
  target-lane
  result-polarity
  side-predicate
  projector
  statement
  theorem-target)

(defstruct smt-core-algorithm
  id
  layer
  status
  theorem-target
  callable
  note)

(defstruct admitted-obligation-class
  id
  source-lane
  target-lane
  smt-obligation-class-id
  result-polarity
  fragment-predicate
  side-predicate
  projector
  statement
  theorem-target)

(defstruct theorem-bridge-binding
  theorem-obligation-id
  admitted-obligation-id
  result-polarity
  note)

(defstruct closure-backlog-entry
  id
  lane
  current-status
  target-relation
  required-theorem
  dependencies
  blocking-dependency
  notes)

(defparameter *kernel-spec*
  '(:core-terms (:sort :var :const :app :lam :pi :let)
    :certificate-schema-version 1
    :certificate-judgments (:typing)
    :reduction (:beta :zeta :delta :iota-nat :iota-eq)
    :conversion (:whnf-structural)
    :trusted-kernel-functions (shift subst subst-top whnf conv? infer check validate-certificate check-certificate)
    :reference-checker (mini-kernel-reference:validate-certificate
                        mini-kernel-reference:check-certificate)))

(defparameter *kernel-core-algorithms*
  (list
   (make-kernel-core-algorithm :id :shiftIndex :layer :binding :status :implemented
                               :theorem-target :jd-weakening :callable 'shift
                               :note "Index lifting above cutoff in the frozen core carrier.")
   (make-kernel-core-algorithm :id :shift :layer :binding :status :implemented
                               :theorem-target :jd-weakening :callable 'shift
                               :note "Capture-avoiding de Bruijn shift on core terms.")
   (make-kernel-core-algorithm :id :subst :layer :binding :status :implemented
                               :theorem-target :jd-substitution :callable 'subst
                               :note "Capture-avoiding substitution on core terms.")
   (make-kernel-core-algorithm :id :subst-top :layer :binding :status :implemented
                               :theorem-target :jd-substitution :callable 'subst-top
                               :note "Top-level binder discharge via substitution.")
   (make-kernel-core-algorithm :id :instantiate :layer :binding :status :implemented
                               :theorem-target :jd-substitution :callable 'subst-top
                               :note "Instantiation on the frozen core fragment.")
   (make-kernel-core-algorithm :id :lookup :layer :binding :status :implemented
                               :theorem-target :jd-weakening :callable 'mini-kernel::ctx-lookup
                               :note "Context lookup with de Bruijn lifting discipline.")
   (make-kernel-core-algorithm :id :closedn :layer :binding :status :fragment-audited
                               :theorem-target :jd-substitution :callable 'core-closedn-p
                               :note "Well-scopedness predicate for the frozen core carrier.")
   (make-kernel-core-algorithm :id :reduceNatRec :layer :reduction :status :implemented
                               :theorem-target :jd-subject-reduction :callable 'mini-kernel::reduce-nat-rec
                               :note "Iota reduction for nat recursors.")
   (make-kernel-core-algorithm :id :reduceEqRec :layer :reduction :status :implemented
                               :theorem-target :jd-subject-reduction :callable 'mini-kernel::reduce-eq-rec
                               :note "Iota reduction for equality recursors.")
   (make-kernel-core-algorithm :id :whnf :layer :reduction :status :implemented
                               :theorem-target :jd-subject-reduction :callable 'whnf
                               :note "Weak-head normalization on the frozen core fragment.")
   (make-kernel-core-algorithm :id :conv :layer :reduction :status :implemented
                               :theorem-target :jkr-soundness :callable 'conv?
                               :note "Definitional equality / conversion for the kernel fragment.")
   (make-kernel-core-algorithm :id :checkSort :layer :typing :status :implemented
                               :theorem-target :jkr-soundness :callable 'check-sort
                               :note "Sort checking for binder and type positions.")
   (make-kernel-core-algorithm :id :infer :layer :typing :status :implemented
                               :theorem-target :jkr-soundness :callable 'infer
                               :note "Type inference on explicit frozen core terms.")
   (make-kernel-core-algorithm :id :check :layer :typing :status :implemented
                               :theorem-target :jkr-soundness :callable 'check
                               :note "Conversion-aware type checking on the frozen core fragment.")))

(defun find-kernel-core-algorithm (id)
  (find id *kernel-core-algorithms* :key #'kernel-core-algorithm-id :test #'eq))

(defun list-kernel-core-algorithms ()
  (copy-list *kernel-core-algorithms*))

(defparameter *smt-core-algorithms*
  (list
   (make-smt-core-algorithm :id :eval-smt-term :layer :term-semantics :status :implemented
                            :theorem-target :jsmt-normalization-soundness :callable 'eval-smt-term
                            :note "Closed SMT evaluator for the admitted Bool/BV/Int fragment.")
   (make-smt-core-algorithm :id :normalize-smt-term :layer :term-semantics :status :implemented
                            :theorem-target :smt-bridge-normalization :callable 'normalize-smt-term
                            :note "Canonical normalization on the admitted SMT fragment.")
   (make-smt-core-algorithm :id :smt-sort-check :layer :term-semantics :status :implemented
                            :theorem-target :jsmt-fragment-well-sortedness :callable 'mini-kernel::%smtlib-ast-sort
                            :note "Sort computation/checking for admitted SMT terms.")
   (make-smt-core-algorithm :id :lower-smt-to-boolean-core :layer :lowering :status :implemented
                            :theorem-target :jsmt-boolean-core-lowering-soundness :callable 'lower-smt-to-boolean-core
                            :note "Lowering from the admitted SMT term language into Boolean core.")
   (make-smt-core-algorithm :id :compile-boolean-core-to-cnf :layer :lowering :status :implemented
                            :theorem-target :jsmt-cnf-lowering-soundness :callable 'compile-boolean-core-to-cnf
                            :note "CNF/Tseitin lowering for Boolean core.")
   (make-smt-core-algorithm :id :compile-boolean-core-to-cnf-with-assumptions
                            :layer :lowering :status :implemented
                            :theorem-target :jsmt-assumption-lowering-soundness
                            :callable 'compile-boolean-core-to-cnf-with-assumptions
                            :note "Assumption-aware CNF lowering for Boolean core.")
   (make-smt-core-algorithm :id :bitblast-smt-term :layer :lowering :status :implemented
                            :theorem-target :jsmt-bitblast-soundness :callable 'bitblast-smt-term
                            :note "Bit-blasting for the admitted bitvector fragment.")
   (make-smt-core-algorithm :id :compile-smt-to-cnf :layer :lowering :status :implemented
                            :theorem-target :jsmt-cnf-lowering-soundness :callable 'compile-smt-to-cnf
                            :note "Composed SMT-to-CNF lowering on the admitted fragment.")
   (make-smt-core-algorithm :id :compile-smt-to-cnf-with-assumptions :layer :lowering :status :implemented
                            :theorem-target :jsmt-assumption-lowering-soundness
                            :callable 'compile-smt-to-cnf-with-assumptions
                            :note "Composed assumption-aware SMT-to-CNF lowering.")
   (make-smt-core-algorithm :id :solve-cnf-dpll :layer :decision :status :implemented
                            :theorem-target :jsmt-sat-soundness :callable 'solve-cnf-dpll
                            :note "SAT decision procedure on the admitted CNF fragment.")
   (make-smt-core-algorithm :id :solve-cnf-under-assumptions-dpll :layer :decision :status :implemented
                            :theorem-target :jsmt-assumption-soundness
                            :callable 'solve-cnf-under-assumptions-dpll
                            :note "SAT decision procedure under assumptions on the admitted CNF fragment.")
   (make-smt-core-algorithm :id :smt-cnf-unsat-core :layer :decision :status :fragment-audited
                            :theorem-target :jsmt-unsat-core-soundness :callable 'smt-cnf-unsat-core
                            :note "Unsat-core extraction on the frozen assumption-bearing CNF path.")))

(defun find-smt-core-algorithm (id)
  (find id *smt-core-algorithms* :key #'smt-core-algorithm-id :test #'eq))

(defun list-smt-core-algorithms ()
  (copy-list *smt-core-algorithms*))

(defparameter *metakernel-obligations*
  (list
   (make-theorem-obligation
    :id :jd-substitution
    :lane :jd
    :relation :metatheory
    :statement "Declarative substitution preserves typing."
    :witness-kind :counterexample-search)
   (make-theorem-obligation
    :id :jd-weakening
    :lane :jd
    :relation :metatheory
    :statement "Declarative weakening preserves typing."
    :witness-kind :counterexample-search)
   (make-theorem-obligation
    :id :jd-subject-reduction
    :lane :jd
    :relation :metatheory
    :statement "Declarative one-step reduction preserves typing."
    :witness-kind :counterexample-search)
   (make-theorem-obligation
    :id :jkr-soundness
    :lane :jkr
    :relation :implication
    :statement "Reference checker acceptance implies declarative judgment."
    :witness-kind :counterexample-search)
   (make-theorem-obligation
    :id :jkr-fragment-completeness
    :lane :jkr
    :relation :implication
    :statement "Declarative judgment implies reference checker acceptance on the frozen fragment."
    :witness-kind :counterexample-search)
   (make-theorem-obligation
    :id :jkl-jkr-equivalence
    :lane :jkl
    :relation :equivalence
    :statement "Implementation checker and reference checker agree on the frozen fragment."
    :witness-kind :counterexample-search)
   (make-theorem-obligation
    :id :jdefir-jkr-equivalence
    :lane :jdefir
    :relation :equivalence
    :statement "DefIR-backed checker execution and reference checker agree on the frozen fragment."
    :witness-kind :counterexample-search)
   (make-theorem-obligation
    :id :stage1-jl-jr-equivalence
    :lane :stage1
    :relation :equivalence
    :statement "Stage1 implementation property checker and reference checker agree on the frozen scenarios."
    :witness-kind :counterexample-search)
   (make-theorem-obligation
    :id :stage1-jr-soundness
    :lane :stage1
    :relation :implication
    :statement "Stage1 reference checker acceptance implies the declarative stage1 property relation."
    :witness-kind :counterexample-search)
   (make-theorem-obligation
    :id :smt-bridge-normalization
    :lane :jsmt
    :relation :bridge
    :statement "SMT normalization bridge implies the normalization side condition."
    :witness-kind :counterexample-search)
   (make-theorem-obligation
    :id :smt-bridge-boolean-unsat
    :lane :jsmt
    :relation :bridge
    :statement "Closed Boolean unsat bridge implies the Boolean unsatisfiability side condition."
    :witness-kind :counterexample-search)
   (make-theorem-obligation
    :id :smt-bridge-bitvector-unsat
    :lane :jsmt
    :relation :bridge
    :statement "Closed bitvector unsat bridge implies the bitvector unsatisfiability side condition."
    :witness-kind :counterexample-search)
   (make-theorem-obligation
    :id :smt-bridge-int-unsat
    :lane :jsmt
    :relation :bridge
    :statement "Closed integer unsat bridge implies the integer unsatisfiability side condition."
    :witness-kind :counterexample-search)
   (make-theorem-obligation
    :id :smt-bridge-affine-int-contradiction
    :lane :jsmt
    :relation :bridge
    :statement "Affine integer contradiction bridge implies the admitted affine contradiction side condition."
    :witness-kind :counterexample-search)
   (make-theorem-obligation
    :id :smt-obligation-catalog
    :lane :jsmt
    :relation :catalog
    :statement "Finite Π_i/S_i catalog exists for every currently trusted SMT bridge class."
    :witness-kind :counterexample-search)))

(defparameter *closure-backlog*
  (list
   (make-closure-backlog-entry
    :id :jd-substitution
    :lane :jd
    :current-status :fragment-audited
    :target-relation :proved
    :required-theorem "Declarative substitution preserves typing."
    :dependencies '()
    :blocking-dependency nil
    :notes "Frozen-fragment carrier is now certifiable and replay-checkable; theorem-level closure is still open.")
   (make-closure-backlog-entry
    :id :jd-weakening
    :lane :jd
    :current-status :fragment-audited
    :target-relation :proved
    :required-theorem "Declarative weakening preserves typing."
    :dependencies '(:jd-substitution)
    :blocking-dependency :jd-substitution
    :notes "Frozen-fragment carrier is now certifiable and replay-checkable; theorem-level closure still depends on substitution and local-closedness discipline.")
   (make-closure-backlog-entry
    :id :jd-subject-reduction
    :lane :jd
    :current-status :fragment-audited
    :target-relation :proved
    :required-theorem "Declarative one-step reduction preserves typing."
    :dependencies '(:jd-substitution :jd-weakening)
    :blocking-dependency :jd-weakening
    :notes "Needs reduction and conversion lemmas closed theoremically.")
   (make-closure-backlog-entry
    :id :jkr-soundness
    :lane :jkr
    :current-status :fragment-audited
    :target-relation :proved-implication
    :required-theorem "Reference checker acceptance implies declarative judgment."
    :dependencies '(:jd-substitution :jd-weakening :jd-subject-reduction)
    :blocking-dependency :jd-subject-reduction
    :notes "Currently bounded over the frozen carrier, not fully proved.")
   (make-closure-backlog-entry
    :id :jkr-fragment-completeness
    :lane :jkr
    :current-status :fragment-audited
    :target-relation :proved-implication
    :required-theorem "Declarative judgment implies reference checker acceptance on the frozen fragment."
    :dependencies '(:jkr-soundness)
    :blocking-dependency :jkr-soundness
    :notes "Exact fragment characterization must stay frozen.")
   (make-closure-backlog-entry
    :id :jkl-jkr-equivalence
    :lane :jkl
    :current-status :fragment-audited
    :target-relation :proved-equivalence
    :required-theorem "Implementation checker agrees with the reference checker on the frozen fragment."
    :dependencies '(:jkr-soundness :jkr-fragment-completeness)
    :blocking-dependency :jkr-fragment-completeness
    :notes "Still an audit result rather than an implementation proof.")
   (make-closure-backlog-entry
    :id :jdefir-jkr-equivalence
    :lane :jdefir
    :current-status :fragment-audited
    :target-relation :proved-equivalence
    :required-theorem "DefIR-backed checker execution agrees with the reference checker on the frozen fragment."
    :dependencies '(:jkr-soundness :jkr-fragment-completeness)
    :blocking-dependency :jkr-fragment-completeness
    :notes "Execution-lane agreement is now bounded and explicit, but still audit-based rather than implementation-proved.")
   (make-closure-backlog-entry
    :id :stage1-jr-soundness
    :lane :stage1
    :current-status :fragment-audited
    :target-relation :proved-implication
    :required-theorem "Stage1 reference checker acceptance implies the declarative stage1 property relation."
    :dependencies '()
    :blocking-dependency nil
    :notes "Declarative stage1 relation is now present; still audit-based.")
   (make-closure-backlog-entry
    :id :stage1-jl-jr-equivalence
    :lane :stage1
    :current-status :fragment-audited
    :target-relation :proved-equivalence
    :required-theorem "Stage1 implementation checker agrees with the stage1 reference checker on the frozen scenarios."
    :dependencies '(:stage1-jr-soundness)
    :blocking-dependency :stage1-jr-soundness
    :notes "Reference and implementation carriers are aligned on current scenarios.")
   (make-closure-backlog-entry
    :id :smt-bridge-normalization
    :lane :jsmt
    :current-status :fragment-audited
    :target-relation :proved-bridge
    :required-theorem "SMT normalization bridge implies the declarative normalization side condition."
    :dependencies '()
    :blocking-dependency nil
    :notes "Only one bridge family exists; broader Π_i/S_i inventory is still missing.")
   (make-closure-backlog-entry
    :id :smt-bridge-boolean-unsat
    :lane :jsmt
    :current-status :fragment-audited
    :target-relation :proved-bridge
    :required-theorem "Closed Boolean unsat bridge implies the Boolean unsatisfiability side condition."
    :dependencies '()
    :blocking-dependency nil
    :notes "Bridge is fragment-audited on the closed Boolean contradiction carrier.")
   (make-closure-backlog-entry
    :id :smt-bridge-bitvector-unsat
    :lane :jsmt
    :current-status :fragment-audited
    :target-relation :proved-bridge
    :required-theorem "Closed bitvector unsat bridge implies the bitvector unsatisfiability side condition."
    :dependencies '()
    :blocking-dependency nil
    :notes "Bridge is fragment-audited on the closed bitvector contradiction carrier.")
   (make-closure-backlog-entry
    :id :smt-bridge-int-unsat
    :lane :jsmt
    :current-status :fragment-audited
    :target-relation :proved-bridge
   :required-theorem "Closed integer unsat bridge implies the integer unsatisfiability side condition."
    :dependencies '()
    :blocking-dependency nil
    :notes "Bridge is fragment-audited on the closed integer contradiction carrier.")
   (make-closure-backlog-entry
    :id :smt-bridge-affine-int-contradiction
    :lane :jsmt
    :current-status :fragment-audited
    :target-relation :proved-bridge
    :required-theorem "Affine integer contradiction bridge implies the admitted affine contradiction side condition."
    :dependencies '()
    :blocking-dependency nil
    :notes "Bridge is fragment-audited on the admitted affine integer contradiction carrier.")
   (make-closure-backlog-entry
    :id :smt-obligation-catalog
    :lane :jsmt
    :current-status :fragment-audited
    :target-relation :frozen-catalog
    :required-theorem "Finite Π_i/S_i catalog for all trusted SMT uses."
    :dependencies '(:smt-bridge-normalization
                    :smt-bridge-boolean-unsat
                    :smt-bridge-bitvector-unsat
                    :smt-bridge-int-unsat
                    :smt-bridge-affine-int-contradiction)
    :blocking-dependency :smt-bridge-affine-int-contradiction
    :notes "Fragment catalog is now explicit, but not yet complete for every trusted SMT use.")))

(defun find-theorem-obligation (id)
  (find id *metakernel-obligations* :key #'theorem-obligation-id :test #'eq))

(defun %closed-smt-term-p (term)
  (labels ((closed-p (current)
             (case (first current)
               (:bool t)
               (:int-lit t)
               (:bv-lit t)
               (:not (closed-p (second current)))
               ((:and :or :xor :=)
                (every #'closed-p (rest current)))
               ((:=> :bvand :bvor :bvxor :bvadd :bvsub :concat :ult
                 :int-sub :int-mod :int-lt :int-le :int-gt :int-ge)
                (and (closed-p (second current))
                     (closed-p (third current))))
               (:int-add
                (every #'closed-p (rest current)))
               (:ite
                (and (closed-p (second current))
                     (closed-p (third current))
                     (closed-p (fourth current))))
               (:extract
                (closed-p (fourth current)))
               (otherwise nil))))
    (closed-p term)))

(defun find-closure-backlog-entry (id)
  (find id *closure-backlog* :key #'closure-backlog-entry-id :test #'eq))

(defun closure-backlog-summary (&optional (entries *closure-backlog*))
  (let ((counts (make-hash-table :test #'eq)))
    (dolist (entry entries)
      (incf (gethash (closure-backlog-entry-current-status entry) counts 0)))
    (list :missing (gethash :missing counts 0)
          :bounded-audit (gethash :bounded-audit counts 0)
          :fragment-audited (gethash :fragment-audited counts 0)
          :proved (gethash :proved counts 0)
          :proved-implication (gethash :proved-implication counts 0)
          :proved-equivalence (gethash :proved-equivalence counts 0)
          :proved-bridge (gethash :proved-bridge counts 0)
          :frozen-catalog (gethash :frozen-catalog counts 0)
          :total (length entries))))

(defun executable-closure-backlog ()
  (list :entries *closure-backlog*
        :summary (closure-backlog-summary)))

(defun make-typing-judgment (context term type &optional (config *current-config-digest*))
  (make-kernel-judgment
   :context context
   :term term
   :type type
   :config config
   :judgment-kind :typing))

(defun make-defeq-judgment (context lhs rhs &optional (config *current-config-digest*))
  (make-kernel-judgment
   :context context
   :term lhs
   :type rhs
   :config config
   :judgment-kind :defeq))

(defun make-step-judgment (lhs rhs &optional (config *current-config-digest*))
  (make-kernel-judgment
   :context '()
   :term lhs
   :type rhs
   :config config
   :judgment-kind :step))

(defun make-wf-context-judgment (context &optional (config *current-config-digest*))
  (make-kernel-judgment
   :context context
   :term nil
   :type nil
   :config config
   :judgment-kind :wf-ctx))

(defun make-smt-status-judgment (formula expected-status &optional (config *current-config-digest*))
  (make-smt-judgment
   :formula formula
   :config config
   :expected-status expected-status))

(defun d-shift (delta cutoff term)
  (case (term-tag term)
    (:sort
     term)
    (:var
     (let* ((k (second term))
            (shifted (if (>= k cutoff) (+ k delta) k)))
       (when (minusp shifted)
         (kernel-error "negative de Bruijn index after declarative shift: ~A" shifted))
       (mk-var shifted)))
    (:const
     term)
    (:app
     (mk-app (d-shift delta cutoff (second term))
             (d-shift delta cutoff (third term))))
    (:lam
     (mk-lam (d-shift delta cutoff (second term))
             (d-shift delta (1+ cutoff) (third term))))
    (:pi
     (mk-pi (d-shift delta cutoff (second term))
            (d-shift delta (1+ cutoff) (third term))))
    (:let
     (mk-let (d-shift delta cutoff (second term))
             (d-shift delta cutoff (third term))
             (d-shift delta (1+ cutoff) (fourth term))))
    (otherwise
     (kernel-error "unknown term in declarative shift: ~S" term))))

(defun d-subst (j replacement term)
  (case (term-tag term)
    (:sort
     term)
    (:var
     (let ((k (second term)))
       (if (= k j)
           replacement
           term)))
    (:const
     term)
    (:app
     (mk-app (d-subst j replacement (second term))
             (d-subst j replacement (third term))))
    (:lam
     (mk-lam (d-subst j replacement (second term))
             (d-subst (1+ j)
                      (d-shift 1 0 replacement)
                      (third term))))
    (:pi
     (mk-pi (d-subst j replacement (second term))
            (d-subst (1+ j)
                     (d-shift 1 0 replacement)
                     (third term))))
    (:let
     (mk-let (d-subst j replacement (second term))
             (d-subst j replacement (third term))
             (d-subst (1+ j)
                      (d-shift 1 0 replacement)
                      (fourth term))))
    (otherwise
     (kernel-error "unknown term in declarative subst: ~S" term))))

(defun d-subst-top (replacement body)
  (d-shift -1 0
           (d-subst 0 (d-shift 1 0 replacement) body)))

(defun d-ctx-lookup (ctx k)
  (let ((type (nth k ctx)))
    (unless type
      (kernel-error "unbound de Bruijn index in declarative ctx lookup: ~A" k))
    (d-shift (1+ k) 0 type)))

(defun d-check-sort (env ctx term)
  (let ((type (d-whnf env (d-infer env ctx term))))
    (case (term-tag type)
      (:sort
       (second type))
      (otherwise
       (kernel-error "declarative sort check failed, got ~S" type)))))

(defun d-conv (env ctx lhs rhs)
  (let ((lhs* (d-whnf env lhs))
        (rhs* (d-whnf env rhs)))
    (case (term-tag lhs*)
      (:sort
       (and (eq (term-tag rhs*) :sort)
            (= (second lhs*) (second rhs*))))
      (:var
       (and (eq (term-tag rhs*) :var)
            (= (second lhs*) (second rhs*))))
      (:const
       (and (eq (term-tag rhs*) :const)
            (eq (second lhs*) (second rhs*))
            (equal (third lhs*) (third rhs*))))
      (:app
       (and (eq (term-tag rhs*) :app)
            (d-conv env ctx (second lhs*) (second rhs*))
            (d-conv env ctx (third lhs*) (third rhs*))))
      (:pi
       (and (eq (term-tag rhs*) :pi)
            (d-conv env ctx (second lhs*) (second rhs*))
            (d-conv env (cons (second lhs*) ctx)
                    (third lhs*)
                    (third rhs*))))
      (:lam
       (and (eq (term-tag rhs*) :lam)
            (d-conv env ctx (second lhs*) (second rhs*))
            (d-conv env (cons (second lhs*) ctx)
                    (third lhs*)
                    (third rhs*))))
      (otherwise
       nil))))

(defun d-infer (env ctx term)
  (case (term-tag term)
    (:sort
     (mk-sort (1+ (second term))))
    (:var
     (d-ctx-lookup ctx (second term)))
    (:const
     (let ((decl (env-lookup env (second term))))
       (unless decl
         (kernel-error "unknown constant in declarative inference: ~A" (second term)))
       (instantiate-levels (decl-type decl) (third term))))
    (:pi
     (let ((u (d-check-sort env ctx (second term)))
           (v (d-check-sort env (cons (second term) ctx) (third term))))
       (mk-sort (max u v))))
    (:lam
     (d-check-sort env ctx (second term))
     (mk-pi (second term)
            (d-infer env (cons (second term) ctx) (third term))))
    (:app
     (let ((function-type (d-whnf env (d-infer env ctx (second term)))))
       (if (eq (term-tag function-type) :pi)
           (progn
             (d-check env ctx (third term) (second function-type))
             (d-subst-top (third term) (third function-type)))
           (kernel-error "declarative application of non-function: ~S" function-type))))
    (:let
     (d-check-sort env ctx (third term))
     (d-check env ctx (second term) (third term))
     (d-subst-top (second term)
                  (d-infer env (cons (third term) ctx) (fourth term))))
    (otherwise
     (kernel-error "unknown term in declarative inference: ~S" term))))

(defun d-check (env ctx term expected)
  (let ((actual (d-infer env ctx term)))
    (unless (d-conv env ctx actual expected)
      (kernel-error "declarative type mismatch~%expected: ~S~%actual:   ~S"
                    expected
                    actual))
    t))

(defun d-wf-ctx (env ctx)
  (labels ((wf (current)
             (if (endp current)
                 t
                 (let ((tail (rest current))
                       (head (first current)))
                   (and (wf tail)
                        (handler-case
                            (progn
                              (d-check-sort env tail head)
                              t)
                          (kernel-error ()
                            nil)))))))
    (wf ctx)))

(defun d-one-step-results (env term)
  (labels ((step-term (current)
             (let ((results '()))
               (case (term-tag current)
                 (:app
                  (let ((f (second current))
                        (a (third current)))
                    (when (eq (term-tag f) :lam)
                      (push (d-subst-top a (third f)) results))
                    (dolist (f* (step-term f))
                      (push (mk-app f* a) results))
                    (dolist (a* (step-term a))
                      (push (mk-app f a*) results))
                    (multiple-value-bind (head args)
                        (app-head+args current)
                      (when (eq (term-tag head) :const)
                        (let ((name (second head))
                              (levels (third head)))
                          (cond
                            ((eq name 'nat-rec)
                             (let ((reduced (d-reduce-nat-rec env levels args)))
                               (unless (equal reduced current)
                                 (push reduced results))))
                            ((eq name 'eq-rec)
                             (let ((reduced (d-reduce-eq-rec env levels args)))
                               (unless (equal reduced current)
                                 (push reduced results))))))))))
                 (:const
                  (let* ((name (second current))
                         (levels (third current))
                         (decl (env-lookup env name)))
                    (when (and decl
                               (eq (decl-kind decl) :def)
                               (decl-reduciblep decl))
                      (push (instantiate-levels (decl-value decl) levels) results))))
                 (:lam
                  (dolist (body* (step-term (third current)))
                    (push (mk-lam (second current) body*) results)))
                 (:pi
                  (dolist (domain* (step-term (second current)))
                    (push (mk-pi domain* (third current)) results))
                  (dolist (codomain* (step-term (third current)))
                    (push (mk-pi (second current) codomain*) results)))
                 (:let
                  (push (d-subst-top (second current) (fourth current)) results)
                  (dolist (value* (step-term (second current)))
                    (push (mk-let value* (third current) (fourth current)) results))
                  (dolist (type* (step-term (third current)))
                    (push (mk-let (second current) type* (fourth current)) results))
                  (dolist (body* (step-term (fourth current)))
                    (push (mk-let (second current) (third current) body*) results))))
               (remove-duplicates results :test #'equal))))
    (step-term term)))

(defun kr-one-step-results (reference-env term)
  (labels ((step-term (current)
             (let ((results '()))
               (case (term-tag current)
                 (:app
                  (let ((f (second current))
                        (a (third current)))
                    (when (eq (term-tag f) :lam)
                      (push (mini-kernel-reference::r-subst-top a (third f)) results))
                    (dolist (f* (step-term f))
                      (push (mk-app f* a) results))
                    (dolist (a* (step-term a))
                      (push (mk-app f a*) results))
                    (multiple-value-bind (head args)
                        (app-head+args current)
                      (when (eq (term-tag head) :const)
                        (let ((name (second head))
                              (levels (third head)))
                          (cond
                            ((eq name 'nat-rec)
                             (let ((reduced (mini-kernel-reference::r-reduce-nat-rec
                                             reference-env levels args)))
                               (unless (equal reduced current)
                                 (push reduced results))))
                            ((eq name 'eq-rec)
                             (let ((reduced (mini-kernel-reference::r-reduce-eq-rec
                                             reference-env levels args)))
                               (unless (equal reduced current)
                                 (push reduced results))))))))))
                 (:const
                  (let* ((name (second current))
                         (levels (third current))
                         (decl (mini-kernel-reference::r-env-lookup reference-env name)))
                    (when (and decl
                               (eq (mini-kernel-reference::rdecl-kind decl) :def)
                               (mini-kernel-reference::rdecl-reduciblep decl))
                      (push (mini-kernel-reference::r-instantiate-levels
                             (mini-kernel-reference::rdecl-value decl)
                             levels)
                            results))))
                 (:lam
                  (dolist (body* (step-term (third current)))
                    (push (mk-lam (second current) body*) results)))
                 (:pi
                  (dolist (domain* (step-term (second current)))
                    (push (mk-pi domain* (third current)) results))
                  (dolist (codomain* (step-term (third current)))
                    (push (mk-pi (second current) codomain*) results)))
                 (:let
                  (push (mini-kernel-reference::r-subst-top (second current)
                                                            (fourth current))
                        results)
                  (dolist (value* (step-term (second current)))
                    (push (mk-let value* (third current) (fourth current)) results))
                  (dolist (type* (step-term (third current)))
                    (push (mk-let (second current) type* (fourth current)) results))
                  (dolist (body* (step-term (fourth current)))
                    (push (mk-let (second current) (third current) body*) results))))
               (remove-duplicates results :test #'equal))))
    (step-term term)))

(defun kl-one-step-results (env term)
  (labels ((step-term (current)
             (let ((results '()))
               (case (term-tag current)
                 (:app
                  (let ((f (second current))
                        (a (third current)))
                    (when (eq (term-tag f) :lam)
                      (push (subst-top a (third f)) results))
                    (dolist (f* (step-term f))
                      (push (mk-app f* a) results))
                    (dolist (a* (step-term a))
                      (push (mk-app f a*) results))
                    (multiple-value-bind (head args)
                        (app-head+args current)
                      (when (eq (term-tag head) :const)
                        (let ((name (second head))
                              (levels (third head)))
                          (cond
                            ((eq name 'nat-rec)
                             (let ((reduced (reduce-nat-rec env levels args)))
                               (unless (equal reduced current)
                                 (push reduced results))))
                            ((eq name 'eq-rec)
                             (let ((reduced (reduce-eq-rec env levels args)))
                               (unless (equal reduced current)
                                 (push reduced results))))))))))
                 (:const
                  (let* ((name (second current))
                         (levels (third current))
                         (decl (env-lookup env name)))
                    (when (and decl
                               (eq (decl-kind decl) :def)
                               (decl-reduciblep decl))
                      (push (instantiate-levels (decl-value decl) levels) results))))
                 (:lam
                  (dolist (body* (step-term (third current)))
                    (push (mk-lam (second current) body*) results)))
                 (:pi
                  (dolist (domain* (step-term (second current)))
                    (push (mk-pi domain* (third current)) results))
                  (dolist (codomain* (step-term (third current)))
                    (push (mk-pi (second current) codomain*) results)))
                 (:let
                  (push (subst-top (second current) (fourth current)) results)
                  (dolist (value* (step-term (second current)))
                    (push (mk-let value* (third current) (fourth current)) results))
                  (dolist (type* (step-term (third current)))
                    (push (mk-let (second current) type* (fourth current)) results))
                  (dolist (body* (step-term (fourth current)))
                    (push (mk-let (second current) (third current) body*) results))))
               (remove-duplicates results :test #'equal))))
    (step-term term)))

(defun d-reduce-nat-rec (env levels args)
  (if (< (length args) 4)
      (rebuild-apps (mk-const 'nat-rec levels) args)
      (destructuring-bind (motive base step n &rest rest) args
        (let ((n* (d-whnf env n)))
          (cond
            ((equal n* (mk-const 'zero))
             (d-whnf env (rebuild-apps base rest)))
            ((and (eq (term-tag n*) :app)
                  (equal (second n*) (mk-const 'succ)))
             (let* ((k (third n*))
                    (rec-call (rebuild-apps (mk-const 'nat-rec levels)
                                            (list motive base step k)))
                    (step-app (app* step (list k rec-call))))
               (d-whnf env (rebuild-apps step-app rest))))
            (t
             (rebuild-apps (mk-const 'nat-rec levels)
                           (append (list motive base step n*) rest))))))))

(defun d-reduce-eq-rec (env levels args)
  (if (< (length args) 6)
      (rebuild-apps (mk-const 'eq-rec levels) args)
      (destructuring-bind (type lhs motive proof rhs equality &rest rest) args
        (let ((equality* (d-whnf env equality)))
          (if (and (eq (term-tag equality*) :app)
                   (eq (term-tag (second equality*)) :app)
                   (equal (second (second equality*)) (mk-const 'refl)))
              (d-whnf env (rebuild-apps proof rest))
              (rebuild-apps (mk-const 'eq-rec levels)
                            (append (list type lhs motive proof rhs equality*)
                                    rest)))))))

(defun d-whnf (env term)
  (labels ((reduce-term (current)
             (case (term-tag current)
               (:let
                (reduce-term (d-subst-top (second current) (fourth current))))
               (:app
                (multiple-value-bind (head args)
                    (app-head+args current)
                  (reduce-head (reduce-term head) args)))
               (:const
                (let* ((name (second current))
                       (levels (third current))
                       (decl (env-lookup env name)))
                  (if (and decl
                           (eq (decl-kind decl) :def)
                           (decl-reduciblep decl))
                      (reduce-term (instantiate-levels (decl-value decl) levels))
                      current)))
               (otherwise
               current)))
           (reduce-head (head args)
             (cond
               ((null args)
                head)
               ((eq (term-tag head) :let)
                (reduce-term
                 (rebuild-apps (d-subst-top (second head) (fourth head)) args)))
               ((eq (term-tag head) :lam)
                (reduce-term
                 (rebuild-apps (d-subst-top (first args) (third head))
                               (rest args))))
               ((and (eq (term-tag head) :const)
                     (eq (second head) 'nat-rec))
                (d-reduce-nat-rec env (third head) args))
               ((and (eq (term-tag head) :const)
                     (eq (second head) 'eq-rec))
                (d-reduce-eq-rec env (third head) args))
               (t
                (rebuild-apps head args)))))
    (reduce-term term)))

(defun j-d (env judgment)
  (unless (equal (kernel-judgment-config judgment) *current-config-digest*)
    (kernel-error "declarative judgment config mismatch~%expected: ~S~%actual:   ~S"
                  *current-config-digest*
                  (kernel-judgment-config judgment)))
  (case (kernel-judgment-judgment-kind judgment)
    (:typing
     (handler-case
         (progn
           (d-check env
                    (kernel-judgment-context judgment)
                    (kernel-judgment-term judgment)
                    (kernel-judgment-type judgment))
           t)
       (kernel-error ()
         nil)))
    (:defeq
     (handler-case
         (d-conv env
                 (kernel-judgment-context judgment)
                 (kernel-judgment-term judgment)
                 (kernel-judgment-type judgment))
       (kernel-error ()
         nil)))
    (:step
     (member (kernel-judgment-type judgment)
             (d-one-step-results env (kernel-judgment-term judgment))
             :test #'equal))
    (:wf-ctx
     (d-wf-ctx env (kernel-judgment-context judgment)))
    (otherwise
     (kernel-error "unsupported declarative judgment kind: ~S"
                   (kernel-judgment-judgment-kind judgment)))))

(defun j-kr (reference-env judgment)
  (unless (equal (kernel-judgment-config judgment) *current-config-digest*)
    (error "reference judgment config mismatch~%expected: ~S~%actual:   ~S"
           *current-config-digest*
           (kernel-judgment-config judgment)))
  (case (kernel-judgment-judgment-kind judgment)
    (:typing
     (let ((certificate
             (make-typing-certificate
              (kernel-judgment-context judgment)
              (kernel-judgment-term judgment)
              (kernel-judgment-type judgment)
              :bootstrap-v1
              :checker-ids '(j-kr)
              :metadata '(:judgment j-kr))))
       (handler-case
           (progn
             (mini-kernel-reference:check-certificate reference-env certificate)
             t)
         (mini-kernel-reference::reference-error ()
           nil))))
    (:defeq
     (handler-case
         (mini-kernel-reference::r-conv
          reference-env
          (kernel-judgment-context judgment)
          (kernel-judgment-term judgment)
          (kernel-judgment-type judgment))
       (mini-kernel-reference::reference-error ()
         nil)))
    (:step
     (member (kernel-judgment-type judgment)
             (kr-one-step-results reference-env (kernel-judgment-term judgment))
             :test #'equal))
    (:wf-ctx
     (labels ((wf (current)
                (if (endp current)
                    t
                    (let ((tail (rest current))
                          (head (first current)))
                      (and (wf tail)
                           (handler-case
                               (progn
                                 (mini-kernel-reference::r-check-sort
                                  reference-env tail head)
                                 t)
                             (mini-kernel-reference::reference-error ()
                               nil)))))))
       (wf (kernel-judgment-context judgment))))
    (otherwise
     (error "unsupported reference judgment kind: ~S"
            (kernel-judgment-judgment-kind judgment)))))

(defun j-kl (env judgment)
  (unless (equal (kernel-judgment-config judgment) *current-config-digest*)
    (kernel-error "implementation judgment config mismatch~%expected: ~S~%actual:   ~S"
                  *current-config-digest*
                  (kernel-judgment-config judgment)))
  (case (kernel-judgment-judgment-kind judgment)
    (:typing
     (let ((certificate
             (make-typing-certificate
              (kernel-judgment-context judgment)
              (kernel-judgment-term judgment)
              (kernel-judgment-type judgment)
              :bootstrap-v1
              :checker-ids '(j-kl)
              :metadata '(:judgment j-kl))))
       (handler-case
           (progn
             (check-certificate env certificate)
             t)
         (kernel-error ()
           nil))))
    (:defeq
     (handler-case
         (conv? env
                (kernel-judgment-context judgment)
                (kernel-judgment-term judgment)
                (kernel-judgment-type judgment))
       (kernel-error ()
         nil)))
    (:step
     (member (kernel-judgment-type judgment)
             (kl-one-step-results env (kernel-judgment-term judgment))
             :test #'equal))
    (:wf-ctx
     (labels ((wf (current)
                (if (endp current)
                    t
                    (let ((tail (rest current))
                          (head (first current)))
                      (and (wf tail)
                           (handler-case
                               (progn
                                 (check-sort env tail head)
                                 t)
                             (kernel-error ()
                               nil)))))))
       (wf (kernel-judgment-context judgment))))
    (otherwise
     (kernel-error "unsupported implementation judgment kind: ~S"
                   (kernel-judgment-judgment-kind judgment)))))

(defun j-smt (formula-store judgment)
  (unless (equal (smt-judgment-config judgment) *current-config-digest*)
    (kernel-error "SMT judgment config mismatch~%expected: ~S~%actual:   ~S"
                  *current-config-digest*
                  (smt-judgment-config judgment)))
  (let ((result (run-smt-check formula-store (smt-judgment-formula judgment))))
    (eq (backend-result-status result)
        (smt-judgment-expected-status judgment))))

(defun normalization-side-condition (formula)
  (equal (eval-smt-term formula)
         (eval-smt-term (normalize-smt-term formula))))

(defun project-normalization-obligation (formula)
  (smt-not (smt-eq formula (normalize-smt-term formula))))

(defun boolean-unsat-side-condition (formula)
  (and (%closed-smt-term-p formula)
       (equal (eval-smt-term formula) nil)))

(defun project-boolean-unsat-obligation (formula)
  formula)

(defun bitvector-unsat-side-condition (formula)
  (and (%closed-smt-term-p formula)
       (equal (eval-smt-term formula) nil)))

(defun project-bitvector-unsat-obligation (formula)
  formula)

(defun int-unsat-side-condition (formula)
  (and (%closed-smt-term-p formula)
       (equal (eval-smt-term formula) nil)))

(defun project-int-unsat-obligation (formula)
  formula)

(defun %affine-int-fragment-p (term)
  (case (smt-tag term)
    ((:bool :int-lit) t)
    (:var t)
    (:not (%affine-int-fragment-p (second term)))
    ((:and :or :xor :=>)
     (every #'%affine-int-fragment-p (rest term)))
    (:ite
     (and (%affine-int-fragment-p (second term))
          (%affine-int-fragment-p (third term))
          (%affine-int-fragment-p (fourth term))))
    (:= (and (%affine-int-fragment-p (second term))
             (%affine-int-fragment-p (third term))))
    (:int-add
     (every #'%affine-int-fragment-p (rest term)))
    ((:int-sub :int-lt :int-le :int-gt :int-ge)
     (and (%affine-int-fragment-p (second term))
          (%affine-int-fragment-p (third term))))
    (otherwise nil)))

(defun affine-int-contradiction-side-condition (formula)
  (and (%affine-int-fragment-p formula)
       (let ((result (run-smt-check (make-advisory-store) formula)))
         (eq (backend-result-status result) :rejected))))

(defun project-affine-int-contradiction-obligation (formula)
  formula)

(defparameter *smt-obligation-classes*
  (list
   (make-smt-obligation-class
    :id :normalization-equivalence
    :polarity :unsat
    :statement "Normalized SMT term is semantically equivalent to the source term on the closed fragment."
    :fragment-predicate #'%closed-smt-term-p
    :side-condition #'normalization-side-condition
    :projector #'project-normalization-obligation)
   (make-smt-obligation-class
    :id :closed-boolean-unsat
    :polarity :unsat
    :statement "Closed Boolean SMT formula is semantically false."
    :fragment-predicate #'%closed-smt-term-p
    :side-condition #'boolean-unsat-side-condition
    :projector #'project-boolean-unsat-obligation)
   (make-smt-obligation-class
    :id :closed-bitvector-unsat
    :polarity :unsat
    :statement "Closed bitvector SMT formula is semantically false."
    :fragment-predicate #'%closed-smt-term-p
    :side-condition #'bitvector-unsat-side-condition
    :projector #'project-bitvector-unsat-obligation)
   (make-smt-obligation-class
    :id :closed-int-unsat
    :polarity :unsat
    :statement "Closed integer SMT formula is semantically false."
    :fragment-predicate #'%closed-smt-term-p
    :side-condition #'int-unsat-side-condition
    :projector #'project-int-unsat-obligation)
   (make-smt-obligation-class
    :id :affine-int-contradiction
    :polarity :unsat
    :statement "Affine integer SMT formula is solver-rejected on the admitted Int fragment."
    :fragment-predicate #'%affine-int-fragment-p
    :side-condition #'affine-int-contradiction-side-condition
    :projector #'project-affine-int-contradiction-obligation)))

(defparameter *bridge-laws*
  (list
   (make-bridge-law
    :id :smt-bridge-normalization
    :obligation-class-id :normalization-equivalence
    :source-lane :jsmt
    :target-lane :kernel-side-condition
    :result-polarity :unsat
    :side-predicate #'normalization-side-condition
    :projector #'project-normalization-obligation
    :statement "Unsat of the negated normalization-equivalence projection implies the kernel-side normalization condition."
    :theorem-target :smt-bridge-normalization)
   (make-bridge-law
    :id :smt-bridge-boolean-unsat
    :obligation-class-id :closed-boolean-unsat
    :source-lane :jsmt
    :target-lane :kernel-side-condition
    :result-polarity :unsat
    :side-predicate #'boolean-unsat-side-condition
    :projector #'project-boolean-unsat-obligation
    :statement "Unsat of the Boolean obligation projection implies the closed-Boolean side condition."
    :theorem-target :smt-bridge-boolean-unsat)
   (make-bridge-law
    :id :smt-bridge-bitvector-unsat
    :obligation-class-id :closed-bitvector-unsat
    :source-lane :jsmt
    :target-lane :kernel-side-condition
    :result-polarity :unsat
    :side-predicate #'bitvector-unsat-side-condition
    :projector #'project-bitvector-unsat-obligation
    :statement "Unsat of the bitvector obligation projection implies the closed-bitvector side condition."
    :theorem-target :smt-bridge-bitvector-unsat)
   (make-bridge-law
    :id :smt-bridge-int-unsat
    :obligation-class-id :closed-int-unsat
    :source-lane :jsmt
    :target-lane :kernel-side-condition
   :result-polarity :unsat
    :side-predicate #'int-unsat-side-condition
    :projector #'project-int-unsat-obligation
    :statement "Unsat of the integer obligation projection implies the closed-integer side condition."
    :theorem-target :smt-bridge-int-unsat)
   (make-bridge-law
    :id :smt-bridge-affine-int-contradiction
    :obligation-class-id :affine-int-contradiction
    :source-lane :jsmt
    :target-lane :kernel-side-condition
    :result-polarity :unsat
    :side-predicate #'affine-int-contradiction-side-condition
    :projector #'project-affine-int-contradiction-obligation
    :statement "Unsat of the affine-integer obligation projection implies the admitted affine contradiction side condition."
    :theorem-target :smt-bridge-affine-int-contradiction)))

(defparameter *admitted-obligation-classes*
  (list
   (make-admitted-obligation-class
    :id :o-normalization-equivalence
    :source-lane :jsmt
    :target-lane :kernel-side-condition
    :smt-obligation-class-id :normalization-equivalence
    :result-polarity :unsat
    :fragment-predicate #'%closed-smt-term-p
    :side-predicate #'normalization-side-condition
    :projector #'project-normalization-obligation
    :statement "Closed normalization-equivalence obligation projected to SMT and discharged by unsat."
    :theorem-target :smt-bridge-normalization)
   (make-admitted-obligation-class
    :id :o-closed-boolean-unsat
    :source-lane :jsmt
    :target-lane :kernel-side-condition
    :smt-obligation-class-id :closed-boolean-unsat
    :result-polarity :unsat
    :fragment-predicate #'%closed-smt-term-p
    :side-predicate #'boolean-unsat-side-condition
    :projector #'project-boolean-unsat-obligation
    :statement "Closed Boolean falsity obligation projected to SMT and discharged by unsat."
    :theorem-target :smt-bridge-boolean-unsat)
   (make-admitted-obligation-class
    :id :o-closed-bitvector-unsat
    :source-lane :jsmt
    :target-lane :kernel-side-condition
    :smt-obligation-class-id :closed-bitvector-unsat
    :result-polarity :unsat
    :fragment-predicate #'%closed-smt-term-p
    :side-predicate #'bitvector-unsat-side-condition
    :projector #'project-bitvector-unsat-obligation
    :statement "Closed bitvector falsity obligation projected to SMT and discharged by unsat."
    :theorem-target :smt-bridge-bitvector-unsat)
   (make-admitted-obligation-class
    :id :o-closed-int-unsat
    :source-lane :jsmt
    :target-lane :kernel-side-condition
    :smt-obligation-class-id :closed-int-unsat
    :result-polarity :unsat
    :fragment-predicate #'%closed-smt-term-p
    :side-predicate #'int-unsat-side-condition
    :projector #'project-int-unsat-obligation
    :statement "Closed integer falsity obligation projected to SMT and discharged by unsat."
    :theorem-target :smt-bridge-int-unsat)
   (make-admitted-obligation-class
    :id :o-affine-int-contradiction
    :source-lane :jsmt
    :target-lane :kernel-side-condition
    :smt-obligation-class-id :affine-int-contradiction
    :result-polarity :unsat
    :fragment-predicate #'%affine-int-fragment-p
    :side-predicate #'affine-int-contradiction-side-condition
    :projector #'project-affine-int-contradiction-obligation
    :statement "Affine integer contradiction obligation projected to SMT and discharged by unsat on the admitted fragment."
    :theorem-target :smt-bridge-affine-int-contradiction)))

(defparameter *theorem-bridge-bindings*
  (list
   (make-theorem-bridge-binding
    :theorem-obligation-id :smt-bridge-normalization
    :admitted-obligation-id :o-normalization-equivalence
    :result-polarity :unsat
    :note "Normalization bridge theorem binds to the normalization admitted SMT obligation class.")
   (make-theorem-bridge-binding
    :theorem-obligation-id :smt-bridge-boolean-unsat
    :admitted-obligation-id :o-closed-boolean-unsat
    :result-polarity :unsat
    :note "Boolean unsat bridge theorem binds to the closed-Boolean admitted SMT obligation class.")
   (make-theorem-bridge-binding
    :theorem-obligation-id :smt-bridge-bitvector-unsat
    :admitted-obligation-id :o-closed-bitvector-unsat
    :result-polarity :unsat
    :note "Bitvector unsat bridge theorem binds to the closed-bitvector admitted SMT obligation class.")
   (make-theorem-bridge-binding
    :theorem-obligation-id :smt-bridge-int-unsat
    :admitted-obligation-id :o-closed-int-unsat
    :result-polarity :unsat
    :note "Integer unsat bridge theorem binds to the closed-integer admitted SMT obligation class.")
   (make-theorem-bridge-binding
    :theorem-obligation-id :smt-bridge-affine-int-contradiction
    :admitted-obligation-id :o-affine-int-contradiction
    :result-polarity :unsat
    :note "Affine integer contradiction bridge theorem binds to the admitted affine-Int SMT obligation class.")))

(defun find-smt-obligation-class (id)
  (find id *smt-obligation-classes* :key #'smt-obligation-class-id :test #'eq))

(defun find-bridge-law (id)
  (find id *bridge-laws* :key #'bridge-law-id :test #'eq))

(defun list-bridge-laws ()
  (copy-list *bridge-laws*))

(defun find-admitted-obligation-class (id)
  (find id *admitted-obligation-classes*
        :key #'admitted-obligation-class-id
        :test #'eq))

(defun list-admitted-obligation-classes ()
  (copy-list *admitted-obligation-classes*))

(defun find-theorem-bridge-binding (theorem-obligation-id)
  (find theorem-obligation-id *theorem-bridge-bindings*
        :key #'theorem-bridge-binding-theorem-obligation-id
        :test #'eq))

(defun list-theorem-bridge-bindings ()
  (copy-list *theorem-bridge-bindings*))

(defun smt-obligation-side-condition (obligation-id formula)
  (let ((entry (find-smt-obligation-class obligation-id)))
    (unless entry
      (kernel-error "unknown SMT obligation class: ~S" obligation-id))
    (funcall (smt-obligation-class-side-condition entry) formula)))

(defun project-smt-obligation (obligation-id formula)
  (let ((entry (find-smt-obligation-class obligation-id)))
    (unless entry
      (kernel-error "unknown SMT obligation class: ~S" obligation-id))
    (funcall (smt-obligation-class-projector entry) formula)))

(defun admitted-obligation-side-condition (obligation-id formula)
  (let ((entry (find-admitted-obligation-class obligation-id)))
    (unless entry
      (kernel-error "unknown admitted obligation class: ~S" obligation-id))
    (funcall (admitted-obligation-class-side-predicate entry) formula)))

(defun project-admitted-obligation (obligation-id formula)
  (let ((entry (find-admitted-obligation-class obligation-id)))
    (unless entry
      (kernel-error "unknown admitted obligation class: ~S" obligation-id))
    (funcall (admitted-obligation-class-projector entry) formula)))

(defun j-smt-obligation-bridge (obligation-id formula
                                  &optional (config *current-config-digest*))
  (declare (ignore config))
  (let ((entry (find-smt-obligation-class obligation-id)))
    (unless entry
      (kernel-error "unknown SMT obligation class: ~S" obligation-id))
    (unless (funcall (smt-obligation-class-fragment-predicate entry) formula)
      (return-from j-smt-obligation-bridge nil))
    (let ((store (make-advisory-store))
          (expected-status (ecase (smt-obligation-class-polarity entry)
                             (:unsat :rejected)
                             (:sat :accepted))))
      (and (j-smt store
                  (make-smt-status-judgment
                   (project-smt-obligation obligation-id formula)
                   expected-status))
           (smt-obligation-side-condition obligation-id formula)))))

(defun j-smt-admitted-obligation-bridge (obligation-id formula
                                           &optional (config *current-config-digest*))
  (declare (ignore config))
  (let ((entry (find-admitted-obligation-class obligation-id)))
    (unless entry
      (kernel-error "unknown admitted obligation class: ~S" obligation-id))
    (unless (funcall (admitted-obligation-class-fragment-predicate entry) formula)
      (return-from j-smt-admitted-obligation-bridge nil))
    (let ((store (make-advisory-store))
          (expected-status (ecase (admitted-obligation-class-result-polarity entry)
                             (:unsat :rejected)
                             (:sat :accepted))))
      (and (j-smt store
                  (make-smt-status-judgment
                   (project-admitted-obligation obligation-id formula)
                   expected-status))
           (admitted-obligation-side-condition obligation-id formula)))))

(defun j-smt-normalization-bridge (formula &optional (config *current-config-digest*))
  (j-smt-admitted-obligation-bridge :o-normalization-equivalence formula config))
