(in-package :mini-kernel)

(defparameter *kernel-judgment-lanes* '(:j-d :j-kr :j-kl))
(defparameter *theorem-derivation-kinds*
  '(:premise
    :proof-fragment
    :theorem-fragment
    :apply-theorem-fragment
    :apply-relation-fragment
    :and-intro
    :and-elim-left
    :and-elim-right))

(defstruct (theorem-statement
            (:constructor %make-theorem-statement
                (&key id premises conclusion config-digest metadata)))
  id
  premises
  conclusion
  config-digest
  metadata)

(defstruct (theorem-derivation
            (:constructor %make-theorem-derivation
                (&key kind payload subderivations metadata)))
  kind
  payload
  subderivations
  metadata)

(defun valid-kernel-judgment-lane-p (lane)
  (member lane *kernel-judgment-lanes* :test #'eq))

(defun valid-theorem-derivation-kind-p (kind)
  (member kind *theorem-derivation-kinds* :test #'eq))

(defun proof-claim->proposition (lane claim)
  (unless (valid-kernel-judgment-lane-p lane)
    (kernel-error "invalid kernel judgment lane: ~S" lane))
  (validate-proof-claim claim)
  (case (proof-claim-kind claim)
    (:has-type
     (list :kernel-claim
           lane
           :has-type
           (copy-tree (proof-claim-context claim))
           (proof-claim-term claim)
           (proof-claim-type claim)
           (proof-claim-config-digest claim)))
    (:defeq
     (list :kernel-claim
           lane
           :defeq
           (copy-tree (proof-claim-context claim))
           (proof-claim-lhs claim)
           (proof-claim-rhs claim)
           (proof-claim-config-digest claim)))
    (:step
     (list :kernel-claim
           lane
           :step
           (proof-claim-lhs claim)
           (proof-claim-rhs claim)
           (proof-claim-config-digest claim)))
    (:wf-ctx
     (list :kernel-claim
           lane
           :wf-ctx
           (copy-tree (proof-claim-context claim))
           (proof-claim-config-digest claim)))
    (otherwise
     (kernel-error "unsupported proof claim kind for proposition lowering: ~S"
                   (proof-claim-kind claim)))))

(defun theorem-claim->proposition (claim)
  (validate-theorem-claim claim)
  (list :theorem-claim
        (theorem-claim-obligation-id claim)
        (copy-list (theorem-claim-parameters claim))
        (theorem-claim-config-digest claim)))

(defun validate-theorem-proposition (proposition)
  (unless (consp proposition)
    (kernel-error "theorem proposition must be a proper list, got ~S" proposition))
  (case (first proposition)
    (:kernel-claim
     (unless (member (length proposition) '(5 6 7) :test #'=)
       (kernel-error "malformed kernel-claim proposition: ~S" proposition))
     (unless (valid-kernel-judgment-lane-p (second proposition))
       (kernel-error "invalid kernel-claim lane in proposition: ~S" proposition))
     proposition)
    (:theorem-claim
     (unless (= (length proposition) 4)
       (kernel-error "malformed theorem-claim proposition: ~S" proposition))
     (unless (find-theorem-obligation (second proposition))
       (kernel-error "unknown theorem obligation in proposition: ~S" proposition))
     proposition)
    (:and
     (unless (= (length proposition) 3)
       (kernel-error "malformed conjunction proposition: ~S" proposition))
     (validate-theorem-proposition (second proposition))
     (validate-theorem-proposition (third proposition))
     proposition)
    (otherwise
     (kernel-error "unknown theorem proposition kind: ~S" proposition))))

(defun make-theorem-statement (&key id (premises '()) conclusion metadata)
  (unless (listp premises)
    (kernel-error "theorem statement premises must be a list, got ~S" premises))
  (dolist (premise premises)
    (validate-theorem-proposition premise))
  (validate-theorem-proposition conclusion)
  (%make-theorem-statement
   :id id
   :premises (copy-tree premises)
   :conclusion (copy-tree conclusion)
   :config-digest *current-config-digest*
   :metadata metadata))

(defun make-premise-derivation (index &key metadata)
  (unless (and (integerp index) (<= 0 index))
    (kernel-error "premise derivation index must be a nonnegative integer, got ~S" index))
  (%make-theorem-derivation
   :kind :premise
   :payload index
   :subderivations '()
   :metadata metadata))

(defun make-proof-fragment-derivation (lane fragment &key metadata)
  (unless (valid-kernel-judgment-lane-p lane)
    (kernel-error "invalid kernel judgment lane for proof-fragment derivation: ~S" lane))
  (%make-theorem-derivation
   :kind :proof-fragment
   :payload (list :lane lane :fragment fragment)
   :subderivations '()
   :metadata metadata))

(defun make-theorem-fragment-derivation (fragment &key metadata)
  (%make-theorem-derivation
   :kind :theorem-fragment
   :payload fragment
   :subderivations '()
   :metadata metadata))

(defun make-apply-theorem-fragment-derivation
    (fragment premises &key conclusion metadata)
  (unless (listp premises)
    (kernel-error "apply-theorem-fragment premises must be a list, got ~S" premises))
  (%make-theorem-derivation
   :kind :apply-theorem-fragment
   :payload (list :fragment fragment :conclusion conclusion)
   :subderivations (copy-list premises)
   :metadata metadata))

(defun make-apply-relation-fragment-derivation (fragment premise &key metadata)
  (%make-theorem-derivation
   :kind :apply-relation-fragment
   :payload fragment
   :subderivations (list premise)
   :metadata metadata))

(defun make-and-intro-derivation (left right &key metadata)
  (%make-theorem-derivation
   :kind :and-intro
   :payload nil
   :subderivations (list left right)
   :metadata metadata))

(defun make-and-elim-left-derivation (source &key metadata)
  (%make-theorem-derivation
   :kind :and-elim-left
   :payload nil
   :subderivations (list source)
   :metadata metadata))

(defun make-and-elim-right-derivation (source &key metadata)
  (%make-theorem-derivation
   :kind :and-elim-right
   :payload nil
   :subderivations (list source)
   :metadata metadata))

(defun validate-theorem-statement (statement)
  (unless (typep statement 'theorem-statement)
    (kernel-error "expected theorem statement, got ~S" statement))
  (unless (equal (theorem-statement-config-digest statement) *current-config-digest*)
    (kernel-error "theorem statement config digest mismatch~%expected: ~S~%actual:   ~S"
                  *current-config-digest*
                  (theorem-statement-config-digest statement)))
  (unless (listp (theorem-statement-premises statement))
    (kernel-error "theorem statement premises must be a list, got ~S"
                  (theorem-statement-premises statement)))
  (dolist (premise (theorem-statement-premises statement))
    (validate-theorem-proposition premise))
  (validate-theorem-proposition (theorem-statement-conclusion statement))
  statement)

(defun validate-theorem-derivation (derivation)
  (unless (typep derivation 'theorem-derivation)
    (kernel-error "expected theorem derivation, got ~S" derivation))
  (unless (valid-theorem-derivation-kind-p (theorem-derivation-kind derivation))
    (kernel-error "invalid theorem derivation kind: ~S"
                  (theorem-derivation-kind derivation)))
  (unless (listp (theorem-derivation-subderivations derivation))
    (kernel-error "theorem derivation subderivations must be a list, got ~S"
                  (theorem-derivation-subderivations derivation)))
  (dolist (sub (theorem-derivation-subderivations derivation))
    (validate-theorem-derivation sub))
  derivation)

(defun %kernel-claim-proposition-lane (proposition)
  (unless (and (consp proposition) (eq (first proposition) :kernel-claim))
    (kernel-error "expected kernel-claim proposition, got ~S" proposition))
  (second proposition))

(defun %kernel-claim-proposition-kind (proposition)
  (unless (and (consp proposition) (eq (first proposition) :kernel-claim))
    (kernel-error "expected kernel-claim proposition, got ~S" proposition))
  (third proposition))

(defun %kernel-claim-proposition-args (proposition)
  (unless (and (consp proposition) (eq (first proposition) :kernel-claim))
    (kernel-error "expected kernel-claim proposition, got ~S" proposition))
  (cdddr proposition))

(defun %rewrite-kernel-claim-proposition-lane (proposition new-lane)
  (unless (valid-kernel-judgment-lane-p new-lane)
    (kernel-error "invalid target lane for kernel-claim proposition: ~S" new-lane))
  (unless (and (consp proposition) (eq (first proposition) :kernel-claim))
    (kernel-error "expected kernel-claim proposition, got ~S" proposition))
  (cons :kernel-claim
        (cons new-lane (cddr proposition))))

(defun %relation-entry-covers-kernel-proposition-p (proposition entry)
  (unless (and (listp entry) (consp proposition) (eq (first proposition) :kernel-claim))
    (return-from %relation-entry-covers-kernel-proposition-p nil))
  (let ((lane (%kernel-claim-proposition-lane proposition))
        (kind (%kernel-claim-proposition-kind proposition))
        (args (%kernel-claim-proposition-args proposition)))
    (and (eq kind :has-type)
         (= (length args) 4)
         (equal (getf entry :context) (first args))
         (equal (getf entry :term) (second args))
         (equal (getf entry :type) (third args))
         (eq (getf entry :judgment-kind) :typing)
         (eq (getf entry lane) :accepted))))

(defun %relation-fragment-conclusion (fragment premise)
  (validate-theorem-fragment fragment)
  (validate-theorem-proposition premise)
  (unless (and (consp premise) (eq (first premise) :kernel-claim))
    (kernel-error "relation fragment premise must be a kernel-claim proposition, got ~S"
                  premise))
  (unless (check-theorem-fragment fragment)
    (kernel-error "relation theorem fragment not accepted: ~S" fragment))
  (let* ((claim (theorem-fragment-claim fragment))
         (obligation-id (theorem-claim-obligation-id claim))
         (evidence (theorem-fragment-evidence fragment))
         (payload (theorem-evidence-payload evidence)))
    (unless (and (eq (theorem-evidence-kind evidence) :audit-witness)
                 (typep payload 'theorem-witness-bundle))
      (kernel-error "relation fragment must carry an audit-witness theorem bundle: ~S"
                    fragment))
    (unless (verify-theorem-witness-bundle payload)
      (kernel-error "relation theorem witness bundle did not verify: ~S" payload))
    (unless (find premise
                  (theorem-witness-bundle-entries payload)
                  :test #'%relation-entry-covers-kernel-proposition-p)
      (kernel-error "premise proposition not covered by theorem witness bundle: ~S" premise))
    (case obligation-id
      (:jkr-soundness
       (unless (eq (%kernel-claim-proposition-lane premise) :j-kr)
         (kernel-error "jkr-soundness premise must live on :j-kr, got ~S" premise))
       (%rewrite-kernel-claim-proposition-lane premise :j-d))
      (:jkr-fragment-completeness
       (unless (eq (%kernel-claim-proposition-lane premise) :j-d)
         (kernel-error "jkr-fragment-completeness premise must live on :j-d, got ~S" premise))
       (%rewrite-kernel-claim-proposition-lane premise :j-kr))
      (:jkl-jkr-equivalence
       (case (%kernel-claim-proposition-lane premise)
         (:j-kr (%rewrite-kernel-claim-proposition-lane premise :j-kl))
         (:j-kl (%rewrite-kernel-claim-proposition-lane premise :j-kr))
         (otherwise
          (kernel-error "jkl-jkr-equivalence premise must live on :j-kr or :j-kl, got ~S"
                        premise))))
      (otherwise
       (kernel-error "unsupported relation theorem obligation for application: ~S"
                     obligation-id)))))

(defun %theorem-fragment-application-conclusion (fragment premises &optional expected-conclusion)
  (validate-theorem-fragment fragment)
  (dolist (premise premises)
    (validate-theorem-proposition premise))
  (when expected-conclusion
    (validate-theorem-proposition expected-conclusion))
  (unless (check-theorem-fragment fragment)
    (kernel-error "theorem fragment not accepted: ~S" fragment))
  (let* ((claim (theorem-fragment-claim fragment))
         (obligation-id (theorem-claim-obligation-id claim))
         (evidence (theorem-fragment-evidence fragment))
         (payload (theorem-evidence-payload evidence)))
    (unless (and (eq (theorem-evidence-kind evidence) :audit-witness)
                 (typep payload 'theorem-witness-bundle))
      (kernel-error "theorem fragment application requires an audit-witness theorem bundle: ~S"
                    fragment))
    (unless (verify-theorem-witness-bundle payload)
      (kernel-error "theorem witness bundle did not verify: ~S" payload))
    (let* ((matches
             (remove-if-not
              (lambda (bundle-entry)
                (and (equal premises (getf bundle-entry :premises))
                     (or (null expected-conclusion)
                         (equal expected-conclusion
                                (getf bundle-entry :conclusion)))))
              (theorem-witness-bundle-entries payload)))
           (entry
             (cond
               ((null matches)
                nil)
               ((null (rest matches))
                (first matches))
               (t
                (kernel-error "ambiguous theorem application for ~S with premises ~S"
                              obligation-id
                              premises)))))
      (unless entry
        (kernel-error "premises/conclusion not covered by theorem witness bundle for ~S: ~S => ~S"
                      obligation-id
                      premises
                      expected-conclusion))
      (getf entry :conclusion))))

(defun %derive-proof-fragment-proposition (env reference-env lane fragment)
  (validate-proof-fragment fragment)
  (let ((accepted
          (case lane
            (:j-d (j-d-proof-fragment env fragment))
            (:j-kr (j-kr-proof-fragment reference-env fragment))
            (:j-kl (j-kl-proof-fragment env fragment))
            (otherwise
             (kernel-error "unknown kernel judgment lane in derivation: ~S" lane)))))
    (unless accepted
      (kernel-error "proof fragment not accepted on lane ~S: ~S" lane fragment))
    (proof-claim->proposition lane (proof-fragment-claim fragment))))

(defun %derive-theorem-fragment-proposition (fragment)
  (validate-theorem-fragment fragment)
  (unless (check-theorem-fragment fragment)
    (kernel-error "theorem fragment not accepted: ~S" fragment))
  (theorem-claim->proposition (theorem-fragment-claim fragment)))

(defun %derive-theorem-proposition (premises derivation env reference-env)
  (validate-theorem-derivation derivation)
  (case (theorem-derivation-kind derivation)
    (:premise
     (let ((index (theorem-derivation-payload derivation)))
       (unless (and (integerp index) (<= 0 index) (< index (length premises)))
         (kernel-error "premise derivation index out of bounds: ~S" index))
       (nth index premises)))
    (:proof-fragment
     (let ((payload (theorem-derivation-payload derivation)))
       (unless (and (listp payload)
                    (eq (first payload) :lane))
         (kernel-error "malformed proof-fragment derivation payload: ~S" payload))
       (%derive-proof-fragment-proposition env
                                           reference-env
                                           (second payload)
                                           (getf payload :fragment))))
    (:theorem-fragment
     (%derive-theorem-fragment-proposition (theorem-derivation-payload derivation)))
    (:apply-theorem-fragment
     (let ((payload (theorem-derivation-payload derivation)))
       (unless (and (listp payload) (getf payload :fragment))
         (kernel-error "malformed apply-theorem-fragment payload: ~S" payload))
       (%theorem-fragment-application-conclusion
        (getf payload :fragment)
        (mapcar (lambda (sub)
                  (%derive-theorem-proposition premises sub env reference-env))
                (theorem-derivation-subderivations derivation))
        (getf payload :conclusion))))
    (:apply-relation-fragment
     (unless (= (length (theorem-derivation-subderivations derivation)) 1)
       (kernel-error "apply-relation-fragment requires exactly one premise derivation"))
     (%relation-fragment-conclusion
      (theorem-derivation-payload derivation)
      (%derive-theorem-proposition
       premises
       (first (theorem-derivation-subderivations derivation))
       env
       reference-env)))
    (:and-intro
     (unless (= (length (theorem-derivation-subderivations derivation)) 2)
       (kernel-error "and-intro derivation requires exactly two subderivations"))
     (destructuring-bind (left right) (theorem-derivation-subderivations derivation)
       (list :and
             (%derive-theorem-proposition premises left env reference-env)
             (%derive-theorem-proposition premises right env reference-env))))
    (:and-elim-left
     (unless (= (length (theorem-derivation-subderivations derivation)) 1)
       (kernel-error "and-elim-left derivation requires exactly one subderivation"))
     (let ((source (%derive-theorem-proposition
                    premises
                    (first (theorem-derivation-subderivations derivation))
                    env
                    reference-env)))
       (unless (and (consp source) (eq (first source) :and))
         (kernel-error "and-elim-left source is not a conjunction: ~S" source))
       (second source)))
    (:and-elim-right
     (unless (= (length (theorem-derivation-subderivations derivation)) 1)
       (kernel-error "and-elim-right derivation requires exactly one subderivation"))
     (let ((source (%derive-theorem-proposition
                    premises
                    (first (theorem-derivation-subderivations derivation))
                    env
                    reference-env)))
       (unless (and (consp source) (eq (first source) :and))
         (kernel-error "and-elim-right source is not a conjunction: ~S" source))
       (third source)))
    (otherwise
     (kernel-error "unsupported theorem derivation kind: ~S"
                   (theorem-derivation-kind derivation)))))

(defun infer-theorem-derivation-proposition
    (statement derivation &key (env (make-bootstrap-env)) (reference-env nil))
  (validate-theorem-statement statement)
  (let ((reference-env* (or reference-env
                            (mini-kernel-reference:make-reference-env env))))
    (let ((proposition (%derive-theorem-proposition
                        (theorem-statement-premises statement)
                        derivation
                        env
                        reference-env*)))
      (validate-theorem-proposition proposition)
      proposition)))

(defun check-theorem-derivation
    (statement derivation &key (env (make-bootstrap-env)) (reference-env nil))
  (handler-case
      (equal (infer-theorem-derivation-proposition
              statement
              derivation
              :env env
              :reference-env reference-env)
             (theorem-statement-conclusion (validate-theorem-statement statement)))
    (kernel-error ()
      nil)))
