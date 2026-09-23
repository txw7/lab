(in-package :mini-kernel)

(defun %native-shift (delta cutoff term)
  (case (term-tag term)
    (:sort
     term)
    (:var
     (let* ((k (second term))
            (shifted (if (>= k cutoff) (+ k delta) k)))
       (when (minusp shifted)
         (kernel-error "negative de Bruijn index after shift: ~A" shifted))
       (mk-var shifted)))
    (:const
     term)
    (:app
     (mk-app (%native-shift delta cutoff (second term))
             (%native-shift delta cutoff (third term))))
    (:lam
     (mk-lam (%native-shift delta cutoff (second term))
             (%native-shift delta (1+ cutoff) (third term))))
    (:pi
     (mk-pi (%native-shift delta cutoff (second term))
            (%native-shift delta (1+ cutoff) (third term))))
    (:let
     (mk-let (%native-shift delta cutoff (second term))
             (%native-shift delta cutoff (third term))
             (%native-shift delta (1+ cutoff) (fourth term))))
    (otherwise
     (kernel-error "unknown term in shift: ~S" term))))

(defun %native-subst (j replacement term)
  (case (term-tag term)
    (:sort
     term)
    (:var
     (let ((k (second term)))
       (if (= k j)
           replacement
           term)))
    (:const
     term)
    (:app
     (mk-app (%native-subst j replacement (second term))
             (%native-subst j replacement (third term))))
    (:lam
     (mk-lam (%native-subst j replacement (second term))
             (%native-subst (1+ j)
                            (%native-shift 1 0 replacement)
                            (third term))))
    (:pi
     (mk-pi (%native-subst j replacement (second term))
            (%native-subst (1+ j)
                           (%native-shift 1 0 replacement)
                           (third term))))
    (:let
     (mk-let (%native-subst j replacement (second term))
             (%native-subst j replacement (third term))
             (%native-subst (1+ j)
                            (%native-shift 1 0 replacement)
                            (fourth term))))
    (otherwise
     (kernel-error "unknown term in subst: ~S" term))))

(defun %native-subst-top (replacement body)
  (%native-shift -1 0
                 (%native-subst 0 (%native-shift 1 0 replacement) body)))

(defun %native-ctx-lookup (ctx k)
  (let ((type (nth k ctx)))
    (unless type
      (kernel-error "unbound de Bruijn index: ~A" k))
    (%native-shift (1+ k) 0 type)))

(defun shift (delta cutoff term)
  (%kernel-implementation-call
   (kernel-implementation-shift (current-kernel-implementation))
   delta cutoff term))

(defun subst (j replacement term)
  (%kernel-implementation-call
   (kernel-implementation-subst (current-kernel-implementation))
   j replacement term))

(defun subst-top (replacement body)
  (%kernel-implementation-call
   (kernel-implementation-subst-top (current-kernel-implementation))
   replacement body))

(defun ctx-lookup (ctx k)
  (%kernel-implementation-call
   (kernel-implementation-ctx-lookup (current-kernel-implementation))
   ctx k))

(install-native-kernel-implementation
 (%make-validated-kernel-implementation
  :id :native
  :shift #'%native-shift
  :subst #'%native-subst
  :subst-top #'%native-subst-top
  :ctx-lookup #'%native-ctx-lookup
  :metadata '(:origin native)))
