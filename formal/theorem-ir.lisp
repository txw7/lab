(in-package :mini-kernel)

(defparameter *theorem-evidence-kinds*
  '(:audit-witness :fragment-certificate))

(defstruct (theorem-claim
            (:constructor %make-theorem-claim
                (&key obligation-id parameters config-digest metadata)))
  obligation-id
  parameters
  config-digest
  metadata)

(defstruct (theorem-evidence
            (:constructor %make-theorem-evidence (&key kind payload checkedp)))
  kind
  payload
  checkedp)

(defstruct (theorem-fragment
            (:constructor %make-theorem-fragment
                (&key claim evidence checker-ids config-digest metadata)))
  claim
  evidence
  checker-ids
  config-digest
  metadata)

(defstruct (theorem-witness-bundle
            (:constructor %make-theorem-witness-bundle
                (&key obligation-id parameters checked entries failures config-digest)))
  obligation-id
  parameters
  checked
  entries
  failures
  config-digest)

(defun valid-theorem-evidence-kind-p (kind)
  (member kind *theorem-evidence-kinds* :test #'eq))

(defun make-theorem-claim (obligation-id &key (parameters '()) metadata)
  (unless (find-theorem-obligation obligation-id)
    (kernel-error "unknown theorem obligation id: ~S" obligation-id))
  (unless (listp parameters)
    (kernel-error "theorem claim parameters must be a plist, got ~S" parameters))
  (%make-theorem-claim
   :obligation-id obligation-id
   :parameters (copy-list parameters)
   :config-digest *current-config-digest*
   :metadata metadata))

(defun make-theorem-evidence (kind &key payload (checkedp nil))
  (unless (valid-theorem-evidence-kind-p kind)
    (kernel-error "invalid theorem evidence kind: ~S" kind))
  (%make-theorem-evidence
   :kind kind
   :payload payload
   :checkedp (not (null checkedp))))

(defun make-theorem-fragment (claim evidence &key (checker-ids '()) metadata)
  (unless (listp checker-ids)
    (kernel-error "theorem fragment checker ids must be a list, got ~S" checker-ids))
  (%make-theorem-fragment
   :claim claim
   :evidence evidence
   :checker-ids (copy-list checker-ids)
   :config-digest *current-config-digest*
   :metadata metadata))

(defun validate-theorem-claim (claim)
  (unless (typep claim 'theorem-claim)
    (kernel-error "expected theorem claim, got ~S" claim))
  (unless (find-theorem-obligation (theorem-claim-obligation-id claim))
    (kernel-error "unknown theorem obligation id: ~S"
                  (theorem-claim-obligation-id claim)))
  (unless (listp (theorem-claim-parameters claim))
    (kernel-error "theorem claim parameters must be a plist, got ~S"
                  (theorem-claim-parameters claim)))
  (unless (equal (theorem-claim-config-digest claim) *current-config-digest*)
    (kernel-error "theorem claim config digest mismatch~%expected: ~S~%actual:   ~S"
                  *current-config-digest*
                  (theorem-claim-config-digest claim)))
  claim)

(defun validate-theorem-evidence (evidence)
  (unless (typep evidence 'theorem-evidence)
    (kernel-error "expected theorem evidence, got ~S" evidence))
  (unless (valid-theorem-evidence-kind-p (theorem-evidence-kind evidence))
    (kernel-error "invalid theorem evidence kind: ~S"
                  (theorem-evidence-kind evidence)))
  evidence)

(defun validate-theorem-witness-bundle (bundle)
  (unless (typep bundle 'theorem-witness-bundle)
    (kernel-error "expected theorem witness bundle, got ~S" bundle))
  (unless (find-theorem-obligation (theorem-witness-bundle-obligation-id bundle))
    (kernel-error "unknown theorem obligation id in witness bundle: ~S"
                  (theorem-witness-bundle-obligation-id bundle)))
  (unless (listp (theorem-witness-bundle-parameters bundle))
    (kernel-error "theorem witness bundle parameters must be a plist, got ~S"
                  (theorem-witness-bundle-parameters bundle)))
  (unless (listp (theorem-witness-bundle-entries bundle))
    (kernel-error "theorem witness bundle entries must be a list, got ~S"
                  (theorem-witness-bundle-entries bundle)))
  (unless (listp (theorem-witness-bundle-failures bundle))
    (kernel-error "theorem witness bundle failures must be a list, got ~S"
                  (theorem-witness-bundle-failures bundle)))
  (unless (equal (theorem-witness-bundle-config-digest bundle) *current-config-digest*)
    (kernel-error "theorem witness bundle config digest mismatch~%expected: ~S~%actual:   ~S"
                  *current-config-digest*
                  (theorem-witness-bundle-config-digest bundle)))
  bundle)

(defun validate-theorem-fragment (fragment)
  (unless (typep fragment 'theorem-fragment)
    (kernel-error "expected theorem fragment, got ~S" fragment))
  (validate-theorem-claim (theorem-fragment-claim fragment))
  (validate-theorem-evidence (theorem-fragment-evidence fragment))
  (unless (listp (theorem-fragment-checker-ids fragment))
    (kernel-error "theorem fragment checker ids must be a list, got ~S"
                  (theorem-fragment-checker-ids fragment)))
  (unless (equal (theorem-fragment-config-digest fragment) *current-config-digest*)
    (kernel-error "theorem fragment config digest mismatch~%expected: ~S~%actual:   ~S"
                  *current-config-digest*
                  (theorem-fragment-config-digest fragment)))
  fragment)

(defun theorem-obligation-emitter (obligation-id)
  (case obligation-id
    (:jd-substitution #'emit-jd-substitution-fragment-certificate)
    (:jd-weakening #'emit-jd-weakening-fragment-certificate)
    (:jd-subject-reduction #'emit-jd-subject-reduction-fragment-certificate)
    (:jkr-soundness #'emit-jd-jkr-soundness-fragment-certificate)
    (:jkr-fragment-completeness #'emit-jd-jkr-completeness-fragment-certificate)
    (:jkl-jkr-equivalence #'emit-jkr-jkl-equivalence-fragment-certificate)
    (:jdefir-jkr-equivalence #'emit-jkr-defir-equivalence-fragment-certificate)
    (otherwise nil)))

(defun theorem-obligation-verifier (obligation-id)
  (case obligation-id
    (:jd-substitution #'verify-jd-substitution-fragment-certificate)
    (:jd-weakening #'verify-jd-weakening-fragment-certificate)
    (:jd-subject-reduction #'verify-jd-subject-reduction-fragment-certificate)
    (:jkr-soundness #'verify-jd-jkr-soundness-fragment-certificate)
    (:jkr-fragment-completeness #'verify-jd-jkr-fragment-completeness-fragment-certificate)
    (:jkl-jkr-equivalence #'verify-jkr-jkl-equivalence-fragment-certificate)
    (:jdefir-jkr-equivalence #'verify-jkr-defir-equivalence-fragment-certificate)
    (otherwise nil)))

(defun theorem-obligation-witness-builder (obligation-id)
  (case obligation-id
    (:jd-substitution #'make-jd-substitution-witness-bundle)
    (:jd-weakening #'make-jd-weakening-witness-bundle)
    (:jd-subject-reduction #'make-jd-subject-reduction-witness-bundle)
    (:jkr-soundness #'make-jkr-soundness-witness-bundle)
    (:jkr-fragment-completeness #'make-jkr-fragment-completeness-witness-bundle)
    (:jkl-jkr-equivalence #'make-jkl-jkr-equivalence-witness-bundle)
    (:jdefir-jkr-equivalence #'make-jdefir-jkr-equivalence-witness-bundle)
    (otherwise nil)))

(defun %kernel-has-type-proposition (lane context term type)
  (proof-claim->proposition lane (make-has-type-claim context term type)))

(defun %kernel-step-proposition (lane lhs rhs)
  (proof-claim->proposition lane (make-step-claim lhs rhs)))

(defun %theorem-entry (premises conclusion)
  (list :premises premises :conclusion conclusion))

(defun %jd-weakening-entry (instance)
  (let* ((gamma (getf instance :gamma))
         (binder-type (getf instance :binder-type))
         (term (getf instance :term))
         (type (getf instance :type))
         (weakened-context (getf instance :weakened-context))
         (weakened-term (getf instance :weakened-term))
         (weakened-type (getf instance :weakened-type)))
    (%theorem-entry
     (list (%kernel-has-type-proposition :j-d gamma term type))
     (%kernel-has-type-proposition :j-d
                                  weakened-context
                                  weakened-term
                                  weakened-type))))

(defun %jd-substitution-entry (instance)
  (let* ((gamma (getf instance :gamma))
         (binder-type (getf instance :binder-type))
         (replacement (getf instance :replacement))
         (body (getf instance :body))
         (body-type (getf instance :body-type))
         (substituted-body (getf instance :substituted-body))
         (substituted-type (getf instance :substituted-type))
         (extended-context (cons binder-type gamma)))
    (%theorem-entry
     (list (%kernel-has-type-proposition :j-d extended-context body body-type)
           (%kernel-has-type-proposition :j-d gamma replacement binder-type))
     (%kernel-has-type-proposition :j-d gamma substituted-body substituted-type))))

(defun %jd-subject-reduction-entry (instance)
  (let ((gamma (getf instance :gamma))
        (term (getf instance :term))
        (type (getf instance :type))
        (reduct (getf instance :reduct)))
    (%theorem-entry
     (list (%kernel-has-type-proposition :j-d gamma term type)
           (%kernel-step-proposition :j-d term reduct))
     (%kernel-has-type-proposition :j-d gamma reduct type))))

(defun %make-jd-witness-bundle (obligation-id payload entry-builder
                                 &key max-depth max-context-size)
  (%make-theorem-witness-bundle
   :obligation-id obligation-id
   :parameters (list :max-depth max-depth :max-context-size max-context-size)
   :checked (getf payload :checked)
   :entries (mapcar entry-builder (getf payload :instances))
   :failures (mapcar entry-builder (getf payload :failures))
   :config-digest *current-config-digest*))

(defun make-jd-weakening-witness-bundle (&key (max-depth 0) (max-context-size 1))
  (%make-jd-witness-bundle
   :jd-weakening
   (%jd-weakening-fragment-data
    :max-depth max-depth
    :max-context-size max-context-size)
   #'%jd-weakening-entry
   :max-depth max-depth
   :max-context-size max-context-size))

(defun make-jd-substitution-witness-bundle (&key (max-depth 0) (max-context-size 1))
  (%make-jd-witness-bundle
   :jd-substitution
   (%jd-substitution-fragment-data
    :max-depth max-depth
    :max-context-size max-context-size)
   #'%jd-substitution-entry
   :max-depth max-depth
   :max-context-size max-context-size))

(defun make-jd-subject-reduction-witness-bundle (&key (max-depth 0) (max-context-size 1))
  (%make-jd-witness-bundle
   :jd-subject-reduction
   (%jd-subject-reduction-fragment-data
    :max-depth max-depth
    :max-context-size max-context-size)
   #'%jd-subject-reduction-entry
   :max-depth max-depth
   :max-context-size max-context-size))

(defun %relation-witness-entry (judgment &rest lane-statuses)
  (append (list :context (kernel-judgment-context judgment)
                :term (kernel-judgment-term judgment)
                :type (kernel-judgment-type judgment)
                :judgment-kind (kernel-judgment-judgment-kind judgment))
          lane-statuses))

(defun %make-kernel-relation-witness-bundle
    (obligation-id entry-builder failure-predicate
     &key (max-depth 1) (max-context-size 1) (carrier-mode :cross-product))
  (let* ((env (make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (judgments (%judgment-audit-cases max-depth max-context-size
                                           :carrier-mode carrier-mode))
         (entries '())
         (failures '())
         (checked 0))
    (dolist (judgment judgments)
      (let* ((jd (%jd-judgment-status env judgment))
             (jkr (%jkr-judgment-status reference-env judgment))
             (jkl (%jkl-judgment-status env judgment))
             (entry (funcall entry-builder judgment jd jkr jkl)))
        (incf checked)
        (push entry entries)
        (when (funcall failure-predicate jd jkr jkl)
          (push entry failures))))
    (%make-theorem-witness-bundle
     :obligation-id obligation-id
     :parameters (list :max-depth max-depth
                       :max-context-size max-context-size
                       :carrier-mode carrier-mode)
     :checked checked
     :entries (nreverse entries)
     :failures (nreverse failures)
     :config-digest *current-config-digest*)))

(defun make-jkr-soundness-witness-bundle
    (&key (max-depth 1) (max-context-size 1) (carrier-mode :cross-product))
  (%make-kernel-relation-witness-bundle
   :jkr-soundness
   (lambda (judgment jd jkr jkl)
     (declare (ignore jkl))
     (%relation-witness-entry judgment :j-d jd :j-kr jkr))
   (lambda (jd jkr jkl)
     (declare (ignore jkl))
     (and (eq jkr :accepted)
          (not (eq jd :accepted))))
   :max-depth max-depth
   :max-context-size max-context-size
   :carrier-mode carrier-mode))

(defun make-jkr-fragment-completeness-witness-bundle
    (&key (max-depth 1) (max-context-size 1) (carrier-mode :cross-product))
  (%make-kernel-relation-witness-bundle
   :jkr-fragment-completeness
   (lambda (judgment jd jkr jkl)
     (declare (ignore jkl))
     (%relation-witness-entry judgment :j-d jd :j-kr jkr))
   (lambda (jd jkr jkl)
     (declare (ignore jkl))
     (and (eq jd :accepted)
          (not (eq jkr :accepted))))
   :max-depth max-depth
   :max-context-size max-context-size
   :carrier-mode carrier-mode))

(defun make-jkl-jkr-equivalence-witness-bundle
    (&key (max-depth 1) (max-context-size 1) (carrier-mode :cross-product))
  (%make-kernel-relation-witness-bundle
   :jkl-jkr-equivalence
   (lambda (judgment jd jkr jkl)
     (declare (ignore jd))
     (%relation-witness-entry judgment :j-kr jkr :j-kl jkl))
   (lambda (jd jkr jkl)
     (declare (ignore jd))
     (not (eq jkr jkl)))
   :max-depth max-depth
   :max-context-size max-context-size
   :carrier-mode carrier-mode))

(defun make-jdefir-jkr-equivalence-witness-bundle
    (&key (max-depth 1) (max-context-size 1) (carrier-mode :cross-product))
  (let* ((env (make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (implementation (make-defir-kernel-implementation))
         (judgments (%judgment-audit-cases max-depth max-context-size
                                           :carrier-mode carrier-mode))
         (entries '())
         (failures '())
         (checked 0))
    (dolist (judgment judgments)
      (let* ((jkr (%jkr-judgment-status reference-env judgment))
             (jdefir (%implementation-judgment-status implementation env judgment))
             (entry (%relation-witness-entry judgment :j-kr jkr :j-defir jdefir)))
        (incf checked)
        (push entry entries)
        (unless (eq jkr jdefir)
          (push entry failures))))
    (%make-theorem-witness-bundle
     :obligation-id :jdefir-jkr-equivalence
     :parameters (list :max-depth max-depth
                       :max-context-size max-context-size
                       :carrier-mode carrier-mode)
     :checked checked
     :entries (nreverse entries)
     :failures (nreverse failures)
     :config-digest *current-config-digest*)))

(defun theorem-claim->witness-bundle (claim)
  (validate-theorem-claim claim)
  (let ((builder (theorem-obligation-witness-builder
                  (theorem-claim-obligation-id claim))))
    (unless builder
      (kernel-error "theorem obligation ~S has no witness-bundle builder"
                    (theorem-claim-obligation-id claim)))
    (apply builder (theorem-claim-parameters claim))))

(defun verify-theorem-witness-bundle (bundle)
  (validate-theorem-witness-bundle bundle)
  (let ((builder (theorem-obligation-witness-builder
                  (theorem-witness-bundle-obligation-id bundle))))
    (unless builder
      (kernel-error "theorem obligation ~S has no witness-bundle verifier"
                    (theorem-witness-bundle-obligation-id bundle)))
    (let ((expected (apply builder (theorem-witness-bundle-parameters bundle))))
      (and (= (theorem-witness-bundle-checked bundle)
              (theorem-witness-bundle-checked expected))
           (equal (theorem-witness-bundle-parameters bundle)
                  (theorem-witness-bundle-parameters expected))
           (equal (theorem-witness-bundle-entries bundle)
                  (theorem-witness-bundle-entries expected))
           (equal (theorem-witness-bundle-failures bundle)
                  (theorem-witness-bundle-failures expected))))))

(defun theorem-claim->fragment-certificate (claim)
  (validate-theorem-claim claim)
  (let ((emitter (theorem-obligation-emitter (theorem-claim-obligation-id claim))))
    (unless emitter
      (kernel-error "theorem obligation ~S has no fragment-certificate emitter"
                    (theorem-claim-obligation-id claim)))
    (apply emitter (theorem-claim-parameters claim))))

(defun verify-theorem-fragment-certificate (certificate)
  (unless (typep certificate 'theorem-fragment-certificate)
    (kernel-error "expected theorem fragment certificate, got ~S" certificate))
  (let ((verifier (theorem-obligation-verifier
                   (theorem-fragment-certificate-obligation-id certificate))))
    (unless verifier
      (kernel-error "theorem obligation ~S has no fragment-certificate verifier"
                    (theorem-fragment-certificate-obligation-id certificate)))
    (funcall verifier certificate)))

(defun check-theorem-claim (claim)
  (validate-theorem-claim claim)
  (let ((result
          (apply #'run-theorem-obligation-audit
                 (theorem-claim-obligation-id claim)
                 (theorem-claim-parameters claim))))
    (let ((builder (theorem-obligation-witness-builder
                    (theorem-claim-obligation-id claim))))
      (when builder
        (setf (getf (backend-result-artifacts result) :witness-bundle)
              (apply builder (theorem-claim-parameters claim)))))
    result))

(defun check-theorem-fragment (fragment)
  (validate-theorem-fragment fragment)
  (and (theorem-evidence-checkedp (theorem-fragment-evidence fragment))
       (let* ((claim (theorem-fragment-claim fragment))
              (evidence (theorem-fragment-evidence fragment)))
         (case (theorem-evidence-kind evidence)
           (:audit-witness
            (let ((payload (theorem-evidence-payload evidence)))
              (and (validate-theorem-witness-bundle payload)
                   (eq (theorem-witness-bundle-obligation-id payload)
                       (theorem-claim-obligation-id claim))
                   (verify-theorem-witness-bundle payload)
                   (null (theorem-witness-bundle-failures payload)))))
           (:fragment-certificate
            (let ((result (check-theorem-claim claim)))
              (eq (backend-result-status result) :accepted)))
           (otherwise
            nil)))))
