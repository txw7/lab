(in-package :mini-kernel)

(defstruct (lean-theorem-schema
            (:constructor %make-lean-theorem-schema
                (&key id module name source-kind obligation-id parameter-keys statement-builder)))
  id
  module
  name
  source-kind
  obligation-id
  parameter-keys
  statement-builder)

(defparameter *lean-theorem-schemas* nil)

(defun valid-lean-theorem-source-kind-p (kind)
  (member kind '(:axiom :theorem) :test #'eq))

(defun validate-lean-theorem-schema (schema)
  (unless (typep schema 'lean-theorem-schema)
    (kernel-error "expected lean theorem schema, got ~S" schema))
  (unless (stringp (lean-theorem-schema-module schema))
    (kernel-error "lean theorem schema module must be a string, got ~S"
                  (lean-theorem-schema-module schema)))
  (unless (stringp (lean-theorem-schema-name schema))
    (kernel-error "lean theorem schema name must be a string, got ~S"
                  (lean-theorem-schema-name schema)))
  (unless (valid-lean-theorem-source-kind-p (lean-theorem-schema-source-kind schema))
    (kernel-error "invalid lean theorem source kind: ~S"
                  (lean-theorem-schema-source-kind schema)))
  (unless (or (null (lean-theorem-schema-obligation-id schema))
              (find-theorem-obligation (lean-theorem-schema-obligation-id schema)))
    (kernel-error "unknown theorem obligation id in lean schema: ~S"
                  (lean-theorem-schema-obligation-id schema)))
  (unless (listp (lean-theorem-schema-parameter-keys schema))
    (kernel-error "lean theorem schema parameter keys must be a list, got ~S"
                  (lean-theorem-schema-parameter-keys schema)))
  (unless (or (functionp (lean-theorem-schema-statement-builder schema))
              (and (symbolp (lean-theorem-schema-statement-builder schema))
                   (fboundp (lean-theorem-schema-statement-builder schema))))
    (kernel-error "lean theorem schema statement builder must name a function, got ~S"
                  (lean-theorem-schema-statement-builder schema)))
  schema)

(defun find-lean-theorem-schema (id)
  (find id *lean-theorem-schemas* :key #'lean-theorem-schema-id :test #'eq))

(defun list-lean-theorem-schemas ()
  (copy-list *lean-theorem-schemas*))

(defun %ensure-plist-has-keys (plist keys source)
  (let ((missing (gensym "MISSING")))
  (dolist (key keys)
      (when (eq (getf plist key missing) missing)
      (kernel-error "~A missing required parameter key ~S" source key)))
    plist))

(defun %normalize-lean-schema-params (schema params)
  (unless (listp params)
    (kernel-error "lean theorem schema parameters must be a plist, got ~S" params))
  (%ensure-plist-has-keys params (lean-theorem-schema-parameter-keys schema)
                          (lean-theorem-schema-id schema))
  params)

(defun instantiate-lean-weakening-statement (&key gamma a term type)
  (ensure-core-context gamma 'lean-weakening)
  (ensure-core-term a 'binder 'lean-weakening)
  (ensure-core-term term 'term 'lean-weakening)
  (ensure-core-term type 'type 'lean-weakening)
  (make-theorem-statement
   :id :declarativecore-weakening
   :premises
   (list
    (proof-claim->proposition
     :j-d
     (make-has-type-claim gamma term type)))
   :conclusion
   (proof-claim->proposition
    :j-d
    (make-has-type-claim (cons a gamma)
                         (shift 1 0 term)
                         (shift 1 0 type)))
   :metadata
   (list :lean-module "Formal.DeclarativeCore"
         :lean-name "weakening"
         :source-kind :axiom)))

(defun instantiate-lean-substitution-statement (&key gamma a term type replacement)
  (ensure-core-context gamma 'lean-substitution)
  (ensure-core-term a 'binder 'lean-substitution)
  (ensure-core-term term 'term 'lean-substitution)
  (ensure-core-term type 'type 'lean-substitution)
  (ensure-core-term replacement 'replacement 'lean-substitution)
  (make-theorem-statement
   :id :declarativecore-substitution
   :premises
   (list
    (proof-claim->proposition
     :j-d
     (make-has-type-claim (cons a gamma) term type))
    (proof-claim->proposition
     :j-d
     (make-has-type-claim gamma replacement a)))
   :conclusion
   (proof-claim->proposition
    :j-d
    (make-has-type-claim gamma
                         (subst-top replacement term)
                         (subst-top replacement type)))
   :metadata
   (list :lean-module "Formal.DeclarativeCore"
         :lean-name "substitution"
         :source-kind :axiom)))

(defun instantiate-lean-subject-reduction-statement (&key gamma term type reduct)
  (ensure-core-context gamma 'lean-subject-reduction)
  (ensure-core-term term 'term 'lean-subject-reduction)
  (ensure-core-term type 'type 'lean-subject-reduction)
  (ensure-core-term reduct 'reduct 'lean-subject-reduction)
  (make-theorem-statement
   :id :declarativecore-subject-reduction
   :premises
   (list
    (proof-claim->proposition
     :j-d
     (make-has-type-claim gamma term type))
    (proof-claim->proposition
     :j-d
     (make-step-claim term reduct)))
   :conclusion
   (proof-claim->proposition
    :j-d
    (make-has-type-claim gamma reduct type))
   :metadata
   (list :lean-module "Formal.DeclarativeCore"
         :lean-name "subjectReduction"
         :source-kind :axiom)))

(defun instantiate-lean-krcheck-sound-statement (&key gamma term type)
  (ensure-core-context gamma 'lean-krcheck-sound)
  (ensure-core-term term 'term 'lean-krcheck-sound)
  (ensure-core-term type 'type 'lean-krcheck-sound)
  (make-theorem-statement
   :id :declarativecore-krcheck-sound
   :premises
   (list
    (proof-claim->proposition
     :j-kr
     (make-has-type-claim gamma term type)))
   :conclusion
   (proof-claim->proposition
    :j-d
    (make-has-type-claim gamma term type))
   :metadata
   (list :lean-module "Formal.DeclarativeCore"
         :lean-name "krCheck_sound"
         :source-kind :theorem)))

(defun instantiate-lean-theorem-statement (schema-id &rest params)
  (let ((schema (find-lean-theorem-schema schema-id)))
    (unless schema
      (kernel-error "unknown lean theorem schema id: ~S" schema-id))
    (validate-lean-theorem-schema schema)
    (apply (if (symbolp (lean-theorem-schema-statement-builder schema))
               (symbol-function (lean-theorem-schema-statement-builder schema))
               (lean-theorem-schema-statement-builder schema))
           (%normalize-lean-schema-params schema params))))

(setf *lean-theorem-schemas*
      (list
       (%make-lean-theorem-schema
        :id :declarativecore-weakening
        :module "Formal.DeclarativeCore"
        :name "weakening"
        :source-kind :axiom
        :obligation-id :jd-weakening
        :parameter-keys '(:gamma :a :term :type)
        :statement-builder 'instantiate-lean-weakening-statement)
       (%make-lean-theorem-schema
        :id :declarativecore-substitution
        :module "Formal.DeclarativeCore"
        :name "substitution"
        :source-kind :axiom
        :obligation-id :jd-substitution
        :parameter-keys '(:gamma :a :term :type :replacement)
        :statement-builder 'instantiate-lean-substitution-statement)
       (%make-lean-theorem-schema
        :id :declarativecore-subject-reduction
        :module "Formal.DeclarativeCore"
       :name "subjectReduction"
       :source-kind :axiom
       :obligation-id :jd-subject-reduction
       :parameter-keys '(:gamma :term :type :reduct)
        :statement-builder 'instantiate-lean-subject-reduction-statement)
       (%make-lean-theorem-schema
        :id :declarativecore-krcheck-sound
        :module "Formal.DeclarativeCore"
        :name "krCheck_sound"
        :source-kind :theorem
        :obligation-id :jkr-soundness
        :parameter-keys '(:gamma :term :type)
        :statement-builder 'instantiate-lean-krcheck-sound-statement)))
