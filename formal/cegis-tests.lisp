(defpackage :mini-kernel-cegis-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-cegis-tests)

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

(defun make-boolean-blocking-problem ()
  (mini-kernel:make-smt-cegis-problem
   :id :boolean-blocking
   :logic :qf_bool
   :vars '((p (:Bool)) (q (:Bool)))
   :goal '(:or (:var p (:Bool))
               (:var q (:Bool)))
   :expected-status :rejected
   :max-iterations 5
   :metadata '(:test boolean-blocking)))

(defun make-lsip-edge-policy-relation ()
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
            '(:authority-bundle :linkset-id "link-1"))))
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
                  :no-partial-callable-visibility-p t))))

(defun make-lsip-edge-policy-problem ()
  (mini-kernel:make-lsip-edge-policy-cegis-problem
   :id :lsip-edge-policy
   :edge-id :x2-r0-to-a0
   :relation (make-lsip-edge-policy-relation)
   :required-obligation-classes '(:authority-linkset-preservation
                                  :machine-residency-separation
                                  :runtime-inertness
                                  :admission-ordering)
   :initial-law-ids '()
   :expected-status :accepted
   :max-iterations 8
   :metadata '(:test lsip-edge-policy)))

(defun make-compiler-mutation-problem ()
  (mini-kernel:make-compiler-mutation-cegis-problem
   :id :compiler-mutation
   :initial-payload '(:guard (:bool t))
   :counterexamples
   (list
    '(:kind :guard-counterexample
      :obligation :input-domain
      :guard (:and (:bool t) (:var safe (:Bool))))
    '(:kind :branch-counterexample
      :selector :opcode
      :constraint (:member :add (:add :sub)))
    '(:kind :mutation-counterexample
      :mutation-kind :rewrite-commute))
   :expected-status :accepted
   :max-iterations 8
   :metadata '(:test compiler-mutation)))

(defun test-run-smt-check-emits-model-artifact ()
  (let* ((store (mini-kernel:make-advisory-store))
         (result (mini-kernel:run-smt-check
                  store
                  '(:or (:var p (:Bool))
                        (:var q (:Bool)))))
         (models (mini-kernel:advisory-store-find-by-kind store :model))
         (payload (mini-kernel:advisory-artifact-payload (first models))))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal 1 (length models))
    (is-true (assoc '(:var p (:Bool)) payload :test #'equal))
    (is-true (assoc '(:var q (:Bool)) payload :test #'equal))))

(defun test-run-smt-cegis ()
  (let* ((problem (make-boolean-blocking-problem))
         (state (mini-kernel:run-smt-cegis problem))
         (history (mini-kernel:cegis-run-state-history state))
         (accepted (mini-kernel:cegis-run-state-accepted-candidate state))
         (summary (mini-kernel:summarize-cegis-run-state state))
         (first-step (first history))
         (last-step (car (last history))))
    (is-equal :accepted (mini-kernel:cegis-run-state-status state))
    (is-equal 4 (length history))
    (is-equal 3 (length (mini-kernel:cegis-candidate-payload accepted)))
    (is-equal 7 (getf (getf summary :score) :score))
    (is-equal 3 (getf summary :accepted-candidate-payload-size))
    (is-equal :counterexample
              (mini-kernel:cegis-step-result-status first-step))
    (is-equal :accepted
              (mini-kernel:cegis-step-result-status last-step))
    (is-true (mini-kernel:cegis-step-result-counterexample first-step))
    (is-true (mini-kernel:cegis-step-result-refinement first-step))))

(defun test-invoke-formal-capability-cegis ()
  (let* ((problem (make-boolean-blocking-problem))
         (result (mini-kernel:invoke-formal-capability
                  :run-smt-cegis
                  :caller-class :synth
                  :problem problem))
         (state (mini-kernel:formal-capability-result-payload result)))
    (is-equal :accepted (mini-kernel:formal-capability-result-status result))
    (is-equal :cegis-state
              (mini-kernel:formal-capability-result-evidence-kind result))
    (is-true (typep state 'mini-kernel:cegis-run-state))
    (is-equal :accepted (mini-kernel:cegis-run-state-status state))))

(defun test-run-lsip-edge-policy-cegis ()
  (let* ((problem (make-lsip-edge-policy-problem))
         (state (mini-kernel:run-lsip-edge-policy-cegis problem))
         (history (mini-kernel:cegis-run-state-history state))
         (accepted (mini-kernel:cegis-run-state-accepted-candidate state))
         (accepted-score (getf (mini-kernel:cegis-candidate-metadata accepted)
                               :score))
         (first-step (first history))
         (last-step (car (last history))))
    (is-equal :accepted (mini-kernel:cegis-run-state-status state))
    (is-equal 5 (length history))
    (is-true accepted)
    (is-equal 4 (length (mini-kernel:cegis-candidate-payload accepted)))
    (is-equal 4 (getf accepted-score :selected-law-count))
    (is-equal 0 (getf accepted-score :missing-obligation-count))
    (is-equal :reject-on-failure
              (getf (mini-kernel:cegis-candidate-metadata accepted)
                    :fallback-policy))
    (is-equal 0 (getf accepted-score :hard-failures))
    (is-equal 4 (getf accepted-score :score))
    (is-equal :missing-obligation-class
              (mini-kernel:cegis-counterexample-kind
               (mini-kernel:cegis-step-result-counterexample first-step)))
    (is-equal :require-law
              (mini-kernel:cegis-refinement-kind
               (mini-kernel:cegis-step-result-refinement first-step)))
    (is-equal :accepted
              (mini-kernel:cegis-step-result-status last-step))))

(defun test-invoke-formal-capability-lsip-edge-policy-cegis ()
  (let* ((problem (make-lsip-edge-policy-problem))
         (result (mini-kernel:invoke-formal-capability
                  :run-lsip-edge-policy-cegis
                  :caller-class :compiler
                  :problem problem))
         (state (mini-kernel:formal-capability-result-payload result)))
    (is-equal :accepted (mini-kernel:formal-capability-result-status result))
    (is-equal :cegis-state
              (mini-kernel:formal-capability-result-evidence-kind result))
    (is-true (typep state 'mini-kernel:cegis-run-state))
    (is-equal :accepted (mini-kernel:cegis-run-state-status state))))

(defun test-cegis-family-manifests ()
  (let* ((smt (mini-kernel:find-cegis-family-manifest :smt-constraint))
         (lsip (mini-kernel:find-cegis-family-manifest :lsip-edge-policy))
         (compiler (mini-kernel:find-cegis-family-manifest :compiler-mutation))
         (compiler-obligation
           (mini-kernel:find-cegis-obligation-class
            :compiler-input-domain-guard
            :compiler-mutation))
         (require-law (mini-kernel:find-cegis-refinement-kind
                       :require-law
                       :lsip-edge-policy))
         (conjoin (mini-kernel:find-cegis-refinement-kind
                   :conjoin-constraint
                   :smt-constraint))
         (disable-mutation (mini-kernel:find-cegis-refinement-kind
                            :disable-mutation
                            :compiler-mutation))
         (manifest-objects (mini-kernel:list-cegis-family-manifest-objects)))
    (is-true smt)
    (is-true lsip)
    (is-true compiler)
    (is-true compiler-obligation)
    (is-true require-law)
    (is-true conjoin)
    (is-true disable-mutation)
    (is-equal :run-smt-cegis
              (mini-kernel:cegis-family-manifest-operation-id smt))
    (is-equal :lsip-edge-policy-cegis
              (mini-kernel:cegis-family-manifest-constraint-class lsip))
    (is-equal :run-compiler-mutation-cegis
              (mini-kernel:cegis-family-manifest-operation-id compiler))
    (is-equal :compiler-mutation-cegis
              (mini-kernel:cegis-family-manifest-constraint-class compiler))
    (is-equal 3 (length manifest-objects))))

(defun test-cegis-ir-objects ()
  (let* ((space (mini-kernel:cegis-family-space :smt-constraint))
         (rule (mini-kernel:cegis-refinement-rule-object
                :conjoin-constraint
                :smt-constraint))
         (candidate (mini-kernel:make-cegis-candidate
                     :id "candidate-1"
                     :family :smt-constraint
                     :payload '((:bool t))
                     :metadata '(:iteration 0)))
         (object (mini-kernel:cegis-candidate-object candidate))
         (score (mini-kernel:make-cegis-normalized-score
                 :hard-failures 0
                 :soft-failures 1
                 :constraint-count 2
                 :candidate-cost 3
                 :novelty 1)))
    (is-true (typep space 'mini-kernel:cegis-space))
    (is-equal :smt-constraint
              (mini-kernel:cegis-space-family space))
    (is-equal '(:conjoin-constraint :no-refinement)
              (mini-kernel:cegis-space-refinement-kinds space))
    (is-true (typep rule 'mini-kernel:cegis-refinement-rule))
    (is-equal '(:append-constraint :constraint)
              (mini-kernel:cegis-refinement-rule-replay-form rule))
    (is-true (typep object 'mini-kernel:cegis-object))
    (is-equal :candidate (mini-kernel:cegis-object-kind object))
    (is-equal 104 (getf score :score))))

(defun test-apply-cegis-refinement-smt ()
  (let ((problem (make-boolean-blocking-problem)))
    (multiple-value-bind (state step)
        (mini-kernel:run-cegis-step problem)
      (declare (ignore state))
      (let* ((expected (mini-kernel:cegis-step-result-next-candidate step))
             (replayed
               (mini-kernel:apply-cegis-refinement
                problem
                (mini-kernel:cegis-step-result-candidate step)
                (mini-kernel:cegis-step-result-refinement step)))
             (constraint
               (mini-kernel:cegis-refinement-constraint
                (mini-kernel:cegis-step-result-refinement step))))
        (is-true (typep constraint 'mini-kernel:cegis-constraint))
        (is-equal :smt-constraint
                  (mini-kernel:cegis-constraint-family constraint))
        (is-equal (mini-kernel:cegis-candidate-id expected)
                  (mini-kernel:cegis-candidate-id replayed))
        (is-equal (mini-kernel:cegis-candidate-payload expected)
                  (mini-kernel:cegis-candidate-payload replayed))
        (is-equal (mini-kernel:cegis-candidate-metadata expected)
                  (mini-kernel:cegis-candidate-metadata replayed))))))

(defun test-apply-cegis-refinement-lsip ()
  (let ((problem (make-lsip-edge-policy-problem)))
    (multiple-value-bind (state step)
        (mini-kernel:run-cegis-step problem)
      (declare (ignore state))
      (let ((expected (mini-kernel:cegis-step-result-next-candidate step))
            (replayed
              (mini-kernel:apply-cegis-refinement
               problem
               (mini-kernel:cegis-step-result-candidate step)
               (mini-kernel:cegis-step-result-refinement step))))
        (is-equal (mini-kernel:cegis-candidate-id expected)
                  (mini-kernel:cegis-candidate-id replayed))
        (is-equal (mini-kernel:cegis-candidate-payload expected)
                  (mini-kernel:cegis-candidate-payload replayed))
        (is-equal (mini-kernel:cegis-candidate-metadata expected)
                  (mini-kernel:cegis-candidate-metadata replayed))))))

(defun test-cegis-normalized-evaluation ()
  (let* ((problem (make-boolean-blocking-problem))
         (state (mini-kernel:run-smt-cegis problem))
         (score (mini-kernel:cegis-run-state-score state))
         (evaluation (mini-kernel:cegis-run-state-evaluation state)))
    (is-equal 0 (getf score :hard-failures))
    (is-equal 0 (getf score :soft-failures))
    (is-equal 3 (getf score :constraint-count))
    (is-equal 4 (getf score :candidate-cost))
    (is-equal 0 (getf score :novelty))
    (is-equal 7 (getf score :score))
    (is-true (typep evaluation 'mini-kernel:cegis-evaluation))
    (is-equal :accepted
              (mini-kernel:cegis-evaluation-status evaluation))
    (is-equal 7 (mini-kernel:cegis-evaluation-score evaluation))))

(defun test-run-cegis-family-routing ()
  (let* ((smt-problem (make-boolean-blocking-problem))
         (smt-state (mini-kernel:run-cegis-family
                     :smt-constraint
                     smt-problem))
         (lsip-problem (make-lsip-edge-policy-problem))
         (lsip-state (mini-kernel:run-cegis-family
                      :lsip-edge-policy
                      lsip-problem))
         (compiler-problem (make-compiler-mutation-problem))
         (compiler-state (mini-kernel:run-cegis-family
                          :compiler-mutation
                          compiler-problem)))
    (is-equal :accepted
              (mini-kernel:cegis-run-state-status smt-state))
    (is-equal :accepted
              (mini-kernel:cegis-run-state-status lsip-state))
    (is-equal :accepted
              (mini-kernel:cegis-run-state-status compiler-state))))

(defun test-run-compiler-mutation-cegis ()
  (let* ((problem (make-compiler-mutation-problem))
         (state (mini-kernel:run-compiler-mutation-cegis problem))
         (history (mini-kernel:cegis-run-state-history state))
         (accepted (mini-kernel:cegis-run-state-accepted-candidate state))
         (payload (mini-kernel:cegis-candidate-payload accepted)))
    (is-equal :accepted (mini-kernel:cegis-run-state-status state))
    (is-equal 4 (length history))
    (is-equal '(:and (:bool t) (:var safe (:Bool)))
              (getf payload :guard))
    (is-equal '((:selector :opcode
                 :constraint (:member :add (:add :sub))))
              (getf payload :branch-restrictions))
    (is-equal '(:rewrite-commute)
              (getf payload :disabled-mutations))
    (is-equal '(:tighten-guard
                :restrict-branch-domain
                :disable-mutation)
              (remove nil
                      (mapcar (lambda (step)
                                (let ((refinement
                                        (mini-kernel:cegis-step-result-refinement
                                         step)))
                                  (and refinement
                                       (mini-kernel:cegis-refinement-kind
                                        refinement))))
                              history)))))

(defun test-cegis-trace-replay ()
  (let* ((problem (make-compiler-mutation-problem))
         (trace (mini-kernel:run-cegis-trace
                 :compiler-mutation
                 problem))
         (report (mini-kernel:replay-cegis-trace problem trace)))
    (is-true (typep trace 'mini-kernel:cegis-trace))
    (is-equal :accepted (mini-kernel:cegis-trace-status trace))
    (is-equal 4 (length (mini-kernel:cegis-trace-steps trace)))
    (is-equal :accepted (getf report :status))
    (is-equal t (getf report :validp))
    (is-equal 4 (getf report :checked-steps))))

(defun test-cegis-artifact-roundtrip ()
  (let* ((problem (make-compiler-mutation-problem))
         (trace (mini-kernel:run-cegis-trace
                 :compiler-mutation
                 problem))
         (trace-plist (mini-kernel:cegis-artifact-plist trace))
         (trace-copy (mini-kernel:cegis-artifact-from-plist trace-plist))
         (space (mini-kernel:describe-cegis-space :compiler-mutation))
         (space-json (mini-kernel:cegis-artifact-json-object space))
         (space-copy (mini-kernel:cegis-artifact-from-json-object space-json)))
    (is-equal :cegis-trace (getf trace-plist :type))
    (is-equal (mini-kernel:cegis-trace-status trace)
              (mini-kernel:cegis-trace-status trace-copy))
    (is-equal (length (mini-kernel:cegis-trace-steps trace))
              (length (mini-kernel:cegis-trace-steps trace-copy)))
    (is-equal :cegis-space
              (mini-kernel:json-object-get space-json "type"))
    (is-equal :compiler-mutation
              (mini-kernel:cegis-space-family space-copy))))

(defun test-cegis-search-ir-catalog ()
  (let* ((search-ir (mini-kernel:describe-cegis-search-ir :compiler-mutation))
         (search-irs (mini-kernel:list-cegis-search-irs))
         (obligations (mini-kernel:cegis-search-ir-obligation-classes search-ir))
         (artifact (mini-kernel:cegis-artifact-plist search-ir))
         (roundtrip (mini-kernel:cegis-artifact-from-plist artifact)))
    (is-true (typep search-ir 'mini-kernel:cegis-search-ir))
    (is-equal 3 (length search-irs))
    (is-equal :compiler-mutation
              (mini-kernel:cegis-search-ir-family search-ir))
    (is-equal 3 (length obligations))
    (is-true
     (member :compiler-input-domain-guard
             (mapcar #'mini-kernel:cegis-obligation-class-id obligations)))
    (is-equal :search-constraint
              (getf (mini-kernel:cegis-search-ir-projection-schema search-ir)
                    :projection-kind))
    (is-equal :cegis-search-ir (getf artifact :type))
    (is-equal (mini-kernel:cegis-search-ir-family search-ir)
              (mini-kernel:cegis-search-ir-family roundtrip))))

(defun test-invoke-formal-constraint-class-cegis-synthesis ()
  (let* ((problem (make-lsip-edge-policy-problem))
         (result (mini-kernel:invoke-formal-constraint-class
                  :cegis-synthesis
                  :caller-class :synth
                  :family :lsip-edge-policy
                  :problem problem))
         (state (mini-kernel:formal-capability-result-payload result)))
    (is-equal :accepted (mini-kernel:formal-capability-result-status result))
    (is-equal :run-cegis-family
              (mini-kernel:formal-capability-result-operation-id result))
    (is-true (typep state 'mini-kernel:cegis-run-state))
    (is-equal :accepted (mini-kernel:cegis-run-state-status state))))

(defun test-invoke-cegis-family-manifest-capability ()
  (let* ((result (mini-kernel:invoke-formal-capability
                  :list-cegis-family-manifests
                  :caller-class :synth))
         (payload (mini-kernel:formal-capability-result-payload result)))
    (is-equal :accepted (mini-kernel:formal-capability-result-status result))
    (is-equal :audit-result
              (mini-kernel:formal-capability-result-evidence-kind result))
    (is-equal 3 (length payload))
    (is-true (find :smt-constraint payload :key (lambda (entry)
                                                 (getf entry :id))))))

(defun test-invoke-cegis-capability-surface ()
  (let* ((problem (make-compiler-mutation-problem))
         (spaces-result (mini-kernel:invoke-formal-capability
                         :list-cegis-spaces
                         :caller-class :synth))
         (space-result (mini-kernel:invoke-formal-capability
                        :describe-cegis-space
                        :caller-class :compiler
                        :family :compiler-mutation))
         (step-result (mini-kernel:invoke-formal-capability
                       :run-cegis-step
                       :caller-class :compiler
                       :problem problem))
         (trace-result (mini-kernel:invoke-formal-capability
                        :run-cegis-trace
                        :caller-class :compiler
                        :family :compiler-mutation
                        :problem problem))
         (trace (mini-kernel:formal-capability-result-payload trace-result))
         (search-irs-result (mini-kernel:invoke-formal-capability
                             :list-cegis-search-irs
                             :caller-class :compiler))
         (search-ir-result (mini-kernel:invoke-formal-capability
                            :describe-cegis-search-ir
                            :caller-class :compiler
                            :family :compiler-mutation))
         (replay-result (mini-kernel:invoke-formal-capability
                         :replay-cegis-trace
                         :caller-class :compiler
                         :problem problem
                         :trace trace)))
    (is-equal :accepted
              (mini-kernel:formal-capability-result-status spaces-result))
    (is-equal 3
              (length (mini-kernel:formal-capability-result-payload
                       spaces-result)))
    (is-equal :compiler-mutation
              (mini-kernel:cegis-space-family
               (mini-kernel:formal-capability-result-payload space-result)))
    (is-equal 3
              (length (mini-kernel:formal-capability-result-payload
                       search-irs-result)))
    (is-equal :compiler-mutation
              (mini-kernel:cegis-search-ir-family
               (mini-kernel:formal-capability-result-payload search-ir-result)))
    (is-true (getf (mini-kernel:formal-capability-result-payload step-result)
                   :trace-step))
    (is-equal :cegis-trace
              (mini-kernel:formal-capability-result-evidence-kind trace-result))
    (is-equal :accepted
              (getf (mini-kernel:formal-capability-result-payload replay-result)
                    :status))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "run-smt-check-emits-model-artifact"
                  #'test-run-smt-check-emits-model-artifact)
            (cons "run-smt-cegis" #'test-run-smt-cegis)
            (cons "invoke-formal-capability-cegis"
                  #'test-invoke-formal-capability-cegis)
            (cons "run-lsip-edge-policy-cegis"
                  #'test-run-lsip-edge-policy-cegis)
            (cons "invoke-formal-capability-lsip-edge-policy-cegis"
                  #'test-invoke-formal-capability-lsip-edge-policy-cegis)
            (cons "cegis-family-manifests"
                  #'test-cegis-family-manifests)
            (cons "cegis-ir-objects"
                  #'test-cegis-ir-objects)
            (cons "apply-cegis-refinement-smt"
                  #'test-apply-cegis-refinement-smt)
            (cons "apply-cegis-refinement-lsip"
                  #'test-apply-cegis-refinement-lsip)
            (cons "cegis-normalized-evaluation"
                  #'test-cegis-normalized-evaluation)
            (cons "run-cegis-family-routing"
                  #'test-run-cegis-family-routing)
            (cons "run-compiler-mutation-cegis"
                  #'test-run-compiler-mutation-cegis)
            (cons "cegis-trace-replay"
                  #'test-cegis-trace-replay)
            (cons "cegis-artifact-roundtrip"
                  #'test-cegis-artifact-roundtrip)
            (cons "cegis-search-ir-catalog"
                  #'test-cegis-search-ir-catalog)
            (cons "invoke-formal-constraint-class-cegis-synthesis"
                  #'test-invoke-formal-constraint-class-cegis-synthesis)
            (cons "invoke-cegis-family-manifest-capability"
                  #'test-invoke-cegis-family-manifest-capability)
            (cons "invoke-cegis-capability-surface"
                  #'test-invoke-cegis-capability-surface)))
         (passed 0)
         (failed 0))
    (dolist (test tests)
      (if (run-test (car test) (cdr test))
          (incf passed)
          (incf failed)))
    (format t "~%passed: ~D failed: ~D~%" passed failed)
    (when (plusp failed)
      (fail-test "cegis test suite failed"))
    t))
