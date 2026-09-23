(in-package :mini-kernel)

(defparameter *advisory-artifact-kinds*
  '(:model :trace :summary :report :unsat-core :counterexample :invariant))

(defstruct advisory-artifact
  backend-id
  kind
  payload
  metadata)

(defun validate-advisory-artifact (artifact)
  (unless (find-backend (advisory-artifact-backend-id artifact))
    (kernel-error "unknown backend for advisory artifact: ~S"
                  (advisory-artifact-backend-id artifact)))
  (unless (eq (backend-trust-class (find-backend (advisory-artifact-backend-id artifact)))
              :advisory)
    (kernel-error "backend ~S is not advisory and may not emit advisory artifacts"
                  (advisory-artifact-backend-id artifact)))
  (unless (member (advisory-artifact-kind artifact)
                  *advisory-artifact-kinds*
                  :test #'eq)
    (kernel-error "invalid advisory artifact kind: ~S"
                  (advisory-artifact-kind artifact)))
  artifact)

(defun make-advisory-store ()
  (make-hash-table :test #'equal))

(defun advisory-store-add (store artifact)
  (validate-advisory-artifact artifact)
  (let* ((backend-id (advisory-artifact-backend-id artifact))
         (kind (advisory-artifact-kind artifact))
         (key (list backend-id kind))
         (existing (gethash key store)))
    (setf (gethash key store) (cons artifact existing))
    artifact))

(defun emit-advisory-artifact (store backend-id kind payload &optional metadata)
  (let ((backend (find-backend backend-id)))
    (unless backend
      (kernel-error "unknown backend for advisory emission: ~S" backend-id))
    (unless (eq (backend-trust-class backend) :advisory)
      (kernel-error "backend ~S is not advisory and may not emit advisory artifacts"
                    backend-id))
    (unless (member kind *advisory-artifact-kinds* :test #'eq)
      (kernel-error "backend ~S attempted to emit invalid advisory kind: ~S"
                    backend-id
                    kind))
    (advisory-store-add
     store
     (make-advisory-artifact
      :backend-id backend-id
      :kind kind
      :payload payload
      :metadata metadata))))

(defun advisory-store-find-by-kind (store kind)
  (let (results)
    (maphash (lambda (key artifacts)
               (declare (ignore key))
               (dolist (artifact artifacts)
                 (when (eq (advisory-artifact-kind artifact) kind)
                   (push artifact results))))
             store)
    (nreverse results)))

(defun advisory-store-find-by-backend (store backend-id)
  (let (results)
    (maphash (lambda (key artifacts)
               (declare (ignore key))
               (dolist (artifact artifacts)
                 (when (eq (advisory-artifact-backend-id artifact) backend-id)
                   (push artifact results))))
             store)
    (nreverse results)))
