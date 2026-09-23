(in-package :lab.math)

(defparameter *lab-formal-native-operation-allowlist*
  '(:check-kernel-spec-kr
    :check-kernel-spec-kl
    :check-kernel-spec-defir
    :compare-kernel-spec-kr-kl-defir
    :check-smt-spec
    :j-smt-admitted-obligation-bridge
    :run-smt-cegis
    :run-lsip-edge-policy-cegis
    :run-compiler-mutation-cegis
    :evaluate-search-admission-law
    :evaluate-search-evidence-monotonicity
    :evaluate-search-supersession-consistency
    :evaluate-search-legal-transition))

(defstruct (math-formal-native-claim
            (:include math-claim)
            (:constructor %make-math-formal-native-claim
                (&key id statement expression domain-ref hypotheses status dependencies
                      provenance metadata formal-operation-id formal-args
                      target-proposition trusted-boundary)))
  formal-operation-id
  formal-args
  target-proposition
  trusted-boundary)

(defun make-math-formal-native-claim-v1
    (&key id statement expression domain-ref hypotheses (status :open) dependencies
          provenance metadata formal-operation-id formal-args target-proposition
          (trusted-boundary :formal-capability))
  (%ensure-status status)
  (unless (and (stringp id) (plusp (length id)))
    (error "MathFormalNativeClaimV1 needs a nonempty semantic id"))
  (unless (and (stringp statement) (plusp (length statement)))
    (error "MathFormalNativeClaimV1 needs a nonempty statement"))
  (unless (member formal-operation-id *lab-formal-native-operation-allowlist* :test #'eq)
    (error "FORMAL operation ~S is not admitted for MathFormalNativeClaimV1"
           formal-operation-id))
  (unless (listp formal-args)
    (error "MathFormalNativeClaimV1 formal-args must be an argument plist/list"))
  (%make-math-formal-native-claim
   :id id
   :statement statement
   :expression expression
   :domain-ref domain-ref
   :hypotheses (copy-list hypotheses)
   :status status
   :dependencies (copy-list dependencies)
   :provenance provenance
   :metadata metadata
   :formal-operation-id formal-operation-id
   :formal-args (copy-tree formal-args)
   :target-proposition target-proposition
   :trusted-boundary trusted-boundary))

(defun %formal-native-translate (claim)
  (list :operation-id (math-formal-native-claim-formal-operation-id claim)
        :args (copy-tree (math-formal-native-claim-formal-args claim))))

(defun %formal-native-target-proposition (claim payload)
  (declare (ignore payload))
  (or (math-formal-native-claim-target-proposition claim)
      (math-claim-statement claim)))

(defun register-default-math-formal-projection-laws ()
  (register-math-formal-projection-law
   (make-math-formal-projection-law
    :id :lab-formal-native
    :source-claim-class 'math-formal-native-claim
    :supported-domain nil
    :target-backend :lab-formal-capability
    :translator #'%formal-native-translate
    :target-proposition-builder #'%formal-native-target-proposition
    :trusted-boundary :formal-capability
    :reconstruction-description
    "A Lab-authored MathFormalNativeClaimV1 pins one admitted FORMAL operation and its exact argument row"
    :unsupported-behavior :remain-open
    :version 1))
  t)

(register-default-math-formal-projection-laws)
