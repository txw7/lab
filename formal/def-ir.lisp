(in-package :mini-kernel)

(defstruct (defir-function
            (:constructor %make-defir-function
                (&key name params body)))
  name
  params
  body)

(defstruct (defir-program
            (:constructor %make-defir-program
                (&key functions metadata)))
  functions
  metadata)

(defun %defir-app-head (term)
  (multiple-value-bind (head _) (app-head+args term)
    (declare (ignore _))
    head))

(defun %defir-app-args (term)
  (multiple-value-bind (_ args) (app-head+args term)
    (declare (ignore _))
    args))

(defun %defir-some (value)
  (list :some value))

(defun %defir-some-value (option)
  (and (consp option)
       (eq (first option) :some)
       (second option)))

(defun %defir-builtins ()
  (list (cons '+ #'+)
        (cons '- #'-)
        (cons '1+ #'1+)
        (cons '1- #'1-)
        (cons '< #'<)
        (cons '> #'>)
        (cons '<= #'<=)
        (cons '>= #'>=)
        (cons '= #'=)
        (cons 'max #'max)
        (cons 'min #'min)
        (cons 'eq #'eq)
        (cons 'equal #'equal)
        (cons 'not #'not)
        (cons 'null #'null)
        (cons 'consp #'consp)
        (cons 'zerop #'zerop)
        (cons 'list #'list)
        (cons 'cons #'cons)
        (cons 'append #'append)
        (cons 'logand #'logand)
        (cons 'logior #'logior)
        (cons 'logxor #'logxor)
        (cons 'ash #'ash)
        (cons 'mod #'mod)
        (cons 'first #'first)
        (cons 'second #'second)
        (cons 'third #'third)
        (cons 'fourth #'fourth)
        (cons 'fifth #'fifth)
        (cons 'sixth #'sixth)
        (cons 'rest #'rest)
        (cons 'nthcdr #'nthcdr)
        (cons 'length #'length)
        (cons 'term-tag #'term-tag)
        (cons 'mk-sort #'mk-sort)
        (cons 'mk-var #'mk-var)
        (cons 'mk-const #'mk-const)
        (cons 'mk-app #'mk-app)
        (cons 'mk-lam #'mk-lam)
        (cons 'mk-pi #'mk-pi)
        (cons 'mk-let #'mk-let)
        (cons 'app* #'app*)
        (cons 'rebuild-apps #'rebuild-apps)
        (cons 'app-head-of #'%defir-app-head)
        (cons 'app-args-of #'%defir-app-args)
        (cons 'env-lookup #'env-lookup)
        (cons 'decl-kind #'decl-kind)
        (cons 'decl-type #'decl-type)
        (cons 'decl-value #'decl-value)
        (cons 'decl-reduciblep #'decl-reduciblep)
        (cons 'instantiate-levels #'instantiate-levels)
        (cons 'smt-tag #'smt-tag)
        (cons 'smt-bool-const #'smt-bool-const)
        (cons 'smt-bool-true-p #'smt-bool-true-p)
        (cons 'smt-bool-false-p #'smt-bool-false-p)
        (cons 'smt-bv-lit #'smt-bv-lit)
        (cons 'smt-bv-width #'smt-bv-width)
        (cons 'smt-bv-value #'smt-bv-value)
        (cons 'smt-not #'smt-not)
        (cons 'smt-and #'smt-and)
        (cons 'smt-or #'smt-or)
        (cons 'smt-xor #'smt-xor)
        (cons 'smt-ite #'smt-ite)
        (cons 'smt-eq #'smt-eq)
        (cons 'smt-bvnot #'smt-bvnot)
        (cons 'smt-bvand #'smt-bvand)
        (cons 'smt-bvor #'smt-bvor)
        (cons 'smt-bvxor #'smt-bvxor)
        (cons 'smt-bvadd #'smt-bvadd)
        (cons 'smt-bvsub #'smt-bvsub)
        (cons 'smt-concat #'smt-concat)
        (cons 'smt-extract #'smt-extract)
        (cons 'smt-ult #'smt-ult)
        (cons 'make-smt-cnf
              (lambda (var-count clauses root-literal &optional atom-table assumptions)
                (make-smt-cnf
                 :var-count var-count
                 :clauses clauses
                 :root-literal root-literal
                 :atom-table atom-table
                 :assumptions assumptions)))
        (cons 'compile-smt-to-cnf-native #'compile-smt-to-cnf)
        (cons 'compile-boolean-core-to-cnf-with-assumptions-native
              #'compile-boolean-core-to-cnf-with-assumptions)
        (cons 'compile-smt-to-cnf-with-assumptions-native
              #'compile-smt-to-cnf-with-assumptions)
        (cons 'bitblast-smt-term-native #'bitblast-smt-term)
        (cons 'solve-cnf-dpll-native #'solve-cnf-dpll)
        (cons 'solve-cnf-under-assumptions-dpll-native
              #'solve-cnf-under-assumptions-dpll)
        (cons 'canonicalize-smt-terms #'%canonicalize-commutative-terms)
        (cons 'smt-bv-mask #'%smt-bv-mask)
        (cons 'ensure-same-bv-width #'%ensure-same-bv-width)
        (cons 'smt-bv-extract-literal
              (lambda (hi lo term)
                (let* ((width (1+ (- hi lo)))
                       (value (ldb (byte width lo) (smt-bv-value term))))
                  (smt-bv-lit width value))))
        (cons 'some #'%defir-some)
        (cons 'some-value #'%defir-some-value)
        (cons 'kernel-error #'kernel-error)))

(defun validate-defir-program (program)
  (unless (typep program 'defir-program)
    (kernel-error "expected DefIR program, got ~S" program))
  (unless (listp (defir-program-functions program))
    (kernel-error "DefIR functions must be a list, got ~S"
                  (defir-program-functions program)))
  (dolist (function (defir-program-functions program))
    (unless (typep function 'defir-function)
      (kernel-error "DefIR program contains non-function entry: ~S" function))
    (unless (symbolp (defir-function-name function))
      (kernel-error "DefIR function name must be a symbol, got ~S"
                    (defir-function-name function)))
    (unless (listp (defir-function-params function))
      (kernel-error "DefIR function params must be a list, got ~S"
                    (defir-function-params function))))
  program)

(defun find-defir-function (program name)
  (validate-defir-program program)
  (find name
        (defir-program-functions program)
        :key #'defir-function-name
        :test #'eq))

(defun %defir-lookup-local (locals name)
  (let ((entry (assoc name locals)))
    (if entry
        (cdr entry)
        (kernel-error "unbound DefIR local: ~S" name))))

(defun %defir-eval-sequence (program locals forms)
  (let ((result nil))
    (dolist (form forms)
      (setf result (%defir-eval program locals form)))
    result))

(defun %defir-eval-let* (program locals bindings body)
  (let ((env locals))
    (dolist (binding bindings)
      (destructuring-bind (name value-form) binding
        (push (cons name (%defir-eval program env value-form)) env)))
    (%defir-eval-sequence program env body)))

(defun %defir-eval-cond (program locals clauses)
  (dolist (clause clauses)
    (destructuring-bind (test &rest body) clause
      (when (or (eq test 't)
                (%defir-eval program locals test))
        (return-from %defir-eval-cond
          (%defir-eval-sequence program locals body)))))
  nil)

(defun %defir-eval-and (program locals forms)
  (let ((result t))
    (dolist (form forms)
      (setf result (%defir-eval program locals form))
      (unless result
        (return nil)))
    result))

(defun %defir-eval-or (program locals forms)
  (dolist (form forms)
    (let ((result (%defir-eval program locals form)))
      (when result
        (return-from %defir-eval-or result))))
  nil)

(defun %defir-apply (program operator arguments)
  (let ((builtin (assoc operator (%defir-builtins))))
    (cond
      (builtin
       (apply (cdr builtin) arguments))
      ((find-defir-function program operator)
       (apply #'call-defir-function program operator arguments))
      (t
       (kernel-error "unknown DefIR operator: ~S" operator)))))

(defun %defir-eval (program locals expr)
  (cond
    ((or (null expr)
         (numberp expr)
         (stringp expr)
         (keywordp expr)
         (eq expr t))
     expr)
    ((symbolp expr)
     (%defir-lookup-local locals expr))
    ((not (consp expr))
     expr)
    ((eq (first expr) 'quote)
     (second expr))
    ((eq (first expr) 'if)
     (if (%defir-eval program locals (second expr))
         (%defir-eval program locals (third expr))
         (%defir-eval program locals (fourth expr))))
    ((eq (first expr) 'let*)
     (%defir-eval-let* program locals (second expr) (cddr expr)))
    ((eq (first expr) 'cond)
     (%defir-eval-cond program locals (rest expr)))
    ((eq (first expr) 'and)
     (%defir-eval-and program locals (rest expr)))
    ((eq (first expr) 'or)
     (%defir-eval-or program locals (rest expr)))
    ((eq (first expr) 'progn)
     (%defir-eval-sequence program locals (rest expr)))
    (t
     (%defir-apply program
                   (first expr)
                   (mapcar (lambda (arg)
                             (%defir-eval program locals arg))
                           (rest expr))))))

(defun call-defir-function (program name &rest args)
  (let ((function (find-defir-function program name)))
    (unless function
      (kernel-error "unknown DefIR function: ~S" name))
    (unless (= (length args) (length (defir-function-params function)))
      (kernel-error "DefIR arity mismatch for ~S~%expected: ~S~%actual:   ~S"
                    name
                    (length (defir-function-params function))
                    (length args)))
    (%defir-eval program
                 (pairlis (defir-function-params function) args)
                 (defir-function-body function))))

(defun %make-mini-kernel-defir-function (name params body)
  (%make-defir-function :name name :params params :body body))

(defun %normalize-defir-function-name (name)
  (etypecase name
    (symbol name)
    (string (intern (string-upcase name) (find-package :mini-kernel)))))

(defun %filter-defir-functions (functions function-names)
  (if (null function-names)
      functions
      (let* ((allowed (mapcar #'%normalize-defir-function-name function-names))
             (filtered (remove-if-not (lambda (function)
                                        (member (defir-function-name function)
                                                allowed))
                                      functions)))
        (dolist (name allowed)
          (unless (find name filtered :key #'defir-function-name)
            (kernel-error "unknown DefIR function requested: ~S" name)))
        filtered)))

(defun merge-defir-programs (&rest programs)
  (let ((functions '())
        (metadata '()))
    (dolist (program programs)
      (validate-defir-program program)
      (dolist (function (defir-program-functions program))
        (when (find (defir-function-name function)
                    functions
                    :key #'defir-function-name)
          (kernel-error "duplicate DefIR function ~S in merged program"
                        (defir-function-name function)))
        (push function functions))
      (setf metadata (append metadata (defir-program-metadata program))))
    (validate-defir-program
     (%make-defir-program
      :metadata metadata
      :functions (nreverse functions)))))

(defun make-mini-kernel-defir-program (&key metadata function-names)
  (let ((functions
          (list
           (%make-mini-kernel-defir-function
      'shiftIndex
      '(delta k cutoff)
      '(if (< k cutoff)
           k
           (if (>= delta 0)
               (+ k delta)
               (max 0 (- k (- delta))))))
     (%make-mini-kernel-defir-function
      'shift
      '(delta cutoff term)
      '(cond
        ((eq (term-tag term) :sort) term)
        ((eq (term-tag term) :var)
         (mk-var (shiftIndex delta (second term) cutoff)))
        ((eq (term-tag term) :const) term)
        ((eq (term-tag term) :app)
         (mk-app (shift delta cutoff (second term))
                 (shift delta cutoff (third term))))
        ((eq (term-tag term) :lam)
         (mk-lam (shift delta cutoff (second term))
                 (shift delta (+ cutoff 1) (third term))))
        ((eq (term-tag term) :pi)
         (mk-pi (shift delta cutoff (second term))
                (shift delta (+ cutoff 1) (third term))))
        ((eq (term-tag term) :let)
         (mk-let (shift delta cutoff (second term))
                 (shift delta cutoff (third term))
                 (shift delta (+ cutoff 1) (fourth term))))
        (t (kernel-error "unknown term in DefIR shift: ~S" term))))
     (%make-mini-kernel-defir-function
      'subst
      '(j replacement term)
      '(cond
        ((eq (term-tag term) :sort) term)
        ((eq (term-tag term) :var)
         (if (= (second term) j)
             replacement
             term))
        ((eq (term-tag term) :const) term)
        ((eq (term-tag term) :app)
         (mk-app (subst j replacement (second term))
                 (subst j replacement (third term))))
        ((eq (term-tag term) :lam)
         (mk-lam (subst j replacement (second term))
                 (subst (+ j 1)
                        (shift 1 0 replacement)
                        (third term))))
        ((eq (term-tag term) :pi)
         (mk-pi (subst j replacement (second term))
                (subst (+ j 1)
                       (shift 1 0 replacement)
                       (third term))))
        ((eq (term-tag term) :let)
         (mk-let (subst j replacement (second term))
                 (subst j replacement (third term))
                 (subst (+ j 1)
                        (shift 1 0 replacement)
                        (fourth term))))
        (t (kernel-error "unknown term in DefIR subst: ~S" term))))
     (%make-mini-kernel-defir-function
      'instantiate
      '(body arg)
      '(shift -1 0 (subst 0 (shift 1 0 arg) body)))
     (%make-mini-kernel-defir-function
      'lookup
      '(ctx k)
      '(if (null ctx)
           nil
           (if (zerop k)
               (some (shift 1 0 (first ctx)))
               (let* ((mapped (some-value (lookup (rest ctx) (1- k)))))
                 (if mapped
                     (some (shift 1 0 mapped))
                     nil)))))
     (%make-mini-kernel-defir-function
      'reduceNatRec
      '(env args)
      '(if (< (length args) 4)
           (rebuild-apps (mk-const 'nat-rec) args)
           (let* ((motive (first args))
                  (base (second args))
                  (step (third args))
                  (n (fourth args))
                  (rest-args (nthcdr 4 args))
                  (n* (whnf env n)))
             (cond
               ((equal n* (mk-const 'zero))
                (whnf env (rebuild-apps base rest-args)))
               ((and (eq (term-tag n*) :app)
                     (equal (second n*) (mk-const 'succ)))
                (let* ((k (third n*))
                       (rec-call (rebuild-apps (mk-const 'nat-rec)
                                               (list motive base step k)))
                       (step-app (app* step (list k rec-call))))
                  (whnf env (rebuild-apps step-app rest-args))))
               (t
                (rebuild-apps (mk-const 'nat-rec)
                              (append (list motive base step n*) rest-args)))))))
     (%make-mini-kernel-defir-function
      'reduceEqRec
      '(env args)
      '(if (< (length args) 6)
           (rebuild-apps (mk-const 'eq-rec) args)
           (let* ((type (first args))
                  (lhs (second args))
                  (motive (third args))
                  (proof (fourth args))
                  (rhs (fifth args))
                  (equality (sixth args))
                  (rest-args (nthcdr 6 args))
                  (equality* (whnf env equality)))
             (if (and (eq (term-tag equality*) :app)
                      (eq (term-tag (second equality*)) :app)
                      (equal (second (second equality*)) (mk-const 'refl)))
                 (whnf env (rebuild-apps proof rest-args))
                 (rebuild-apps (mk-const 'eq-rec)
                               (append (list type lhs motive proof rhs equality*)
                                       rest-args))))))
     (%make-mini-kernel-defir-function
      'reduceHead
      '(env head args)
      '(cond
        ((null args) head)
        ((eq (term-tag head) :let)
         (whnf env (rebuild-apps (instantiate (fourth head) (second head)) args)))
        ((eq (term-tag head) :lam)
         (whnf env (rebuild-apps (instantiate (third head) (first args))
                                 (rest args))))
        ((and (eq (term-tag head) :const)
              (eq (second head) 'nat-rec))
         (reduceNatRec env args))
        ((and (eq (term-tag head) :const)
              (eq (second head) 'eq-rec))
         (reduceEqRec env args))
        (t
         (rebuild-apps head args))))
     (%make-mini-kernel-defir-function
      'whnf
      '(env term)
      '(cond
        ((eq (term-tag term) :let)
         (whnf env (instantiate (fourth term) (second term))))
        ((eq (term-tag term) :app)
         (reduceHead env
                     (whnf env (app-head-of term))
                     (app-args-of term)))
        ((eq (term-tag term) :const)
         (let* ((name (second term))
                (levels (third term))
                (decl (and env (env-lookup env name))))
           (if (and decl
                    (eq (decl-kind decl) :def)
                    (decl-reduciblep decl))
               (whnf env (instantiate-levels (decl-value decl) levels))
               term)))
        (t term)))
     (%make-mini-kernel-defir-function
      'conv
      '(env ctx lhs rhs)
      '(let* ((lhs* (whnf env lhs))
              (rhs* (whnf env rhs)))
         (cond
           ((eq (term-tag lhs*) :sort)
            (and (eq (term-tag rhs*) :sort)
                 (= (second lhs*) (second rhs*))))
           ((eq (term-tag lhs*) :var)
            (and (eq (term-tag rhs*) :var)
                 (= (second lhs*) (second rhs*))))
           ((eq (term-tag lhs*) :const)
            (and (eq (term-tag rhs*) :const)
                 (eq (second lhs*) (second rhs*))
                 (equal (third lhs*) (third rhs*))))
           ((eq (term-tag lhs*) :app)
            (and (eq (term-tag rhs*) :app)
                 (conv env ctx (second lhs*) (second rhs*))
                 (conv env ctx (third lhs*) (third rhs*))))
           ((eq (term-tag lhs*) :pi)
            (and (eq (term-tag rhs*) :pi)
                 (conv env ctx (second lhs*) (second rhs*))
                 (conv env (cons (second lhs*) ctx)
                       (third lhs*)
                       (third rhs*))))
           ((eq (term-tag lhs*) :lam)
            (and (eq (term-tag rhs*) :lam)
                 (conv env ctx (second lhs*) (second rhs*))
                 (conv env (cons (second lhs*) ctx)
                       (third lhs*)
                       (third rhs*))))
           (t nil))))
     (%make-mini-kernel-defir-function
      'checkSort
      '(env ctx term)
      '(let* ((type (whnf env (infer env ctx term))))
         (if (eq (term-tag type) :sort)
             (second type)
             (kernel-error "expected a sort, got ~S" type))))
     (%make-mini-kernel-defir-function
      'infer
      '(env ctx term)
      '(cond
        ((eq (term-tag term) :sort)
         (mk-sort (+ 1 (second term))))
        ((eq (term-tag term) :var)
         (let* ((maybe (lookup ctx (second term))))
           (if maybe
               (some-value maybe)
               (kernel-error "unbound de Bruijn index: ~A" (second term)))))
        ((eq (term-tag term) :const)
         (let* ((decl (env-lookup env (second term))))
           (if decl
               (instantiate-levels (decl-type decl) (third term))
               (kernel-error "unknown constant: ~A" (second term)))))
        ((eq (term-tag term) :pi)
         (mk-sort (max (checkSort env ctx (second term))
                       (checkSort env (cons (second term) ctx)
                                  (third term)))))
        ((eq (term-tag term) :lam)
         (progn
           (checkSort env ctx (second term))
           (mk-pi (second term)
                  (infer env (cons (second term) ctx)
                         (third term)))))
        ((eq (term-tag term) :app)
         (let* ((function-type (whnf env (infer env ctx (second term)))))
           (if (eq (term-tag function-type) :pi)
               (if (check env ctx (third term) (second function-type))
                   (instantiate (third function-type) (third term))
                   (kernel-error "argument type mismatch"))
               (kernel-error "application of non-function: ~S" function-type))))
        ((eq (term-tag term) :let)
         (progn
           (checkSort env ctx (third term))
           (if (check env ctx (second term) (third term))
               (instantiate (infer env (cons (third term) ctx)
                                   (fourth term))
                            (second term))
               (kernel-error "let value type mismatch"))))
        (t
         (kernel-error "unknown term in DefIR infer: ~S" term))))
     (%make-mini-kernel-defir-function
      'check
      '(env ctx term expected)
      '(conv env ctx (infer env ctx term) expected)))))
    (validate-defir-program
     (%make-defir-program
     :metadata metadata
     :functions (%filter-defir-functions functions function-names)))))

(defun make-smt-normalizer-defir-program (&key metadata)
  (let ((functions
          (list
           (%make-defir-function
            :name 'collect-and-terms
            :params '(term)
            :body '(if (eq (smt-tag term) :and)
                       (rest term)
                       (list term)))
           (%make-defir-function
            :name 'collect-or-terms
            :params '(term)
            :body '(if (eq (smt-tag term) :or)
                       (rest term)
                       (list term)))
           (%make-defir-function
            :name 'collapse-and-terms
            :params '(terms)
            :body '(let* ((ordered (canonicalize-smt-terms terms)))
                     (cond
                       ((null ordered) (smt-bool-const t))
                       ((null (rest ordered)) (first ordered))
                       (t (cons :and ordered)))))
           (%make-defir-function
            :name 'collapse-or-terms
            :params '(terms)
            :body '(let* ((ordered (canonicalize-smt-terms terms)))
                     (cond
                       ((null ordered) (smt-bool-const nil))
                       ((null (rest ordered)) (first ordered))
                       (t (cons :or ordered)))))
           (%make-defir-function
            :name 'normalize-and-list
            :params '(terms)
            :body '(if (null terms)
                       '()
                       (append (collect-and-terms
                                (normalize-smt-term (first terms)))
                               (normalize-and-list (rest terms)))))
           (%make-defir-function
            :name 'normalize-or-list
            :params '(terms)
            :body '(if (null terms)
                       '()
                       (append (collect-or-terms
                                (normalize-smt-term (first terms)))
                               (normalize-or-list (rest terms)))))
           (%make-defir-function
            :name 'normalize-and-terms
            :params '(terms)
            :body '(if (null terms)
                       (smt-bool-const t)
                       (let* ((head (first terms)))
                         (cond
                           ((smt-bool-false-p head) (smt-bool-const nil))
                           ((smt-bool-true-p head)
                            (normalize-and-terms (rest terms)))
                           (t
                            (let* ((tail (normalize-and-terms (rest terms))))
                              (cond
                                ((smt-bool-false-p tail) (smt-bool-const nil))
                                ((smt-bool-true-p tail) head)
                                (t
                                 (collapse-and-terms
                                  (append (list head)
                                          (collect-and-terms tail)))))))))))
           (%make-defir-function
            :name 'normalize-or-terms
            :params '(terms)
            :body '(if (null terms)
                       (smt-bool-const nil)
                       (let* ((head (first terms)))
                         (cond
                           ((smt-bool-true-p head) (smt-bool-const t))
                           ((smt-bool-false-p head)
                            (normalize-or-terms (rest terms)))
                           (t
                            (let* ((tail (normalize-or-terms (rest terms))))
                              (cond
                                ((smt-bool-true-p tail) (smt-bool-const t))
                                ((smt-bool-false-p tail) head)
                                (t
                                 (collapse-or-terms
                                  (append (list head)
                                          (collect-or-terms tail)))))))))))
           (%make-defir-function
            :name 'normalize-smt-term
            :params '(term)
            :body
            '(let* ((tag (smt-tag term)))
               (cond
                 ((eq tag :bool) term)
                 ((eq tag :var) term)
                 ((eq tag :bv-lit) term)
                 ((eq tag :not)
                  (let* ((inner (normalize-smt-term (second term))))
                    (cond
                      ((smt-bool-true-p inner) (smt-bool-const nil))
                      ((smt-bool-false-p inner) (smt-bool-const t))
                      ((eq (smt-tag inner) :not) (second inner))
                      (t (smt-not inner)))))
                 ((eq tag :and)
                  (normalize-and-terms (normalize-and-list (rest term))))
                 ((eq tag :or)
                  (normalize-or-terms (normalize-or-list (rest term))))
                 ((eq tag :xor)
                  (let* ((lhs (normalize-smt-term (second term)))
                         (rhs (normalize-smt-term (third term))))
                    (cond
                      ((equal lhs rhs) (smt-bool-const nil))
                      ((smt-bool-false-p lhs) rhs)
                      ((smt-bool-false-p rhs) lhs)
                      ((smt-bool-true-p lhs)
                       (normalize-smt-term (smt-not rhs)))
                      ((smt-bool-true-p rhs)
                       (normalize-smt-term (smt-not lhs)))
                      (t
                       (let* ((ordered (canonicalize-smt-terms
                                        (list lhs rhs))))
                         (smt-xor (first ordered) (second ordered)))))))
                 ((eq tag :=>)
                  (normalize-smt-term
                   (smt-or (smt-not (second term))
                           (third term))))
                 ((eq tag :ite)
                  (let* ((condition (normalize-smt-term (second term)))
                         (then-branch (normalize-smt-term (third term)))
                         (else-branch (normalize-smt-term (fourth term))))
                    (cond
                      ((smt-bool-true-p condition) then-branch)
                      ((smt-bool-false-p condition) else-branch)
                      ((equal then-branch else-branch) then-branch)
                      (t (smt-ite condition then-branch else-branch)))))
                 ((eq tag :=)
                  (let* ((lhs (normalize-smt-term (second term)))
                         (rhs (normalize-smt-term (third term))))
                    (cond
                      ((equal lhs rhs) (smt-bool-const t))
                      ((and (eq (smt-tag lhs) :bv-lit)
                            (eq (smt-tag rhs) :bv-lit))
                       (smt-bool-const
                        (= (smt-bv-value lhs)
                           (smt-bv-value rhs))))
                      ((or (and (smt-bool-true-p lhs)
                                (smt-bool-false-p rhs))
                           (and (smt-bool-false-p lhs)
                                (smt-bool-true-p rhs)))
                       (smt-bool-const nil))
                      (t
                       (let* ((ordered (canonicalize-smt-terms
                                        (list lhs rhs))))
                         (smt-eq (first ordered) (second ordered)))))))
                 ((eq tag :bvnot)
                  (let* ((inner (normalize-smt-term (second term))))
                    (if (eq (smt-tag inner) :bv-lit)
                        (let* ((width (smt-bv-width inner))
                               (mask (smt-bv-mask width)))
                          (smt-bv-lit width
                                      (logxor (smt-bv-value inner) mask)))
                        (smt-bvnot inner))))
                 ((eq tag :bvand)
                  (let* ((lhs (normalize-smt-term (second term)))
                         (rhs (normalize-smt-term (third term))))
                    (if (and (eq (smt-tag lhs) :bv-lit)
                             (eq (smt-tag rhs) :bv-lit))
                        (let* ((width (ensure-same-bv-width lhs rhs :bvand)))
                          (smt-bv-lit width
                                      (logand (smt-bv-value lhs)
                                              (smt-bv-value rhs))))
                        (let* ((ordered (canonicalize-smt-terms
                                         (list lhs rhs))))
                          (smt-bvand (first ordered) (second ordered))))))
                 ((eq tag :bvor)
                  (let* ((lhs (normalize-smt-term (second term)))
                         (rhs (normalize-smt-term (third term))))
                    (if (and (eq (smt-tag lhs) :bv-lit)
                             (eq (smt-tag rhs) :bv-lit))
                        (let* ((width (ensure-same-bv-width lhs rhs :bvor)))
                          (smt-bv-lit width
                                      (logior (smt-bv-value lhs)
                                              (smt-bv-value rhs))))
                        (let* ((ordered (canonicalize-smt-terms
                                         (list lhs rhs))))
                          (smt-bvor (first ordered) (second ordered))))))
                 ((eq tag :bvxor)
                  (let* ((lhs (normalize-smt-term (second term)))
                         (rhs (normalize-smt-term (third term))))
                    (if (and (eq (smt-tag lhs) :bv-lit)
                             (eq (smt-tag rhs) :bv-lit))
                        (let* ((width (ensure-same-bv-width lhs rhs :bvxor)))
                          (smt-bv-lit width
                                      (logxor (smt-bv-value lhs)
                                              (smt-bv-value rhs))))
                        (let* ((ordered (canonicalize-smt-terms
                                         (list lhs rhs))))
                          (smt-bvxor (first ordered) (second ordered))))))
                 ((eq tag :bvadd)
                  (let* ((lhs (normalize-smt-term (second term)))
                         (rhs (normalize-smt-term (third term))))
                    (if (and (eq (smt-tag lhs) :bv-lit)
                             (eq (smt-tag rhs) :bv-lit))
                        (let* ((width (ensure-same-bv-width lhs rhs :bvadd))
                               (modulus (ash 1 width)))
                          (smt-bv-lit width
                                      (mod (+ (smt-bv-value lhs)
                                              (smt-bv-value rhs))
                                           modulus)))
                        (smt-bvadd lhs rhs))))
                 ((eq tag :bvsub)
                  (let* ((lhs (normalize-smt-term (second term)))
                         (rhs (normalize-smt-term (third term))))
                    (if (and (eq (smt-tag lhs) :bv-lit)
                             (eq (smt-tag rhs) :bv-lit))
                        (let* ((width (ensure-same-bv-width lhs rhs :bvsub))
                               (modulus (ash 1 width)))
                          (smt-bv-lit width
                                      (mod (- (smt-bv-value lhs)
                                              (smt-bv-value rhs))
                                           modulus)))
                        (smt-bvsub lhs rhs))))
                 ((eq tag :concat)
                  (let* ((lhs (normalize-smt-term (second term)))
                         (rhs (normalize-smt-term (third term))))
                    (if (and (eq (smt-tag lhs) :bv-lit)
                             (eq (smt-tag rhs) :bv-lit))
                        (let* ((lw (smt-bv-width lhs))
                               (rw (smt-bv-width rhs))
                               (value (logior (ash (smt-bv-value lhs) rw)
                                              (smt-bv-value rhs))))
                          (smt-bv-lit (+ lw rw) value))
                        (smt-concat lhs rhs))))
                 ((eq tag :extract)
                  (let* ((hi (second term))
                         (lo (third term))
                         (inner (normalize-smt-term (fourth term))))
                    (if (< hi lo)
                        (kernel-error
                         "extract requires hi >= lo, got ~S and ~S"
                         hi lo)
                        (if (eq (smt-tag inner) :bv-lit)
                            (smt-bv-extract-literal hi lo inner)
                            (smt-extract hi lo inner)))))
                 ((eq tag :ult)
                  (let* ((lhs (normalize-smt-term (second term)))
                         (rhs (normalize-smt-term (third term))))
                    (if (and (eq (smt-tag lhs) :bv-lit)
                             (eq (smt-tag rhs) :bv-lit))
                        (progn
                          (ensure-same-bv-width lhs rhs :ult)
                          (smt-bool-const
                           (< (smt-bv-value lhs)
                              (smt-bv-value rhs))))
                        (smt-ult lhs rhs))))
                 (t
                  (kernel-error
                   "unsupported SMT term in DefIR normalization: ~S"
                   term))))))))
    (validate-defir-program
     (%make-defir-program
      :metadata metadata
      :functions functions))))

(defun make-smt-lowering-defir-program (&key metadata)
  (let ((functions
          (list
           (%make-defir-function
            :name 'lower-and-list
            :params '(terms)
            :body '(if (null terms)
                       '()
                       (append (collect-and-terms
                                (lower-smt-to-boolean-core (first terms)))
                               (lower-and-list (rest terms)))))
           (%make-defir-function
            :name 'lower-or-list
            :params '(terms)
            :body '(if (null terms)
                       '()
                       (append (collect-or-terms
                                (lower-smt-to-boolean-core (first terms)))
                               (lower-or-list (rest terms)))))
           (%make-defir-function
            :name 'lower-smt-to-boolean-core
            :params '(term)
            :body
            '(normalize-smt-term
              (let* ((tag (smt-tag term)))
                (cond
                  ((eq tag :bool) term)
                  ((eq tag :var) term)
                  ((eq tag :not)
                   (smt-not (lower-smt-to-boolean-core (second term))))
                  ((eq tag :and)
                   (collapse-and-terms (lower-and-list (rest term))))
                  ((eq tag :or)
                   (collapse-or-terms (lower-or-list (rest term))))
                  ((eq tag :xor)
                   (let* ((lhs (lower-smt-to-boolean-core (second term)))
                          (rhs (lower-smt-to-boolean-core (third term))))
                     (smt-or (smt-and lhs (smt-not rhs))
                             (smt-and (smt-not lhs) rhs))))
                  ((eq tag :=>)
                   (lower-smt-to-boolean-core
                    (smt-or (smt-not (second term))
                            (third term))))
                  ((eq tag :ite)
                   (let* ((condition (lower-smt-to-boolean-core (second term)))
                          (then-branch (lower-smt-to-boolean-core (third term)))
                          (else-branch (lower-smt-to-boolean-core (fourth term))))
                     (smt-or (smt-and condition then-branch)
                             (smt-and (smt-not condition) else-branch))))
                  ((eq tag :=)
                   (let* ((lhs (lower-smt-to-boolean-core (second term)))
                          (rhs (lower-smt-to-boolean-core (third term))))
                     (smt-or (smt-and lhs rhs)
                             (smt-and (smt-not lhs) (smt-not rhs)))))
                  (t
                   (kernel-error
                    "term is not in Boolean CNF fragment in DefIR lowerer: ~S"
                    term)))))))))
    (validate-defir-program
     (%make-defir-program
     :metadata metadata
      :functions functions))))

(defun make-smt-cnf-defir-program (&key metadata)
  (let ((functions
          (list
           (%make-defir-function
            :name 'make-cnf-state
            :params '(next-var clauses atom-table)
            :body '(list next-var clauses atom-table))
           (%make-defir-function
            :name 'cnf-state-next-var
            :params '(state)
            :body '(first state))
           (%make-defir-function
            :name 'cnf-state-clauses
            :params '(state)
            :body '(second state))
           (%make-defir-function
            :name 'cnf-state-atom-table
            :params '(state)
            :body '(third state))
           (%make-defir-function
            :name 'cnf-find-atom-binding
            :params '(atom atom-table)
            :body '(if (null atom-table)
                       nil
                       (if (equal atom (first (first atom-table)))
                           (first atom-table)
                           (cnf-find-atom-binding atom (rest atom-table)))))
           (%make-defir-function
            :name 'cnf-fresh-var
            :params '(state)
            :body '(let* ((next (+ (cnf-state-next-var state) 1))
                          (state* (make-cnf-state next
                                                  (cnf-state-clauses state)
                                                  (cnf-state-atom-table state))))
                     (list next state*)))
           (%make-defir-function
            :name 'cnf-add-clause
            :params '(state clause)
            :body '(make-cnf-state (cnf-state-next-var state)
                                   (append (cnf-state-clauses state)
                                           (list clause))
                                   (cnf-state-atom-table state)))
           (%make-defir-function
            :name 'cnf-add-atom-binding
            :params '(state atom literal)
            :body '(make-cnf-state (cnf-state-next-var state)
                                   (cnf-state-clauses state)
                                   (append (cnf-state-atom-table state)
                                           (list (list atom literal)))))
           (%make-defir-function
            :name 'cnf-atom-literal
            :params '(state atom)
            :body '(let* ((binding (cnf-find-atom-binding atom
                                                          (cnf-state-atom-table state))))
                     (if binding
                         (list (second binding) state)
                         (let* ((fresh (cnf-fresh-var state))
                                (literal (first fresh))
                                (state* (second fresh)))
                           (list literal
                                 (cnf-add-atom-binding state* atom literal))))))
           (%make-defir-function
            :name 'negate-literals
            :params '(literals)
            :body '(if (null literals)
                       '()
                       (append (list (- (first literals)))
                               (negate-literals (rest literals)))))
           (%make-defir-function
            :name 'emit-and-clauses
            :params '(state var children)
            :body '(if (null children)
                       state
                       (emit-and-clauses
                        (cnf-add-clause state (list (- var) (first children)))
                        var
                        (rest children))))
           (%make-defir-function
            :name 'emit-or-clauses
            :params '(state var children)
            :body '(if (null children)
                       state
                       (emit-or-clauses
                        (cnf-add-clause state (list var (- (first children))))
                        var
                        (rest children))))
           (%make-defir-function
            :name 'compile-core-literals
            :params '(state terms)
            :body '(if (null terms)
                       (list '() state)
                       (let* ((head-result (compile-core-literal state (first terms)))
                              (head-literal (first head-result))
                              (state* (second head-result))
                              (tail-result (compile-core-literals state* (rest terms)))
                              (tail-literals (first tail-result))
                              (state** (second tail-result)))
                         (list (append (list head-literal) tail-literals)
                               state**))))
           (%make-defir-function
            :name 'compile-core-literal
            :params '(state term)
            :body '(cond
                     ((eq (smt-tag term) :bool)
                      (let* ((fresh (cnf-fresh-var state))
                             (literal (first fresh))
                             (state* (second fresh))
                             (unit (if (smt-bool-true-p term)
                                       literal
                                       (- literal))))
                        (list literal
                              (cnf-add-clause state* (list unit)))))
                     ((eq (smt-tag term) :var)
                      (cnf-atom-literal state term))
                     ((eq (smt-tag term) :not)
                      (let* ((inner (compile-core-literal state (second term))))
                        (list (- (first inner))
                              (second inner))))
                     ((eq (smt-tag term) :and)
                      (let* ((children-result (compile-core-literals state (rest term)))
                             (children (first children-result))
                             (state* (second children-result))
                             (fresh (cnf-fresh-var state*))
                             (literal (first fresh))
                             (state** (second fresh))
                             (state*** (emit-and-clauses state** literal children))
                             (state**** (cnf-add-clause state***
                                                        (append (list literal)
                                                                (negate-literals children)))))
                        (list literal state****)))
                     ((eq (smt-tag term) :or)
                      (let* ((children-result (compile-core-literals state (rest term)))
                             (children (first children-result))
                             (state* (second children-result))
                             (fresh (cnf-fresh-var state*))
                             (literal (first fresh))
                             (state** (second fresh))
                             (state*** (emit-or-clauses state** literal children))
                             (state**** (cnf-add-clause state***
                                                        (append (list (- literal))
                                                                children))))
                        (list literal state****)))
                     (t
                      (kernel-error
                       "CNF compiler expected Boolean core term in DefIR, got ~S"
                       term))))
           (%make-defir-function
            :name 'compile-boolean-core-to-cnf
            :params '(core)
            :body '(let* ((initial-state (make-cnf-state 0 '() '()))
                          (root-result (compile-core-literal initial-state core))
                          (root-literal (first root-result))
                          (state* (second root-result))
                          (state** (cnf-add-clause state* (list root-literal))))
                     (make-smt-cnf (cnf-state-next-var state**)
                                   (cnf-state-clauses state**)
                                   root-literal
                                   (cnf-state-atom-table state**)
                                   '())))
           (%make-defir-function
            :name 'compile-boolean-core-to-cnf-with-assumptions
            :params '(assumptions core)
            :body '(compile-boolean-core-to-cnf-with-assumptions-native assumptions core))
           (%make-defir-function
            :name 'lower-smt-assumptions-to-boolean-core
            :params '(assumptions)
            :body '(if (null assumptions)
                       '()
                       (append
                        (list
                         (list (first (first assumptions))
                               (lower-smt-to-boolean-core
                                (second (first assumptions)))))
                        (lower-smt-assumptions-to-boolean-core
                         (rest assumptions)))))
           (%make-defir-function
            :name 'bitblast-smt-term
            :params '(term)
            :body '(bitblast-smt-term-native term))
           (%make-defir-function
            :name 'compile-smt-to-cnf
            :params '(term)
            :body '(compile-boolean-core-to-cnf
                    (lower-smt-to-boolean-core term)))
           (%make-defir-function
            :name 'compile-smt-to-cnf-with-assumptions
            :params '(assumptions term)
            :body '(compile-boolean-core-to-cnf-with-assumptions
                    (lower-smt-assumptions-to-boolean-core assumptions)
                    (lower-smt-to-boolean-core term)))
           (%make-defir-function
            :name 'solve-cnf-dpll
            :params '(cnf)
            :body '(solve-cnf-dpll-native cnf))
           (%make-defir-function
            :name 'solve-cnf-under-assumptions-dpll
            :params '(cnf assumptions)
            :body '(solve-cnf-under-assumptions-dpll-native cnf assumptions)))))
    (validate-defir-program
     (%make-defir-program
      :metadata metadata
      :functions functions))))

(defun make-smt-core-defir-program (&key metadata)
  (merge-defir-programs
   (make-smt-normalizer-defir-program :metadata metadata)
   (make-smt-lowering-defir-program :metadata metadata)
   (make-smt-cnf-defir-program :metadata metadata)))
