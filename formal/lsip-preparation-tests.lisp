(defpackage :mini-kernel-lsip-preparation-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-lsip-preparation-tests)

(define-condition test-failure (error)
  ((message :initarg :message :reader test-failure-message))
  (:report (lambda (condition stream)
             (princ (test-failure-message condition) stream))))

(defun fail-test (format-string &rest args)
  (error 'test-failure :message (apply #'format nil format-string args)))

(defmacro is-true (form)
  `(unless ,form
     (fail-test "expected truthy form: ~S" ',form)))

(defmacro is-equal (expected form)
  `(let ((expected-value ,expected)
         (actual-value ,form))
     (unless (equal expected-value actual-value)
       (fail-test "expected ~S, got ~S from ~S"
                  expected-value
                  actual-value
                  ',form))))

(defun run-test (name thunk)
  (handler-case
      (progn
        (funcall thunk)
        (format t "ok   ~A~%" name)
        t)
    (error (condition)
      (format t "FAIL ~A~%  ~A~%" name condition)
      nil)))

(defun test-lsip-strata-registry ()
  (let* ((strata (mini-kernel:list-lsip-strata))
         (x1 (mini-kernel:find-lsip-stratum :x1))
         (x2 (mini-kernel:find-lsip-stratum :x2))
         (a0 (mini-kernel:find-lsip-stratum :a0)))
    (is-equal 22 (length strata))
    (is-equal :x (mini-kernel:lsip-stratum-band x1))
    (is-equal "compiler-ir-node"
              (mini-kernel:lsip-stratum-current-carrier x1))
    (is-equal "runtime-program"
              (mini-kernel:lsip-stratum-current-carrier x2))
    (is-equal :a (mini-kernel:lsip-stratum-band a0))
    (is-equal :yes (mini-kernel:lsip-stratum-shared-lane-status x2))))

(defun test-lsip-lowering-edge-registry ()
  (let* ((edges (mini-kernel:list-lsip-lowering-edges))
         (x1-to-x2 (mini-kernel:find-lsip-lowering-edge :x1-to-x2)))
    (is-equal 5 (length edges))
    (is-equal '(:x1) (mini-kernel:lsip-lowering-edge-source-strata x1-to-x2))
    (is-equal '(:x2) (mini-kernel:lsip-lowering-edge-target-strata x1-to-x2))
    (is-true
     (member :rehydration-stability
             (mini-kernel:lsip-lowering-edge-invariant-families x1-to-x2)))
    (is-true
     (every (lambda (edge)
              (and (every #'mini-kernel:find-lsip-stratum
                          (mini-kernel:lsip-lowering-edge-source-strata edge))
                   (every #'mini-kernel:find-lsip-stratum
                          (mini-kernel:lsip-lowering-edge-target-strata edge))))
            edges))))

(defun test-lsip-edge-contract-registry ()
  (let* ((contracts (mini-kernel:list-lsip-edge-contracts))
         (contract (mini-kernel:find-lsip-edge-contract-for-edge :x2-r0-to-a0)))
    (is-equal 5 (length contracts))
    (is-equal :runtime-authority-sync-contract
              (mini-kernel:lsip-edge-contract-contract-family contract))
    (is-true
     (member :smt-admitted-bridge
             (mini-kernel:lsip-edge-contract-candidate-constraint-classes contract)))
    (is-true
     (member :admission-ordering-contract
             (mini-kernel:lsip-edge-contract-blocking-gaps contract)))
    (is-true
     (every (lambda (entry)
              (mini-kernel:find-lsip-lowering-edge
               (mini-kernel:lsip-edge-contract-edge-id entry)))
            contracts))))

(defun test-lsip-edge-capability-surface ()
  (let ((surface-none
          (mini-kernel:build-lsip-edge-capability-surface :s1-to-t0))
        (surface-partial
          (mini-kernel:build-lsip-edge-capability-surface :x1-to-x2))
        (surface-complete
          (mini-kernel:build-lsip-edge-capability-surface :x2-r0-to-a0)))
    (is-equal :partial
              (mini-kernel:lsip-edge-capability-surface-coverage-status
               surface-none))
    (is-equal :partial
              (mini-kernel:lsip-edge-capability-surface-coverage-status
               surface-partial))
    (is-true
     (member :structural-lsip-law
             (mini-kernel:lsip-edge-capability-surface-available-constraint-classes
              surface-partial)))
    (is-true
     (member :machine-local-identity
             (mini-kernel:lsip-edge-capability-surface-missing-obligation-classes
              surface-partial)))
    (is-equal :complete
              (mini-kernel:lsip-edge-capability-surface-coverage-status
               surface-complete))
    (is-true
     (member :x2-r0-to-a0-admission-ordering
             (mini-kernel:lsip-edge-capability-surface-supported-law-ids
              surface-complete)))))

(defun test-lsip-law-and-relation-carriers ()
  (let* ((source
           (mini-kernel:compile-lsip-stratum-object
            :x1
            '(:compiler-ir :program-id "prog-1")))
         (target
           (mini-kernel:compile-lsip-stratum-object
            :x2
            '(:runtime-program :program-id "prog-1")))
         (relation
           (mini-kernel:compile-lsip-relation
            :x1-to-x2
            :source-objects (list source)
            :target-objects (list target)
            :facts (list :source-program-id "prog-1"
                         :target-program-id "prog-1"
                         :stable-runtime-id-p t
                         :callable-surface-preserved-p t
                         :machine-local-identity-p t)))
         (result
           (mini-kernel:check-lsip-law
            :x1-to-x2-rehydration-stability
            relation)))
    (is-true (typep source 'mini-kernel:lsip-stratum-object))
    (is-true (typep relation 'mini-kernel:lsip-relation))
    (is-equal :accepted
              (mini-kernel:lsip-law-result-status result))
    (is-equal :lsip-law-result
              (mini-kernel:lsip-law-result-evidence-kind result))))

(defun test-lsip-edge-gate ()
  (let* ((runtime-program
           (mini-kernel:compile-lsip-stratum-object
            :x2
            '(:runtime-program :linkset-id "link-1")))
         (runtime-state
           (mini-kernel:compile-lsip-stratum-object
            :r0
            '(:runtime-state :machine-id "machine-a")))
         (authority-artifact
           (mini-kernel:compile-lsip-stratum-object
            :a0
            '(:authority-bundle :linkset-id "link-1")))
         (relation
           (mini-kernel:compile-lsip-relation
            :x2-r0-to-a0
            :source-objects (list runtime-program runtime-state)
            :target-objects (list authority-artifact)
            :facts (list :resident-machine-id "machine-a"
                         :foreign-machine-id "machine-b"
                         :separated-p t
                         :pre-runtime-digest "runtime-1"
                         :post-runtime-digest "runtime-1"
                         :inert-p t
                         :runtime-linkset-id "link-1"
                         :authority-linkset-id "link-1"
                         :admission-before-sync-p t
                         :registration-before-dispatch-p t
                         :no-partial-callable-visibility-p t)))
         (gate
           (mini-kernel:build-lsip-edge-gate :x2-r0-to-a0))
         (result
           (mini-kernel:check-lsip-edge-gate :x2-r0-to-a0 relation)))
    (is-equal :complete
              (mini-kernel:lsip-edge-gate-coverage-status gate))
    (is-equal :accepted
              (mini-kernel:lsip-edge-gate-result-status result))
    (is-equal 4
              (length (mini-kernel:lsip-edge-gate-result-law-results result)))
    (is-equal '()
              (mini-kernel:lsip-edge-gate-result-missing-obligation-classes result))))

(defun test-lsip-formal-preparation-report ()
  (let ((report (mini-kernel:evaluate-lsip-formal-preparation-report)))
    (is-equal 22 (mini-kernel:lsip-formal-preparation-report-stratum-count report))
    (is-equal 5 (mini-kernel:lsip-formal-preparation-report-edge-count report))
    (is-equal 5 (mini-kernel:lsip-formal-preparation-report-contract-count report))
    (is-equal 5
              (mini-kernel:lsip-formal-preparation-report-capability-surface-count
               report))
    (is-true
     (member :structural-lsip-law-coverage
             (mini-kernel:lsip-formal-preparation-report-blocking-gaps report)))
    (is-true
     (member :x1-to-x2
             (getf (mini-kernel:lsip-formal-preparation-report-summary report)
                   :edges-with-current-coverage)))
    (is-true
     (member :x2-r0-to-a0
             (getf (mini-kernel:lsip-formal-preparation-report-summary report)
                   :edges-with-complete-gates)))
    (is-true
     (member :s1-to-t0
             (getf (mini-kernel:lsip-formal-preparation-report-summary report)
                   :edges-needing-new-capability)))))

(defun test-lsip-edge-search-alignment ()
  (let ((x2-policy
          (mini-kernel:build-lsip-edge-search-alignment
           :x2-r0-to-a0
           :lsip-edge-policy))
        (x2-smt
          (mini-kernel:build-lsip-edge-search-alignment
           :x2-r0-to-a0
           :smt-constraint))
        (s1-policy
          (mini-kernel:build-lsip-edge-search-alignment
           :s1-to-t0
           :lsip-edge-policy)))
    (is-equal :complete
              (mini-kernel:lsip-edge-search-alignment-coverage-status
               x2-policy))
    (is-true
     (member :structural-lsip-law
             (mini-kernel:lsip-edge-search-alignment-matched-constraint-classes
              x2-policy)))
    (is-equal :partial
              (mini-kernel:lsip-edge-search-alignment-coverage-status
               x2-smt))
    (is-true
     (member :smt-admitted-bridge
             (mini-kernel:lsip-edge-search-alignment-matched-constraint-classes
              x2-smt)))
    (is-equal :partial
              (mini-kernel:lsip-edge-search-alignment-coverage-status
               s1-policy))
    (is-true
     (member :typed-tree-recognition-totality
             (mini-kernel:lsip-edge-search-alignment-missing-obligation-classes
              s1-policy)))))

(defun test-lsip-search-preparation-manifest ()
  (let ((manifest (mini-kernel:evaluate-lsip-search-preparation-manifest)))
    (is-equal 5
              (mini-kernel:lsip-search-preparation-manifest-edge-count manifest))
    (is-equal 15
              (mini-kernel:lsip-search-preparation-manifest-alignment-count manifest))
    (is-equal 1
              (mini-kernel:lsip-search-preparation-manifest-ready-edge-count manifest))
    (is-equal 4
              (mini-kernel:lsip-search-preparation-manifest-partial-edge-count manifest))
    (is-true
     (member :lsip-edge-policy
             (getf (mini-kernel:lsip-search-preparation-manifest-summary manifest)
                   :families-with-edge-coverage)))
    (is-true
     (member :x2-r0-to-a0
             (getf (mini-kernel:lsip-search-preparation-manifest-summary manifest)
                   :ready-edges)))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "lsip-strata-registry" #'test-lsip-strata-registry)
            (cons "lsip-lowering-edge-registry" #'test-lsip-lowering-edge-registry)
            (cons "lsip-edge-contract-registry" #'test-lsip-edge-contract-registry)
            (cons "lsip-edge-capability-surface" #'test-lsip-edge-capability-surface)
            (cons "lsip-law-and-relation-carriers" #'test-lsip-law-and-relation-carriers)
            (cons "lsip-edge-gate" #'test-lsip-edge-gate)
            (cons "lsip-formal-preparation-report" #'test-lsip-formal-preparation-report)
            (cons "lsip-edge-search-alignment" #'test-lsip-edge-search-alignment)
            (cons "lsip-search-preparation-manifest" #'test-lsip-search-preparation-manifest)))
         (passed 0)
         (failed 0))
    (dolist (test tests)
      (if (run-test (car test) (cdr test))
          (incf passed)
          (incf failed)))
    (format t "~%passed: ~D failed: ~D~%" passed failed)
    (when (plusp failed)
      (fail-test "lsip preparation test suite failed"))
    t))
