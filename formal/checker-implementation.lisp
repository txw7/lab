(in-package :mini-kernel)

(defstruct (kernel-implementation
            (:constructor %make-kernel-implementation
                (&key id shift subst subst-top ctx-lookup whnf conv infer check
                      metadata)))
  id
  shift
  subst
  subst-top
  ctx-lookup
  whnf
  conv
  infer
  check
  metadata)

(defparameter *native-kernel-implementation* nil)
(defparameter *kernel-implementation* nil)

(defun %kernel-implementation-callable-p (value)
  (or (functionp value)
      (and (symbolp value)
           (fboundp value))))

(defun %kernel-implementation-call (callable &rest args)
  (apply (if (symbolp callable)
             (symbol-function callable)
             callable)
         args))

(defun validate-kernel-implementation (implementation)
  (unless (typep implementation 'kernel-implementation)
    (kernel-error "expected kernel implementation, got ~S" implementation))
  (dolist (entry (list (cons 'shift (kernel-implementation-shift implementation))
                       (cons 'subst (kernel-implementation-subst implementation))
                       (cons 'subst-top (kernel-implementation-subst-top implementation))
                       (cons 'ctx-lookup (kernel-implementation-ctx-lookup implementation))))
    (unless (%kernel-implementation-callable-p (cdr entry))
      (kernel-error "kernel implementation slot ~S must be a function designator, got ~S"
                    (car entry)
                    (cdr entry))))
  (dolist (entry (list (cons 'whnf (kernel-implementation-whnf implementation))
                       (cons 'conv (kernel-implementation-conv implementation))
                       (cons 'infer (kernel-implementation-infer implementation))
                       (cons 'check (kernel-implementation-check implementation))))
    (when (cdr entry)
      (unless (%kernel-implementation-callable-p (cdr entry))
        (kernel-error "kernel implementation slot ~S must be NIL or a function designator, got ~S"
                      (car entry)
                      (cdr entry)))))
  implementation)

(defun %make-validated-kernel-implementation
    (&key id shift subst subst-top ctx-lookup whnf conv infer check metadata)
  (validate-kernel-implementation
   (%make-kernel-implementation
    :id id
    :shift shift
    :subst subst
    :subst-top subst-top
    :ctx-lookup ctx-lookup
    :whnf whnf
    :conv conv
    :infer infer
    :check check
    :metadata metadata)))

(defun install-native-kernel-implementation (implementation)
  (let ((old-native *native-kernel-implementation*))
    (setf *native-kernel-implementation*
          (validate-kernel-implementation implementation))
    (when (or (null *kernel-implementation*)
              (eq *kernel-implementation* old-native))
      (setf *kernel-implementation* *native-kernel-implementation*)))
  *native-kernel-implementation*)

(defun native-kernel-implementation ()
  (or *native-kernel-implementation*
      (kernel-error "native kernel implementation is not installed")))

(defun current-kernel-implementation ()
  (or *kernel-implementation*
      (native-kernel-implementation)))

(defun call-with-kernel-implementation (implementation thunk)
  (let ((*kernel-implementation*
          (validate-kernel-implementation implementation)))
    (funcall thunk)))

(defmacro with-kernel-implementation ((implementation) &body body)
  `(call-with-kernel-implementation ,implementation (lambda () ,@body)))

(defun %kernel-implementation-slot-call (accessor fallback &rest args)
  (apply #'%kernel-implementation-call
         (or (funcall accessor (current-kernel-implementation))
             fallback)
         args))

(defun %require-ingested-lean-def-function (program name)
  (unless (find-ingested-lean-def-function program name)
    (kernel-error "required ingested Lean def function ~S missing from ~S"
                  name
                  (lean-def-program-source-path program)))
  t)

(defun make-ingested-lean-def-kernel-implementation
    (&optional (program (ingest-declarativecore-def-program)))
  (validate-lean-def-program program)
  (%make-validated-kernel-implementation
   :id (list :ingested-lean-def
             (lean-def-program-source-digest program))
   :shift (lambda (delta cutoff term)
            (call-ingested-lean-def program "shift" delta cutoff term))
   :subst (lambda (j replacement term)
            (call-ingested-lean-def program "subst" j replacement term))
   :subst-top (lambda (replacement body)
                (call-ingested-lean-def program "instantiate" body replacement))
   :ctx-lookup (lambda (ctx k)
                 (let ((result (call-ingested-lean-def program "lookup" ctx k)))
                   (if result
                       (second result)
                       (kernel-error "unbound de Bruijn index: ~A" k))))
   :metadata (list :source-path (lean-def-program-source-path program)
                   :source-digest (lean-def-program-source-digest program)
                   :function-count (length (lean-def-program-functions program)))))

(defun make-defir-kernel-implementation
    (&key
       (primitive-program (ingest-declarativecore-def-program))
       (whnf-program (ingest-mini-kernel-whnf-program)))
  (validate-lean-def-program primitive-program)
  (validate-lean-def-program whnf-program)
  (dolist (name '("shiftIndex" "shift" "subst" "instantiate" "lookup"))
    (%require-ingested-lean-def-function primitive-program name))
  (dolist (name '("reduceNatRec" "reduceEqRec" "whnf" "conv" "checkSort" "infer" "check"))
    (%require-ingested-lean-def-function whnf-program name))
  (let ((base (make-ingested-lean-def-kernel-implementation primitive-program))
        (program (merge-defir-programs
                  (lower-ingested-lean-def-program-to-defir
                   primitive-program
                   :metadata (list :segment :primitive))
                  (lower-ingested-lean-def-program-to-defir
                   whnf-program
                   :metadata (list :segment :whnf
                                   :primitive-source-path
                                   (lean-def-program-source-path primitive-program)
                                   :primitive-source-digest
                                   (lean-def-program-source-digest primitive-program)
                                   :whnf-source-path
                                   (lean-def-program-source-path whnf-program)
                                   :whnf-source-digest
                                   (lean-def-program-source-digest whnf-program))))))
    (%make-validated-kernel-implementation
     :id (list :defir
               (lean-def-program-source-digest primitive-program)
               (lean-def-program-source-digest whnf-program))
     :shift (kernel-implementation-shift base)
     :subst (kernel-implementation-subst base)
     :subst-top (kernel-implementation-subst-top base)
     :ctx-lookup (kernel-implementation-ctx-lookup base)
     :whnf (lambda (env term)
             (call-defir-function program 'whnf env term))
     :conv (lambda (env ctx lhs rhs)
             (call-defir-function program 'conv env ctx lhs rhs))
     :infer (lambda (env ctx term)
              (call-defir-function program 'infer env ctx term))
     :check (lambda (env ctx term expected)
              (or (call-defir-function program 'check env ctx term expected)
                  (kernel-error "type mismatch~%expected: ~S~%actual:   ~S"
                                expected
                                (call-defir-function program 'infer env ctx term))))
     :metadata (append (defir-program-metadata program)
                       (list :execution-lane :defir)))))

(defun make-ingested-lean-whnf-kernel-implementation
    (&key
       (primitive-program (ingest-declarativecore-def-program))
       (whnf-program (ingest-mini-kernel-whnf-program)))
  (make-defir-kernel-implementation
   :primitive-program primitive-program
   :whnf-program whnf-program))

(defun make-kernel-family-ingested-algorithm
    (&key
       (primitive-program (ingest-declarativecore-def-program))
       (whnf-program (ingest-mini-kernel-whnf-program))
       (config (list :fragment :mini-kernel-frozen-core
                     :config-digest *current-config-digest*))
       (status :accepted))
  (validate-lean-def-program primitive-program)
  (validate-lean-def-program whnf-program)
  (validate-ingested-algorithm
   (make-ingested-algorithm
    :name :kernel-frozen-core
    :lane :kernel
    :input-schema '(:environment :context :term :expected-type :certificate)
    :output-schema '(:core-term :boolean :checker-status :certificate-status)
    :semantic-contract
    '(:closure-chain (:j-defir :j-kl :j-kr :j-d)
      :note "DefIR-backed kernel helper execution agrees with KL and KR on the frozen fragment; KR-to-D remains the declarative proof target.")
    :reference-judgment '(:j-d :j-kr :j-kl :j-defir)
    :defir-program
    (merge-defir-programs
     (lower-ingested-lean-def-program-to-defir
      primitive-program
      :metadata (list :segment :primitive))
     (lower-ingested-lean-def-program-to-defir
      whnf-program
      :metadata (list :segment :whnf)))
    :config config
    :agreement-theorem-kind :equivalence
    :status status
    :metadata (list :primitive-source-path (lean-def-program-source-path primitive-program)
                    :primitive-source-digest (lean-def-program-source-digest primitive-program)
                    :whnf-source-path (lean-def-program-source-path whnf-program)
                    :whnf-source-digest (lean-def-program-source-digest whnf-program)
                    :operations '(shiftIndex shift subst instantiate lookup
                                  reduceNatRec reduceEqRec whnf conv checkSort
                                  infer check)
                    :implementation-id
                    (kernel-implementation-id
                     (make-defir-kernel-implementation
                      :primitive-program primitive-program
                      :whnf-program whnf-program))))))

(defun %call-reference-implementation (thunk)
  (handler-case
      (funcall thunk)
    (mini-kernel-reference::reference-error (condition)
      (kernel-error "~A" condition))))

(defun make-reference-kernel-implementation ()
  (%make-validated-kernel-implementation
   :id :reference
   :shift (lambda (delta cutoff term)
            (%call-reference-implementation
             (lambda ()
               (mini-kernel-reference::r-shift delta cutoff term))))
   :subst (lambda (j replacement term)
            (%call-reference-implementation
             (lambda ()
               (mini-kernel-reference::r-subst j replacement term))))
   :subst-top (lambda (replacement body)
                (%call-reference-implementation
                 (lambda ()
                   (mini-kernel-reference::r-subst-top replacement body))))
   :ctx-lookup (lambda (ctx k)
                 (%call-reference-implementation
                  (lambda ()
                    (mini-kernel-reference::r-ctx-lookup ctx k))))
   :whnf (lambda (env term)
           (%call-reference-implementation
            (lambda ()
              (mini-kernel-reference::r-whnf
               (mini-kernel-reference:make-reference-env env)
               term))))
   :conv (lambda (env ctx lhs rhs)
           (%call-reference-implementation
            (lambda ()
              (mini-kernel-reference::r-conv
               (mini-kernel-reference:make-reference-env env)
               ctx lhs rhs))))
   :infer (lambda (env ctx term)
            (%call-reference-implementation
             (lambda ()
               (mini-kernel-reference::r-infer
                (mini-kernel-reference:make-reference-env env)
                ctx term))))
   :check (lambda (env ctx term expected)
            (%call-reference-implementation
             (lambda ()
               (mini-kernel-reference::r-check
                (mini-kernel-reference:make-reference-env env)
                ctx term expected))))
   :metadata '(:origin reference)))
