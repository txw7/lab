(in-package :mini-kernel)

(defparameter *store-kinds* '(:gamma :delta :omega :rho :alpha))
(defparameter *trust-classes* '(:trusted :checked :advisory))
(defparameter *ingested-algorithm-lanes* '(:kernel :smt :ai :opt :ts))
(defparameter *ingested-algorithm-agreement-kinds*
  '(:equivalence :soundness :completeness :bridge :preservation :refinement
    :overapproximation))

(defstruct backend
  id
  layer
  trust-class
  candidate-kind
  spec-kind
  evidence-kind
  statuses
  reads
  writes
  proposes)

(defstruct backend-result
  backend-id
  status
  evidence
  artifacts)

(defstruct ingested-algorithm
  name
  lane
  input-schema
  output-schema
  semantic-contract
  reference-judgment
  defir-program
  config
  agreement-theorem-kind
  status
  metadata)

(defparameter *backend-registry* (make-hash-table :test #'eq))
(defparameter *ingested-algorithm-registry* (make-hash-table :test #'eq))

(defun subsetp-eq (xs ys)
  (every (lambda (x) (member x ys :test #'eq)) xs))

(defun validate-backend (backend)
  (unless (member (backend-trust-class backend) *trust-classes* :test #'eq)
    (kernel-error "unknown backend trust class: ~S" (backend-trust-class backend)))
  (unless (subsetp-eq (backend-reads backend) *store-kinds*)
    (kernel-error "backend ~S has invalid read stores: ~S"
                  (backend-id backend)
                  (backend-reads backend)))
  (unless (subsetp-eq (backend-writes backend) *store-kinds*)
    (kernel-error "backend ~S has invalid write stores: ~S"
                  (backend-id backend)
                  (backend-writes backend)))
  (unless (subsetp-eq (backend-proposes backend)
                      '(:none :core-term :declaration :proof-term :model :trace :summary :candidate))
    (kernel-error "backend ~S has invalid proposal kinds: ~S"
                  (backend-id backend)
                  (backend-proposes backend)))
  (when (and (member :delta (backend-writes backend) :test #'eq)
             (not (eq (backend-id backend) 'kernel-check)))
    (kernel-error "backend ~S may not write trusted environment Δ"
                  (backend-id backend)))
  (when (and (eq (backend-trust-class backend) :advisory)
             (member :delta (backend-reads backend) :test #'eq))
    (kernel-error "advisory backend ~S may not depend on trusted logical environment"
                  (backend-id backend)))
  (when (and (eq (backend-trust-class backend) :trusted)
             (not (eq (backend-id backend) 'kernel-check)))
    (kernel-error "only kernel-check may currently be trusted, got ~S"
                  (backend-id backend)))
  backend)

(defun validate-backend-result (result)
  (ensure-checker-status (backend-result-status result) 'backend-result)
  result)

(defun validate-ingested-algorithm (algorithm)
  (unless (typep algorithm 'ingested-algorithm)
    (kernel-error "expected ingested algorithm, got ~S" algorithm))
  (unless (or (symbolp (ingested-algorithm-name algorithm))
              (stringp (ingested-algorithm-name algorithm)))
    (kernel-error "ingested algorithm name must be symbol or string, got ~S"
                  (ingested-algorithm-name algorithm)))
  (unless (member (ingested-algorithm-lane algorithm)
                  *ingested-algorithm-lanes*
                  :test #'eq)
    (kernel-error "unknown ingested algorithm lane: ~S"
                  (ingested-algorithm-lane algorithm)))
  (unless (listp (ingested-algorithm-input-schema algorithm))
    (kernel-error "ingested algorithm input schema must be a list, got ~S"
                  (ingested-algorithm-input-schema algorithm)))
  (unless (listp (ingested-algorithm-output-schema algorithm))
    (kernel-error "ingested algorithm output schema must be a list, got ~S"
                  (ingested-algorithm-output-schema algorithm)))
  (unless (or (stringp (ingested-algorithm-semantic-contract algorithm))
              (listp (ingested-algorithm-semantic-contract algorithm)))
    (kernel-error "ingested algorithm semantic contract must be string or list, got ~S"
                  (ingested-algorithm-semantic-contract algorithm)))
  (unless (member (ingested-algorithm-agreement-theorem-kind algorithm)
                  *ingested-algorithm-agreement-kinds*
                  :test #'eq)
    (kernel-error "unknown ingested algorithm agreement theorem kind: ~S"
                  (ingested-algorithm-agreement-theorem-kind algorithm)))
  (ensure-checker-status (ingested-algorithm-status algorithm) 'ingested-algorithm)
  (let ((program (ingested-algorithm-defir-program algorithm)))
    (when program
      (validate-defir-program program)))
  algorithm)

(defun register-backend (backend)
  (validate-backend backend)
  (setf (gethash (backend-id backend) *backend-registry*) backend)
  backend)

(defun register-ingested-algorithm (algorithm)
  (validate-ingested-algorithm algorithm)
  (setf (gethash (ingested-algorithm-name algorithm) *ingested-algorithm-registry*)
        algorithm)
  algorithm)

(defun find-backend (backend-id)
  (gethash backend-id *backend-registry*))

(defun list-backends ()
  (let (backends)
    (maphash (lambda (_ backend)
               (declare (ignore _))
               (push backend backends))
             *backend-registry*)
    (sort backends #'string<
          :key (lambda (backend) (symbol-name (backend-id backend))))))

(defun find-ingested-algorithm (name)
  (gethash name *ingested-algorithm-registry*))

(defun %require-ingested-algorithm (algorithm-or-name)
  (let ((algorithm (if (typep algorithm-or-name 'ingested-algorithm)
                       algorithm-or-name
                       (find-ingested-algorithm algorithm-or-name))))
    (unless algorithm
      (kernel-error "unknown ingested algorithm: ~S" algorithm-or-name))
    algorithm))

(defun %unique-operation-list (operations)
  (let ((seen (make-hash-table :test #'eq))
        (result '()))
    (dolist (operation operations)
      (unless (gethash operation seen)
        (setf (gethash operation seen) t)
        (push operation result)))
    (nreverse result)))

(defun %normalize-ingested-operation-name (operation)
  (etypecase operation
    (symbol operation)
    (string (intern (string-upcase operation) (find-package :mini-kernel)))))

(defun ingested-algorithm-operations (algorithm-or-name)
  (let* ((algorithm (%require-ingested-algorithm algorithm-or-name))
         (metadata-operations
           (copy-list (getf (ingested-algorithm-metadata algorithm) :operations)))
         (program (ingested-algorithm-defir-program algorithm))
         (program-operations
           (when program
             (mapcar #'defir-function-name
                     (defir-program-functions program)))))
    (if metadata-operations
        (%unique-operation-list metadata-operations)
        (%unique-operation-list program-operations))))

(defun %capture-ingested-execution (thunk)
  (handler-case
      (list :ok (funcall thunk))
    (error (condition)
      (list :error (princ-to-string condition)))))

(defun %smt-cnf-equal (lhs rhs)
  (and (typep lhs 'smt-cnf)
       (typep rhs 'smt-cnf)
       (= (smt-cnf-var-count lhs) (smt-cnf-var-count rhs))
       (equal (smt-cnf-clauses lhs) (smt-cnf-clauses rhs))
       (equal (smt-cnf-root-literal lhs) (smt-cnf-root-literal rhs))))

(defun %captured-ingested-result-equal (lhs rhs)
  (and (equal (first lhs) (first rhs))
       (if (eq (first lhs) :ok)
           (let ((lhs-value (second lhs))
                 (rhs-value (second rhs)))
             (or (equal lhs-value rhs-value)
                 (equalp lhs-value rhs-value)
                 (%smt-cnf-equal lhs-value rhs-value)))
           (equal (second lhs) (second rhs)))))

(defun %native-lookup-option (ctx k)
  (let ((type (nth k ctx)))
    (and type
         (list :some (shift (1+ k) 0 type)))))

(defun %native-shift-index (delta k cutoff)
  (second (shift delta cutoff (list :var k))))

(defun %call-with-native-kernel (thunk)
  (call-with-kernel-implementation (native-kernel-implementation) thunk))

(defun %default-ingested-reference-function (algorithm operation)
  (case (ingested-algorithm-lane algorithm)
    (:kernel
     (case operation
       (shiftIndex (lambda (delta k cutoff)
                     (%call-with-native-kernel
                      (lambda ()
                        (%native-shift-index delta k cutoff)))))
       (shift (lambda (delta cutoff term)
                (%call-with-native-kernel
                 (lambda ()
                   (shift delta cutoff term)))))
       (subst (lambda (j replacement term)
                (%call-with-native-kernel
                 (lambda ()
                   (subst j replacement term)))))
       (instantiate (lambda (body arg)
                      (%call-with-native-kernel
                       (lambda ()
                         (subst-top arg body)))))
       (lookup (lambda (ctx k)
                 (%call-with-native-kernel
                  (lambda ()
                    (%native-lookup-option ctx k)))))
       (reduceNatRec (lambda (env levels args)
                       (%call-with-native-kernel
                        (lambda ()
                          (reduce-nat-rec env levels args)))))
       (reduceEqRec (lambda (env levels args)
                      (%call-with-native-kernel
                       (lambda ()
                         (reduce-eq-rec env levels args)))))
       (whnf (lambda (env term)
               (%call-with-native-kernel
                (lambda ()
                  (whnf env term)))))
       (conv (lambda (env ctx lhs rhs)
               (%call-with-native-kernel
                (lambda ()
                  (conv? env ctx lhs rhs)))))
       (checkSort (lambda (env ctx term)
                    (%call-with-native-kernel
                     (lambda ()
                       (check-sort env ctx term)))))
       (infer (lambda (env ctx term)
                (%call-with-native-kernel
                 (lambda ()
                   (infer env ctx term)))))
       (check (lambda (env ctx term expected)
                (%call-with-native-kernel
                 (lambda ()
                   (check env ctx term expected)))))
       (otherwise nil)))
    (:smt
     (case operation
       (normalize-smt-term #'normalize-smt-term)
       (lower-smt-to-boolean-core #'lower-smt-to-boolean-core)
       (compile-boolean-core-to-cnf #'compile-boolean-core-to-cnf)
       (compile-boolean-core-to-cnf-with-assumptions
        #'compile-boolean-core-to-cnf-with-assumptions)
       (bitblast-smt-term #'bitblast-smt-term)
       (compile-smt-to-cnf #'compile-smt-to-cnf)
       (compile-smt-to-cnf-with-assumptions #'compile-smt-to-cnf-with-assumptions)
       (solve-cnf-dpll #'solve-cnf-dpll)
       (solve-cnf-under-assumptions-dpll #'solve-cnf-under-assumptions-dpll)
       (otherwise nil)))
    (otherwise
     nil)))

(defun execute-ingested-algorithm (algorithm-or-name operation &rest args)
  (let* ((algorithm (%require-ingested-algorithm algorithm-or-name))
         (program (ingested-algorithm-defir-program algorithm))
         (normalized-operation (%normalize-ingested-operation-name operation))
         (available (ingested-algorithm-operations algorithm)))
    (unless program
      (kernel-error "ingested algorithm ~S has no executable DefIR program"
                    (ingested-algorithm-name algorithm)))
    (unless (member normalized-operation available :test #'eq)
      (kernel-error "operation ~S is not available on ingested algorithm ~S~%available: ~S"
                    operation
                    (ingested-algorithm-name algorithm)
                    available))
    (apply #'call-defir-function program normalized-operation args)))

(defun compare-ingested-algorithm-operation
    (algorithm-or-name operation args &key reference-function)
  (let* ((algorithm (%require-ingested-algorithm algorithm-or-name))
         (normalized-operation (%normalize-ingested-operation-name operation))
         (reference
           (or reference-function
               (%default-ingested-reference-function algorithm normalized-operation))))
    (unless reference
      (kernel-error "no reference function available for ~S/~S"
                    (ingested-algorithm-name algorithm)
                    normalized-operation))
    (let ((actual (%capture-ingested-execution
                   (lambda ()
                     (apply #'execute-ingested-algorithm
                            (ingested-algorithm-name algorithm)
                            normalized-operation
                            args))))
          (expected (%capture-ingested-execution
                     (lambda ()
                       (apply reference args)))))
      (list :algorithm (ingested-algorithm-name algorithm)
            :lane (ingested-algorithm-lane algorithm)
            :operation normalized-operation
            :matches (%captured-ingested-result-equal actual expected)
            :actual actual
            :expected expected))))

(defun list-ingested-algorithms ()
  (let (algorithms)
    (maphash (lambda (_ algorithm)
               (declare (ignore _))
               (push algorithm algorithms))
             *ingested-algorithm-registry*)
    (sort algorithms #'string<
          :key (lambda (algorithm)
                 (string (ingested-algorithm-name algorithm))))))

(defun clear-ingested-algorithm-registry ()
  (clrhash *ingested-algorithm-registry*)
  t)

(defun initialize-backend-registry ()
  (clrhash *backend-registry*)
  (register-backend
   (make-backend
    :id 'kernel-check
    :layer :core-term
    :trust-class :trusted
    :candidate-kind :core-term
    :spec-kind :typing-spec
    :evidence-kind :typing-derivation
    :statuses '(:accepted :rejected)
    :reads '(:gamma :delta)
    :writes '(:delta)
    :proposes '(:declaration)))
  (register-backend
   (make-backend
    :id 'frontend-lower
    :layer :surface
    :trust-class :checked
    :candidate-kind :surface-term
    :spec-kind :lowering-spec
    :evidence-kind :lowered-term
    :statuses '(:accepted :rejected)
    :reads '(:omega :delta)
    :writes '(:omega)
    :proposes '(:core-term)))
  (register-backend
   (make-backend
    :id 'smt-check
    :layer :solver
    :trust-class :advisory
    :candidate-kind :formula
    :spec-kind :solver-spec
    :evidence-kind :model-or-unsat-core
    :statuses '(:accepted :rejected :counterexample :unknown :timeout)
    :reads '(:alpha)
    :writes '(:alpha)
    :proposes '(:model)))
  (register-backend
   (make-backend
    :id 'model-check
    :layer :protocol
    :trust-class :advisory
    :candidate-kind :transition-system
    :spec-kind :temporal-spec
    :evidence-kind :trace-or-invariant
    :statuses '(:accepted :counterexample :unknown)
    :reads '(:rho)
    :writes '(:alpha)
    :proposes '(:trace)))
  (register-backend
   (make-backend
    :id 'audit-check
    :layer :audit
    :trust-class :checked
    :candidate-kind :stage
    :spec-kind :agreement-spec
    :evidence-kind :agreement-report
    :statuses '(:accepted :rejected)
    :reads '(:delta :alpha :rho)
    :writes '(:rho)
    :proposes '(:candidate)))
  t)

(initialize-backend-registry)
