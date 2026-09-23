(in-package :mini-kernel)

(declaim (ftype function make-bootstrap-env activate-stage-from-bundle))

(defstruct (stage-manifest
            (:constructor %make-stage-manifest (&key
                                                   stage-id
                                                   env-digest
                                                   config-digest
                                                   certificate-ids
                                                   provenance)))
  stage-id
  env-digest
  config-digest
  certificate-ids
  provenance)

(defstruct (stage
            (:constructor %make-stage (&key
                                          id
                                          manifest
                                          env
                                          reference-env
                                          advisory-store
                                          certificates
                                          external-bundles
                                          config-digest
                                          env-digest
                                          activatedp)))
  id
  manifest
  env
  reference-env
  advisory-store
  certificates
  external-bundles
  config-digest
  env-digest
  activatedp)

(defstruct (stage-verification-bundle
            (:constructor %make-stage-verification-bundle (&key
                                                              stage-id
                                                              env-digest
                                                              config-digest
                                                              agreement
                                                              bounded
                                                              external
                                                              protocol)))
  stage-id
  env-digest
  config-digest
  agreement
  bounded
  external
  protocol)

(defun make-stage-manifest (&key stage-id
                              (env-digest :bootstrap-v1)
                              (config-digest *current-config-digest*)
                              (certificate-ids '())
                              (provenance '(:stage bootstrap)))
  (%make-stage-manifest :stage-id stage-id
                        :env-digest env-digest
                        :config-digest config-digest
                        :certificate-ids certificate-ids
                        :provenance provenance))

(defun certificate->corpus-entry (certificate &key id)
  (mini-kernel-corpus::make-corpus-entry
   :id (or id
           (getf (certificate-metadata certificate) :certificate-id)
           (getf (certificate-metadata certificate) :id)
           (kernel-error "certificate metadata is missing :certificate-id/:id for stage normalization~%certificate: ~S"
                         certificate))
   :certificate certificate))

(defun normalize-stage-certificates (certificates)
  (loop for item in certificates
        for index from 0
        collect
        (cond
          ((typep item 'mini-kernel-corpus:corpus-entry)
           item)
          ((typep item 'certificate)
           (certificate->corpus-entry item
                                      :id (or (getf (certificate-metadata item) :certificate-id)
                                              (getf (certificate-metadata item) :id)
                                              (intern (format nil "STAGE-CERT-~D" index) :keyword))))
          (t
           (kernel-error "unsupported stage certificate item: ~S" item)))))

(defun make-stage (&key id
                     (manifest nil)
                     (env (make-bootstrap-env))
                     (reference-env (mini-kernel-reference:make-reference-env env))
                     (advisory-store (make-advisory-store))
                     (certificates '())
                     (external-bundles '())
                     (config-digest *current-config-digest*)
                     (env-digest :bootstrap-v1)
                     (activatedp nil))
  (let* ((certificates (normalize-stage-certificates certificates))
         (manifest (or manifest
                      (make-stage-manifest :stage-id id
                                           :env-digest env-digest
                                           :config-digest config-digest
                                           :certificate-ids (mapcar #'mini-kernel-corpus:corpus-entry-id certificates)
                                           :provenance '(:stage explicit)))))
    (%make-stage :id id
                 :manifest manifest
                 :env env
                 :reference-env reference-env
                 :advisory-store advisory-store
                 :certificates certificates
                 :external-bundles (copy-list external-bundles)
                 :config-digest config-digest
                 :env-digest env-digest
                 :activatedp activatedp)))

(defun make-stage-from-surface-specs (&key id
                                           surface-specs
                                           (env (make-bootstrap-env))
                                           (reference-env (mini-kernel-reference:make-reference-env env))
                                           (advisory-store (make-advisory-store))
                                           (config-digest *current-config-digest*)
                                           (env-digest :bootstrap-v1)
                                           (provenance '(:stage surface-compiled)))
  (let* ((certificates (compile-stage-surface-certificates
                        surface-specs
                        :env env
                        :env-digest env-digest
                        :checker-id 'frontend-lower))
         (entries (normalize-stage-certificates certificates))
         (manifest (make-stage-manifest
                    :stage-id id
                    :env-digest env-digest
                    :config-digest config-digest
                    :certificate-ids (mapcar #'mini-kernel-corpus:corpus-entry-id entries)
                    :provenance provenance)))
    (make-stage :id id
                :manifest manifest
                :env env
                :reference-env reference-env
                :advisory-store advisory-store
                :certificates entries
                :config-digest config-digest
                :env-digest env-digest)))

(defun make-stage-verification-bundle (&key stage-id
                                         env-digest
                                         config-digest
                                         agreement
                                         bounded
                                         external
                                         protocol)
  (%make-stage-verification-bundle :stage-id stage-id
                                   :env-digest env-digest
                                   :config-digest config-digest
                                   :agreement agreement
                                   :bounded bounded
                                   :external external
                                   :protocol protocol))

(defun serialize-backend-result (result)
  (validate-backend-result result)
  (list :backend-id (backend-result-backend-id result)
        :status (backend-result-status result)
        :evidence (copy-list (backend-result-evidence result))
        :artifacts (copy-tree (backend-result-artifacts result))))

(defun deserialize-backend-result (payload)
  (validate-backend-result
   (make-backend-result
    :backend-id (getf payload :backend-id)
    :status (getf payload :status)
    :evidence (copy-list (getf payload :evidence))
    :artifacts (copy-tree (getf payload :artifacts)))))

(defun serialize-stage-verification-bundle (bundle)
  (list :stage-id (stage-verification-bundle-stage-id bundle)
        :env-digest (stage-verification-bundle-env-digest bundle)
        :config-digest (stage-verification-bundle-config-digest bundle)
        :agreement (serialize-backend-result (stage-verification-bundle-agreement bundle))
        :bounded (serialize-backend-result (stage-verification-bundle-bounded bundle))
        :external (serialize-backend-result (stage-verification-bundle-external bundle))
        :protocol (serialize-backend-result (stage-verification-bundle-protocol bundle))))

(defun deserialize-stage-verification-bundle (payload)
  (make-stage-verification-bundle
   :stage-id (getf payload :stage-id)
   :env-digest (getf payload :env-digest)
   :config-digest (getf payload :config-digest)
   :agreement (deserialize-backend-result (getf payload :agreement))
   :bounded (deserialize-backend-result (getf payload :bounded))
   :external (deserialize-backend-result (getf payload :external))
   :protocol (deserialize-backend-result (getf payload :protocol))))

(defun check-stage-manifest (stage)
  (let ((manifest (stage-manifest stage)))
    (unless manifest
      (kernel-error "stage ~S is missing a manifest" (stage-id stage)))
    (unless (eql (stage-manifest-stage-id manifest) (stage-id stage))
      (kernel-error "stage manifest id mismatch~%stage: ~S~%manifest: ~S"
                    (stage-id stage)
                    (stage-manifest-stage-id manifest)))
    (unless (equal (stage-manifest-env-digest manifest) (stage-env-digest stage))
      (kernel-error "stage manifest env digest mismatch~%expected: ~S~%actual:   ~S"
                    (stage-env-digest stage)
                    (stage-manifest-env-digest manifest)))
    (unless (equal (stage-manifest-config-digest manifest) (stage-config-digest stage))
      (kernel-error "stage manifest config digest mismatch~%expected: ~S~%actual:   ~S"
                    (stage-config-digest stage)
                    (stage-manifest-config-digest manifest)))
    (unless (listp (stage-manifest-certificate-ids manifest))
      (kernel-error "stage manifest certificate ids must be a list, got ~S"
                    (stage-manifest-certificate-ids manifest)))
    manifest))

(defun certificate-accepted-p-kl (env certificate expected-env-digest)
  (handler-case
      (progn
        (check-certificate env certificate :expected-env-digest expected-env-digest)
        t)
    (kernel-error ()
      nil)))

(defun certificate-accepted-p-kr (reference-env certificate expected-env-digest)
  (handler-case
      (progn
        (mini-kernel-reference:check-certificate
         reference-env certificate :expected-env-digest expected-env-digest)
        t)
    (mini-kernel-reference::reference-error ()
      nil)))

(defun %corpus-groups ()
  (list (cons :accepted (mini-kernel-corpus:accepted-certificates))
        (cons :rejected (mini-kernel-corpus:rejected-certificates))
        (cons :malformed (mini-kernel-corpus:malformed-certificates))
        (cons :generated (mini-kernel-corpus:generated-certificates))))

(defun %stage-certificate-entries (stage)
  (if (endp (stage-certificates stage))
      (mapcan #'copy-list (mapcar #'cdr (%corpus-groups)))
      (copy-list (stage-certificates stage))))

(defun check-stage-certificates (stage)
  (let ((mismatches '())
        (expected-ids (copy-list (stage-manifest-certificate-ids (check-stage-manifest stage))))
        (seen-ids '()))
    (dolist (entry (%stage-certificate-entries stage))
      (let* ((entry-id (mini-kernel-corpus:corpus-entry-id entry))
             (certificate (mini-kernel-corpus:corpus-entry-certificate entry))
             (expected-env-digest (stage-env-digest stage))
             (kl (certificate-accepted-p-kl (stage-env stage) certificate expected-env-digest))
             (kr (certificate-accepted-p-kr (stage-reference-env stage) certificate expected-env-digest)))
        (push entry-id seen-ids)
        (unless (eql kl kr)
          (push (list :id entry-id :kl kl :kr kr) mismatches))))
    (dolist (expected-id expected-ids)
      (unless (member expected-id seen-ids :test #'eql)
        (push (list :id expected-id :status :missing) mismatches)))
    (make-backend-result
     :backend-id 'audit-check
     :status (if mismatches :rejected :accepted)
     :evidence '(:stage-certificates)
     :artifacts (nreverse mismatches))))

(defun check-stage-corpus-agreement (stage)
  (if (endp (stage-certificates stage))
      (let ((mismatches '()))
        (dolist (group (%corpus-groups))
          (dolist (entry (cdr group))
            (let* ((certificate (mini-kernel-corpus:corpus-entry-certificate entry))
                   (expected-env-digest (stage-env-digest stage))
                   (kl (certificate-accepted-p-kl (stage-env stage) certificate expected-env-digest))
                   (kr (certificate-accepted-p-kr (stage-reference-env stage) certificate expected-env-digest)))
              (unless (eql kl kr)
                (push (list :group (car group)
                            :id (mini-kernel-corpus:corpus-entry-id entry)
                            :kl kl
                            :kr kr)
                      mismatches)))))
        (make-backend-result
         :backend-id 'audit-check
         :status (if mismatches :rejected :accepted)
         :evidence '(:agreement-report)
         :artifacts (nreverse mismatches)))
      (check-stage-certificates stage)))

(defun check-stage-bounded-obligations (stage obligations)
  (let ((blocking '())
        (artifacts '()))
    (dolist (obligation obligations)
      (if (and (consp obligation) (eq (first obligation) :admitted-bridge))
          (destructuring-bind (_ obligation-id formula) obligation
            (declare (ignore _))
            (if (j-smt-admitted-obligation-bridge obligation-id formula)
                (push (list :obligation obligation
                            :bridge obligation-id
                            :status :rejected)
                      artifacts)
                (push (list :obligation obligation
                            :bridge obligation-id
                            :status :counterexample)
                      blocking)))
          (let ((result (run-smt-check (stage-advisory-store stage) obligation)))
            (setf artifacts (nconc artifacts (copy-list (backend-result-artifacts result))))
            (unless (eq (backend-result-status result) :rejected)
              (push (list :obligation obligation
                          :status (backend-result-status result))
                    blocking)))))
    (make-backend-result
     :backend-id 'smt-check
     :status (if blocking :counterexample :accepted)
     :evidence '(:bounded-obligation-check)
     :artifacts (append artifacts (nreverse blocking)))))

(defun replay-smt-obligation-bundle (stage bundle)
  (unless (typep bundle 'smt-obligation-bundle)
    (kernel-error "expected SMT obligation bundle for replay, got ~S" bundle))
  (let* ((query (smt-obligation-bundle-input bundle))
         (result (run-smt-check (stage-advisory-store stage) query))
         (replay-bundle
           (find-if (lambda (artifact)
                      (typep artifact 'smt-obligation-bundle))
                    (backend-result-artifacts result))))
    (unless replay-bundle
      (kernel-error "SMT replay produced no obligation bundle for query: ~S" query))
    (let ((mismatches '()))
      (unless (eq (backend-result-status result) (smt-obligation-bundle-status bundle))
        (push (list :field :status
                    :expected (smt-obligation-bundle-status bundle)
                    :actual (backend-result-status result))
              mismatches))
      (unless (equal (smt-obligation-bundle-input-digest replay-bundle)
                     (smt-obligation-bundle-input-digest bundle))
        (push (list :field :input-digest
                    :expected (smt-obligation-bundle-input-digest bundle)
                    :actual (smt-obligation-bundle-input-digest replay-bundle))
              mismatches))
      (unless (equal (smt-obligation-bundle-normalized-digest replay-bundle)
                     (smt-obligation-bundle-normalized-digest bundle))
        (push (list :field :normalized-digest
                    :expected (smt-obligation-bundle-normalized-digest bundle)
                    :actual (smt-obligation-bundle-normalized-digest replay-bundle))
              mismatches))
      (unless (equal (smt-obligation-bundle-assumption-ids replay-bundle)
                     (smt-obligation-bundle-assumption-ids bundle))
        (push (list :field :assumption-ids
                    :expected (smt-obligation-bundle-assumption-ids bundle)
                    :actual (smt-obligation-bundle-assumption-ids replay-bundle))
              mismatches))
      (unless (equal (smt-obligation-bundle-unsat-core replay-bundle)
                     (smt-obligation-bundle-unsat-core bundle))
        (push (list :field :unsat-core
                    :expected (smt-obligation-bundle-unsat-core bundle)
                    :actual (smt-obligation-bundle-unsat-core replay-bundle))
              mismatches))
      mismatches)))

(defun replay-stage-bounded-artifacts (stage bounded-result)
  (let ((mismatches '()))
    (dolist (artifact (backend-result-artifacts bounded-result))
      (when (typep artifact 'smt-obligation-bundle)
        (let ((artifact-mismatches (replay-smt-obligation-bundle stage artifact)))
          (when artifact-mismatches
            (push (list :obligation-id (smt-obligation-bundle-obligation-id artifact)
                        :mismatches artifact-mismatches)
                  mismatches)))))
    (make-backend-result
     :backend-id 'audit-check
     :status (if mismatches :replay-mismatch :accepted)
     :evidence '(:smt-replay)
     :artifacts (nreverse mismatches))))

(defun check-stage-external-bundles (stage)
  (let ((blocking '()))
    (dolist (bundle (stage-external-bundles stage))
      (unless (eq (external-report-bundle-status bundle) :accepted)
        (push (list :artifact-id (external-report-bundle-artifact-id bundle)
                    :status (external-report-bundle-status bundle))
              blocking)))
    (make-backend-result
     :backend-id 'audit-check
     :status (if blocking :rejected :accepted)
     :evidence '(:external-report-check)
     :artifacts (append (copy-list (stage-external-bundles stage))
                        (nreverse blocking)))))

(defun replay-external-report-bundle (bundle)
  (unless (typep bundle 'external-report-bundle)
    (kernel-error "expected external report bundle for replay, got ~S" bundle))
  (let* ((path (external-report-bundle-source-path bundle))
         (replay-bundle
           (case (external-report-bundle-report-kind bundle)
             (:lsip-closure-report
              (ingest-lsip-closure-report path))
             (:mir-report
              (ingest-mir-report path :artifact-id (external-report-bundle-artifact-id bundle)))
             (otherwise
              (kernel-error "unsupported external report kind for replay: ~S"
                            (external-report-bundle-report-kind bundle)))))
         (mismatches '()))
    (unless (eq (external-report-bundle-status replay-bundle)
                (external-report-bundle-status bundle))
      (push (list :field :status
                  :expected (external-report-bundle-status bundle)
                  :actual (external-report-bundle-status replay-bundle))
            mismatches))
    (unless (equal (external-report-bundle-source-digest replay-bundle)
                   (external-report-bundle-source-digest bundle))
      (push (list :field :source-digest
                  :expected (external-report-bundle-source-digest bundle)
                  :actual (external-report-bundle-source-digest replay-bundle))
            mismatches))
    (unless (equal (external-report-bundle-summary-digest replay-bundle)
                   (external-report-bundle-summary-digest bundle))
      (push (list :field :summary-digest
                  :expected (external-report-bundle-summary-digest bundle)
                  :actual (external-report-bundle-summary-digest replay-bundle))
            mismatches))
    mismatches))

(defun replay-stage-external-bundles (stage)
  (let ((mismatches '()))
    (dolist (bundle (stage-external-bundles stage))
      (let ((artifact-mismatches (replay-external-report-bundle bundle)))
        (when artifact-mismatches
          (push (list :artifact-id (external-report-bundle-artifact-id bundle)
                      :mismatches artifact-mismatches)
                mismatches))))
    (make-backend-result
     :backend-id 'audit-check
     :status (if mismatches :replay-mismatch :accepted)
     :evidence '(:external-replay)
     :artifacts (nreverse mismatches))))

(defun run-model-check (store query)
  (let ((backend (find-backend 'model-check)))
    (unless backend
      (kernel-error "model-check backend is not registered"))
    (unless (eq (backend-trust-class backend) :advisory)
      (kernel-error "model-check backend lost advisory status"))
    (cond
      ((and (consp query) (eq (first query) :counterexample))
       (let* ((bundle (make-protocol-check-bundle
                       :query query
                       :result-payload (second query)
                       :status :counterexample
                       :evidence-kind :trace
                       :trace-ref '(:checker stub)))
              (artifact (emit-advisory-artifact
                         store 'model-check :trace (second query) '(:checker stub))))
         (make-backend-result
          :backend-id 'model-check
          :status :counterexample
          :evidence '(:trace)
          :artifacts (list bundle artifact))))
      ((and (consp query) (eq (first query) :invariant))
       (let* ((bundle (make-protocol-check-bundle
                       :query query
                       :result-payload (second query)
                       :status :accepted
                       :evidence-kind :invariant
                       :trace-ref '(:checker stub)))
              (artifact (emit-advisory-artifact
                         store 'model-check :invariant (second query) '(:checker stub))))
         (make-backend-result
          :backend-id 'model-check
          :status :accepted
          :evidence '(:invariant)
          :artifacts (list bundle artifact))))
      ((eq query :unknown)
       (make-backend-result
        :backend-id 'model-check
        :status :unknown
        :evidence '(:unknown)
        :artifacts '()))
      (t
       (kernel-error "unsupported model-check query: ~S" query)))))

(defun check-stage-activation-protocol (stage protocol-query)
  (run-model-check (stage-advisory-store stage) protocol-query))

(defun replay-protocol-check-bundle (stage bundle)
  (unless (typep bundle 'protocol-check-bundle)
    (kernel-error "expected protocol check bundle for replay, got ~S" bundle))
  (let* ((query (protocol-check-bundle-query bundle))
         (result (run-model-check (stage-advisory-store stage) query))
         (replay-bundle
           (find-if (lambda (artifact)
                      (typep artifact 'protocol-check-bundle))
                    (backend-result-artifacts result))))
    (unless replay-bundle
      (kernel-error "protocol replay produced no protocol bundle for query: ~S" query))
    (let ((mismatches '()))
      (unless (eq (backend-result-status result) (protocol-check-bundle-status bundle))
        (push (list :field :status
                    :expected (protocol-check-bundle-status bundle)
                    :actual (backend-result-status result))
              mismatches))
      (unless (equal (protocol-check-bundle-query-digest replay-bundle)
                     (protocol-check-bundle-query-digest bundle))
        (push (list :field :query-digest
                    :expected (protocol-check-bundle-query-digest bundle)
                    :actual (protocol-check-bundle-query-digest replay-bundle))
              mismatches))
      (unless (equal (protocol-check-bundle-result-digest replay-bundle)
                     (protocol-check-bundle-result-digest bundle))
        (push (list :field :result-digest
                    :expected (protocol-check-bundle-result-digest bundle)
                    :actual (protocol-check-bundle-result-digest replay-bundle))
              mismatches))
      (unless (eq (protocol-check-bundle-evidence-kind replay-bundle)
                  (protocol-check-bundle-evidence-kind bundle))
        (push (list :field :evidence-kind
                    :expected (protocol-check-bundle-evidence-kind bundle)
                    :actual (protocol-check-bundle-evidence-kind replay-bundle))
              mismatches))
      mismatches)))

(defun replay-stage-protocol-artifacts (stage protocol-result)
  (let ((mismatches '()))
    (dolist (artifact (backend-result-artifacts protocol-result))
      (when (typep artifact 'protocol-check-bundle)
        (let ((artifact-mismatches (replay-protocol-check-bundle stage artifact)))
          (when artifact-mismatches
            (push (list :protocol-id (protocol-check-bundle-protocol-id artifact)
                        :mismatches artifact-mismatches)
                  mismatches)))))
    (make-backend-result
     :backend-id 'audit-check
     :status (if mismatches :replay-mismatch :accepted)
     :evidence '(:protocol-replay)
     :artifacts (nreverse mismatches))))

(defun activate-stage-if-verified (stage &key
                                           (obligations '())
                                           (protocol-query '(:invariant (:activation-gate ok))))
  (let* ((agreement (check-stage-corpus-agreement stage))
         (bounded (check-stage-bounded-obligations stage obligations))
         (external (check-stage-external-bundles stage))
         (protocol (check-stage-activation-protocol stage protocol-query))
         (bundle (make-stage-verification-bundle
                  :stage-id (stage-id stage)
                  :env-digest (stage-env-digest stage)
                  :config-digest (stage-config-digest stage)
                  :agreement agreement
                  :bounded bounded
                  :external external
                  :protocol protocol)))
    (activate-stage-from-bundle stage bundle)))

(defun verify-stage (stage &key
                             (obligations '())
                             (protocol-query '(:invariant (:activation-gate ok))))
  (check-stage-manifest stage)
  (unless (equal (stage-config-digest stage) *current-config-digest*)
    (kernel-error "stage ~S config digest mismatch~%expected: ~S~%actual:   ~S"
                  (stage-id stage)
                  *current-config-digest*
                  (stage-config-digest stage)))
  (make-stage-verification-bundle
   :stage-id (stage-id stage)
   :env-digest (stage-env-digest stage)
   :config-digest (stage-config-digest stage)
   :agreement (check-stage-corpus-agreement stage)
   :bounded (check-stage-bounded-obligations stage obligations)
   :external (check-stage-external-bundles stage)
   :protocol (check-stage-activation-protocol stage protocol-query)))

(defun verify-stage-from-surface-specs (&key id
                                             surface-specs
                                             (env (make-bootstrap-env))
                                             (reference-env (mini-kernel-reference:make-reference-env env))
                                             (advisory-store (make-advisory-store))
                                             (config-digest *current-config-digest*)
                                             (env-digest :bootstrap-v1)
                                             (provenance '(:stage surface-compiled))
                                             (obligations '())
                                             (protocol-query '(:invariant (:activation-gate ok))))
  (let ((stage (make-stage-from-surface-specs
                :id id
                :surface-specs surface-specs
                :env env
                :reference-env reference-env
                :advisory-store advisory-store
                :config-digest config-digest
                :env-digest env-digest
                :provenance provenance)))
    (values stage
            (verify-stage stage
                          :obligations obligations
                          :protocol-query protocol-query))))

(defun activate-stage-from-bundle (stage bundle)
  (check-stage-manifest stage)
  (unless (eql (stage-verification-bundle-stage-id bundle) (stage-id stage))
    (kernel-error "stage verification bundle id mismatch~%expected: ~S~%actual:   ~S"
                  (stage-id stage)
                  (stage-verification-bundle-stage-id bundle)))
  (unless (equal (stage-verification-bundle-env-digest bundle) (stage-env-digest stage))
    (kernel-error "stage verification bundle env digest mismatch~%expected: ~S~%actual:   ~S"
                  (stage-env-digest stage)
                  (stage-verification-bundle-env-digest bundle)))
  (unless (equal (stage-verification-bundle-config-digest bundle) (stage-config-digest stage))
    (kernel-error "stage verification bundle config digest mismatch~%expected: ~S~%actual:   ~S"
                  (stage-config-digest stage)
                  (stage-verification-bundle-config-digest bundle)))
  (unless (eq (backend-result-status (stage-verification-bundle-agreement bundle)) :accepted)
    (kernel-error "stage ~S failed corpus agreement gate: ~S"
                  (stage-id stage)
                  (backend-result-artifacts (stage-verification-bundle-agreement bundle))))
  (unless (eq (backend-result-status (stage-verification-bundle-bounded bundle)) :accepted)
    (kernel-error "stage ~S failed bounded-obligation gate: ~S"
                  (stage-id stage)
                  (backend-result-artifacts (stage-verification-bundle-bounded bundle))))
  (let ((replay (replay-stage-bounded-artifacts stage
                                                (stage-verification-bundle-bounded bundle))))
    (unless (eq (backend-result-status replay) :accepted)
      (kernel-error "stage ~S failed SMT replay gate: ~S"
                    (stage-id stage)
                    (backend-result-artifacts replay))))
  (unless (eq (backend-result-status (stage-verification-bundle-external bundle)) :accepted)
    (kernel-error "stage ~S failed external artifact gate: ~S"
                  (stage-id stage)
                  (backend-result-artifacts (stage-verification-bundle-external bundle))))
  (let ((replay (replay-stage-external-bundles stage)))
    (unless (eq (backend-result-status replay) :accepted)
      (kernel-error "stage ~S failed external replay gate: ~S"
                    (stage-id stage)
                    (backend-result-artifacts replay))))
  (unless (eq (backend-result-status (stage-verification-bundle-protocol bundle)) :accepted)
    (kernel-error "stage ~S failed activation protocol gate: ~S"
                  (stage-id stage)
                  (backend-result-artifacts (stage-verification-bundle-protocol bundle))))
  (let ((replay (replay-stage-protocol-artifacts stage
                                                 (stage-verification-bundle-protocol bundle))))
    (unless (eq (backend-result-status replay) :accepted)
      (kernel-error "stage ~S failed protocol replay gate: ~S"
                    (stage-id stage)
                    (backend-result-artifacts replay))))
  (setf (stage-activatedp stage) t)
  stage)

(defun emit-stage-verification-bundle (store stage bundle &optional metadata)
  (emit-checked-proposal
   store
   'audit-check
   :candidate
   (serialize-stage-verification-bundle bundle)
   (append (list :stage-id (stage-id stage)
                 :env-digest (stage-env-digest stage)
                 :config-digest (stage-config-digest stage))
           metadata)))

(defun emit-verified-stage-proposal (store &key
                                           id
                                           surface-specs
                                           (env (make-bootstrap-env))
                                           (reference-env (mini-kernel-reference:make-reference-env env))
                                           (advisory-store (make-advisory-store))
                                           (config-digest *current-config-digest*)
                                           (env-digest :bootstrap-v1)
                                           (provenance '(:stage surface-compiled))
                                           (obligations '())
                                           (protocol-query '(:invariant (:activation-gate ok)))
                                           metadata)
  (multiple-value-bind (stage bundle)
      (verify-stage-from-surface-specs
       :id id
       :surface-specs surface-specs
       :env env
       :reference-env reference-env
       :advisory-store advisory-store
       :config-digest config-digest
       :env-digest env-digest
       :provenance provenance
       :obligations obligations
       :protocol-query protocol-query)
    (values stage
            bundle
            (emit-stage-verification-bundle store stage bundle metadata))))

(defun activate-stage-from-proposal (stage proposal)
  (unless (eq (checked-proposal-backend-id proposal) 'audit-check)
    (kernel-error "stage verification proposal must come from audit-check, got ~S"
                  (checked-proposal-backend-id proposal)))
  (unless (eq (checked-proposal-kind proposal) :candidate)
    (kernel-error "stage verification proposal must have kind :candidate, got ~S"
                  (checked-proposal-kind proposal)))
  (activate-stage-from-bundle
   stage
   (deserialize-stage-verification-bundle (checked-proposal-payload proposal))))

(defun validate-environment (env)
  (maphash
   (lambda (name decl)
     (declare (ignore name))
     (check-sort env '() (decl-type decl))
     (when (eq (decl-kind decl) :def)
       (check env '() (decl-value decl) (decl-type decl))))
   env)
  t)

(defun nat-type ()
  (mk-const 'nat))

(defun zero-term ()
  (mk-const 'zero))

(defun succ-term (n)
  (mk-app (mk-const 'succ) n))

(defun eq-term (type lhs rhs)
  (app* (mk-const 'eq) (list type lhs rhs)))

(defun refl-term (type value)
  (app* (mk-const 'refl) (list type value)))

(defun nat-rec-type ()
  (let* ((nat (nat-type))
         (motive-type (mk-pi nat (mk-sort 0)))
         (zero-branch-type (mk-app (mk-var 0) (zero-term)))
         (step-branch-type
           (mk-pi nat
                  (mk-pi (mk-app (mk-var 2) (mk-var 0))
                         (mk-app (mk-var 3)
                                 (succ-term (mk-var 1))))))
         (result-type
           (mk-pi nat
                  (mk-app (mk-var 3) (mk-var 0)))))
    (mk-pi motive-type
           (mk-pi zero-branch-type
                  (mk-pi step-branch-type
                         result-type)))))

(defun eq-type ()
  (mk-pi (mk-sort 0)
         (mk-pi (mk-var 0)
                (mk-pi (mk-var 1)
                       (mk-sort 0)))))

(defun refl-type ()
  (mk-pi (mk-sort 0)
         (mk-pi (mk-var 0)
                (eq-term (mk-var 1)
                         (mk-var 0)
                         (mk-var 0)))))

(defun eq-rec-type ()
  (let* ((p-type
           (mk-pi (mk-var 1)
                  (mk-pi (eq-term (mk-var 2)
                                  (mk-var 1)
                                  (mk-var 0))
                         (mk-sort 0))))
         (proof-type
           (app* (mk-var 0)
                 (list (mk-var 1)
                       (refl-term (mk-var 2) (mk-var 1)))))
         (equality-type
           (eq-term (mk-var 4)
                    (mk-var 3)
                    (mk-var 0)))
         (result-type
           (app* (mk-var 3)
                 (list (mk-var 1)
                       (mk-var 0)))))
    (mk-pi (mk-sort 0)
           (mk-pi (mk-var 0)
                  (mk-pi p-type
                         (mk-pi proof-type
                                (mk-pi (mk-var 3)
                                       (mk-pi equality-type
                                              result-type))))))))

(defun add-type ()
  (let ((nat (nat-type)))
    (mk-pi nat
           (mk-pi nat nat))))

(defun add-value ()
  (let ((nat (nat-type)))
    (mk-lam nat
            (mk-lam nat
                    (app* (mk-const 'nat-rec)
                          (list (mk-lam nat nat)
                                (mk-var 0)
                                (mk-lam nat
                                        (mk-lam nat
                                                (succ-term (mk-var 0))))
                                (mk-var 1)))))))

(defun make-bootstrap-env ()
  (let ((env (make-env)))
    (env-add env 'nat
             (make-decl :kind :axiom
                        :type (mk-sort 0)
                        :value nil
                        :reduciblep nil))
    (env-add env 'zero
             (make-decl :kind :axiom
                        :type (nat-type)
                        :value nil
                        :reduciblep nil))
    (env-add env 'succ
             (make-decl :kind :axiom
                        :type (mk-pi (nat-type) (nat-type))
                        :value nil
                        :reduciblep nil))
    (env-add env 'nat-rec
             (make-decl :kind :axiom
                        :type (nat-rec-type)
                        :value nil
                        :reduciblep nil))
    (env-add env 'eq
             (make-decl :kind :axiom
                        :type (eq-type)
                        :value nil
                        :reduciblep nil))
    (env-add env 'refl
             (make-decl :kind :axiom
                        :type (refl-type)
                        :value nil
                        :reduciblep nil))
    (env-add env 'eq-rec
             (make-decl :kind :axiom
                        :type (eq-rec-type)
                        :value nil
                        :reduciblep nil))
    (env-add env 'add
             (make-decl :kind :def
                        :type (add-type)
                        :value (add-value)
                        :reduciblep t))
    env))
