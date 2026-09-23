(in-package :mini-kernel)

(defparameter *smt-bool-sort* '(:Bool))
(defparameter *smt-int-sort* '(:Int))

(defun smt-bool-sort ()
  *smt-bool-sort*)

(defun smt-int-sort ()
  *smt-int-sort*)

(defun smt-bv-sort (width)
  (unless (and (integerp width) (plusp width))
    (kernel-error "bitvector sort width must be a positive integer, got ~S" width))
  `(:BV ,width))

(defun smt-array-sort (index-sort element-sort)
  `(:Array ,index-sort ,element-sort))

(defun smt-sort-kind (sort)
  (and (consp sort) (first sort)))

(defun smt-bool-const (value)
  `(:bool ,(not (null value))))

(defun smt-bool-true-p (term)
  (equal term '(:bool t)))

(defun smt-bool-false-p (term)
  (equal term '(:bool nil)))

(defun smt-var (name sort)
  `(:var ,name ,sort))

(defun smt-bv-lit (width value)
  (unless (and (integerp width) (plusp width))
    (kernel-error "bitvector literal width must be a positive integer, got ~S" width))
  (unless (and (integerp value) (<= 0 value))
    (kernel-error "bitvector literal value must be a non-negative integer, got ~S" value))
  (let ((modulus (ash 1 width)))
    `(:bv-lit ,width ,(mod value modulus))))

(defun smt-int-lit (value)
  (unless (integerp value)
    (kernel-error "integer literal value must be an integer, got ~S" value))
  `(:int-lit ,value))

(defun smt-tag (term)
  (and (consp term) (first term)))

(defun smt-bv-width (term)
  (unless (eq (smt-tag term) :bv-lit)
    (kernel-error "expected bitvector literal, got ~S" term))
  (second term))

(defun smt-bv-value (term)
  (unless (eq (smt-tag term) :bv-lit)
    (kernel-error "expected bitvector literal, got ~S" term))
  (third term))

(defun smt-int-value (term)
  (unless (eq (smt-tag term) :int-lit)
    (kernel-error "expected integer literal, got ~S" term))
  (second term))

(defun smt-op (tag &rest args)
  (cons tag args))

(defun smt-not (term)
  (smt-op :not term))

(defun smt-and (&rest terms)
  (cons :and terms))

(defun smt-or (&rest terms)
  (cons :or terms))

(defun smt-xor (&rest terms)
  (cons :xor terms))

(defun smt-implies (lhs rhs)
  (smt-op :=> lhs rhs))

(defun smt-ite (condition then-branch else-branch)
  (smt-op :ite condition then-branch else-branch))

(defun smt-eq (lhs rhs)
  (smt-op := lhs rhs))

(defun smt-bvnot (term)
  (smt-op :bvnot term))

(defun smt-bvand (lhs rhs)
  (smt-op :bvand lhs rhs))

(defun smt-bvor (lhs rhs)
  (smt-op :bvor lhs rhs))

(defun smt-bvxor (lhs rhs)
  (smt-op :bvxor lhs rhs))

(defun smt-bvadd (lhs rhs)
  (smt-op :bvadd lhs rhs))

(defun smt-bvsub (lhs rhs)
  (smt-op :bvsub lhs rhs))

(defun smt-int-add (&rest terms)
  (cons :int-add terms))

(defun smt-int-sub (lhs rhs)
  (smt-op :int-sub lhs rhs))

(defun smt-int-mod (lhs rhs)
  (smt-op :int-mod lhs rhs))

(defun smt-int-lt (lhs rhs)
  (smt-op :int-lt lhs rhs))

(defun smt-int-le (lhs rhs)
  (smt-op :int-le lhs rhs))

(defun smt-int-gt (lhs rhs)
  (smt-op :int-gt lhs rhs))

(defun smt-int-ge (lhs rhs)
  (smt-op :int-ge lhs rhs))

(defun smt-concat (lhs rhs)
  (smt-op :concat lhs rhs))

(defun smt-extract (hi lo term)
  (smt-op :extract hi lo term))

(defun smt-ult (lhs rhs)
  (smt-op :ult lhs rhs))

(defun smt-term< (lhs rhs)
  (string< (prin1-to-string lhs) (prin1-to-string rhs)))
