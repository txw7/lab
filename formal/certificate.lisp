(in-package :mini-kernel)

(defparameter *certificate-schema-version* 1)
(defparameter *supported-certificate-judgments* '(:typing))
(defparameter *current-config-digest* '(:config-id :pi0
                                        :universe-policy :monomorphic
                                        :conversion :whnf-structural
                                        :inductives (:nat :eq)
                                        :levels :identity))

(defstruct certificate
  schema-version
  judgment-kind
  context
  term
  type
  env-digest
  config-digest
  checker-ids
  metadata)

(defun core-term-p (term)
  (member (term-tag term)
          '(:sort :var :const :app :lam :pi :let)
          :test #'eq))

(defun make-typing-certificate (context term type env-digest &key checker-ids metadata)
  (make-certificate
   :schema-version *certificate-schema-version*
   :judgment-kind :typing
   :context context
   :term term
   :type type
   :env-digest env-digest
   :config-digest *current-config-digest*
   :checker-ids checker-ids
   :metadata metadata))

(defun validate-certificate (certificate)
  (unless (= (certificate-schema-version certificate) *certificate-schema-version*)
    (kernel-error "unsupported certificate schema version: ~S"
                  (certificate-schema-version certificate)))
  (unless (member (certificate-judgment-kind certificate)
                  *supported-certificate-judgments*
                  :test #'eq)
    (kernel-error "unsupported certificate judgment kind: ~S"
                  (certificate-judgment-kind certificate)))
  (unless (listp (certificate-context certificate))
    (kernel-error "certificate context must be a list, got ~S"
                  (certificate-context certificate)))
  (unless (every #'core-term-p (certificate-context certificate))
    (kernel-error "certificate context contains non-core terms: ~S"
                  (certificate-context certificate)))
  (unless (core-term-p (certificate-term certificate))
    (kernel-error "certificate term is not a core term: ~S"
                  (certificate-term certificate)))
  (unless (core-term-p (certificate-type certificate))
    (kernel-error "certificate type is not a core term: ~S"
                  (certificate-type certificate)))
  (unless (certificate-env-digest certificate)
    (kernel-error "certificate env digest is missing"))
  (unless (equal (certificate-config-digest certificate) *current-config-digest*)
    (kernel-error "certificate config digest mismatch~%expected: ~S~%actual:   ~S"
                  *current-config-digest*
                  (certificate-config-digest certificate)))
  (unless (listp (certificate-checker-ids certificate))
    (kernel-error "certificate checker ids must be a list, got ~S"
                  (certificate-checker-ids certificate)))
  certificate)

(defun check-certificate (env certificate &key (expected-env-digest nil)
                                            checker-implementation)
  (validate-certificate certificate)
  (when (and expected-env-digest
             (not (equal (certificate-env-digest certificate) expected-env-digest)))
    (kernel-error "certificate environment digest mismatch~%expected: ~S~%actual:   ~S"
                  expected-env-digest
                  (certificate-env-digest certificate)))
  (if checker-implementation
      (with-kernel-implementation (checker-implementation)
        (check env
               (certificate-context certificate)
               (certificate-term certificate)
               (certificate-type certificate)))
      (check env
             (certificate-context certificate)
             (certificate-term certificate)
             (certificate-type certificate))))
