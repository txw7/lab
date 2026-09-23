(in-package :mini-kernel)

(defun core-closedn-p (n term)
  (case (term-tag term)
    (:var (< (second term) n))
    (:sort t)
    (:const t)
    (:app (and (core-closedn-p n (second term))
               (core-closedn-p n (third term))))
    (:lam (and (core-closedn-p n (second term))
               (core-closedn-p (1+ n) (third term))))
    (:pi (and (core-closedn-p n (second term))
              (core-closedn-p (1+ n) (third term))))
    (:let (and (core-closedn-p n (second term))
               (core-closedn-p n (third term))
               (core-closedn-p (1+ n) (fourth term))))
    (otherwise
     (kernel-error "unknown core term in core-closedn-p: ~S" term))))

(defun %collect-unique-terms (terms)
  (let ((seen (make-hash-table :test #'equal))
        (result '()))
    (dolist (term terms)
      (unless (gethash term seen)
        (setf (gethash term seen) t)
        (push term result)))
    (nreverse result)))

(defun %base-core-terms (binders)
  (append (loop for k below binders collect (mk-var k))
          (list (mk-sort 0)
                (mk-sort 1)
                (mk-const 'nat)
                (mk-const 'zero)
                (mk-const 'succ)
                (mk-const 'eq)
                (mk-const 'refl))))

(defun enumerate-bounded-core-terms (&key (depth 1) (binders 0))
  (labels ((enum (current-depth current-binders)
             (let ((base (%base-core-terms current-binders)))
               (if (zerop current-depth)
                   (%collect-unique-terms base)
                   (let* ((smaller (enum (1- current-depth) current-binders))
                          (under-binder (enum (1- current-depth) (1+ current-binders)))
                          (apps (loop for f in smaller append
                                      (loop for a in smaller collect (mk-app f a))))
                          (lams (loop for A in smaller append
                                      (loop for body in under-binder collect (mk-lam A body))))
                          (pis (loop for A in smaller append
                                     (loop for body in under-binder collect (mk-pi A body))))
                          (lets (loop for v in smaller append
                                      (loop for A in smaller append
                                            (loop for body in under-binder
                                                  collect (mk-let v A body))))))
                     (%collect-unique-terms
                      (append base smaller apps lams pis lets)))))))
    (enum depth binders)))

(defun run-shift-closure-audit (&key (max-depth 1) (max-binders 2) (delta 1))
  (let ((failures '())
        (checked 0))
    (loop for binders from 0 to max-binders do
      (dolist (term (enumerate-bounded-core-terms :depth max-depth :binders binders))
        (when (core-closedn-p binders term)
          (incf checked)
          (unless (equal (shift delta binders term) term)
            (push (list :binders binders :term term :shifted (shift delta binders term))
                  failures)))))
    (make-backend-result
     :backend-id 'audit-check
     :status (if failures :rejected :accepted)
     :evidence '(:shift-closure-audit)
     :artifacts (list :checked checked :failures (nreverse failures)))))

(defun run-subst-irrelevance-audit (&key (max-depth 1) (max-binders 2))
  (let ((failures '())
        (checked 0)
        (replacements (enumerate-bounded-core-terms :depth 0 :binders 0)))
    (loop for binders from 0 to max-binders do
      (dolist (term (enumerate-bounded-core-terms :depth max-depth :binders binders))
        (when (core-closedn-p binders term)
          (dolist (replacement replacements)
            (let ((j binders))
              (incf checked)
              (unless (equal (subst j replacement term) term)
                (push (list :binders binders
                            :index j
                            :replacement replacement
                            :term term
                            :substituted (subst j replacement term))
                      failures)))))))
    (make-backend-result
     :backend-id 'audit-check
     :status (if failures :rejected :accepted)
     :evidence '(:subst-irrelevance-audit)
     :artifacts (list :checked checked :failures (nreverse failures)))))

(defun bounded-smt-audit-formulas ()
  (list
   (smt-and (smt-bool-const t) (smt-bool-const t))
   (smt-or (smt-bool-const nil) (smt-bool-const t))
   (smt-eq (smt-bvadd (smt-bv-lit 4 1) (smt-bv-lit 4 2))
           (smt-bv-lit 4 3))
   (smt-not (smt-ult (smt-bv-lit 4 2) (smt-bv-lit 4 1)))
   (smt-eq (smt-extract 3 0 (smt-concat (smt-bv-lit 4 1) (smt-bv-lit 4 5)))
           (smt-bv-lit 4 5))))

(defun run-smt-normalization-audit (&optional (formulas (bounded-smt-audit-formulas)))
  (let ((store (make-advisory-store))
        (failures '())
        (checked 0))
    (dolist (formula formulas)
      (incf checked)
      (let* ((normalized (normalize-smt-term formula))
             (equiv-query (smt-not (smt-eq formula normalized)))
             (result (run-smt-check store equiv-query)))
        (unless (eq (backend-result-status result) :rejected)
          (push (list :formula formula
                      :normalized normalized
                      :status (backend-result-status result))
                failures))))
    (make-backend-result
     :backend-id 'audit-check
     :status (if failures :rejected :accepted)
     :evidence '(:smt-normalization-audit)
     :artifacts (list :checked checked :failures (nreverse failures)))))

(defun %kl-certificate-status (env certificate)
  (handler-case
      (progn
        (check-certificate env certificate)
        :accepted)
    (kernel-error ()
      :rejected)))

(defun %kr-certificate-status (reference-env certificate)
  (handler-case
      (progn
        (mini-kernel-reference:check-certificate reference-env certificate)
        :accepted)
    (mini-kernel-reference::reference-error ()
      :rejected)))

(defun %jd-judgment-status (env judgment)
  (if (j-d env judgment)
      :accepted
      :rejected))

(defun %jkr-judgment-status (reference-env judgment)
  (if (j-kr reference-env judgment)
      :accepted
      :rejected))

(defun %jkl-judgment-status (env judgment)
  (if (j-kl env judgment)
      :accepted
      :rejected))

(defun %implementation-certificate-status (implementation env certificate)
  (with-kernel-implementation (implementation)
    (%kl-certificate-status env certificate)))

(defun %implementation-judgment-status (implementation env judgment)
  (with-kernel-implementation (implementation)
    (%jkl-judgment-status env judgment)))

(defun summarize-kernel-spec-audit-entries (entries)
  (let ((matched 0)
        (mismatched 0))
    (dolist (entry entries)
      (if (getf entry :matchedp)
          (incf matched)
          (incf mismatched)))
    (list :total (length entries)
          :matched matched
          :mismatched mismatched)))

(defun run-kernel-spec-kr-kl-audit (&optional (suite (make-default-kernel-spec-suite)))
  (let ((entries '())
        (failures '()))
    (dolist (spec suite)
      (let* ((report (compare-kernel-spec-kr-kl spec))
             (spec-id (getf report :spec-id)))
        (dolist (entry (getf report :entries))
          (let ((audit-entry
                  (list :spec-id spec-id
                        :id (getf entry :id)
                        :expected-status (getf entry :expected-status)
                        :kr-status (getf entry :kr-status)
                        :kl-status (getf entry :kl-status)
                        :matchedp (getf entry :matchedp))))
            (push audit-entry entries)
            (unless (getf entry :matchedp)
              (push audit-entry failures))))))
    (let ((ordered-entries (nreverse entries))
          (ordered-failures (nreverse failures)))
      (make-backend-result
       :backend-id 'audit-check
       :status (if ordered-failures :rejected :accepted)
       :evidence '(:kernel-spec-kr-kl-audit)
       :artifacts (list :checked (length ordered-entries)
                        :suite-size (length suite)
                        :summary (summarize-kernel-spec-audit-entries ordered-entries)
                        :entries ordered-entries
                        :failures ordered-failures)))))

(defun run-kernel-spec-kr-kl-defir-audit (&optional (suite (make-default-kernel-spec-suite)))
  (let ((entries '())
        (failures '()))
    (dolist (spec suite)
      (let* ((report (compare-kernel-spec-kr-kl-defir spec))
             (spec-id (getf report :spec-id)))
        (dolist (entry (getf report :entries))
          (let ((audit-entry
                  (list :spec-id spec-id
                        :id (getf entry :id)
                        :expected-status (getf entry :expected-status)
                        :kr-status (getf entry :kr-status)
                        :kl-status (getf entry :kl-status)
                        :defir-status (getf entry :defir-status)
                        :matchedp (getf entry :matchedp))))
            (push audit-entry entries)
            (unless (getf entry :matchedp)
              (push audit-entry failures))))))
    (let ((ordered-entries (nreverse entries))
          (ordered-failures (nreverse failures)))
      (make-backend-result
       :backend-id 'audit-check
       :status (if ordered-failures :rejected :accepted)
       :evidence '(:kernel-spec-kr-kl-defir-audit)
       :artifacts (list :checked (length ordered-entries)
                        :suite-size (length suite)
                        :summary (summarize-kernel-spec-audit-entries ordered-entries)
                        :entries ordered-entries
                        :failures ordered-failures)))))

(defun %theorem-audit-result (obligation-id checked failures)
  (let ((obligation (find-theorem-obligation obligation-id)))
    (unless obligation
      (kernel-error "unknown theorem obligation id: ~S" obligation-id))
    (let ((witness
            (make-theorem-witness
             :obligation-id obligation-id
             :lane (theorem-obligation-lane obligation)
             :relation (theorem-obligation-relation obligation)
             :checked checked
             :payload (if failures nil '(:status :no-counterexample-found))))
          (counterexamples
            (mapcar (lambda (failure)
                      (make-theorem-counterexample
                       :obligation-id obligation-id
                       :lane (theorem-obligation-lane obligation)
                       :relation (theorem-obligation-relation obligation)
                       :payload failure))
                    failures)))
    (make-backend-result
     :backend-id 'audit-check
     :status (if failures :rejected :accepted)
     :evidence (list :theorem-obligation obligation-id)
     :artifacts (list :obligation-id obligation-id
                      :relation (theorem-obligation-relation obligation)
                      :lane (theorem-obligation-lane obligation)
                      :checked checked
                      :witness witness
                      :counterexamples counterexamples
                      :failures (nreverse failures))))))

(defun %bounded-contexts (max-context-size)
  (loop for n from 0 to max-context-size
        collect (loop repeat n collect (mk-const 'nat))))

(defun %make-bounded-typing-judgment (ctx term type)
  (make-typing-judgment ctx term type))

(defun %collect-unique-judgments (judgments)
  (let ((seen (make-hash-table :test #'equal))
        (result '()))
    (dolist (judgment judgments)
      (let ((key (list (kernel-judgment-context judgment)
                       (kernel-judgment-term judgment)
                       (kernel-judgment-type judgment)
                       (kernel-judgment-config judgment)
                       (kernel-judgment-judgment-kind judgment))))
        (unless (gethash key seen)
          (setf (gethash key seen) t)
          (push judgment result))))
    (nreverse result)))

(defun %seed-typing-judgments ()
  (list
   (%make-bounded-typing-judgment '()
                                  (mk-const 'zero)
                                  (mk-const 'nat))
   (%make-bounded-typing-judgment '()
                                  (succ-term (zero-term))
                                  (mk-const 'nat))
   (%make-bounded-typing-judgment '()
                                  (app* (mk-const 'add)
                                        (list (zero-term)
                                              (zero-term)))
                                  (mk-const 'nat))
   (%make-bounded-typing-judgment
    '()
    (mk-lam (mk-const 'nat)
            (app* (mk-const 'refl)
                  (list (mk-const 'nat)
                        (mk-var 0))))
    (mk-pi (mk-const 'nat)
           (app* (mk-const 'eq)
                 (list (mk-const 'nat)
                       (mk-var 0)
                       (mk-var 0)))))
   (%make-bounded-typing-judgment (list (mk-const 'nat))
                                  (mk-var 0)
                                  (mk-const 'nat))
   (%make-bounded-typing-judgment (list (mk-const 'nat))
                                  (succ-term (mk-var 0))
                                  (mk-const 'nat))))

(defun %judgment-frontier-types (ctx)
  (list (mk-const 'nat)
        (mk-sort 0)
        (mk-pi (mk-const 'nat) (mk-const 'nat))
        (app* (mk-const 'eq)
              (list (mk-const 'nat)
                    (zero-term)
                    (zero-term)))
        (when ctx
          (first ctx))))

(defun %accepted-judgment-cases (env max-depth max-context-size)
  (%collect-unique-judgments
   (append
    (remove-if (lambda (judgment)
                 (> (length (kernel-judgment-context judgment)) max-context-size))
               (%seed-typing-judgments))
    (loop for ctx in (%bounded-contexts max-context-size) append
          (let ((binders (length ctx)))
            (loop for term in (enumerate-bounded-core-terms :depth max-depth :binders binders)
                  for inferred = (handler-case (d-infer env ctx term)
                                  (kernel-error () nil))
                  when inferred
                  collect (%make-bounded-typing-judgment ctx term inferred)))))))

(defun %dense-judgment-audit-cases (env max-depth max-context-size)
  (let ((accepted (%accepted-judgment-cases env max-depth max-context-size)))
    (%collect-unique-judgments
     (append
      accepted
      (loop for judgment in accepted append
            (let* ((ctx (kernel-judgment-context judgment))
                   (term (kernel-judgment-term judgment))
                   (actual-type (kernel-judgment-type judgment)))
              (loop for candidate in (%judgment-frontier-types ctx)
                    unless (equal candidate actual-type)
                    collect (%make-bounded-typing-judgment ctx term candidate))))))))

(defun %judgment-audit-cases (max-depth max-context-size &key (carrier-mode :cross-product))
  (%collect-unique-judgments
   (let ((env (make-bootstrap-env)))
     (case carrier-mode
       (:dense
        (%dense-judgment-audit-cases env max-depth max-context-size))
       (otherwise
        (append
         (loop for ctx in (%bounded-contexts max-context-size) append
               (let ((binders (length ctx)))
                 (loop for term in (enumerate-bounded-core-terms :depth max-depth :binders binders)
                       append
                       (loop for type in (enumerate-bounded-core-terms :depth max-depth :binders binders)
                             collect (%make-bounded-typing-judgment ctx term type)))))
         (remove-if (lambda (judgment)
                      (> (length (kernel-judgment-context judgment)) max-context-size))
                    (%seed-typing-judgments))))))))

(defun %accepted-d-check-p (env ctx term type)
  (handler-case
      (progn
        (d-check env ctx term type)
        t)
    (kernel-error ()
      nil)))

(defun %bounded-binder-types (depth binders)
  (remove-if-not
   (lambda (term) (core-closedn-p binders term))
   (enumerate-bounded-core-terms :depth depth :binders binders)))

(defun %collect-unique-terms-equal (terms)
  (let ((seen (make-hash-table :test #'equal))
        (result '()))
    (dolist (term terms)
      (unless (gethash term seen)
        (setf (gethash term seen) t)
        (push term result)))
    (nreverse result)))

(defun %jd-substitution-fragment-data (&key (max-depth 0) (max-context-size 1))
  (let* ((env (make-bootstrap-env))
         (failures '())
         (checked 0)
         (instances '()))
    (dolist (gamma (%bounded-contexts max-context-size))
      (let* ((gamma-binders (length gamma))
             (a-candidates (%bounded-binder-types max-depth gamma-binders)))
        (dolist (a-type a-candidates)
          (when (handler-case (progn (d-check-sort env gamma a-type) t)
                  (kernel-error () nil))
            (let* ((extended-ctx (cons a-type gamma))
                   (replacement-candidates
                     (enumerate-bounded-core-terms :depth max-depth :binders gamma-binders))
                   (body-candidates
                     (enumerate-bounded-core-terms :depth max-depth :binders (1+ gamma-binders))))
              (dolist (replacement replacement-candidates)
                (when (%accepted-d-check-p env gamma replacement a-type)
                  (dolist (body body-candidates)
                    (dolist (body-type body-candidates)
                      (when (%accepted-d-check-p env extended-ctx body body-type)
                        (incf checked)
                        (let ((subst-body (d-subst-top replacement body))
                              (subst-type (d-subst-top replacement body-type)))
                          (push (list :gamma gamma
                                      :binder-type a-type
                                      :replacement replacement
                                      :body body
                                      :body-type body-type
                                      :substituted-body subst-body
                                      :substituted-type subst-type)
                                instances)
                          (unless (%accepted-d-check-p env gamma subst-body subst-type)
                            (push (list :gamma gamma
                                        :binder-type a-type
                                        :replacement replacement
                                        :body body
                                        :body-type body-type
                                        :substituted-body subst-body
                                        :substituted-type subst-type)
                                  failures)))))))))))))
    (list :checked checked
          :instances (nreverse instances)
          :failures (nreverse failures))))

(defun emit-jd-substitution-fragment-certificate (&key (max-depth 0) (max-context-size 1))
  (let* ((payload (%jd-substitution-fragment-data
                   :max-depth max-depth
                   :max-context-size max-context-size))
         (certificate-payload
           (list :obligation-id :jd-substitution
                 :parameters (list :max-depth max-depth
                                   :max-context-size max-context-size)
                 :checked (getf payload :checked)
                 :instances (getf payload :instances)
                 :failures (getf payload :failures))))
    (make-theorem-fragment-certificate
     :obligation-id :jd-substitution
     :parameters (list :max-depth max-depth
                       :max-context-size max-context-size)
     :checked (getf payload :checked)
     :payload-digest (artifact-digest certificate-payload)
     :status (if (getf payload :failures) :rejected :accepted)
     :config-digest *current-config-digest*)))

(defun verify-jd-substitution-fragment-certificate (certificate)
  (unless (typep certificate 'theorem-fragment-certificate)
    (kernel-error "expected theorem fragment certificate, got ~S" certificate))
  (unless (eq (theorem-fragment-certificate-obligation-id certificate) :jd-substitution)
    (kernel-error "wrong theorem fragment certificate obligation id: ~S"
                  (theorem-fragment-certificate-obligation-id certificate)))
  (unless (equal (theorem-fragment-certificate-config-digest certificate)
                 *current-config-digest*)
    (kernel-error "theorem fragment certificate config digest mismatch~%expected: ~S~%actual:   ~S"
                  *current-config-digest*
                  (theorem-fragment-certificate-config-digest certificate)))
  (let* ((parameters (theorem-fragment-certificate-parameters certificate))
         (payload (%jd-substitution-fragment-data
                   :max-depth (getf parameters :max-depth 0)
                   :max-context-size (getf parameters :max-context-size 1)))
         (expected-payload
           (list :obligation-id :jd-substitution
                 :parameters parameters
                 :checked (getf payload :checked)
                 :instances (getf payload :instances)
                 :failures (getf payload :failures)))
         (expected-digest (artifact-digest expected-payload))
         (expected-status (if (getf payload :failures) :rejected :accepted)))
    (unless (= (theorem-fragment-certificate-checked certificate)
               (getf payload :checked))
      (kernel-error "theorem fragment certificate checked-count mismatch~%expected: ~S~%actual:   ~S"
                    (getf payload :checked)
                    (theorem-fragment-certificate-checked certificate)))
    (unless (eql (theorem-fragment-certificate-payload-digest certificate)
                 expected-digest)
      (kernel-error "theorem fragment certificate payload digest mismatch~%expected: ~S~%actual:   ~S"
                    expected-digest
                    (theorem-fragment-certificate-payload-digest certificate)))
    (unless (eq (theorem-fragment-certificate-status certificate)
                expected-status)
      (kernel-error "theorem fragment certificate status mismatch~%expected: ~S~%actual:   ~S"
                    expected-status
                    (theorem-fragment-certificate-status certificate)))
    t))

(defun %jd-weakening-fragment-data (&key (max-depth 0) (max-context-size 1))
  (let* ((env (make-bootstrap-env))
         (failures '())
         (checked 0)
         (instances '()))
    (dolist (gamma (%bounded-contexts max-context-size))
      (let ((gamma-binders (length gamma))
            (terms (enumerate-bounded-core-terms :depth max-depth :binders (length gamma))))
        (dolist (binder-type (%bounded-binder-types max-depth gamma-binders))
          (when (handler-case (progn (d-check-sort env gamma binder-type) t)
                  (kernel-error () nil))
            (dolist (term terms)
              (dolist (type terms)
                (when (%accepted-d-check-p env gamma term type)
                  (incf checked)
                  (let ((weakened-term (d-shift 1 0 term))
                        (weakened-type (d-shift 1 0 type))
                        (weakened-ctx (cons binder-type gamma)))
                    (push (list :gamma gamma
                                :binder-type binder-type
                                :term term
                                :type type
                                :weakened-context weakened-ctx
                                :weakened-term weakened-term
                                :weakened-type weakened-type)
                          instances)
                    (unless (%accepted-d-check-p env weakened-ctx weakened-term weakened-type)
                      (push (list :gamma gamma
                                  :binder-type binder-type
                                  :term term
                                  :type type
                                  :weakened-context weakened-ctx
                                  :weakened-term weakened-term
                                  :weakened-type weakened-type)
                            failures))))))))))
    (list :checked checked
          :instances (nreverse instances)
          :failures (nreverse failures))))

(defun emit-jd-weakening-fragment-certificate (&key (max-depth 0) (max-context-size 1))
  (let* ((payload (%jd-weakening-fragment-data
                   :max-depth max-depth
                   :max-context-size max-context-size))
         (certificate-payload
           (list :obligation-id :jd-weakening
                 :parameters (list :max-depth max-depth
                                   :max-context-size max-context-size)
                 :checked (getf payload :checked)
                 :instances (getf payload :instances)
                 :failures (getf payload :failures))))
    (make-theorem-fragment-certificate
     :obligation-id :jd-weakening
     :parameters (list :max-depth max-depth
                       :max-context-size max-context-size)
     :checked (getf payload :checked)
     :payload-digest (artifact-digest certificate-payload)
     :status (if (getf payload :failures) :rejected :accepted)
     :config-digest *current-config-digest*)))

(defun verify-jd-weakening-fragment-certificate (certificate)
  (unless (typep certificate 'theorem-fragment-certificate)
    (kernel-error "expected theorem fragment certificate, got ~S" certificate))
  (unless (eq (theorem-fragment-certificate-obligation-id certificate) :jd-weakening)
    (kernel-error "wrong theorem fragment certificate obligation id: ~S"
                  (theorem-fragment-certificate-obligation-id certificate)))
  (unless (equal (theorem-fragment-certificate-config-digest certificate)
                 *current-config-digest*)
    (kernel-error "theorem fragment certificate config digest mismatch~%expected: ~S~%actual:   ~S"
                  *current-config-digest*
                  (theorem-fragment-certificate-config-digest certificate)))
  (let* ((parameters (theorem-fragment-certificate-parameters certificate))
         (payload (%jd-weakening-fragment-data
                   :max-depth (getf parameters :max-depth 0)
                   :max-context-size (getf parameters :max-context-size 1)))
         (expected-payload
           (list :obligation-id :jd-weakening
                 :parameters parameters
                 :checked (getf payload :checked)
                 :instances (getf payload :instances)
                 :failures (getf payload :failures)))
         (expected-digest (artifact-digest expected-payload))
         (expected-status (if (getf payload :failures) :rejected :accepted)))
    (unless (= (theorem-fragment-certificate-checked certificate)
               (getf payload :checked))
      (kernel-error "theorem fragment certificate checked-count mismatch~%expected: ~S~%actual:   ~S"
                    (getf payload :checked)
                    (theorem-fragment-certificate-checked certificate)))
    (unless (eql (theorem-fragment-certificate-payload-digest certificate)
                 expected-digest)
      (kernel-error "theorem fragment certificate payload digest mismatch~%expected: ~S~%actual:   ~S"
                    expected-digest
                    (theorem-fragment-certificate-payload-digest certificate)))
      (unless (eq (theorem-fragment-certificate-status certificate)
                  expected-status)
        (kernel-error "theorem fragment certificate status mismatch~%expected: ~S~%actual:   ~S"
                      expected-status
                      (theorem-fragment-certificate-status certificate)))
    t))

(defun %jd-jkr-soundness-fragment-data (&key (max-depth 1) (max-context-size 1)
                                         (carrier-mode :cross-product))
  (let* ((env (make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (judgments (%judgment-audit-cases max-depth max-context-size
                                           :carrier-mode carrier-mode))
         (checked 0)
         (failures '()))
    (dolist (judgment judgments)
      (let ((jd (%jd-judgment-status env judgment))
            (jkr (%jkr-judgment-status reference-env judgment)))
        (incf checked)
        (when (and (eq jkr :accepted)
                   (not (eq jd :accepted)))
          (push (list :context (kernel-judgment-context judgment)
                      :term (kernel-judgment-term judgment)
                      :type (kernel-judgment-type judgment)
                      :j-d jd
                      :j-kr jkr)
                failures))))
    (list :checked checked
          :parameters (list :max-depth max-depth
                           :max-context-size max-context-size
                           :carrier-mode carrier-mode)
          :failures (nreverse failures)
          :carrier-mode carrier-mode)))

(defun emit-jd-jkr-soundness-fragment-certificate
    (&key (max-depth 1) (max-context-size 1) (carrier-mode :cross-product))
  (let* ((payload (%jd-jkr-soundness-fragment-data
                   :max-depth max-depth
                   :max-context-size max-context-size
                   :carrier-mode carrier-mode))
         (certificate-payload
          (list :obligation-id :jkr-soundness
                :parameters (list :max-depth max-depth
                                  :max-context-size max-context-size
                                  :carrier-mode carrier-mode)
                :checked (getf payload :checked)
                :failures (getf payload :failures))))
    (make-theorem-fragment-certificate
     :obligation-id :jkr-soundness
     :parameters (list :max-depth max-depth
                       :max-context-size max-context-size
                       :carrier-mode carrier-mode)
     :checked (getf payload :checked)
     :payload-digest (artifact-digest certificate-payload)
     :status (if (getf payload :failures) :rejected :accepted)
     :config-digest *current-config-digest*)))

(defun verify-jd-jkr-soundness-fragment-certificate (certificate)
  (unless (typep certificate 'theorem-fragment-certificate)
    (kernel-error "expected theorem fragment certificate, got ~S" certificate))
  (unless (eq (theorem-fragment-certificate-obligation-id certificate)
              :jkr-soundness)
    (kernel-error "wrong theorem fragment certificate obligation id: ~S"
                  (theorem-fragment-certificate-obligation-id certificate)))
  (unless (equal (theorem-fragment-certificate-config-digest certificate)
                 *current-config-digest*)
    (kernel-error "theorem fragment certificate config digest mismatch~%expected: ~S~%actual:   ~S"
                  *current-config-digest*
                  (theorem-fragment-certificate-config-digest certificate)))
  (let* ((parameters (theorem-fragment-certificate-parameters certificate))
         (payload (%jd-jkr-soundness-fragment-data
                   :max-depth (getf parameters :max-depth 1)
                   :max-context-size (getf parameters :max-context-size 1)
                   :carrier-mode (getf parameters :carrier-mode :cross-product)))
         (expected-payload
          (list :obligation-id :jkr-soundness
                :parameters (list :max-depth (getf parameters :max-depth 1)
                                 :max-context-size (getf parameters :max-context-size 1)
                                 :carrier-mode (getf parameters :carrier-mode :cross-product))
                :checked (getf payload :checked)
                :failures (getf payload :failures)))
         (expected-digest (artifact-digest expected-payload))
         (expected-status (if (getf payload :failures) :rejected :accepted)))
    (unless (= (theorem-fragment-certificate-checked certificate)
               (getf payload :checked))
      (kernel-error "theorem fragment certificate checked-count mismatch~%expected: ~S~%actual:   ~S"
                    (getf payload :checked)
                    (theorem-fragment-certificate-checked certificate)))
    (unless (eql (theorem-fragment-certificate-payload-digest certificate)
                 expected-digest)
      (kernel-error "theorem fragment certificate payload digest mismatch~%expected: ~S~%actual:   ~S"
                    expected-digest
                    (theorem-fragment-certificate-payload-digest certificate)))
    (unless (eq (theorem-fragment-certificate-status certificate)
                expected-status)
      (kernel-error "theorem fragment certificate status mismatch~%expected: ~S~%actual:   ~S"
                    expected-status
                    (theorem-fragment-certificate-status certificate)))
    t))

(defun %jd-jkr-completeness-fragment-data (&key (max-depth 1) (max-context-size 1)
                                            (carrier-mode :cross-product))
  (let* ((env (make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (judgments (%judgment-audit-cases max-depth max-context-size
                                           :carrier-mode carrier-mode))
         (checked 0)
         (failures '()))
    (dolist (judgment judgments)
      (let ((jd (%jd-judgment-status env judgment))
            (jkr (%jkr-judgment-status reference-env judgment)))
        (incf checked)
        (when (and (eq jd :accepted)
                   (not (eq jkr :accepted)))
          (push (list :context (kernel-judgment-context judgment)
                      :term (kernel-judgment-term judgment)
                      :type (kernel-judgment-type judgment)
                      :j-d jd
                      :j-kr jkr)
                failures))))
    (list :checked checked
          :parameters (list :max-depth max-depth
                           :max-context-size max-context-size
                           :carrier-mode carrier-mode)
          :failures (nreverse failures)
          :carrier-mode carrier-mode)))

(defun emit-jd-jkr-completeness-fragment-certificate
    (&key (max-depth 1) (max-context-size 1) (carrier-mode :cross-product))
  (let* ((payload (%jd-jkr-completeness-fragment-data
                   :max-depth max-depth
                   :max-context-size max-context-size
                   :carrier-mode carrier-mode))
         (certificate-payload
          (list :obligation-id :jkr-fragment-completeness
                :parameters (list :max-depth max-depth
                                  :max-context-size max-context-size
                                  :carrier-mode carrier-mode)
                :checked (getf payload :checked)
                :failures (getf payload :failures))))
    (make-theorem-fragment-certificate
     :obligation-id :jkr-fragment-completeness
     :parameters (list :max-depth max-depth
                       :max-context-size max-context-size
                       :carrier-mode carrier-mode)
     :checked (getf payload :checked)
     :payload-digest (artifact-digest certificate-payload)
     :status (if (getf payload :failures) :rejected :accepted)
     :config-digest *current-config-digest*)))

(defun verify-jd-jkr-fragment-completeness-fragment-certificate (certificate)
  (unless (typep certificate 'theorem-fragment-certificate)
    (kernel-error "expected theorem fragment certificate, got ~S" certificate))
  (unless (eq (theorem-fragment-certificate-obligation-id certificate)
              :jkr-fragment-completeness)
    (kernel-error "wrong theorem fragment certificate obligation id: ~S"
                  (theorem-fragment-certificate-obligation-id certificate)))
  (unless (equal (theorem-fragment-certificate-config-digest certificate)
                 *current-config-digest*)
    (kernel-error "theorem fragment certificate config digest mismatch~%expected: ~S~%actual:   ~S"
                  *current-config-digest*
                  (theorem-fragment-certificate-config-digest certificate)))
  (let* ((parameters (theorem-fragment-certificate-parameters certificate))
         (payload (%jd-jkr-completeness-fragment-data
                   :max-depth (getf parameters :max-depth 1)
                   :max-context-size (getf parameters :max-context-size 1)
                   :carrier-mode (getf parameters :carrier-mode :cross-product)))
         (expected-payload
          (list :obligation-id :jkr-fragment-completeness
                :parameters (list :max-depth (getf parameters :max-depth 1)
                                 :max-context-size (getf parameters :max-context-size 1)
                                 :carrier-mode (getf parameters :carrier-mode :cross-product))
                :checked (getf payload :checked)
                :failures (getf payload :failures)))
         (expected-digest (artifact-digest expected-payload))
         (expected-status (if (getf payload :failures) :rejected :accepted)))
    (unless (= (theorem-fragment-certificate-checked certificate)
               (getf payload :checked))
      (kernel-error "theorem fragment certificate checked-count mismatch~%expected: ~S~%actual:   ~S"
                    (getf payload :checked)
                    (theorem-fragment-certificate-checked certificate)))
    (unless (eql (theorem-fragment-certificate-payload-digest certificate)
                 expected-digest)
      (kernel-error "theorem fragment certificate payload digest mismatch~%expected: ~S~%actual:   ~S"
                    expected-digest
                    (theorem-fragment-certificate-payload-digest certificate)))
    (unless (eq (theorem-fragment-certificate-status certificate)
                expected-status)
      (kernel-error "theorem fragment certificate status mismatch~%expected: ~S~%actual:   ~S"
                    expected-status
                    (theorem-fragment-certificate-status certificate)))
    t))

(defun %jkr-jkl-equivalence-fragment-data (&key (max-depth 1) (max-context-size 1)
                                            (carrier-mode :cross-product))
  (let* ((env (make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (judgments (%judgment-audit-cases max-depth max-context-size
                                           :carrier-mode carrier-mode))
         (checked 0)
         (failures '()))
    (dolist (judgment judgments)
      (let ((jkr (%jkr-judgment-status reference-env judgment))
            (jkl (%jkl-judgment-status env judgment)))
        (incf checked)
        (unless (eq jkr jkl)
          (push (list :context (kernel-judgment-context judgment)
                      :term (kernel-judgment-term judgment)
                      :type (kernel-judgment-type judgment)
                      :j-kr jkr
                      :j-kl jkl)
                failures))))
    (list :checked checked
          :parameters (list :max-depth max-depth
                           :max-context-size max-context-size
                           :carrier-mode carrier-mode)
          :failures (nreverse failures)
          :carrier-mode carrier-mode)))

(defun emit-jkr-jkl-equivalence-fragment-certificate
    (&key (max-depth 1) (max-context-size 1) (carrier-mode :cross-product))
  (let* ((payload (%jkr-jkl-equivalence-fragment-data
                   :max-depth max-depth
                   :max-context-size max-context-size
                   :carrier-mode carrier-mode))
         (certificate-payload
          (list :obligation-id :jkl-jkr-equivalence
                :parameters (list :max-depth max-depth
                                  :max-context-size max-context-size
                                  :carrier-mode carrier-mode)
                :checked (getf payload :checked)
                :failures (getf payload :failures))))
    (make-theorem-fragment-certificate
     :obligation-id :jkl-jkr-equivalence
     :parameters (list :max-depth max-depth
                       :max-context-size max-context-size
                       :carrier-mode carrier-mode)
     :checked (getf payload :checked)
     :payload-digest (artifact-digest certificate-payload)
     :status (if (getf payload :failures) :rejected :accepted)
     :config-digest *current-config-digest*)))

(defun verify-jkr-jkl-equivalence-fragment-certificate (certificate)
  (unless (typep certificate 'theorem-fragment-certificate)
    (kernel-error "expected theorem fragment certificate, got ~S" certificate))
  (unless (eq (theorem-fragment-certificate-obligation-id certificate)
              :jkl-jkr-equivalence)
    (kernel-error "wrong theorem fragment certificate obligation id: ~S"
                  (theorem-fragment-certificate-obligation-id certificate)))
  (unless (equal (theorem-fragment-certificate-config-digest certificate)
                 *current-config-digest*)
    (kernel-error "theorem fragment certificate config digest mismatch~%expected: ~S~%actual:   ~S"
                  *current-config-digest*
                  (theorem-fragment-certificate-config-digest certificate)))
  (let* ((parameters (theorem-fragment-certificate-parameters certificate))
         (payload (%jkr-jkl-equivalence-fragment-data
                   :max-depth (getf parameters :max-depth 1)
                   :max-context-size (getf parameters :max-context-size 1)
                   :carrier-mode (getf parameters :carrier-mode :cross-product)))
         (expected-payload
          (list :obligation-id :jkl-jkr-equivalence
                :parameters (list :max-depth (getf parameters :max-depth 1)
                                 :max-context-size (getf parameters :max-context-size 1)
                                 :carrier-mode (getf parameters :carrier-mode :cross-product))
                :checked (getf payload :checked)
                :failures (getf payload :failures)))
         (expected-digest (artifact-digest expected-payload))
         (expected-status (if (getf payload :failures) :rejected :accepted)))
    (unless (= (theorem-fragment-certificate-checked certificate)
               (getf payload :checked))
      (kernel-error "theorem fragment certificate checked-count mismatch~%expected: ~S~%actual:   ~S"
                    (getf payload :checked)
                    (theorem-fragment-certificate-checked certificate)))
    (unless (eql (theorem-fragment-certificate-payload-digest certificate)
                 expected-digest)
      (kernel-error "theorem fragment certificate payload digest mismatch~%expected: ~S~%actual:   ~S"
                    expected-digest
                    (theorem-fragment-certificate-payload-digest certificate)))
    (unless (eq (theorem-fragment-certificate-status certificate)
                expected-status)
      (kernel-error "theorem fragment certificate status mismatch~%expected: ~S~%actual:   ~S"
                    expected-status
                    (theorem-fragment-certificate-status certificate)))
    t))

(defun %jkr-defir-equivalence-fragment-data
    (&key (max-depth 1) (max-context-size 1) (carrier-mode :cross-product))
  (let* ((env (make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (implementation (make-defir-kernel-implementation))
         (judgments (%judgment-audit-cases max-depth max-context-size
                                           :carrier-mode carrier-mode))
         (checked 0)
         (failures '()))
    (dolist (judgment judgments)
      (let ((jkr (%jkr-judgment-status reference-env judgment))
            (jdefir (%implementation-judgment-status implementation env judgment)))
        (incf checked)
        (unless (eq jkr jdefir)
          (push (list :context (kernel-judgment-context judgment)
                      :term (kernel-judgment-term judgment)
                      :type (kernel-judgment-type judgment)
                      :j-kr jkr
                      :j-defir jdefir)
                failures))))
    (list :checked checked
          :parameters (list :max-depth max-depth
                            :max-context-size max-context-size
                            :carrier-mode carrier-mode)
          :failures (nreverse failures)
          :carrier-mode carrier-mode)))

(defun emit-jkr-defir-equivalence-fragment-certificate
    (&key (max-depth 1) (max-context-size 1) (carrier-mode :cross-product))
  (let* ((payload (%jkr-defir-equivalence-fragment-data
                   :max-depth max-depth
                   :max-context-size max-context-size
                   :carrier-mode carrier-mode))
         (certificate-payload
          (list :obligation-id :jdefir-jkr-equivalence
                :parameters (list :max-depth max-depth
                                  :max-context-size max-context-size
                                  :carrier-mode carrier-mode)
                :checked (getf payload :checked)
                :failures (getf payload :failures))))
    (make-theorem-fragment-certificate
     :obligation-id :jdefir-jkr-equivalence
     :parameters (list :max-depth max-depth
                       :max-context-size max-context-size
                       :carrier-mode carrier-mode)
     :checked (getf payload :checked)
     :payload-digest (artifact-digest certificate-payload)
     :status (if (getf payload :failures) :rejected :accepted)
     :config-digest *current-config-digest*)))

(defun verify-jkr-defir-equivalence-fragment-certificate (certificate)
  (unless (typep certificate 'theorem-fragment-certificate)
    (kernel-error "expected theorem fragment certificate, got ~S" certificate))
  (unless (eq (theorem-fragment-certificate-obligation-id certificate)
              :jdefir-jkr-equivalence)
    (kernel-error "wrong theorem fragment certificate obligation id: ~S"
                  (theorem-fragment-certificate-obligation-id certificate)))
  (unless (equal (theorem-fragment-certificate-config-digest certificate)
                 *current-config-digest*)
    (kernel-error "theorem fragment certificate config digest mismatch~%expected: ~S~%actual:   ~S"
                  *current-config-digest*
                  (theorem-fragment-certificate-config-digest certificate)))
  (let* ((parameters (theorem-fragment-certificate-parameters certificate))
         (payload (%jkr-defir-equivalence-fragment-data
                   :max-depth (getf parameters :max-depth 1)
                   :max-context-size (getf parameters :max-context-size 1)
                   :carrier-mode (getf parameters :carrier-mode :cross-product)))
         (expected-payload
          (list :obligation-id :jdefir-jkr-equivalence
                :parameters (list :max-depth (getf parameters :max-depth 1)
                                  :max-context-size (getf parameters :max-context-size 1)
                                  :carrier-mode (getf parameters :carrier-mode :cross-product))
                :checked (getf payload :checked)
                :failures (getf payload :failures)))
         (expected-digest (artifact-digest expected-payload))
         (expected-status (if (getf payload :failures) :rejected :accepted)))
    (unless (= (theorem-fragment-certificate-checked certificate)
               (getf payload :checked))
      (kernel-error "theorem fragment certificate checked-count mismatch~%expected: ~S~%actual:   ~S"
                    (getf payload :checked)
                    (theorem-fragment-certificate-checked certificate)))
    (unless (eql (theorem-fragment-certificate-payload-digest certificate)
                 expected-digest)
      (kernel-error "theorem fragment certificate payload digest mismatch~%expected: ~S~%actual:   ~S"
                    expected-digest
                    (theorem-fragment-certificate-payload-digest certificate)))
    (unless (eq (theorem-fragment-certificate-status certificate)
                expected-status)
      (kernel-error "theorem fragment certificate status mismatch~%expected: ~S~%actual:   ~S"
                    expected-status
                    (theorem-fragment-certificate-status certificate)))
    t))

(defun %jd-subject-reduction-fragment-data (&key (max-depth 0) (max-context-size 1))
  (let* ((env (make-bootstrap-env))
         (failures '())
         (checked 0)
         (instances '()))
    (dolist (gamma (%bounded-contexts max-context-size))
      (let ((terms (%subject-reduction-audit-terms max-depth (length gamma))))
        (dolist (term terms)
          (dolist (type terms)
            (when (%accepted-d-check-p env gamma term type)
              (dolist (term* (d-step-results env term))
                (incf checked)
                (push (list :gamma gamma
                            :term term
                            :type type
                            :reduct term*)
                      instances)
                (unless (%accepted-d-check-p env gamma term* type)
                  (push (list :gamma gamma
                              :term term
                              :type type
                              :reduct term*)
                        failures))))))))
    (list :checked checked
          :instances (nreverse instances)
          :failures (nreverse failures))))

(defun emit-jd-subject-reduction-fragment-certificate (&key (max-depth 0) (max-context-size 1))
  (let* ((payload (%jd-subject-reduction-fragment-data
                   :max-depth max-depth
                   :max-context-size max-context-size))
         (certificate-payload
           (list :obligation-id :jd-subject-reduction
                 :parameters (list :max-depth max-depth
                                   :max-context-size max-context-size)
                 :checked (getf payload :checked)
                 :instances (getf payload :instances)
                 :failures (getf payload :failures))))
    (make-theorem-fragment-certificate
     :obligation-id :jd-subject-reduction
     :parameters (list :max-depth max-depth
                       :max-context-size max-context-size)
     :checked (getf payload :checked)
     :payload-digest (artifact-digest certificate-payload)
     :status (if (getf payload :failures) :rejected :accepted)
     :config-digest *current-config-digest*)))

(defun verify-jd-subject-reduction-fragment-certificate (certificate)
  (unless (typep certificate 'theorem-fragment-certificate)
    (kernel-error "expected theorem fragment certificate, got ~S" certificate))
  (unless (eq (theorem-fragment-certificate-obligation-id certificate)
              :jd-subject-reduction)
    (kernel-error "wrong theorem fragment certificate obligation id: ~S"
                  (theorem-fragment-certificate-obligation-id certificate)))
  (unless (equal (theorem-fragment-certificate-config-digest certificate)
                 *current-config-digest*)
    (kernel-error "theorem fragment certificate config digest mismatch~%expected: ~S~%actual:   ~S"
                  *current-config-digest*
                  (theorem-fragment-certificate-config-digest certificate)))
  (let* ((parameters (theorem-fragment-certificate-parameters certificate))
         (payload (%jd-subject-reduction-fragment-data
                   :max-depth (getf parameters :max-depth 0)
                   :max-context-size (getf parameters :max-context-size 1)))
         (expected-payload
           (list :obligation-id :jd-subject-reduction
                 :parameters parameters
                 :checked (getf payload :checked)
                 :instances (getf payload :instances)
                 :failures (getf payload :failures)))
         (expected-digest (artifact-digest expected-payload))
         (expected-status (if (getf payload :failures) :rejected :accepted)))
    (unless (= (theorem-fragment-certificate-checked certificate)
               (getf payload :checked))
      (kernel-error "theorem fragment certificate checked-count mismatch~%expected: ~S~%actual:   ~S"
                    (getf payload :checked)
                    (theorem-fragment-certificate-checked certificate)))
    (unless (eql (theorem-fragment-certificate-payload-digest certificate)
                 expected-digest)
      (kernel-error "theorem fragment certificate payload digest mismatch~%expected: ~S~%actual:   ~S"
                    expected-digest
                    (theorem-fragment-certificate-payload-digest certificate)))
    (unless (eq (theorem-fragment-certificate-status certificate)
                expected-status)
      (kernel-error "theorem fragment certificate status mismatch~%expected: ~S~%actual:   ~S"
                    expected-status
                    (theorem-fragment-certificate-status certificate)))
    t))

(defun d-step-results (env term)
  (labels ((step-term (current)
             (let ((results '()))
               (case (term-tag current)
                 (:app
                  (let ((f (second current))
                        (a (third current)))
                    (when (eq (term-tag f) :lam)
                      (push (d-subst-top a (third f)) results))
                    (dolist (f* (step-term f))
                      (push (mk-app f* a) results))
                    (dolist (a* (step-term a))
                      (push (mk-app f a*) results))
                    (multiple-value-bind (head args)
                        (app-head+args current)
                      (when (eq (term-tag head) :const)
                        (let ((name (second head))
                              (levels (third head)))
                          (cond
                            ((eq name 'nat-rec)
                             (let ((reduced (d-reduce-nat-rec env levels args)))
                               (unless (equal reduced current)
                                 (push reduced results))))
                            ((eq name 'eq-rec)
                             (let ((reduced (d-reduce-eq-rec env levels args)))
                               (unless (equal reduced current)
                                 (push reduced results))))))))))
                 (:const
                  (let* ((name (second current))
                         (levels (third current))
                         (decl (env-lookup env name)))
                    (when (and decl
                               (eq (decl-kind decl) :def)
                               (decl-reduciblep decl))
                      (push (instantiate-levels (decl-value decl) levels) results))))
                 (:lam
                  (dolist (body* (step-term (third current)))
                    (push (mk-lam (second current) body*) results)))
                 (:pi
                  (dolist (domain* (step-term (second current)))
                    (push (mk-pi domain* (third current)) results))
                  (dolist (codomain* (step-term (third current)))
                    (push (mk-pi (second current) codomain*) results)))
                 (:let
                  (push (d-subst-top (second current) (fourth current)) results)
                  (dolist (value* (step-term (second current)))
                    (push (mk-let value* (third current) (fourth current)) results))
                  (dolist (type* (step-term (third current)))
                    (push (mk-let (second current) type* (fourth current)) results))
                  (dolist (body* (step-term (fourth current)))
                    (push (mk-let (second current) (third current) body*) results))))
               (%collect-unique-terms-equal results))))
    (step-term term)))

(defun %subject-reduction-seed-terms ()
  (list
   ;; beta
   (mk-app (mk-lam (mk-const 'nat) (mk-var 0))
           (mk-const 'zero))
   ;; zeta
   (mk-let (mk-const 'zero)
           (mk-const 'nat)
           (mk-var 0))
   ;; delta through reducible bootstrap definition
   (app* (mk-const 'add)
         (list (mk-const 'zero)
               (mk-const 'zero)))
   ;; iota for nat-rec on zero
   (app* (mk-const 'nat-rec)
         (list (mk-lam (mk-const 'nat) (mk-const 'nat))
               (mk-const 'zero)
               (mk-lam (mk-const 'nat)
                       (mk-lam (mk-const 'nat)
                               (mk-app (mk-const 'succ) (mk-var 0))))
               (mk-const 'zero)))
   ;; iota for eq-rec on refl
   (app* (mk-const 'eq-rec)
         (list (mk-const 'nat)
               (mk-const 'zero)
               (mk-lam (mk-const 'nat)
                       (mk-pi (app* (mk-const 'eq)
                                    (list (mk-const 'nat)
                                          (mk-const 'zero)
                                          (mk-var 0)))
                              (mk-sort 0)))
               (mk-const 'zero)
               (mk-const 'zero)
               (app* (mk-const 'refl)
                     (list (mk-const 'nat)
                           (mk-const 'zero)))))))

(defun %subject-reduction-audit-terms (max-depth binders)
  (%collect-unique-terms-equal
   (append (enumerate-bounded-core-terms :depth max-depth :binders binders)
           (when (zerop binders)
             (%subject-reduction-seed-terms)))))

(defun run-jd-substitution-audit (&key (max-depth 0) (max-context-size 1))
  (let* ((payload (%jd-substitution-fragment-data
                   :max-depth max-depth
                   :max-context-size max-context-size))
         (checked (getf payload :checked))
         (failures (getf payload :failures))
         (result (%theorem-audit-result :jd-substitution checked failures))
         (certificate (emit-jd-substitution-fragment-certificate
                       :max-depth max-depth
                       :max-context-size max-context-size)))
    (verify-jd-substitution-fragment-certificate certificate)
    (setf (getf (backend-result-artifacts result) :fragment-certificate) certificate)
    result))

(defun run-jd-weakening-audit (&key (max-depth 0) (max-context-size 1))
  (let* ((payload (%jd-weakening-fragment-data
                   :max-depth max-depth
                   :max-context-size max-context-size))
         (checked (getf payload :checked))
         (failures (getf payload :failures))
         (result (%theorem-audit-result :jd-weakening checked failures))
         (certificate (emit-jd-weakening-fragment-certificate
                       :max-depth max-depth
                       :max-context-size max-context-size)))
    (verify-jd-weakening-fragment-certificate certificate)
    (setf (getf (backend-result-artifacts result) :fragment-certificate) certificate)
    result))

(defun run-jd-subject-reduction-audit (&key (max-depth 0) (max-context-size 1))
  (let* ((payload (%jd-subject-reduction-fragment-data
                   :max-depth max-depth
                   :max-context-size max-context-size))
         (checked (getf payload :checked))
         (failures (getf payload :failures))
         (result (%theorem-audit-result :jd-subject-reduction checked failures))
         (certificate (emit-jd-subject-reduction-fragment-certificate
                       :max-depth max-depth
                       :max-context-size max-context-size)))
    (verify-jd-subject-reduction-fragment-certificate certificate)
    (setf (getf (backend-result-artifacts result) :fragment-certificate) certificate)
    result))

(defun run-jd-jkr-equivalence-audit (&key (max-depth 1) (max-context-size 1)
                                           (carrier-mode :cross-product))
  (let* ((env (make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (judgments (%judgment-audit-cases max-depth max-context-size
                                           :carrier-mode carrier-mode))
         (failures '())
         (checked 0))
    (dolist (judgment judgments)
      (let ((jd (%jd-judgment-status env judgment))
            (jkr (%jkr-judgment-status reference-env judgment)))
        (incf checked)
        (when (and (eq jkr :accepted)
                   (not (eq jd :accepted)))
          (push (list :context (kernel-judgment-context judgment)
                      :term (kernel-judgment-term judgment)
                      :type (kernel-judgment-type judgment)
                      :j-d jd
                      :j-kr jkr)
                failures))))
    (let* ((result (%theorem-audit-result :jkr-soundness checked failures))
           (certificate (emit-jd-jkr-soundness-fragment-certificate
                         :max-depth max-depth
                         :max-context-size max-context-size
                         :carrier-mode carrier-mode)))
      (verify-jd-jkr-soundness-fragment-certificate certificate)
      (setf (getf (backend-result-artifacts result) :fragment-certificate) certificate)
      result)))

(defun run-jd-jkr-completeness-audit (&key (max-depth 1) (max-context-size 1)
                                             (carrier-mode :cross-product))
  (let* ((env (make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (judgments (%judgment-audit-cases max-depth max-context-size
                                           :carrier-mode carrier-mode))
         (failures '())
         (checked 0))
    (dolist (judgment judgments)
      (let ((jd (%jd-judgment-status env judgment))
            (jkr (%jkr-judgment-status reference-env judgment)))
        (incf checked)
        (when (and (eq jd :accepted)
                   (not (eq jkr :accepted)))
          (push (list :context (kernel-judgment-context judgment)
                      :term (kernel-judgment-term judgment)
                      :type (kernel-judgment-type judgment)
                      :j-d jd
                      :j-kr jkr)
                failures))))
    (let* ((result (%theorem-audit-result :jkr-fragment-completeness checked failures))
           (certificate (emit-jd-jkr-completeness-fragment-certificate
                         :max-depth max-depth
                         :max-context-size max-context-size
                         :carrier-mode carrier-mode)))
      (verify-jd-jkr-fragment-completeness-fragment-certificate certificate)
      (setf (getf (backend-result-artifacts result) :fragment-certificate) certificate)
      result)))

(defun run-jkr-jkl-equivalence-audit (&key (max-depth 1) (max-context-size 1)
                                             (carrier-mode :cross-product))
  (let* ((env (make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (judgments (%judgment-audit-cases max-depth max-context-size
                                           :carrier-mode carrier-mode))
         (failures '())
         (checked 0))
    (dolist (judgment judgments)
      (let ((jkr (%jkr-judgment-status reference-env judgment))
            (jkl (%jkl-judgment-status env judgment)))
        (incf checked)
        (unless (eq jkr jkl)
          (push (list :context (kernel-judgment-context judgment)
                      :term (kernel-judgment-term judgment)
                      :type (kernel-judgment-type judgment)
                      :j-kr jkr
                      :j-kl jkl)
                failures))))
    (let* ((result (%theorem-audit-result :jkl-jkr-equivalence checked failures))
           (certificate (emit-jkr-jkl-equivalence-fragment-certificate
                         :max-depth max-depth
                         :max-context-size max-context-size
                         :carrier-mode carrier-mode)))
      (verify-jkr-jkl-equivalence-fragment-certificate certificate)
      (setf (getf (backend-result-artifacts result) :fragment-certificate) certificate)
      result)))

(defun run-jkr-defir-equivalence-obligation-audit (&key (max-depth 1) (max-context-size 1)
                                                        (carrier-mode :cross-product))
  (let* ((result (run-jkr-defir-equivalence-audit
                  :max-depth max-depth
                  :max-context-size max-context-size
                  :carrier-mode carrier-mode))
         (checked (getf (backend-result-artifacts result) :checked))
         (failures (getf (backend-result-artifacts result) :failures))
         (obligation (find-theorem-obligation :jdefir-jkr-equivalence))
         (witness (make-jdefir-jkr-equivalence-witness-bundle
                   :max-depth max-depth
                   :max-context-size max-context-size
                   :carrier-mode carrier-mode))
         (certificate (emit-jkr-defir-equivalence-fragment-certificate
                       :max-depth max-depth
                       :max-context-size max-context-size
                       :carrier-mode carrier-mode)))
    (verify-theorem-witness-bundle witness)
    (verify-jkr-defir-equivalence-fragment-certificate certificate)
    (setf (getf (backend-result-artifacts result) :obligation-id) :jdefir-jkr-equivalence)
    (setf (getf (backend-result-artifacts result) :witness)
          (make-theorem-witness
           :obligation-id :jdefir-jkr-equivalence
           :lane (theorem-obligation-lane obligation)
           :relation (theorem-obligation-relation obligation)
           :checked checked
           :payload (if failures nil '(:status :no-counterexample-found))))
    (setf (getf (backend-result-artifacts result) :witness-bundle) witness)
    (setf (getf (backend-result-artifacts result) :fragment-certificate) certificate)
    result))

(defun run-stage1-jr-jl-equivalence-audit (&key
                                             (path *stage1-concept-source-path*)
                                             (limit 8)
                                             &allow-other-keys)
  (let* ((reference (stage1-reference-property-certificates :path path :limit limit))
         (implementation (stage1-property-certificates :path path :limit limit))
         (failures '())
         (checked 0))
    (unless (= (length reference) (length implementation))
      (push (list :certificate-count
                  :reference (length reference)
                  :implementation (length implementation))
            failures))
    (loop for jr in reference
          for jl in implementation
          for index from 0
          do (incf checked)
             (unless (%stage1-property-certificate= jr jl)
               (push (list :index index
                           :reference jr
                           :implementation jl)
                     failures)))
    (%theorem-audit-result :stage1-jl-jr-equivalence checked failures)))

(defun run-stage1-jr-soundness-audit (&key
                                        (path *stage1-concept-source-path*)
                                        (limit 8)
                                        &allow-other-keys)
  (let* ((program (ingest-stage1-concept-file path))
         (reference (stage1-reference-property-certificates :path path :limit limit))
         (failures '())
         (checked 0))
    (dolist (certificate reference)
      (incf checked)
      (when (and (eq (stage1-property-certificate-status certificate) :accepted)
                 (not (stage1-d-claim program
                                      (stage1-property-certificate-claim certificate))))
        (push (list :certificate certificate) failures)))
    (%theorem-audit-result :stage1-jr-soundness checked failures)))

(defun run-smt-normalization-bridge-audit (&optional (formulas (bounded-smt-audit-formulas)))
  (let ((failures '())
        (checked 0))
    (dolist (formula formulas)
      (incf checked)
      (unless (j-smt-normalization-bridge formula)
        (push (list :formula formula
                    :normalized (normalize-smt-term formula)
                    :side-condition (normalization-side-condition formula))
              failures)))
    (%theorem-audit-result :smt-bridge-normalization checked failures)))

(defun %smt-obligation-sample-formulas (obligation-id)
  (ecase obligation-id
    (:smt-bridge-normalization
     (bounded-smt-audit-formulas))
    (:smt-bridge-boolean-unsat
     (list '(:and (:bool t) (:bool nil))
           '(:and (:not (:bool t)) (:bool t))))
    (:smt-bridge-bitvector-unsat
     (list '(:and (:= (:bv-lit 2 1) (:bv-lit 2 2))
                  (:bool t))
           '(:and (:= (:bv-lit 4 3) (:bv-lit 4 7))
                  (:= (:bv-lit 1 0) (:bv-lit 1 0)))))
    (:smt-bridge-int-unsat
     (list '(:and (:= (:int-lit 1) (:int-lit 1))
                  (:int-lt (:int-lit 2) (:int-lit 1)))
           '(:and (:int-le (:int-lit 0) (:int-lit 0))
                  (:int-lt (:int-lit 1) (:int-lit 0)))))
    (:smt-bridge-affine-int-contradiction
     (list '(:and (:int-ge (:var x (:Int)) (:int-lit 0))
                  (:int-lt (:var x (:Int)) (:int-lit 0)))
           '(:and (:= (:var y (:Int)) (:int-lit 3))
                  (:int-gt (:var y (:Int)) (:int-lit 3)))))))

(defun run-smt-obligation-bridge-audit (obligation-id
                                        &optional
                                          (formulas (%smt-obligation-sample-formulas obligation-id)))
  (let* ((binding (find-theorem-bridge-binding obligation-id))
         (admitted-class (and binding
                              (find-admitted-obligation-class
                               (theorem-bridge-binding-admitted-obligation-id binding))))
        (failures '())
        (checked 0))
    (unless binding
      (return-from run-smt-obligation-bridge-audit
        (%theorem-audit-result obligation-id 0
                               (list (list :missing-theorem-bridge-binding obligation-id)))))
    (unless admitted-class
      (return-from run-smt-obligation-bridge-audit
        (%theorem-audit-result obligation-id 0
                               (list (list :missing-admitted-obligation
                                           (theorem-bridge-binding-admitted-obligation-id binding))))))
    (dolist (formula formulas)
      (incf checked)
      (unless (j-smt-admitted-obligation-bridge
               (theorem-bridge-binding-admitted-obligation-id binding)
               formula)
        (push (list :formula formula
                    :theorem-obligation-id obligation-id
                    :admitted-obligation-id
                    (theorem-bridge-binding-admitted-obligation-id binding)
                    :projected (project-admitted-obligation
                                (theorem-bridge-binding-admitted-obligation-id binding)
                                formula)
                    :side-condition
                    (admitted-obligation-side-condition
                     (theorem-bridge-binding-admitted-obligation-id binding)
                     formula))
              failures)))
    (%theorem-audit-result obligation-id checked failures)))

(defun run-smt-boolean-unsat-bridge-audit
    (&optional (formulas (%smt-obligation-sample-formulas :smt-bridge-boolean-unsat)))
  (run-smt-obligation-bridge-audit :smt-bridge-boolean-unsat formulas))

(defun run-smt-bitvector-unsat-bridge-audit
    (&optional (formulas (%smt-obligation-sample-formulas :smt-bridge-bitvector-unsat)))
  (run-smt-obligation-bridge-audit :smt-bridge-bitvector-unsat formulas))

(defun run-smt-int-unsat-bridge-audit
    (&optional (formulas (%smt-obligation-sample-formulas :smt-bridge-int-unsat)))
  (run-smt-obligation-bridge-audit :smt-bridge-int-unsat formulas))

(defun run-smt-affine-int-contradiction-bridge-audit
    (&optional (formulas (%smt-obligation-sample-formulas :smt-bridge-affine-int-contradiction)))
  (run-smt-obligation-bridge-audit :smt-bridge-affine-int-contradiction formulas))

(defun run-smt-obligation-catalog-audit ()
  (let ((expected-obligation-ids '(:smt-bridge-normalization
                                   :smt-bridge-boolean-unsat
                                   :smt-bridge-bitvector-unsat
                                   :smt-bridge-int-unsat
                                   :smt-bridge-affine-int-contradiction))
        (expected-class-ids '(:normalization-equivalence
                              :closed-boolean-unsat
                              :closed-bitvector-unsat
                              :closed-int-unsat
                              :affine-int-contradiction))
        (expected-admitted-ids '(:o-normalization-equivalence
                                 :o-closed-boolean-unsat
                                 :o-closed-bitvector-unsat
                                 :o-closed-int-unsat
                                 :o-affine-int-contradiction))
        (expected-bindings '(:smt-bridge-normalization
                             :smt-bridge-boolean-unsat
                             :smt-bridge-bitvector-unsat
                             :smt-bridge-int-unsat
                             :smt-bridge-affine-int-contradiction))
        (failures '())
        (checked 0))
    (dolist (obligation-id expected-obligation-ids)
      (incf checked)
      (unless (find-theorem-obligation obligation-id)
        (push (list :missing-theorem-obligation obligation-id) failures)))
    (dolist (class-id expected-class-ids)
      (incf checked)
      (unless (find-smt-obligation-class class-id)
        (push (list :missing-smt-class class-id) failures)))
    (dolist (admitted-id expected-admitted-ids)
      (incf checked)
      (let* ((admitted (find-admitted-obligation-class admitted-id))
             (class (and admitted
                         (find-smt-obligation-class
                          (admitted-obligation-class-smt-obligation-class-id admitted)))))
        (unless admitted
          (push (list :missing-admitted-class admitted-id) failures))
        (when admitted
          (unless class
            (push (list :dangling-admitted-class admitted-id
                        (admitted-obligation-class-smt-obligation-class-id admitted))
                  failures))
          (unless (eq (admitted-obligation-class-result-polarity admitted)
                      (smt-obligation-class-polarity class))
            (push (list :admitted-polarity-mismatch admitted-id) failures))
          (unless (eq (admitted-obligation-class-side-predicate admitted)
                      (smt-obligation-class-side-condition class))
            (push (list :admitted-side-predicate-mismatch admitted-id) failures))
          (unless (eq (admitted-obligation-class-projector admitted)
                      (smt-obligation-class-projector class))
            (push (list :admitted-projector-mismatch admitted-id) failures)))))
    (dolist (binding-id expected-bindings)
      (incf checked)
      (let* ((binding (find-theorem-bridge-binding binding-id))
             (admitted (and binding
                            (find-admitted-obligation-class
                             (theorem-bridge-binding-admitted-obligation-id binding)))))
        (unless binding
          (push (list :missing-theorem-bridge-binding binding-id) failures))
        (when binding
          (unless admitted
            (push (list :dangling-theorem-bridge-binding binding-id
                        (theorem-bridge-binding-admitted-obligation-id binding))
                  failures))
          (when admitted
            (unless (eq (theorem-bridge-binding-result-polarity binding)
                        (admitted-obligation-class-result-polarity admitted))
              (push (list :theorem-bridge-polarity-mismatch binding-id) failures))))))
    (incf checked)
    (unless (= (length *smt-obligation-classes*) (length expected-class-ids))
      (push (list :unexpected-catalog-size
                  :expected (length expected-class-ids)
                  :actual (length *smt-obligation-classes*))
            failures))
    (incf checked)
    (unless (= (length *admitted-obligation-classes*) (length expected-admitted-ids))
      (push (list :unexpected-admitted-catalog-size
                  :expected (length expected-admitted-ids)
                  :actual (length *admitted-obligation-classes*))
            failures))
    (incf checked)
    (unless (= (length *theorem-bridge-bindings*) (length expected-bindings))
      (push (list :unexpected-theorem-bridge-binding-size
                  :expected (length expected-bindings)
                  :actual (length *theorem-bridge-bindings*))
            failures))
    (%theorem-audit-result :smt-obligation-catalog checked failures)))

(defparameter *theorem-audit-runners*
  (list
   (cons :jd-substitution #'run-jd-substitution-audit)
   (cons :jd-weakening #'run-jd-weakening-audit)
   (cons :jd-subject-reduction #'run-jd-subject-reduction-audit)
   (cons :jkr-soundness #'run-jd-jkr-equivalence-audit)
   (cons :jkr-fragment-completeness #'run-jd-jkr-completeness-audit)
   (cons :jkl-jkr-equivalence #'run-jkr-jkl-equivalence-audit)
   (cons :jdefir-jkr-equivalence #'run-jkr-defir-equivalence-obligation-audit)
   (cons :stage1-jl-jr-equivalence #'run-stage1-jr-jl-equivalence-audit)
   (cons :stage1-jr-soundness #'run-stage1-jr-soundness-audit)
   (cons :smt-bridge-normalization #'run-smt-normalization-bridge-audit)
   (cons :smt-bridge-boolean-unsat #'run-smt-boolean-unsat-bridge-audit)
   (cons :smt-bridge-bitvector-unsat #'run-smt-bitvector-unsat-bridge-audit)
   (cons :smt-bridge-int-unsat #'run-smt-int-unsat-bridge-audit)
   (cons :smt-bridge-affine-int-contradiction #'run-smt-affine-int-contradiction-bridge-audit)
   (cons :smt-obligation-catalog #'run-smt-obligation-catalog-audit)))

(defparameter *metakernel-closure-profiles*
  '((:quick
     (:jd-substitution :max-depth 0 :max-context-size 1)
     (:jd-weakening :max-depth 0 :max-context-size 1)
     (:jd-subject-reduction :max-depth 0 :max-context-size 1)
     (:jkr-soundness :max-depth 0 :max-context-size 1)
     (:jkr-fragment-completeness :max-depth 0 :max-context-size 1)
     (:jkl-jkr-equivalence :max-depth 0 :max-context-size 1)
     (:jdefir-jkr-equivalence :max-depth 0 :max-context-size 1)
     (:stage1-jl-jr-equivalence)
     (:stage1-jr-soundness)
     (:smt-bridge-normalization)
     (:smt-bridge-boolean-unsat)
     (:smt-bridge-bitvector-unsat)
     (:smt-bridge-int-unsat)
     (:smt-bridge-affine-int-contradiction)
     (:smt-obligation-catalog))
    (:strengthened
     (:jd-substitution :max-depth 0 :max-context-size 1)
     (:jd-weakening :max-depth 0 :max-context-size 1)
     (:jd-subject-reduction :max-depth 0 :max-context-size 1)
     (:jkr-soundness :max-depth 1 :max-context-size 1)
     (:jkr-fragment-completeness :max-depth 0 :max-context-size 1)
     (:jkl-jkr-equivalence :max-depth 0 :max-context-size 1)
     (:jdefir-jkr-equivalence :max-depth 0 :max-context-size 1)
     (:stage1-jl-jr-equivalence)
     (:stage1-jr-soundness)
     (:smt-bridge-normalization)
     (:smt-bridge-boolean-unsat)
     (:smt-bridge-bitvector-unsat)
     (:smt-bridge-int-unsat)
     (:smt-bridge-affine-int-contradiction)
     (:smt-obligation-catalog))
    (:relational-strengthened
     (:jd-substitution :max-depth 0 :max-context-size 1)
     (:jd-weakening :max-depth 0 :max-context-size 1)
     (:jd-subject-reduction :max-depth 0 :max-context-size 1)
     (:jkr-soundness :max-depth 1 :max-context-size 1 :carrier-mode :dense)
     (:jkr-fragment-completeness :max-depth 1 :max-context-size 1 :carrier-mode :dense)
     (:jkl-jkr-equivalence :max-depth 1 :max-context-size 1 :carrier-mode :dense)
     (:jdefir-jkr-equivalence :max-depth 1 :max-context-size 1 :carrier-mode :dense)
     (:stage1-jl-jr-equivalence)
     (:stage1-jr-soundness)
     (:smt-bridge-normalization)
     (:smt-bridge-boolean-unsat)
     (:smt-bridge-bitvector-unsat)
     (:smt-bridge-int-unsat)
     (:smt-bridge-affine-int-contradiction)
     (:smt-obligation-catalog))))

(defun find-theorem-audit-runner (obligation-id)
  (cdr (assoc obligation-id *theorem-audit-runners* :test #'eq)))

(defun find-metakernel-closure-profile (profile-id)
  (cdr (assoc profile-id *metakernel-closure-profiles* :test #'eq)))

(defun run-theorem-obligation-audit (obligation-id &rest args)
  (let ((runner (find-theorem-audit-runner obligation-id)))
    (unless runner
      (kernel-error "no theorem audit runner registered for obligation id: ~S"
                    obligation-id))
    (apply runner args)))

(defun %profile-entry-args (entry)
  (rest entry))

(defun %relation-family-obligation-p (obligation-id)
  (member obligation-id '(:jkr-soundness
                          :jkr-fragment-completeness
                          :jkl-jkr-equivalence
                          :jdefir-jkr-equivalence)
          :test #'eq))

(defun %smt-bridge-obligation-p (obligation-id)
  (member obligation-id '(:smt-bridge-normalization
                          :smt-bridge-boolean-unsat
                          :smt-bridge-bitvector-unsat
                          :smt-bridge-int-unsat
                          :smt-bridge-affine-int-contradiction)
          :test #'eq))

(defun %smt-catalog-obligation-p (obligation-id)
  (eq obligation-id :smt-obligation-catalog))

(defun %same-profile-entry-args-p (entries)
  (or (null entries)
      (let ((baseline (%profile-entry-args (first entries))))
        (every (lambda (entry)
                 (equal baseline (%profile-entry-args entry)))
               (rest entries)))))

(defun run-kernel-relation-family-audits (&key (max-depth 1) (max-context-size 1)
                                              (carrier-mode :cross-product))
  (let* ((env (make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (implementation (make-defir-kernel-implementation))
         (judgments (%judgment-audit-cases max-depth max-context-size
                                           :carrier-mode carrier-mode))
         (soundness-failures '())
         (completeness-failures '())
         (equivalence-failures '())
         (defir-equivalence-failures '())
         (checked 0))
    (dolist (judgment judgments)
      (let ((ctx (kernel-judgment-context judgment))
            (term (kernel-judgment-term judgment))
            (type (kernel-judgment-type judgment))
            (jd (%jd-judgment-status env judgment))
            (jkr (%jkr-judgment-status reference-env judgment))
            (jkl (%jkl-judgment-status env judgment))
            (jdefir (%implementation-judgment-status implementation env judgment)))
        (incf checked)
        (when (and (eq jkr :accepted)
                   (not (eq jd :accepted)))
          (push (list :context ctx :term term :type type :j-d jd :j-kr jkr)
                soundness-failures))
        (when (and (eq jd :accepted)
                   (not (eq jkr :accepted)))
          (push (list :context ctx :term term :type type :j-d jd :j-kr jkr)
                completeness-failures))
        (unless (eq jkr jkl)
          (push (list :context ctx :term term :type type :j-kr jkr :j-kl jkl)
                equivalence-failures))
        (unless (eq jkr jdefir)
          (push (list :context ctx :term term :type type :j-kr jkr :j-defir jdefir)
                defir-equivalence-failures))))
    (list (%theorem-audit-result :jkr-soundness checked soundness-failures)
          (%theorem-audit-result :jkr-fragment-completeness checked completeness-failures)
          (%theorem-audit-result :jkl-jkr-equivalence checked equivalence-failures)
          (%theorem-audit-result :jdefir-jkr-equivalence checked defir-equivalence-failures))))

(defun evaluate-metakernel-closure
    (&key (obligation-ids (mapcar #'theorem-obligation-id *metakernel-obligations*))
          (max-depth 1)
          (max-context-size 1)
          (smt-formulas (bounded-smt-audit-formulas)))
  (let ((results '())
        (failures '()))
    (dolist (obligation-id obligation-ids)
      (let ((result
              (case obligation-id
                (:smt-bridge-normalization
                 (run-theorem-obligation-audit obligation-id smt-formulas))
                ((:smt-bridge-boolean-unsat
                  :smt-bridge-bitvector-unsat
                  :smt-bridge-int-unsat
                  :smt-bridge-affine-int-contradiction
                  :smt-obligation-catalog)
                 (run-theorem-obligation-audit obligation-id))
                (otherwise
                 (run-theorem-obligation-audit obligation-id
                                              :max-depth max-depth
                                              :max-context-size max-context-size)))))
        (push result results)
        (unless (eq (backend-result-status result) :accepted)
          (push (list :obligation-id obligation-id
                      :status (backend-result-status result)
                      :artifacts (backend-result-artifacts result))
                failures))))
    (make-backend-result
     :backend-id 'audit-check
     :status (if failures :rejected :accepted)
     :evidence '(:metakernel-closure)
     :artifacts (list :obligation-ids obligation-ids
                      :results (nreverse results)
                      :failures (nreverse failures)))))

(defun summarize-metakernel-closure-results (results)
  (let ((accepted 0)
        (rejected 0)
        (checked-total 0))
    (dolist (result results)
      (case (backend-result-status result)
        (:accepted
         (incf accepted))
        (:rejected
         (incf rejected)))
      (incf checked-total (or (getf (backend-result-artifacts result) :checked) 0)))
    (list :accepted accepted
          :rejected rejected
          :checked-total checked-total)))

(defun evaluate-metakernel-closure-profile (profile-id
                                            &key (smt-formulas (bounded-smt-audit-formulas)))
  (let ((profile (find-metakernel-closure-profile profile-id)))
    (unless profile
      (kernel-error "unknown metakernel closure profile: ~S" profile-id))
    (let ((results '())
          (failures '()))
      (let* ((relation-entries
               (remove-if-not (lambda (entry)
                                (%relation-family-obligation-p (first entry)))
                              profile))
             (shared-relation-results
               (when (and relation-entries
                          (%same-profile-entry-args-p relation-entries))
                 (apply #'run-kernel-relation-family-audits
                        (%profile-entry-args (first relation-entries))))))
        (dolist (entry profile)
          (destructuring-bind (obligation-id &rest args) entry
            (let ((result
                    (cond
                      ((and shared-relation-results
                            (%relation-family-obligation-p obligation-id))
                       (find obligation-id shared-relation-results
                             :key (lambda (candidate)
                                    (getf (backend-result-artifacts candidate) :obligation-id))
                             :test #'eq))
                      ((eq obligation-id :smt-bridge-normalization)
                       (apply #'run-theorem-obligation-audit obligation-id smt-formulas args))
                      ((or (%smt-bridge-obligation-p obligation-id)
                           (%smt-catalog-obligation-p obligation-id))
                       (apply #'run-theorem-obligation-audit obligation-id args))
                      (t
                       (apply #'run-theorem-obligation-audit obligation-id args)))))
              (push result results)
              (unless (eq (backend-result-status result) :accepted)
                (push (list :obligation-id obligation-id
                            :status (backend-result-status result)
                            :artifacts (backend-result-artifacts result))
                      failures))))))
      (let ((ordered-results (nreverse results)))
        (make-backend-result
         :backend-id 'audit-check
         :status (if failures :rejected :accepted)
         :evidence (list :metakernel-closure-profile profile-id)
         :artifacts (list :profile-id profile-id
                          :profile profile
                          :summary (summarize-metakernel-closure-results ordered-results)
                          :results ordered-results
                          :failures (nreverse failures)))))))

(defun run-kr-kl-disagreement-audit (&key (max-depth 1) (max-context-size 1))
  (let* ((env (make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (contexts (loop for n from 0 to max-context-size
                         collect (loop repeat n collect (mk-const 'nat))))
         (failures '())
         (checked 0))
    (dolist (ctx contexts)
      (let ((binders (length ctx)))
        (dolist (term (enumerate-bounded-core-terms :depth max-depth :binders binders))
          (dolist (type (enumerate-bounded-core-terms :depth max-depth :binders binders))
            (let* ((certificate (make-typing-certificate
                                 ctx term type :bootstrap-v1
                                 :checker-ids '(audit)
                                 :metadata (list :audit :kr-kl)))
                   (kl (%kl-certificate-status env certificate))
                   (kr (%kr-certificate-status reference-env certificate)))
              (incf checked)
              (unless (eq kl kr)
                (push (list :context ctx :term term :type type :kl kl :kr kr)
                      failures)))))))
    (make-backend-result
     :backend-id 'audit-check
     :status (if failures :rejected :accepted)
     :evidence '(:kr-kl-agreement-audit)
     :artifacts (list :checked checked :failures (nreverse failures)))))

(defun run-kr-defir-disagreement-audit (&key (max-depth 1) (max-context-size 1))
  (let* ((env (make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (implementation (make-defir-kernel-implementation))
         (contexts (loop for n from 0 to max-context-size
                         collect (loop repeat n collect (mk-const 'nat))))
         (failures '())
         (checked 0))
    (dolist (ctx contexts)
      (let ((binders (length ctx)))
        (dolist (term (enumerate-bounded-core-terms :depth max-depth :binders binders))
          (dolist (type (enumerate-bounded-core-terms :depth max-depth :binders binders))
            (let* ((certificate (make-typing-certificate
                                 ctx term type :bootstrap-v1
                                 :checker-ids '(audit)
                                 :metadata (list :audit :kr-defir)))
                   (defir (%implementation-certificate-status
                           implementation env certificate))
                   (kr (%kr-certificate-status reference-env certificate)))
              (incf checked)
              (unless (eq defir kr)
                (push (list :context ctx
                            :term term
                            :type type
                            :kr kr
                            :defir defir)
                      failures)))))))
    (make-backend-result
     :backend-id 'audit-check
     :status (if failures :rejected :accepted)
     :evidence '(:kr-defir-agreement-audit)
     :artifacts (list :checked checked :failures (nreverse failures)))))

(defun run-jkr-defir-equivalence-audit (&key (max-depth 1) (max-context-size 1)
                                             (carrier-mode :cross-product))
  (let* ((env (make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (implementation (make-defir-kernel-implementation))
         (judgments (%judgment-audit-cases max-depth max-context-size
                                           :carrier-mode carrier-mode))
         (failures '())
         (checked 0))
    (dolist (judgment judgments)
      (let ((jkr (%jkr-judgment-status reference-env judgment))
            (defir (%implementation-judgment-status implementation env judgment)))
        (incf checked)
        (unless (eq jkr defir)
          (push (list :judgment judgment
                      :j-kr jkr
                      :j-defir defir)
                failures))))
    (make-backend-result
     :backend-id 'audit-check
     :status (if failures :rejected :accepted)
     :evidence '(:jkr-defir-equivalence-audit)
     :artifacts (list :checked checked
                      :carrier-mode carrier-mode
                      :failures (nreverse failures)))))

(defun run-whnf-agreement-audit (&key (max-depth 2) (max-binders 2))
  (let* ((env (make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (failures '())
         (checked 0))
    (loop for binders from 0 to max-binders do
      (dolist (term (enumerate-bounded-core-terms :depth max-depth :binders binders))
        (let ((kl (whnf env term))
              (kr (mini-kernel-reference::r-whnf reference-env term)))
          (incf checked)
          (unless (equal kl kr)
            (push (list :binders binders :term term :kl kl :kr kr) failures)))))
    (make-backend-result
     :backend-id 'audit-check
     :status (if failures :rejected :accepted)
     :evidence '(:whnf-agreement-audit)
     :artifacts (list :checked checked :failures (nreverse failures)))))
