(in-package :mini-kernel)

(defparameter *lean-ingest-comment-prefix* "/-! MINI-KERNEL-THEOREM ")
(defparameter *lean-ingest-comment-suffix* " -/")

(defstruct (lean-ingest-artifact
            (:constructor %make-lean-ingest-artifact
                (&key path source-digest schemas)))
  path
  source-digest
  schemas)

(defun %lean-theorem-metadata-plist (schema)
  (list :id (lean-theorem-schema-id schema)
        :module (lean-theorem-schema-module schema)
        :name (lean-theorem-schema-name schema)
        :source-kind (lean-theorem-schema-source-kind schema)
        :obligation-id (lean-theorem-schema-obligation-id schema)
        :parameter-keys (copy-list (lean-theorem-schema-parameter-keys schema))))

(defun %lean-theorem-declaration (schema)
  (case (lean-theorem-schema-id schema)
    (:declarativecore-weakening
     (format nil "axiom weakening~%  {Γ : Context} {A t T : CoreTerm} :~%  HasType Γ t T →~%  HasType (A :: Γ) (shift 1 0 t) (shift 1 0 T)"))
    (:declarativecore-substitution
     (format nil "axiom substitution~%  {Γ : Context} {A t T u : CoreTerm} :~%  HasType (A :: Γ) t T →~%  HasType Γ u A →~%  HasType Γ (instantiate t u) (instantiate T u)"))
    (:declarativecore-subject-reduction
     (format nil "axiom subjectReduction~%  {Γ : Context} {t u T : CoreTerm} :~%  HasType Γ t T →~%  Step t u →~%  HasType Γ u T"))
    (:declarativecore-krcheck-sound
     (format nil "theorem krCheck_sound~%  {Γ : Context} {t T : CoreTerm} :~%  KRCheck Γ t T →~%  HasType Γ t T := by~%  intro h~%  exact h"))
    (otherwise
     (kernel-error "no Lean declaration emitter for schema ~S"
                   (lean-theorem-schema-id schema)))))

(defun %write-lean-theorem-block (stream schema)
  (format stream "~A~S~A~%"
          *lean-ingest-comment-prefix*
          (%lean-theorem-metadata-plist schema)
          *lean-ingest-comment-suffix*)
  (format stream "~A~%~%" (%lean-theorem-declaration schema)))

(defun generate-lean-theorem-artifact
    (path &key (schemas (list-lean-theorem-schemas)) (namespace "MiniKernelGenerated"))
  (let ((path* (pathname path)))
    (ensure-directories-exist path*)
    (with-open-file (stream path* :direction :output :if-exists :supersede
                               :if-does-not-exist :create)
      (format stream "import Formal.DeclarativeCore~%~%")
      (format stream "open DeclarativeCore~%~%")
      (format stream "namespace ~A~%~%" namespace)
      (dolist (schema schemas)
        (validate-lean-theorem-schema schema)
        (%write-lean-theorem-block stream schema))
      (format stream "end ~A~%" namespace))
    path*))

(defun %read-file-string (path)
  (with-open-file (stream path :direction :input)
    (let ((buffer (make-string (file-length stream))))
      (read-sequence buffer stream)
      buffer)))

(defun %extract-lean-theorem-metadata-forms (source)
  (let ((start 0)
        (forms '()))
    (loop
      for block-start = (search *lean-ingest-comment-prefix* source :start2 start)
      while block-start do
        (let* ((payload-start (+ block-start (length *lean-ingest-comment-prefix*)))
               (block-end (search *lean-ingest-comment-suffix* source :start2 payload-start)))
          (unless block-end
            (kernel-error "unterminated Lean theorem metadata block in source"))
          (multiple-value-bind (form position)
              (read-from-string source t nil :start payload-start :end block-end)
            (declare (ignore position))
            (push form forms))
          (setf start (+ block-end (length *lean-ingest-comment-suffix*)))))
    (nreverse forms)))

(defun %lean-statement-builder-for-schema-id (schema-id)
  (case schema-id
    (:declarativecore-weakening 'instantiate-lean-weakening-statement)
    (:declarativecore-substitution 'instantiate-lean-substitution-statement)
    (:declarativecore-subject-reduction 'instantiate-lean-subject-reduction-statement)
    (:declarativecore-krcheck-sound 'instantiate-lean-krcheck-sound-statement)
    (otherwise
     (kernel-error "no Lean statement builder for schema id ~S" schema-id))))

(defun %metadata-form->lean-schema (form)
  (unless (listp form)
    (kernel-error "Lean theorem metadata form must be a plist, got ~S" form))
  (let ((schema
          (%make-lean-theorem-schema
           :id (getf form :id)
           :module (getf form :module)
           :name (getf form :name)
           :source-kind (getf form :source-kind)
           :obligation-id (getf form :obligation-id)
           :parameter-keys (copy-list (getf form :parameter-keys))
           :statement-builder (%lean-statement-builder-for-schema-id
                               (getf form :id)))))
    (validate-lean-theorem-schema schema)
    schema))

(defun validate-lean-ingest-artifact (artifact)
  (unless (typep artifact 'lean-ingest-artifact)
    (kernel-error "expected lean ingest artifact, got ~S" artifact))
  (unless (pathnamep (lean-ingest-artifact-path artifact))
    (kernel-error "lean ingest artifact path must be a pathname, got ~S"
                  (lean-ingest-artifact-path artifact)))
  (unless (listp (lean-ingest-artifact-schemas artifact))
    (kernel-error "lean ingest artifact schemas must be a list, got ~S"
                  (lean-ingest-artifact-schemas artifact)))
  (dolist (schema (lean-ingest-artifact-schemas artifact))
    (validate-lean-theorem-schema schema))
  artifact)

(defun ingest-lean-theorem-artifact (path)
  (let* ((path* (pathname path))
         (source (%read-file-string path*))
         (schemas (mapcar #'%metadata-form->lean-schema
                          (%extract-lean-theorem-metadata-forms source))))
    (validate-lean-ingest-artifact
     (%make-lean-ingest-artifact
      :path path*
      :source-digest (artifact-digest source)
      :schemas schemas))))

(defun find-ingested-lean-theorem-schema (artifact schema-id)
  (validate-lean-ingest-artifact artifact)
  (find schema-id
        (lean-ingest-artifact-schemas artifact)
        :key #'lean-theorem-schema-id
        :test #'eq))

(defun list-ingested-lean-theorem-schemas (artifact)
  (validate-lean-ingest-artifact artifact)
  (copy-list (lean-ingest-artifact-schemas artifact)))

(defun instantiate-ingested-lean-theorem-statement (artifact schema-id &rest params)
  (let ((schema (find-ingested-lean-theorem-schema artifact schema-id)))
    (unless schema
      (kernel-error "unknown ingested Lean theorem schema id: ~S" schema-id))
    (validate-lean-theorem-schema schema)
    (apply (if (symbolp (lean-theorem-schema-statement-builder schema))
               (symbol-function (lean-theorem-schema-statement-builder schema))
               (lean-theorem-schema-statement-builder schema))
           (%normalize-lean-schema-params schema params))))

(defun %theorem-statement-structurally-equal-p (left right)
  (and (typep left 'theorem-statement)
       (typep right 'theorem-statement)
       (eq (theorem-statement-id left)
           (theorem-statement-id right))
       (equal (theorem-statement-premises left)
              (theorem-statement-premises right))
       (equal (theorem-statement-conclusion left)
              (theorem-statement-conclusion right))
       (equal (theorem-statement-config-digest left)
              (theorem-statement-config-digest right))
       (equal (theorem-statement-metadata left)
              (theorem-statement-metadata right))))

(defun check-ingested-lean-statement-parity (artifact schema-id &rest params)
  (%theorem-statement-structurally-equal-p
   (apply #'instantiate-lean-theorem-statement schema-id params)
   (apply #'instantiate-ingested-lean-theorem-statement artifact schema-id params)))
