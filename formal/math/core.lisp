(in-package :lab.math)

(defparameter *math-expression-operators*
  '(:constant :variable :application :equality :lt :le :gt :ge
    :and :or :not :implies :iff :forall :exists
    :add :subtract :multiply :divide :negate :sum :product :series
    :integral :derivative :limit :real-part :imaginary-part :absolute-value
    :power :logarithm :exponential :special-function :big-o :little-o
    :member :domain-restriction :matrix :vector
    :fourier-transform :mellin-transform :laplace-transform :stieltjes-transform))

(defparameter *math-statuses*
  '(:open :candidate :conditionally-proved :proved :disproved
    :bounded-witness :bounded-obstruction :trusted-external :blocked
    :capability-missing :budget-exhausted :superseded :unknown))

(defun %ensure-status (status)
  (unless (member status *math-statuses* :test #'eq)
    (error "Unknown mathematical status ~S" status))
  status)

(defun %stable-write (value)
  (with-standard-io-syntax
    (let ((*print-array* t)
          (*print-circle* nil)
          (*print-length* nil)
          (*print-level* nil)
          (*print-pretty* nil)
          (*print-readably* t))
      (write-to-string value))))

(defun %string-key (value)
  (%stable-write value))

(defstruct (math-expression
            (:constructor %make-math-expression
                (&key op args value name metadata)))
  op args value name metadata)

(defun math-expression-key (expression)
  (unless (typep expression 'math-expression)
    (error "Expected MathExpressionV1 carrier, got ~S" expression))
  (%string-key
   (list :math-expression-v1
         :op (math-expression-op expression)
         :args (mapcar (lambda (arg)
                         (if (typep arg 'math-expression)
                             (math-expression-key arg)
                             arg))
                       (math-expression-args expression))
         :value (math-expression-value expression)
         :name (math-expression-name expression)
         :metadata (math-expression-metadata expression))))

(defun %normalize-expression-args (op args)
  (let ((args (copy-list args)))
    (if (member op '(:add :multiply :and :or :equality) :test #'eq)
        (sort args #'string<
              :key (lambda (arg)
                     (if (typep arg 'math-expression)
                         (math-expression-key arg)
                         (%string-key arg))))
        args)))

(defun make-math-expression-v1 (op &rest args-and-options)
  (unless (member op *math-expression-operators* :test #'eq)
    (error "Unsupported MathExpressionV1 operator ~S" op))
  (let ((args '()) (value nil) (name nil) (metadata nil))
    (loop while args-and-options
          for item = (pop args-and-options)
          do (if (member item '(:value :name :metadata) :test #'eq)
                 (let ((next (pop args-and-options)))
                   (ecase item
                     (:value (setf value next))
                     (:name (setf name next))
                     (:metadata (setf metadata next))))
                 (push item args)))
    (%make-math-expression
     :op op
     :args (%normalize-expression-args op (nreverse args))
     :value value
     :name name
     :metadata metadata)))

(defstruct math-definition id expression domain-ref provenance metadata)
(defstruct math-domain id name parent-refs constraints provenance metadata)
(defstruct math-claim id statement expression domain-ref hypotheses status dependencies provenance metadata)
(defstruct math-theorem id claim status proof-receipt-ref dependencies provenance metadata)
(defstruct math-hypothesis id statement expression domain-ref status provenance metadata)
(defstruct math-bound id subject relation bound domain-ref provenance metadata)
(defstruct math-asymptotic id lhs relation rhs limit domain-ref provenance metadata)
(defstruct math-transform id kind input output domain-ref provenance metadata)
(defstruct math-counterexample id target-claim-ref witness backend scope failed-assumptions provenance metadata)
(defstruct math-proof-problem id target-claim representation allowed-operator-classes policy provenance metadata)
(defstruct math-equivalence id left-ref right-ref forward-ref reverse-ref status provenance metadata)
(defstruct math-no-go id strategy assumptions failure-result-ref counterexample-ref target-refs provenance metadata)

(defun make-math-definition-v1 (&key id expression domain-ref provenance metadata)
  (unless (and (stringp id) (plusp (length id)))
    (error "MathDefinitionV1 needs a nonempty semantic id"))
  (make-math-definition :id id :expression expression :domain-ref domain-ref
                        :provenance provenance :metadata metadata))

(defun make-math-domain-v1 (&key id name parent-refs constraints provenance metadata)
  (unless (and (stringp id) (plusp (length id)))
    (error "MathDomainV1 needs a nonempty semantic id"))
  (make-math-domain :id id :name name :parent-refs (copy-list parent-refs)
                    :constraints (copy-list constraints) :provenance provenance
                    :metadata metadata))

(defun make-math-claim-v1 (&key id statement expression domain-ref hypotheses
                                (status :open) dependencies provenance metadata)
  (%ensure-status status)
  (unless (and (stringp id) (plusp (length id)))
    (error "MathClaimV1 needs a nonempty semantic id"))
  (unless (and (stringp statement) (plusp (length statement)))
    (error "MathClaimV1 needs a nonempty statement"))
  (make-math-claim :id id :statement statement :expression expression
                   :domain-ref domain-ref :hypotheses (copy-list hypotheses)
                   :status status :dependencies (copy-list dependencies)
                   :provenance provenance :metadata metadata))

(defun make-math-theorem-v1 (&key id claim (status :open) proof-receipt-ref dependencies provenance metadata)
  (%ensure-status status)
  (make-math-theorem :id id :claim claim :status status
                     :proof-receipt-ref proof-receipt-ref
                     :dependencies (copy-list dependencies)
                     :provenance provenance :metadata metadata))

(defun make-math-hypothesis-v1 (&key id statement expression domain-ref (status :candidate) provenance metadata)
  (%ensure-status status)
  (make-math-hypothesis :id id :statement statement :expression expression
                        :domain-ref domain-ref :status status
                        :provenance provenance :metadata metadata))

(defun make-math-bound-v1 (&key id subject relation bound domain-ref provenance metadata)
  (make-math-bound :id id :subject subject :relation relation :bound bound
                   :domain-ref domain-ref :provenance provenance :metadata metadata))

(defun make-math-asymptotic-v1 (&key id lhs relation rhs limit domain-ref provenance metadata)
  (make-math-asymptotic :id id :lhs lhs :relation relation :rhs rhs :limit limit
                        :domain-ref domain-ref :provenance provenance :metadata metadata))

(defun make-math-transform-v1 (&key id kind input output domain-ref provenance metadata)
  (make-math-transform :id id :kind kind :input input :output output
                       :domain-ref domain-ref :provenance provenance :metadata metadata))

(defun make-math-counterexample-v1 (&key id target-claim-ref witness backend scope failed-assumptions provenance metadata)
  (make-math-counterexample :id id :target-claim-ref target-claim-ref :witness witness
                            :backend backend :scope scope
                            :failed-assumptions (copy-list failed-assumptions)
                            :provenance provenance :metadata metadata))

(defun make-math-proof-problem-v1 (&key id target-claim representation allowed-operator-classes policy provenance metadata)
  (make-math-proof-problem :id id :target-claim target-claim :representation representation
                           :allowed-operator-classes (copy-list allowed-operator-classes)
                           :policy policy :provenance provenance :metadata metadata))

(defun make-math-equivalence-v1 (&key id left-ref right-ref forward-ref reverse-ref (status :open) provenance metadata)
  (%ensure-status status)
  (make-math-equivalence :id id :left-ref left-ref :right-ref right-ref
                         :forward-ref forward-ref :reverse-ref reverse-ref
                         :status status :provenance provenance :metadata metadata))

(defun make-math-no-go-v1 (&key id strategy assumptions failure-result-ref counterexample-ref target-refs provenance metadata)
  (make-math-no-go :id id :strategy strategy :assumptions (copy-list assumptions)
                   :failure-result-ref failure-result-ref
                   :counterexample-ref counterexample-ref
                   :target-refs (copy-list target-refs)
                   :provenance provenance :metadata metadata))

(defun math-object-id (object)
  (etypecase object
    (math-definition (math-definition-id object))
    (math-domain (math-domain-id object))
    (math-claim (math-claim-id object))
    (math-theorem (math-theorem-id object))
    (math-hypothesis (math-hypothesis-id object))
    (math-bound (math-bound-id object))
    (math-asymptotic (math-asymptotic-id object))
    (math-transform (math-transform-id object))
    (math-counterexample (math-counterexample-id object))
    (math-proof-problem (math-proof-problem-id object))
    (math-equivalence (math-equivalence-id object))
    (math-no-go (math-no-go-id object))))

(defun math-object-status (object)
  (etypecase object
    (math-claim (math-claim-status object))
    (math-theorem (math-theorem-status object))
    (math-hypothesis (math-hypothesis-status object))
    (math-equivalence (math-equivalence-status object))
    ((or math-definition math-domain math-bound math-asymptotic math-transform
         math-counterexample math-proof-problem math-no-go)
     :unknown)))
