(in-package :mini-kernel)

(defparameter *checked-proposal-kinds*
  '(:core-term :proof-term :declaration :candidate))

(defstruct checked-proposal
  backend-id
  kind
  payload
  metadata)

(defun validate-checked-proposal (proposal)
  (let ((backend (find-backend (checked-proposal-backend-id proposal))))
    (unless backend
      (kernel-error "unknown backend for checked proposal: ~S"
                    (checked-proposal-backend-id proposal)))
    (unless (eq (backend-trust-class backend) :checked)
      (kernel-error "backend ~S is not checked and may not emit checked proposals"
                    (checked-proposal-backend-id proposal)))
    (unless (member (checked-proposal-kind proposal)
                    *checked-proposal-kinds*
                    :test #'eq)
      (kernel-error "invalid checked proposal kind: ~S"
                    (checked-proposal-kind proposal)))
    (unless (member (checked-proposal-kind proposal)
                    (backend-proposes backend)
                    :test #'eq)
      (kernel-error "backend ~S may not propose kind ~S"
                    (checked-proposal-backend-id proposal)
                    (checked-proposal-kind proposal))))
  proposal)

(defun make-proposal-store ()
  (make-hash-table :test #'equal))

(defun proposal-store-add (store proposal)
  (validate-checked-proposal proposal)
  (let* ((backend-id (checked-proposal-backend-id proposal))
         (kind (checked-proposal-kind proposal))
         (key (list backend-id kind))
         (existing (gethash key store)))
    (setf (gethash key store) (cons proposal existing))
    proposal))

(defun emit-checked-proposal (store backend-id kind payload &optional metadata)
  (proposal-store-add
   store
   (make-checked-proposal
    :backend-id backend-id
    :kind kind
    :payload payload
    :metadata metadata)))

(defun proposal-store-find-by-kind (store kind)
  (let (results)
    (maphash (lambda (key proposals)
               (declare (ignore key))
               (dolist (proposal proposals)
                 (when (eq (checked-proposal-kind proposal) kind)
                   (push proposal results))))
             store)
    (nreverse results)))

(defun proposal-store-find-by-backend (store backend-id)
  (let (results)
    (maphash (lambda (key proposals)
               (declare (ignore key))
               (dolist (proposal proposals)
                 (when (eq (checked-proposal-backend-id proposal) backend-id)
                   (push proposal results))))
             store)
    (nreverse results)))
