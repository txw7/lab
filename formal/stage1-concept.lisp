(in-package :mini-kernel)

(defparameter *stage1-concept-source-path*
  "/home/user0/MIR/pure_asm_and_or_write/xlisp0-orbit-stage1-hll-concept.lisp")

(defstruct stage1-compiler-form
  name
  compiler-name
  accepted-source-family
  helper-set
  successor-form
  emit-again
  authority)

(defstruct stage1-compiler-instance
  name
  accepted-source-family
  helper-set
  descriptor
  authority
  lineage
  committed-p)

(defstruct stage1-control
  mode
  phase
  active-compiler
  next-compiler
  next-form
  emit-again
  authority
  lineage
  committed-p)

(defstruct stage1-fragment
  lineage
  compiler
  control
  authority
  committed-p)

(defstruct stage1-promotion
  lineage
  compiler
  descriptor
  next-compiler
  next-form
  emit-again
  authority)

(defstruct stage1-scenario
  name
  root
  source)

(defstruct stage1-runtime
  root
  control
  source
  promotions
  trace
  next-lineage
  scenarios)

(defstruct stage1-program
  source-path
  forms
  scenarios
  helper-set)

(defstruct stage1-property-certificate
  property-id
  scenario
  claim
  status
  evidence
  payload
  payload-digest)

(defstruct stage1-claim
  property-id
  scenario
  status
  witness-kind
  subject
  facts)

(defstruct stage1-concept-bundle
  source-path
  source-digest
  program-digest
  checker-lane
  property-certificates
  agreement-certificates)

(define-condition stage1-concept-error (error)
  ((message :initarg :message :reader stage1-concept-error-message))
  (:report (lambda (condition stream)
             (princ (stage1-concept-error-message condition) stream))))

(defun stage1-concept-error (format-string &rest args)
  (error 'stage1-concept-error :message (apply #'format nil format-string args)))

(defun %stage1-symbol= (symbol expected-name)
  (and (symbolp symbol)
       (string= (symbol-name symbol) expected-name)))

(defun %read-lisp-file-forms (path)
  (with-open-file (stream path :direction :input)
    (let ((forms '()))
      (loop for form = (read stream nil :eof)
            until (eq form :eof)
            do (push form forms))
      (nreverse forms))))

(defun %find-top-level-form (forms head-name &optional second-name)
  (find-if (lambda (form)
             (and (consp form)
                  (%stage1-symbol= (first form) head-name)
                  (or (null second-name)
                      (%stage1-symbol= (second form) second-name))))
           forms))

(defun %required-top-level-form (forms head-name &optional second-name)
  (or (%find-top-level-form forms head-name second-name)
      (stage1-concept-error "missing required top-level form ~A ~A"
                            head-name
                            (or second-name ""))))

(defun %stage1-alist-lookup (env symbol)
  (let ((entry (assoc symbol env :test #'eq)))
    (if entry
        (cdr entry)
        (stage1-concept-error "unbound stage1 ingestion variable: ~S" symbol))))

(defun %eval-stage1-constructor (form env)
  (labels
      ((eval-expr (expr)
         (cond
           ((or (eq expr t)
                (null expr)
                (stringp expr)
                (keywordp expr)
                (integerp expr))
            expr)
           ((symbolp expr)
            (%stage1-alist-lookup env expr))
           ((and (consp expr) (%stage1-symbol= (first expr) "QUOTE"))
            (second expr))
           ((and (consp expr) (%stage1-symbol= (first expr) "LIST"))
            (mapcar #'eval-expr (rest expr)))
           ((and (consp expr) (%stage1-symbol= (first expr) "MAKE-COMPILER-FORM"))
            (apply #'make-stage1-compiler-form
                   (loop for (key value) on (rest expr) by #'cddr
                         append (list key (eval-expr value)))))
           ((and (consp expr) (%stage1-symbol= (first expr) "MAKE-COMPILER-INSTANCE"))
            (apply #'make-stage1-compiler-instance
                   (loop for (key value) on (rest expr) by #'cddr
                         append (list key (eval-expr value)))))
           ((and (consp expr) (%stage1-symbol= (first expr) "MAKE-RUNTIME"))
            (apply #'make-stage1-runtime
                   (loop for (key value) on (rest expr) by #'cddr
                         append (list key (eval-expr value)))))
           (t
            (stage1-concept-error "unsupported ingestion expression: ~S" expr)))))
    (eval-expr form)))

(defun %eval-stage1-let* (form)
  (unless (and (consp form) (%stage1-symbol= (first form) "LET*"))
    (stage1-concept-error "make-concept-runtime must use LET*: ~S" form))
  (let ((env '()))
    (dolist (binding (second form))
      (destructuring-bind (name value-form) binding
        (push (cons name (%eval-stage1-constructor value-form env)) env)))
    (%eval-stage1-constructor (third form) env)))

(defun %validate-stage1-source-forms (forms)
  (let ((package-form (%required-top-level-form forms "DEFPACKAGE"))
        (in-package-form (%required-top-level-form forms "IN-PACKAGE"))
        (required-structs '("COMPILER-FORM"
                            "COMPILER-INSTANCE"
                            "CONTROL"
                            "FRAGMENT"
                            "PROMOTION"
                            "RUNTIME"))
        (required-defuns '("MAKE-CONCEPT-RUNTIME"
                           "BOOT-SCENARIO"
                           "SELECT-INTENT"
                           "EMIT-FRAGMENT"
                           "COMMIT-FRAGMENT"
                           "STEP-RUNTIME"
                           "RUN-SCENARIO"
                           "PROMOTION-SUMMARIES"
                           "METACIRCULAR-SUMMARIES")))
    (unless (and (second package-form)
                 (%stage1-symbol= (second package-form)
                                  "XLISP0-ORBIT-STAGE1-HLL-CONCEPT"))
      (stage1-concept-error "unexpected conceptual package form: ~S" package-form))
    (unless (and (second in-package-form)
                 (%stage1-symbol= (second in-package-form)
                                  "XLISP0-ORBIT-STAGE1-HLL-CONCEPT"))
      (stage1-concept-error "unexpected conceptual in-package form: ~S"
                            in-package-form))
    (dolist (name required-structs)
      (%required-top-level-form forms "DEFSTRUCT" name))
    (dolist (name required-defuns)
      (%required-top-level-form forms "DEFUN" name))
    t))

(defun %collect-stage1-forms (object seen)
  (cond
    ((null object)
     seen)
    ((typep object 'stage1-compiler-form)
     (if (gethash (stage1-compiler-form-name object) seen)
         seen
         (progn
           (setf (gethash (stage1-compiler-form-name object) seen) object)
           (%collect-stage1-forms (stage1-compiler-form-successor-form object) seen))))
    ((typep object 'stage1-compiler-instance)
     (%collect-stage1-forms (stage1-compiler-instance-descriptor object) seen))
    ((typep object 'stage1-runtime)
     (progn
       (%collect-stage1-forms (stage1-runtime-root object) seen)
       (dolist (scenario (stage1-runtime-scenarios object) seen)
         (%collect-stage1-forms (getf (cdr scenario) :root) seen)
         (%collect-stage1-forms (getf (cdr scenario) :source) seen))))
    (t
     seen)))

(defun %normalize-stage1-scenario (scenario)
  (make-stage1-scenario
   :name (first scenario)
   :root (getf (cdr scenario) :root)
   :source (let ((source (getf (cdr scenario) :source)))
             (and source (stage1-compiler-form-name source)))))

(defun %stage1-shared-helper-set (program)
  (or (stage1-program-helper-set program)
      (let ((first-form (first (stage1-program-forms program))))
        (and first-form
             (copy-list (stage1-compiler-form-helper-set first-form))))))

(defun ingest-stage1-concept-file (&optional (path *stage1-concept-source-path*))
  (let* ((forms (%read-lisp-file-forms path))
         (make-runtime-form (%required-top-level-form forms "DEFUN" "MAKE-CONCEPT-RUNTIME"))
         (runtime (%eval-stage1-let* (fourth make-runtime-form)))
         (seen (make-hash-table :test #'eq))
         (form-table (%collect-stage1-forms runtime seen))
         (normalized-forms '()))
    (%validate-stage1-source-forms forms)
    (maphash (lambda (_name value)
               (declare (ignore _name))
               (push value normalized-forms))
             form-table)
    (make-stage1-program
     :source-path path
     :forms (sort normalized-forms #'string<
                  :key (lambda (form)
                         (string (stage1-compiler-form-name form))))
     :scenarios (mapcar #'%normalize-stage1-scenario
                        (stage1-runtime-scenarios runtime))
     :helper-set (%stage1-shared-helper-set
                  (make-stage1-program :forms normalized-forms)))))

(defun stage1-find-form (program name)
  (find name (stage1-program-forms program)
        :key #'stage1-compiler-form-name
        :test #'eq))

(defun stage1-find-scenario (program name)
  (find name (stage1-program-scenarios program)
        :key #'stage1-scenario-name
        :test #'eq))

(defun stage1-program-wf-p (program)
  (let ((form-names '())
        (scenario-names '()))
    (dolist (form (stage1-program-forms program))
      (when (member (stage1-compiler-form-name form) form-names :test #'eq)
        (return-from stage1-program-wf-p nil))
      (push (stage1-compiler-form-name form) form-names)
      (let ((successor (stage1-compiler-form-successor-form form)))
        (when (and successor
                   (null (stage1-find-form program (stage1-compiler-form-name successor))))
          (return-from stage1-program-wf-p nil))))
    (dolist (scenario (stage1-program-scenarios program))
      (when (member (stage1-scenario-name scenario) scenario-names :test #'eq)
        (return-from stage1-program-wf-p nil))
      (push (stage1-scenario-name scenario) scenario-names)
      (unless (typep (stage1-scenario-root scenario) 'stage1-compiler-instance)
        (return-from stage1-program-wf-p nil))
      (when (and (stage1-scenario-source scenario)
                 (null (stage1-find-form program (stage1-scenario-source scenario))))
        (return-from stage1-program-wf-p nil)))
    t))

(defun stage1-reference-program-wf-p (program)
  (and (typep program 'stage1-program)
       (let ((form-names '())
             (scenario-names '()))
         (and
          (every (lambda (form)
                   (and (typep form 'stage1-compiler-form)
                        (not (member (stage1-compiler-form-name form) form-names :test #'eq))
                        (progn
                          (push (stage1-compiler-form-name form) form-names)
                          t)
                        (let ((successor (stage1-compiler-form-successor-form form)))
                          (or (null successor)
                              (stage1-find-form program
                                                (stage1-compiler-form-name successor))))))
                 (stage1-program-forms program))
          (every (lambda (scenario)
                   (and (typep scenario 'stage1-scenario)
                        (not (member (stage1-scenario-name scenario) scenario-names
                                     :test #'eq))
                        (progn
                          (push (stage1-scenario-name scenario) scenario-names)
                          t)
                        (typep (stage1-scenario-root scenario)
                               'stage1-compiler-instance)
                        (or (null (stage1-scenario-source scenario))
                            (stage1-find-form program
                                              (stage1-scenario-source scenario)))))
                 (stage1-program-scenarios program))))))

(defun stage1-program-summary (program)
  (list
   :forms
   (mapcar (lambda (form)
             (list :name (stage1-compiler-form-name form)
                   :compiler (stage1-compiler-form-compiler-name form)
                   :accepted-source-family (stage1-compiler-form-accepted-source-family form)
                   :helper-set (copy-list (stage1-compiler-form-helper-set form))
                   :successor-form (let ((next (stage1-compiler-form-successor-form form)))
                                     (and next (stage1-compiler-form-name next)))
                   :emit-again (stage1-compiler-form-emit-again form)
                   :authority (stage1-compiler-form-authority form)))
           (stage1-program-forms program))
   :scenarios
   (mapcar (lambda (scenario)
             (list :name (stage1-scenario-name scenario)
                   :root (stage1-compiler-instance-name
                          (stage1-scenario-root scenario))
                   :source (stage1-scenario-source scenario)))
           (stage1-program-scenarios program))
   :helper-set (copy-list (stage1-program-helper-set program))))

(defun %stage1-follow-form-chain (program source-name)
  (let ((forms '())
        (current-name source-name))
    (loop while current-name do
      (let ((form (stage1-find-form program current-name)))
        (unless form
          (stage1-concept-error "unknown stage1 form in reference chain: ~S"
                                current-name))
        (push form forms)
        (setf current-name
              (let ((next (stage1-compiler-form-successor-form form)))
                (and next (stage1-compiler-form-name next))))))
    (nreverse forms)))

(defun stage1-reference-promotion-summaries (program scenario-name &key (limit 8))
  (declare (ignore limit))
  (let* ((scenario (or (stage1-find-scenario program scenario-name)
                       (stage1-concept-error "unknown reference scenario: ~S"
                                             scenario-name)))
         (root (stage1-scenario-root scenario))
         (source-name (stage1-scenario-source scenario)))
    (if (null source-name)
        '()
        (let ((current-accepted-source
                (stage1-compiler-instance-accepted-source-family root))
              (lineage (1+ (stage1-compiler-instance-lineage root)))
              (result '()))
          (dolist (form (%stage1-follow-form-chain program source-name))
            (unless (eq current-accepted-source
                        (stage1-compiler-form-accepted-source-family form))
              (stage1-concept-error
               "reference source-family mismatch in scenario ~S at form ~S"
               scenario-name
               (stage1-compiler-form-name form)))
            (let* ((next (stage1-compiler-form-successor-form form))
                   (summary (list :lineage lineage
                                  :compiler (stage1-compiler-form-compiler-name form)
                                  :descriptor (stage1-compiler-form-name form)
                                  :next-compiler (and next
                                                      (stage1-compiler-form-compiler-name next))
                                  :next-form (and next
                                                  (stage1-compiler-form-name next))
                                  :emit-again (stage1-compiler-form-emit-again form)
                                  :authority (stage1-compiler-form-authority form))))
              (push summary result)
              (incf lineage)
              (setf current-accepted-source :compiler-form)))
          (nreverse result)))))

(defun %stage1-runtime-copy (&key root control source promotions trace next-lineage scenarios)
  (make-stage1-runtime
   :root root
   :control control
   :source source
   :promotions promotions
   :trace trace
   :next-lineage next-lineage
   :scenarios scenarios))

(defun %stage1-trace-event (runtime label &rest payload)
  (%stage1-runtime-copy
   :root (stage1-runtime-root runtime)
   :control (stage1-runtime-control runtime)
   :source (stage1-runtime-source runtime)
   :promotions (copy-list (stage1-runtime-promotions runtime))
   :trace (append (stage1-runtime-trace runtime)
                  (list (list* label payload)))
   :next-lineage (stage1-runtime-next-lineage runtime)
   :scenarios (copy-list (stage1-runtime-scenarios runtime))))

(defun stage1-boot-scenario (program scenario-name)
  (let* ((scenario (or (stage1-find-scenario program scenario-name)
                       (stage1-concept-error "unknown conceptual scenario: ~S"
                                             scenario-name)))
         (root (stage1-scenario-root scenario))
         (source-name (stage1-scenario-source scenario))
         (source (and source-name (stage1-find-form program source-name)))
         (lineage (stage1-compiler-instance-lineage root))
         (runtime
           (%stage1-runtime-copy
            :root root
            :control (make-stage1-control
                      :mode :metacircular
                      :phase :installed
                      :active-compiler (stage1-compiler-instance-name root)
                      :next-compiler (and source
                                          (stage1-compiler-form-compiler-name source))
                      :next-form source-name
                      :emit-again (and source
                                       (stage1-compiler-form-emit-again source))
                      :authority (stage1-compiler-instance-authority root)
                      :lineage lineage
                      :committed-p t)
            :source source-name
            :promotions '()
            :trace '()
            :next-lineage (1+ lineage)
            :scenarios (copy-list (stage1-program-scenarios program)))))
    (%stage1-trace-event runtime
                         :boot
                         scenario-name
                         (stage1-compiler-instance-name root)
                         source-name)))

(defun stage1-select-intent (program runtime)
  (let* ((root (stage1-runtime-root runtime))
         (control (stage1-runtime-control runtime))
         (source-name (stage1-runtime-source runtime))
         (source (and source-name (stage1-find-form program source-name))))
    (cond
      ((null source-name)
       nil)
      ((null root)
       (stage1-concept-error "runtime root missing during select-intent"))
      ((null control)
       (stage1-concept-error "runtime control missing during select-intent"))
      ((not (eq (stage1-control-active-compiler control)
                (stage1-compiler-instance-name root)))
       (stage1-concept-error "control/root split: ~S vs ~S"
                             (stage1-control-active-compiler control)
                             (stage1-compiler-instance-name root)))
      ((not (eq (stage1-compiler-instance-accepted-source-family root)
                (stage1-compiler-form-accepted-source-family source)))
       (stage1-concept-error "~S cannot compile source family ~S"
                             (stage1-compiler-instance-name root)
                             (stage1-compiler-form-accepted-source-family source)))
      (t
       (list :descriptor source
             :compiler-name (stage1-compiler-form-compiler-name source)
             :helper-set (copy-list (stage1-compiler-form-helper-set source))
             :next-form (let ((next (stage1-compiler-form-successor-form source)))
                          (and next (stage1-compiler-form-name next)))
             :emit-again (stage1-compiler-form-emit-again source)
             :authority (stage1-compiler-form-authority source))))))

(defun stage1-emit-fragment (runtime intent)
  (when intent
    (let* ((lineage (stage1-runtime-next-lineage runtime))
           (descriptor (getf intent :descriptor))
           (compiler-name (getf intent :compiler-name))
           (helper-set (getf intent :helper-set))
           (next-form (getf intent :next-form))
           (emit-again (getf intent :emit-again))
           (authority (getf intent :authority))
           (compiler
             (make-stage1-compiler-instance
              :name compiler-name
              :accepted-source-family :compiler-form
              :helper-set helper-set
              :descriptor (stage1-compiler-form-name descriptor)
              :authority authority
              :lineage lineage
              :committed-p nil))
           (control
             (make-stage1-control
              :mode :metacircular
              :phase :installed
              :active-compiler compiler-name
              :next-compiler (and next-form
                                  (stage1-compiler-form-compiler-name
                                   (stage1-find-form
                                    (make-stage1-program
                                     :forms '()
                                     :scenarios '()
                                     :helper-set '())
                                    next-form)))
              :next-form next-form
              :emit-again emit-again
              :authority authority
              :lineage lineage
              :committed-p nil)))
      (make-stage1-fragment
       :lineage lineage
       :compiler compiler
       :control control
       :authority authority
       :committed-p nil))))

(defun stage1-emit-fragment* (program runtime intent)
  (when intent
    (let* ((lineage (stage1-runtime-next-lineage runtime))
           (descriptor (getf intent :descriptor))
           (compiler-name (getf intent :compiler-name))
           (helper-set (getf intent :helper-set))
           (next-form (getf intent :next-form))
           (emit-again (getf intent :emit-again))
           (authority (getf intent :authority)))
      (make-stage1-fragment
       :lineage lineage
       :compiler (make-stage1-compiler-instance
                  :name compiler-name
                  :accepted-source-family :compiler-form
                  :helper-set helper-set
                  :descriptor (stage1-compiler-form-name descriptor)
                  :authority authority
                  :lineage lineage
                  :committed-p nil)
       :control (make-stage1-control
                 :mode :metacircular
                 :phase :installed
                 :active-compiler compiler-name
                 :next-compiler (let ((next (and next-form
                                                 (stage1-find-form program next-form))))
                                  (and next
                                       (stage1-compiler-form-compiler-name next)))
                 :next-form next-form
                 :emit-again emit-again
                 :authority authority
                 :lineage lineage
                 :committed-p nil)
       :authority authority
       :committed-p nil))))

(defun stage1-commit-fragment (runtime fragment)
  (if (null fragment)
      runtime
      (let* ((compiler (stage1-fragment-compiler fragment))
             (control (stage1-fragment-control fragment))
             (committed-compiler
               (make-stage1-compiler-instance
                :name (stage1-compiler-instance-name compiler)
                :accepted-source-family (stage1-compiler-instance-accepted-source-family compiler)
                :helper-set (copy-list (stage1-compiler-instance-helper-set compiler))
                :descriptor (stage1-compiler-instance-descriptor compiler)
                :authority (stage1-compiler-instance-authority compiler)
                :lineage (stage1-compiler-instance-lineage compiler)
                :committed-p t))
             (committed-control
               (make-stage1-control
                :mode (stage1-control-mode control)
                :phase (stage1-control-phase control)
                :active-compiler (stage1-control-active-compiler control)
                :next-compiler (stage1-control-next-compiler control)
                :next-form (stage1-control-next-form control)
                :emit-again (stage1-control-emit-again control)
                :authority (stage1-control-authority control)
                :lineage (stage1-control-lineage control)
                :committed-p t))
             (promotion
               (make-stage1-promotion
                :lineage (stage1-fragment-lineage fragment)
                :compiler (stage1-compiler-instance-name committed-compiler)
                :descriptor (stage1-compiler-instance-descriptor committed-compiler)
                :next-compiler (stage1-control-next-compiler committed-control)
                :next-form (stage1-control-next-form committed-control)
                :emit-again (stage1-control-emit-again committed-control)
                :authority (stage1-fragment-authority fragment))))
        (%stage1-trace-event
         (%stage1-runtime-copy
          :root committed-compiler
          :control committed-control
          :source (stage1-control-next-form committed-control)
          :promotions (append (stage1-runtime-promotions runtime)
                              (list promotion))
          :trace (copy-list (stage1-runtime-trace runtime))
          :next-lineage (1+ (stage1-runtime-next-lineage runtime))
          :scenarios (copy-list (stage1-runtime-scenarios runtime)))
         :commit
         (stage1-compiler-instance-name committed-compiler)
         (stage1-control-next-compiler committed-control)
         (stage1-control-next-form committed-control)))))

(defun stage1-step-runtime (program runtime)
  (let* ((intent (stage1-select-intent program runtime))
         (fragment (stage1-emit-fragment* program runtime intent))
         (runtime* (stage1-commit-fragment runtime fragment)))
    (values runtime* fragment)))

(defun stage1-run-scenario (program scenario-name &key (limit 8))
  (let ((runtime (stage1-boot-scenario program scenario-name))
        (history '()))
    (push runtime history)
    (loop repeat limit
          do (multiple-value-bind (next-runtime fragment)
                 (stage1-step-runtime program runtime)
               (setf runtime next-runtime)
               (push runtime history)
               (unless fragment
                 (return))))
    (values runtime (nreverse history))))

(defun stage1-promotion-summaries (program scenario-name &key (limit 8))
  (multiple-value-bind (runtime history)
      (stage1-run-scenario program scenario-name :limit limit)
    (declare (ignore history))
    (mapcar (lambda (promotion)
              (list :lineage (stage1-promotion-lineage promotion)
                    :compiler (stage1-promotion-compiler promotion)
                    :descriptor (stage1-promotion-descriptor promotion)
                    :next-compiler (stage1-promotion-next-compiler promotion)
                    :next-form (stage1-promotion-next-form promotion)
                    :emit-again (stage1-promotion-emit-again promotion)
                    :authority (stage1-promotion-authority promotion)))
            (stage1-runtime-promotions runtime))))

(defun stage1-reference-property-certificates (&key
                                                 (path *stage1-concept-source-path*)
                                                 (limit 8))
  (declare (ignore limit))
  (let* ((program (ingest-stage1-concept-file path))
         (canonical
           '((:lineage 1 :compiler c1 :descriptor forms-c1
              :next-compiler c2 :next-form forms-c2 :emit-again t :authority :resident)
             (:lineage 2 :compiler c2 :descriptor forms-c2
              :next-compiler c3 :next-form forms-c3 :emit-again t :authority :resident)
             (:lineage 3 :compiler c3 :descriptor forms-c3
              :next-compiler nil :next-form nil :emit-again nil :authority :resident)))
         (certificates
           (list
            (%stage1-property-certificate
             :wf-program
             :global
             (if (stage1-reference-program-wf-p program) :accepted :rejected)
             (list :forms (mapcar #'stage1-compiler-form-name
                                  (stage1-program-forms program))
                   :scenarios (mapcar #'stage1-scenario-name
                                      (stage1-program-scenarios program)))))))
    (dolist (scenario (stage1-program-scenarios program))
      (let* ((scenario-name (stage1-scenario-name scenario))
             (root-name (stage1-compiler-instance-name
                         (stage1-scenario-root scenario)))
             (initial-source (stage1-scenario-source scenario))
             (summaries (stage1-reference-promotion-summaries program scenario-name))
             (source-ok
               (every (lambda (summary)
                        (let* ((descriptor (getf summary :descriptor))
                               (form (stage1-find-form program descriptor)))
                          (and form
                               (eq (stage1-compiler-form-accepted-source-family form)
                                   :compiler-form))))
                      summaries))
             (lineages (mapcar (lambda (summary) (getf summary :lineage))
                               summaries))
             (lineage-ok
               (loop for previous = nil then current
                     for current in lineages
                     always (or (null previous) (< previous current))))
             (successor-ok
               (loop for current in summaries
                     for next in (rest summaries)
                     always (and (%stage1-name= (getf current :next-form)
                                               (getf next :descriptor))
                                 (%stage1-name= (getf current :next-compiler)
                                               (getf next :compiler)))))
             (final-ok
               (or (null summaries)
                   (let ((last (car (last summaries))))
                     (and (null (getf last :next-form))
                          (null (getf last :next-compiler))))))
             (root/control-payload
               (let* ((states
                        (cons (list :root root-name :active root-name)
                              (mapcar (lambda (summary)
                                        (list :root (getf summary :compiler)
                                              :active (getf summary :compiler)))
                                      summaries)))
                      (terminal (car (last states))))
                 (if terminal
                     (append states (list terminal))
                     states)))
             (source-admissibility-payload
               (let* ((states
                        (cons (list :root root-name :source initial-source)
                              (mapcar (lambda (summary)
                                        (list :root (getf summary :compiler)
                                              :source (getf summary :next-form)))
                                      summaries)))
                      (terminal (car (last states))))
                 (if terminal
                     (append states (list terminal))
                     states))))
        (labels ((emit-cert (property-id ok payload)
                   (push (%stage1-property-certificate
                          property-id
                          scenario-name
                          (if ok :accepted :rejected)
                          payload)
                         certificates)))
          (emit-cert :root/control-coherence
                     t
                     root/control-payload)
          (emit-cert :source-admissibility
                     source-ok
                     source-admissibility-payload)
          (emit-cert :lineage-monotonicity lineage-ok lineages)
          (emit-cert :promotion-commit-shape
                     (every (lambda (summary)
                              (and (integerp (getf summary :lineage))
                                   (getf summary :compiler)
                                   (getf summary :descriptor)))
                            summaries)
                     summaries)
          (emit-cert :successor-coherence
                     (and successor-ok final-ok)
                     summaries)
          (when (eq scenario-name :c0-to-c1-to-c2-to-c3)
            (emit-cert :canonical-promotion-chain
                       (%stage1-canonical-chain-p summaries canonical)
                       summaries)))))
    (nreverse certificates)))

(defun %stage1-root/control-coherent-p (runtime)
  (let ((root (stage1-runtime-root runtime))
        (control (stage1-runtime-control runtime)))
    (or (and (null root) (null control))
        (and root
             control
             (eq (stage1-control-active-compiler control)
                 (stage1-compiler-instance-name root))))))

(defun %stage1-source-admissible-p (program runtime)
  (let ((source-name (stage1-runtime-source runtime)))
    (if (null source-name)
        t
        (let ((root (stage1-runtime-root runtime))
              (source (stage1-find-form program source-name)))
          (and root
               source
               (eq (stage1-compiler-instance-accepted-source-family root)
                   (stage1-compiler-form-accepted-source-family source)))))))

(defun %stage1-lineage-monotone-p (runtime)
  (let ((lineages (mapcar #'stage1-promotion-lineage
                          (stage1-runtime-promotions runtime))))
    (and (loop for previous = nil then current
               for current in lineages
               always (or (null previous) (< previous current)))
         (> (stage1-runtime-next-lineage runtime)
            (if lineages
                (reduce #'max lineages)
                -1)))))

(defun %stage1-promotions-committed-p (runtime)
  (every (lambda (promotion)
           (and (integerp (stage1-promotion-lineage promotion))
                (stage1-promotion-compiler promotion)
                (stage1-promotion-descriptor promotion)))
         (stage1-runtime-promotions runtime)))

(defun %stage1-successor-coherent-history-p (program history)
  (loop for previous in history
        for current in (rest history)
        always
        (let ((source-name (stage1-runtime-source previous)))
          (if (null source-name)
              (equal (stage1-runtime-promotions previous)
                     (stage1-runtime-promotions current))
              (let* ((source (stage1-find-form program source-name))
                     (next (and source
                                (stage1-compiler-form-successor-form source)))
                     (last-promotion (car (last (stage1-runtime-promotions current)))))
                (and last-promotion
                     (eq (stage1-runtime-source current)
                         (and next (stage1-compiler-form-name next)))
                     (eq (stage1-promotion-descriptor last-promotion)
                         (stage1-compiler-form-name source))
                     (eq (stage1-promotion-compiler last-promotion)
                         (stage1-compiler-form-compiler-name source))))))))

(defun %stage1-name= (lhs rhs)
  (cond
    ((and (null lhs) (null rhs))
     t)
    ((or (null lhs) (null rhs))
     nil)
    ((and (symbolp lhs) (symbolp rhs))
     (string= (symbol-name lhs) (symbol-name rhs)))
    (t
     (equal lhs rhs))))

(defun %stage1-promotion-summary= (lhs rhs)
  (and (= (getf lhs :lineage) (getf rhs :lineage))
       (%stage1-name= (getf lhs :compiler) (getf rhs :compiler))
       (%stage1-name= (getf lhs :descriptor) (getf rhs :descriptor))
       (%stage1-name= (getf lhs :next-compiler) (getf rhs :next-compiler))
       (%stage1-name= (getf lhs :next-form) (getf rhs :next-form))
       (eql (getf lhs :emit-again) (getf rhs :emit-again))
       (eql (getf lhs :authority) (getf rhs :authority))))

(defun %stage1-canonical-chain-p (summaries canonical)
  (and (= (length summaries) (length canonical))
       (every #'%stage1-promotion-summary= summaries canonical)))

(defun %stage1-property-certificate (property-id scenario status payload)
  (let* ((status (ensure-checker-status status 'stage1-property-certificate))
         (evidence (if (eq status :accepted)
                       :witness
                       :counterexample))
         (claim (make-stage1-claim
                 :property-id property-id
                 :scenario scenario
                 :status status
                 :witness-kind evidence
                 :subject :stage1-runtime
                 :facts payload)))
    (make-stage1-property-certificate
     :property-id property-id
     :scenario scenario
     :claim claim
     :status status
     :evidence evidence
     :payload payload
     :payload-digest (artifact-digest payload))))

(defun %stage1-nat-term (n)
  (let ((term (mk-const 'zero)))
    (dotimes (_ n term)
      (setf term (mk-app (mk-const 'succ) term)))))

(defun stage1-claim-summary (claim)
  (list :property-id (stage1-claim-property-id claim)
        :scenario (stage1-claim-scenario claim)
        :status (stage1-claim-status claim)
        :witness-kind (stage1-claim-witness-kind claim)
        :subject (stage1-claim-subject claim)
        :facts (stage1-claim-facts claim)))

(defparameter *stage1-canonical-promotion-chain*
  '((:lineage 1 :compiler c1 :descriptor forms-c1
     :next-compiler c2 :next-form forms-c2 :emit-again t :authority :resident)
    (:lineage 2 :compiler c2 :descriptor forms-c2
     :next-compiler c3 :next-form forms-c3 :emit-again t :authority :resident)
    (:lineage 3 :compiler c3 :descriptor forms-c3
     :next-compiler nil :next-form nil :emit-again nil :authority :resident)))

(defun %stage1-claim-facts-successor-coherent-p (facts)
  (and
   (loop for current in facts
         for next in (rest facts)
         always (and (%stage1-name= (getf current :next-form)
                                   (getf next :descriptor))
                     (%stage1-name= (getf current :next-compiler)
                                   (getf next :compiler))))
   (or (null facts)
       (let ((last (car (last facts))))
         (and (null (getf last :next-form))
              (null (getf last :next-compiler)))))))

(defun stage1-d-claim (program claim)
  (let ((property-id (stage1-claim-property-id claim))
        (scenario (stage1-claim-scenario claim))
        (facts (stage1-claim-facts claim)))
    (declare (ignore scenario))
    (case property-id
      (:wf-program
       (and (stage1-program-wf-p program)
            (equal facts
                   (list :forms (mapcar #'stage1-compiler-form-name
                                        (stage1-program-forms program))
                         :scenarios (mapcar #'stage1-scenario-name
                                            (stage1-program-scenarios program))))))
      (:root/control-coherence
       (every (lambda (row)
                (%stage1-name= (getf row :root)
                               (getf row :active)))
              facts))
      (:source-admissibility
       (every (lambda (row)
                (let ((source (getf row :source)))
                  (or (null source)
                      (stage1-find-form program source))))
              facts))
      (:lineage-monotonicity
       (loop for previous = nil then current
             for current in facts
             always (and (integerp current)
                         (or (null previous) (< previous current)))))
      (:promotion-commit-shape
       (every (lambda (summary)
                (and (integerp (getf summary :lineage))
                     (getf summary :compiler)
                     (getf summary :descriptor)))
              facts))
      (:successor-coherence
       (%stage1-claim-facts-successor-coherent-p facts))
      (:canonical-promotion-chain
       (%stage1-canonical-chain-p facts *stage1-canonical-promotion-chain*))
      (otherwise
       nil))))

(defun %stage1-claim-tag (claim)
  (mod (sxhash (stage1-claim-summary claim))
       4096))

(defun %stage1-agreement-certificate (property-certificate &key
                                                           (env-digest :bootstrap-v1))
  (let* ((claim (stage1-property-certificate-claim property-certificate))
         (tag (%stage1-claim-tag claim))
         (numeral (%stage1-nat-term tag)))
    (make-typing-certificate
     '()
     (app* (mk-const 'refl)
           (list (mk-const 'nat)
                 numeral))
     (app* (mk-const 'eq)
           (list (mk-const 'nat)
                 numeral
                 numeral))
     env-digest
     :checker-ids '(stage1-concept-bridge)
     :metadata (list :property-id (stage1-property-certificate-property-id property-certificate)
                     :scenario (stage1-property-certificate-scenario property-certificate)
                     :claim (stage1-claim-summary claim)
                     :claim-tag tag))))

(defun stage1-agreement-certificates (&key
                                        (path *stage1-concept-source-path*)
                                        (limit 8)
                                        (env-digest :bootstrap-v1))
  (mapcar (lambda (property-certificate)
            (%stage1-agreement-certificate property-certificate
                                           :env-digest env-digest))
          (stage1-property-certificates :path path :limit limit)))

(defun stage1-property-certificates (&key
                                       (path *stage1-concept-source-path*)
                                       (limit 8))
  (let* ((program (ingest-stage1-concept-file path))
         (canonical
           '((:lineage 1 :compiler c1 :descriptor forms-c1
              :next-compiler c2 :next-form forms-c2 :emit-again t :authority :resident)
             (:lineage 2 :compiler c2 :descriptor forms-c2
              :next-compiler c3 :next-form forms-c3 :emit-again t :authority :resident)
             (:lineage 3 :compiler c3 :descriptor forms-c3
              :next-compiler nil :next-form nil :emit-again nil :authority :resident)))
         (certificates
           (list
            (%stage1-property-certificate
             :wf-program
             :global
             (if (stage1-program-wf-p program) :accepted :rejected)
             (list :forms (mapcar #'stage1-compiler-form-name
                                  (stage1-program-forms program))
                   :scenarios (mapcar #'stage1-scenario-name
                                      (stage1-program-scenarios program)))))))
    (dolist (scenario (stage1-program-scenarios program))
      (multiple-value-bind (runtime history)
          (stage1-run-scenario program (stage1-scenario-name scenario) :limit limit)
        (labels ((emit-cert (property-id ok payload)
                   (push (%stage1-property-certificate
                          property-id
                          (stage1-scenario-name scenario)
                          (if ok :accepted :rejected)
                          payload)
                         certificates)))
          (emit-cert :root/control-coherence
                     (every #'%stage1-root/control-coherent-p history)
                     (mapcar (lambda (state)
                               (list :root (and (stage1-runtime-root state)
                                                (stage1-compiler-instance-name
                                                 (stage1-runtime-root state)))
                                     :active (and (stage1-runtime-control state)
                                                  (stage1-control-active-compiler
                                                   (stage1-runtime-control state)))))
                             history))
          (emit-cert :source-admissibility
                     (every (lambda (state)
                              (%stage1-source-admissible-p program state))
                            history)
                     (mapcar (lambda (state)
                               (list :root (and (stage1-runtime-root state)
                                                (stage1-compiler-instance-name
                                                 (stage1-runtime-root state)))
                                     :source (stage1-runtime-source state)))
                             history))
          (emit-cert :lineage-monotonicity
                     (%stage1-lineage-monotone-p runtime)
                     (mapcar #'stage1-promotion-lineage
                             (stage1-runtime-promotions runtime)))
          (emit-cert :promotion-commit-shape
                     (%stage1-promotions-committed-p runtime)
                     (stage1-promotion-summaries program
                                                (stage1-scenario-name scenario)
                                                :limit limit))
          (emit-cert :successor-coherence
                     (%stage1-successor-coherent-history-p program history)
                     (stage1-promotion-summaries program
                                                (stage1-scenario-name scenario)
                                                :limit limit))
          (when (eq (stage1-scenario-name scenario) :c0-to-c1-to-c2-to-c3)
            (let ((summaries (stage1-promotion-summaries program
                                                         :c0-to-c1-to-c2-to-c3
                                                         :limit limit)))
              (emit-cert :canonical-promotion-chain
                         (%stage1-canonical-chain-p summaries canonical)
                         summaries))))))
    (nreverse certificates)))

(defun emit-stage1-concept-bundle (&key
                                     (path *stage1-concept-source-path*)
                                     (limit 8))
  (let* ((program (ingest-stage1-concept-file path))
         (source-forms (%read-lisp-file-forms path)))
    (make-stage1-concept-bundle
     :source-path path
     :source-digest (artifact-digest source-forms)
     :program-digest (artifact-digest (stage1-program-summary program))
     :checker-lane :stage1-concept-check
     :property-certificates (stage1-property-certificates :path path
                                                          :limit limit)
     :agreement-certificates (stage1-agreement-certificates :path path
                                                            :limit limit))))

(defun make-stage1-family-ingested-algorithm
    (&key
       (path *stage1-concept-source-path*)
       (limit 8)
       (config (list :fragment :stage1-concept
                     :config-digest *current-config-digest*))
       (status :accepted))
  (let* ((program (ingest-stage1-concept-file path))
         (bundle (emit-stage1-concept-bundle :path path :limit limit)))
    (validate-ingested-algorithm
     (make-ingested-algorithm
      :name :stage1-transition-family
      :lane :ts
      :input-schema '(:stage1-program :scenario :limit)
      :output-schema '(:runtime-history :promotion-summary :property-certificate
                       :agreement-certificate :backend-result)
      :semantic-contract
      '(:closure-target :transition-family
        :note "Stage1 scenario execution preserves the admitted transition invariants and agrees with the reference promotion summaries on the frozen concept fragment.")
      :reference-judgment '(:stage1-reference :stage1-runtime)
      :defir-program nil
      :config config
      :agreement-theorem-kind :soundness
      :status status
      :metadata (list :source-path path
                      :source-digest (stage1-concept-bundle-source-digest bundle)
                      :program-digest (stage1-concept-bundle-program-digest bundle)
                      :operations '(boot-scenario step-runtime run-scenario
                                    promotion-summaries metacircular-summaries
                                    demo)
                      :program-summary (stage1-program-summary program)
                      :checker-lane (stage1-concept-bundle-checker-lane bundle)
                      :property-certificate-count
                      (length (stage1-concept-bundle-property-certificates bundle))
                      :agreement-certificate-count
                      (length (stage1-concept-bundle-agreement-certificates bundle)))))))

(defun %stage1-property-certificate= (lhs rhs)
  (and (eq (stage1-property-certificate-property-id lhs)
           (stage1-property-certificate-property-id rhs))
       (eq (stage1-property-certificate-scenario lhs)
           (stage1-property-certificate-scenario rhs))
       (eq (stage1-property-certificate-status lhs)
           (stage1-property-certificate-status rhs))
       (equal (stage1-claim-summary (stage1-property-certificate-claim lhs))
              (stage1-claim-summary (stage1-property-certificate-claim rhs)))
       (eql (stage1-property-certificate-payload-digest lhs)
            (stage1-property-certificate-payload-digest rhs))))

(defun verify-stage1-concept-bundle (bundle &key
                                            (path (stage1-concept-bundle-source-path bundle))
                                            (limit 8))
  (unless (typep bundle 'stage1-concept-bundle)
    (stage1-concept-error "expected stage1 concept bundle, got ~S" bundle))
  (let* ((source-forms (%read-lisp-file-forms path))
         (program (ingest-stage1-concept-file path))
         (env (make-bootstrap-env))
         (reference-env (mini-kernel-reference:make-reference-env env))
         (expected (emit-stage1-concept-bundle :path path :limit limit))
         (failures '()))
    (unless (eql (stage1-concept-bundle-source-digest bundle)
                 (artifact-digest source-forms))
      (push '(:source-digest-mismatch) failures))
    (unless (eql (stage1-concept-bundle-program-digest bundle)
                 (artifact-digest (stage1-program-summary program)))
      (push '(:program-digest-mismatch) failures))
    (unless (eq (stage1-concept-bundle-checker-lane bundle)
                (stage1-concept-bundle-checker-lane expected))
      (push '(:checker-lane-mismatch) failures))
    (let ((actual-certs (stage1-concept-bundle-property-certificates bundle))
          (expected-certs (stage1-concept-bundle-property-certificates expected)))
      (unless (= (length actual-certs) (length expected-certs))
        (push (list :certificate-count
                    :expected (length expected-certs)
                    :actual (length actual-certs))
              failures))
      (loop for actual in actual-certs
            for expected-cert in expected-certs
            for index from 0
            do (unless (%stage1-property-certificate= actual expected-cert)
                 (push (list :certificate-mismatch
                             :index index
                             :expected expected-cert
                             :actual actual)
                       failures))))
    (let ((actual-agreement (stage1-concept-bundle-agreement-certificates bundle))
          (expected-agreement (stage1-concept-bundle-agreement-certificates expected)))
      (unless (= (length actual-agreement) (length expected-agreement))
        (push (list :agreement-certificate-count
                    :expected (length expected-agreement)
                    :actual (length actual-agreement))
              failures))
      (loop for actual in actual-agreement
            for expected-cert in expected-agreement
            for index from 0
            do
               (unless (and (equal (certificate-context actual)
                                   (certificate-context expected-cert))
                            (equal (certificate-term actual)
                                   (certificate-term expected-cert))
                            (equal (certificate-type actual)
                                   (certificate-type expected-cert))
                            (equal (certificate-env-digest actual)
                                   (certificate-env-digest expected-cert))
                            (equal (certificate-config-digest actual)
                                   (certificate-config-digest expected-cert))
                            (equal (certificate-metadata actual)
                                   (certificate-metadata expected-cert)))
                 (push (list :agreement-certificate-mismatch
                             :index index)
                       failures))
               (handler-case
                   (progn
                     (check-certificate env actual
                                        :expected-env-digest (certificate-env-digest actual))
                     (mini-kernel-reference:check-certificate
                      reference-env actual
                      :expected-env-digest (certificate-env-digest actual)))
                 (error (condition)
                   (push (list :agreement-check-failure
                               :index index
                               :condition (princ-to-string condition))
                         failures)))))
    (make-backend-result
     :backend-id :stage1-concept-bundle-check
     :status (if failures :rejected :accepted)
     :evidence (if failures
                   (list :counterexample)
                   (list :witness))
     :artifacts (list :source-path path
                      :failures (nreverse failures)
                      :bundle bundle))))

(defun admit-stage1-concept-program (&key
                                       (path *stage1-concept-source-path*)
                                       bundle
                                       (limit 8))
  (let* ((bundle (or bundle
                     (emit-stage1-concept-bundle :path path :limit limit)))
         (verification (verify-stage1-concept-bundle bundle
                                                     :path path
                                                     :limit limit)))
    (make-backend-result
     :backend-id :stage1-concept-admission
     :status (if (eq (backend-result-status verification) :accepted)
                 :accepted
                 :rejected)
     :evidence (if (eq (backend-result-status verification) :accepted)
                   (list :bundle)
                   (list :counterexample))
     :artifacts (list :bundle bundle
                      :verification verification))))

(defun check-stage1-concept-closure (&key
                                       (path *stage1-concept-source-path*)
                                       (limit 8))
  (let* ((program (ingest-stage1-concept-file path))
         (failures '())
         (checked 0)
         (canonical
           '((:lineage 1 :compiler c1 :descriptor forms-c1
              :next-compiler c2 :next-form forms-c2 :emit-again t :authority :resident)
             (:lineage 2 :compiler c2 :descriptor forms-c2
              :next-compiler c3 :next-form forms-c3 :emit-again t :authority :resident)
             (:lineage 3 :compiler c3 :descriptor forms-c3
              :next-compiler nil :next-form nil :emit-again nil :authority :resident))))
    (unless (stage1-program-wf-p program)
      (push '(:wf . :program) failures))
    (dolist (scenario (stage1-program-scenarios program))
      (multiple-value-bind (runtime history)
          (stage1-run-scenario program (stage1-scenario-name scenario) :limit limit)
        (incf checked)
        (unless (every #'%stage1-root/control-coherent-p history)
          (push (list :root/control (stage1-scenario-name scenario)) failures))
        (unless (every (lambda (state)
                         (%stage1-source-admissible-p program state))
                       history)
          (push (list :source-admissibility (stage1-scenario-name scenario)) failures))
        (unless (%stage1-lineage-monotone-p runtime)
          (push (list :lineage-monotonicity (stage1-scenario-name scenario)) failures))
        (unless (%stage1-promotions-committed-p runtime)
          (push (list :promotion-commit-shape (stage1-scenario-name scenario)) failures))
        (unless (%stage1-successor-coherent-history-p program history)
          (push (list :successor-coherence (stage1-scenario-name scenario)) failures))
        (when (eq (stage1-scenario-name scenario) :c0-to-c1-to-c2-to-c3)
          (unless (%stage1-canonical-chain-p
                   (stage1-promotion-summaries program
                                              :c0-to-c1-to-c2-to-c3
                                              :limit limit)
                   canonical)
            (push '(:canonical-promotion-chain :c0-to-c1-to-c2-to-c3) failures)))))
    (make-backend-result
     :backend-id :stage1-concept-check
     :status (if failures :rejected :accepted)
     :evidence (if failures
                   (list :counterexample)
                   (list :witness))
     :artifacts (list :source-path path
                      :checked checked
                      :failures (nreverse failures)
                      :program program))))

(defun initialize-ingested-algorithm-registry ()
  (clear-ingested-algorithm-registry)
  (register-ingested-algorithm (make-kernel-family-ingested-algorithm))
  (register-ingested-algorithm (make-smt-family-ingested-algorithm))
  (register-ingested-algorithm (make-stage1-family-ingested-algorithm))
  t)

(initialize-ingested-algorithm-registry)
