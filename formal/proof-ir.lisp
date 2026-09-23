(in-package :mini-kernel)

(defparameter *proof-claim-kinds* '(:has-type :defeq :step :wf-ctx))
(defparameter *proof-evidence-kinds*
  '(:axiom
    :sort
    :var
    :const
    :pi
    :lam
    :app
    :let
    :conv
    :defeq-refl
    :defeq-step
    :defeq-app
    :defeq-lam
    :defeq-pi
    :defeq-let
    :wf-empty
    :wf-cons))

(defstruct proof-claim
  kind
  context
  term
  type
  lhs
  rhs
  config-digest
  metadata)

(defstruct (proof-evidence
            (:constructor %make-proof-evidence (&key kind payload premises checkedp)))
  kind
  payload
  premises
  checkedp)

(defstruct (proof-fragment
            (:constructor %make-proof-fragment
                (&key claim evidence checker-ids config-digest metadata)))
  claim
  evidence
  checker-ids
  config-digest
  metadata)

(defun valid-proof-claim-kind-p (kind)
  (member kind *proof-claim-kinds* :test #'eq))

(defun valid-proof-evidence-kind-p (kind)
  (member kind *proof-evidence-kinds* :test #'eq))

(defun ensure-core-context (context source)
  (unless (listp context)
    (kernel-error "~A context must be a list, got ~S" source context))
  (unless (every #'core-term-p context)
    (kernel-error "~A context contains non-core terms: ~S" source context))
  context)

(defun ensure-core-term (term slot source)
  (unless (core-term-p term)
    (kernel-error "~A ~A is not a core term: ~S" source slot term))
  term)

(defun make-has-type-claim (context term type &key metadata)
  (make-proof-claim
   :kind :has-type
   :context (copy-tree context)
   :term term
   :type type
   :config-digest *current-config-digest*
   :metadata metadata))

(defun make-defeq-claim (context lhs rhs &key metadata)
  (make-proof-claim
   :kind :defeq
   :context (copy-tree context)
   :lhs lhs
   :rhs rhs
   :config-digest *current-config-digest*
   :metadata metadata))

(defun make-step-claim (lhs rhs &key metadata)
  (make-proof-claim
   :kind :step
   :lhs lhs
   :rhs rhs
   :config-digest *current-config-digest*
   :metadata metadata))

(defun make-wf-ctx-claim (context &key metadata)
  (make-proof-claim
   :kind :wf-ctx
   :context (copy-tree context)
   :config-digest *current-config-digest*
   :metadata metadata))

(defun make-proof-evidence (kind &key payload (premises '()) (checkedp nil))
  (unless (valid-proof-evidence-kind-p kind)
    (kernel-error "invalid proof evidence kind: ~S" kind))
  (unless (listp premises)
    (kernel-error "proof evidence premises must be a list, got ~S" premises))
  (%make-proof-evidence
   :kind kind
   :payload payload
   :premises (copy-list premises)
   :checkedp (not (null checkedp))))

(defun validate-proof-claim (claim)
  (unless (typep claim 'proof-claim)
    (kernel-error "expected proof claim, got ~S" claim))
  (unless (valid-proof-claim-kind-p (proof-claim-kind claim))
    (kernel-error "invalid proof claim kind: ~S" (proof-claim-kind claim)))
  (unless (equal (proof-claim-config-digest claim) *current-config-digest*)
    (kernel-error "proof claim config digest mismatch~%expected: ~S~%actual:   ~S"
                  *current-config-digest*
                  (proof-claim-config-digest claim)))
  (case (proof-claim-kind claim)
    (:has-type
     (ensure-core-context (proof-claim-context claim) 'proof-claim)
     (ensure-core-term (proof-claim-term claim) 'term 'proof-claim)
     (ensure-core-term (proof-claim-type claim) 'type 'proof-claim))
    (:defeq
     (ensure-core-context (proof-claim-context claim) 'proof-claim)
     (ensure-core-term (proof-claim-lhs claim) 'lhs 'proof-claim)
     (ensure-core-term (proof-claim-rhs claim) 'rhs 'proof-claim))
    (:step
     (ensure-core-term (proof-claim-lhs claim) 'lhs 'proof-claim)
     (ensure-core-term (proof-claim-rhs claim) 'rhs 'proof-claim))
    (:wf-ctx
     (ensure-core-context (proof-claim-context claim) 'proof-claim)))
  claim)

(defun validate-proof-evidence (evidence)
  (unless (typep evidence 'proof-evidence)
    (kernel-error "expected proof evidence, got ~S" evidence))
  (unless (valid-proof-evidence-kind-p (proof-evidence-kind evidence))
    (kernel-error "invalid proof evidence kind: ~S" (proof-evidence-kind evidence)))
  (unless (listp (proof-evidence-premises evidence))
    (kernel-error "proof evidence premises must be a list, got ~S"
                  (proof-evidence-premises evidence)))
  evidence)

(defun make-proof-fragment (claim evidence &key (checker-ids '()) metadata)
  (unless (listp checker-ids)
    (kernel-error "proof fragment checker ids must be a list, got ~S" checker-ids))
  (%make-proof-fragment
   :claim claim
   :evidence evidence
   :checker-ids (copy-list checker-ids)
   :config-digest *current-config-digest*
   :metadata metadata))

(defun validate-proof-fragment (fragment)
  (unless (typep fragment 'proof-fragment)
    (kernel-error "expected proof fragment, got ~S" fragment))
  (validate-proof-claim (proof-fragment-claim fragment))
  (validate-proof-evidence (proof-fragment-evidence fragment))
  (unless (listp (proof-fragment-checker-ids fragment))
    (kernel-error "proof fragment checker ids must be a list, got ~S"
                  (proof-fragment-checker-ids fragment)))
  (unless (equal (proof-fragment-config-digest fragment) *current-config-digest*)
    (kernel-error "proof fragment config digest mismatch~%expected: ~S~%actual:   ~S"
                  *current-config-digest*
                  (proof-fragment-config-digest fragment)))
  fragment)

(defun proof-claim->kernel-judgment (claim)
  (validate-proof-claim claim)
  (case (proof-claim-kind claim)
    (:has-type
     (make-kernel-judgment
      :context (copy-tree (proof-claim-context claim))
      :term (proof-claim-term claim)
      :type (proof-claim-type claim)
      :config (proof-claim-config-digest claim)
      :judgment-kind :typing))
    (:defeq
     (make-defeq-judgment
      (copy-tree (proof-claim-context claim))
      (proof-claim-lhs claim)
      (proof-claim-rhs claim)
      (proof-claim-config-digest claim)))
    (:step
     (make-step-judgment
      (proof-claim-lhs claim)
      (proof-claim-rhs claim)
      (proof-claim-config-digest claim)))
    (:wf-ctx
     (make-wf-context-judgment
      (copy-tree (proof-claim-context claim))
      (proof-claim-config-digest claim)))
    (otherwise
     (kernel-error "proof claim kind ~S has no kernel-judgment lowering"
                   (proof-claim-kind claim)))))

(defun proof-fragment->certificate (fragment env-digest)
  (validate-proof-fragment fragment)
  (let ((claim (proof-fragment-claim fragment)))
    (unless (eq (proof-claim-kind claim) :has-type)
      (kernel-error "only :has-type proof claims can lower to certificates, got ~S"
                    (proof-claim-kind claim)))
    (make-certificate
     :schema-version *certificate-schema-version*
     :judgment-kind :typing
     :context (copy-tree (proof-claim-context claim))
     :term (proof-claim-term claim)
     :type (proof-claim-type claim)
     :env-digest env-digest
     :config-digest (proof-fragment-config-digest fragment)
     :checker-ids (copy-list (proof-fragment-checker-ids fragment))
     :metadata (append (list :claim-kind (proof-claim-kind claim)
                             :evidence-kind (proof-evidence-kind
                                             (proof-fragment-evidence fragment)))
                       (copy-list (proof-fragment-metadata fragment))))))

(defun j-d-proof-claim (env claim)
  (j-d env (proof-claim->kernel-judgment claim)))

(defun j-kr-proof-claim (reference-env claim)
  (j-kr reference-env (proof-claim->kernel-judgment claim)))

(defun j-kl-proof-claim (env claim)
  (j-kl env (proof-claim->kernel-judgment claim)))

(defun j-d-proof-fragment (env fragment)
  (validate-proof-fragment fragment)
  (and (proof-evidence-checkedp (proof-fragment-evidence fragment))
       (j-d-proof-claim env (proof-fragment-claim fragment))))

(defun j-kr-proof-fragment (reference-env fragment)
  (validate-proof-fragment fragment)
  (and (proof-evidence-checkedp (proof-fragment-evidence fragment))
       (j-kr-proof-claim reference-env (proof-fragment-claim fragment))))

(defun j-kl-proof-fragment (env fragment)
  (validate-proof-fragment fragment)
  (and (proof-evidence-checkedp (proof-fragment-evidence fragment))
       (j-kl-proof-claim env (proof-fragment-claim fragment))))

(defun check-proof-fragment (env fragment &key expected-env-digest)
  (let ((certificate
          (proof-fragment->certificate fragment
                                       (or expected-env-digest
                                           (artifact-digest env)))))
    (check-certificate env certificate :expected-env-digest expected-env-digest)))
