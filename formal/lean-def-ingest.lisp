(in-package :mini-kernel)

(defparameter *lean-def-source-root*
  #.(make-pathname :name nil :type nil
                   :defaults (or *compile-file-truename*
                                 *load-truename*
                                 *default-pathname-defaults*)))

(defparameter *declarativecore-lean-def-source-path*
  (merge-pathnames "Formal/DeclarativeCore.lean"
                   *lean-def-source-root*))

(defparameter *mini-kernel-whnf-lean-source-path*
  (merge-pathnames "generated/mini-kernel-whnf.lean"
                   *lean-def-source-root*))

(defparameter *declarativecore-lean-def-specs*
  '(("shiftIndex"
     :header "def shiftIndex (delta : Int) (k cutoff : Nat) : Nat :="
     :required-fragments ("if k < cutoff then"
                          "else if delta >= 0 then"
                          "Int.toNat"))
    ("shift"
     :header "def shift (delta : Int) (cutoff : Nat) : CoreTerm"
     :required-fragments ("| CoreTerm.var k => CoreTerm.var (shiftIndex delta k cutoff)"
                          "| CoreTerm.app f a => CoreTerm.app (shift delta cutoff f) (shift delta cutoff a)"
                          "| CoreTerm.letE v A t =>"))
    ("subst"
     :header "def subst (j : Nat) (replacement : CoreTerm) : CoreTerm"
     :required-fragments ("if k = j then"
                          "| CoreTerm.lam A t =>"
                          "subst (j + 1) (shift 1 0 replacement) t"))
    ("instantiate"
     :header "def instantiate (body arg : CoreTerm) : CoreTerm :="
     :required-fragments ("shift (-1) 0"
                          "subst 0 (shift 1 0 arg) body"))
    ("lookup"
     :header "def lookup : Context"
     :required-fragments ("| [], _ => none"
                          "| A :: _, 0 => some (shift 1 0 A)"
                          "k + 1 =>"
                          "Option.map (shift 1 0) (lookup"))))

(defparameter *mini-kernel-whnf-lean-def-specs*
  '(("reduceNatRec"
     :header "def reduceNatRec (args : List CoreTerm) : CoreTerm :="
     :required-fragments ("if args.length < 4 then"
                          "ConstName.zero"
                          "ConstName.succ"
                          "CoreTerm.const ConstName.natRec"))
    ("reduceEqRec"
     :header "def reduceEqRec (args : List CoreTerm) : CoreTerm :="
     :required-fragments ("if args.length < 6 then"
                          "ConstName.refl"
                          "CoreTerm.const ConstName.eqRec"))
    ("whnf"
     :header "partial def whnf (t : CoreTerm) : CoreTerm :="
     :required-fragments ("| CoreTerm.letE v A body =>"
                          "| CoreTerm.app f a =>"
                          "| CoreTerm.const ConstName.add => whnf addValue"
                          "| CoreTerm.const ConstName.natRec, args => reduceNatRec args"
                          "| CoreTerm.const ConstName.eqRec, args => reduceEqRec args"))
    ("conv"
     :header "partial def conv (ctx : Context) (lhs rhs : CoreTerm) : Bool :="
     :required-fragments ("match whnf lhs, whnf rhs with"
                          "| CoreTerm.sort u, CoreTerm.sort v => u = v"
                          "| CoreTerm.app f a, CoreTerm.app g b =>"
                          "| CoreTerm.pi A B, CoreTerm.pi A' B' =>"
                          "| CoreTerm.lam A b, CoreTerm.lam A' b' =>"))
    ("checkSort"
     :header "def checkSort (ctx : Context) (t : CoreTerm) : Nat :="
     :required-fragments ("match whnf (infer ctx t) with"
                          "| CoreTerm.sort u => u"
                          "| ty => panic!"))
    ("infer"
     :header "partial def infer (ctx : Context) (t : CoreTerm) : CoreTerm :="
     :required-fragments ("| CoreTerm.sort u => CoreTerm.sort (u + 1)"
                          "| CoreTerm.var k =>"
                          "| CoreTerm.const c ls =>"
                          "| CoreTerm.pi A B =>"
                          "| CoreTerm.lam A b =>"
                          "| CoreTerm.app f a =>"
                          "| CoreTerm.letE v A body =>"))
    ("check"
     :header "partial def check (ctx : Context) (t expected : CoreTerm) : Bool :="
     :required-fragments ("conv ctx (infer ctx t) expected"))))

(defstruct (lean-def-function
            (:constructor %make-lean-def-function
                (&key name source-block source-digest evaluator)))
  name
  source-block
  source-digest
  evaluator)

(defstruct (lean-def-program
            (:constructor %make-lean-def-program
                (&key source-path source-digest functions)))
  source-path
  source-digest
  functions)

(defun %read-text-file (path)
  (with-open-file (stream path :direction :input)
    (let ((buffer (make-string (file-length stream))))
      (read-sequence buffer stream)
      buffer)))

(defun %string-prefix-p (prefix string)
  (and (<= (length prefix) (length string))
       (string= prefix string :end2 (length prefix))))

(defun %top-level-lean-def-line-p (line)
  (or (%string-prefix-p "def " line)
      (%string-prefix-p "partial def " line)))

(defun %trim-whitespace (string)
  (string-trim '(#\Space #\Tab #\Newline #\Return) string))

(defun %top-level-lean-line-p (line)
  (and (plusp (length line))
       (not (member (char line 0) '(#\Space #\Tab)))))

(defun %top-level-lean-stop-line-p (line)
  (and (%top-level-lean-line-p line)
       (or (%string-prefix-p "def " line)
           (%string-prefix-p "partial def " line)
           (%string-prefix-p "inductive " line)
           (%string-prefix-p "abbrev " line)
           (%string-prefix-p "theorem " line)
           (%string-prefix-p "axiom " line)
           (%string-prefix-p "structure " line)
           (%string-prefix-p "namespace " line)
           (%string-prefix-p "mutual" line)
           (%string-prefix-p "end" line))))

(defun %parse-lean-def-name (line)
  (let ((prefix (cond
                  ((%string-prefix-p "def " line) "def ")
                  ((%string-prefix-p "partial def " line) "partial def ")
                  (t nil))))
    (unless prefix
      (kernel-error "expected Lean def line, got ~S" line))
    (let* ((tail (subseq line (length prefix)))
           (stop (or (position-if (lambda (char)
                                    (member char '(#\Space #\( #\: #\=)))
                                  tail)
                     (length tail))))
      (subseq tail 0 stop))))

(defun %split-lines (source)
  (with-input-from-string (stream source)
    (loop for line = (read-line stream nil nil)
          while line
          collect line)))

(defun %join-lines (lines)
  (with-output-to-string (stream)
    (dolist (line lines)
      (write-string line stream)
      (terpri stream))))

(defun %collect-top-level-lean-def-blocks (source)
  (let ((blocks '())
        (current-name nil)
        (current-lines '()))
    (labels ((finish-current ()
               (when current-name
                 (push (cons current-name (%join-lines (nreverse current-lines))) blocks)
                 (setf current-name nil
                       current-lines '())))
             (start-current (line)
               (setf current-name (%parse-lean-def-name line)
                     current-lines (list line))))
      (dolist (line (%split-lines source))
        (cond
          ((and (null current-name)
                (%top-level-lean-line-p line)
                (%top-level-lean-def-line-p line))
           (start-current line))
          ((and current-name
                (%top-level-lean-stop-line-p line))
           (finish-current)
           (when (%top-level-lean-def-line-p line)
             (start-current line)))
          (current-name
           (push line current-lines))
          (t nil)))
      (finish-current))
    (nreverse blocks)))

(defun %find-lean-def-block (blocks name)
  (cdr (assoc name blocks :test #'string=)))

(defun %validate-lean-def-block (name block specs)
  (let ((spec (assoc name specs :test #'string=)))
    (unless spec
      (kernel-error "no Lean def ingestion spec registered for ~S" name))
    (let ((header (getf (rest spec) :header))
          (required-fragments (getf (rest spec) :required-fragments)))
      (unless block
        (kernel-error "missing Lean def block for ~A" name))
      (unless (%string-prefix-p header (%trim-whitespace block))
        (kernel-error "Lean def block header mismatch for ~A~%expected prefix: ~A~%actual block: ~A"
                      name header block))
      (dolist (fragment required-fragments)
        (unless (search fragment block)
          (kernel-error "Lean def block for ~A is missing required fragment ~S"
                        name fragment)))
      block)))

(defun %normalize-ingested-def-name (name)
  (etypecase name
    (string name)
    (symbol (string name))))

(defun %lookup-ingested-option-value (option)
  (and (consp option)
       (eq (first option) :some)
       (second option)))

(defun %make-ingested-some (value)
  (list :some value))

(defun %ingested-shiftIndex (_program delta k cutoff)
  (declare (ignore _program))
  (if (< k cutoff)
      k
      (if (>= delta 0)
          (+ k delta)
          (max 0 (- k (- delta))))))

(defun %ingested-shift (program delta cutoff term)
  (case (term-tag term)
    (:sort
     term)
    (:var
     (mk-var (call-ingested-lean-def program "shiftIndex"
                                     delta
                                     (second term)
                                     cutoff)))
    (:const
     term)
    (:app
     (mk-app (call-ingested-lean-def program "shift" delta cutoff (second term))
             (call-ingested-lean-def program "shift" delta cutoff (third term))))
    (:lam
     (mk-lam (call-ingested-lean-def program "shift" delta cutoff (second term))
             (call-ingested-lean-def program "shift" delta (1+ cutoff) (third term))))
    (:pi
     (mk-pi (call-ingested-lean-def program "shift" delta cutoff (second term))
            (call-ingested-lean-def program "shift" delta (1+ cutoff) (third term))))
    (:let
     (mk-let (call-ingested-lean-def program "shift" delta cutoff (second term))
             (call-ingested-lean-def program "shift" delta cutoff (third term))
             (call-ingested-lean-def program "shift" delta (1+ cutoff) (fourth term))))
    (otherwise
     (kernel-error "unknown term in ingested Lean shift: ~S" term))))

(defun %ingested-subst (program j replacement term)
  (case (term-tag term)
    (:sort
     term)
    (:var
     (if (= (second term) j)
         replacement
         term))
    (:const
     term)
    (:app
     (mk-app (call-ingested-lean-def program "subst" j replacement (second term))
             (call-ingested-lean-def program "subst" j replacement (third term))))
    (:lam
     (mk-lam (call-ingested-lean-def program "subst" j replacement (second term))
             (call-ingested-lean-def program
                                     "subst"
                                     (1+ j)
                                     (call-ingested-lean-def program
                                                             "shift"
                                                             1
                                                             0
                                                             replacement)
                                     (third term))))
    (:pi
     (mk-pi (call-ingested-lean-def program "subst" j replacement (second term))
            (call-ingested-lean-def program
                                    "subst"
                                    (1+ j)
                                    (call-ingested-lean-def program
                                                            "shift"
                                                            1
                                                            0
                                                            replacement)
                                    (third term))))
    (:let
     (mk-let (call-ingested-lean-def program "subst" j replacement (second term))
             (call-ingested-lean-def program "subst" j replacement (third term))
             (call-ingested-lean-def program
                                     "subst"
                                     (1+ j)
                                     (call-ingested-lean-def program
                                                             "shift"
                                                             1
                                                             0
                                                             replacement)
                                     (fourth term))))
    (otherwise
     (kernel-error "unknown term in ingested Lean subst: ~S" term))))

(defun %ingested-instantiate (program body arg)
  (call-ingested-lean-def program
                          "shift"
                          -1
                          0
                          (call-ingested-lean-def program
                                                  "subst"
                                                  0
                                                  (call-ingested-lean-def program
                                                                          "shift"
                                                                          1
                                                                          0
                                                                          arg)
                                                  body)))

(defun %ingested-lookup (program ctx k)
  (cond
    ((null ctx)
     nil)
    ((zerop k)
     (%make-ingested-some
      (call-ingested-lean-def program "shift" 1 0 (first ctx))))
    (t
     (let ((mapped (%lookup-ingested-option-value
                    (call-ingested-lean-def program "lookup" (rest ctx) (1- k)))))
       (and mapped
            (%make-ingested-some
             (call-ingested-lean-def program "shift" 1 0 mapped)))))))

(defun %lean-def-evaluator-symbol (name)
  (cond
    ((string= name "shiftIndex") '%ingested-shiftIndex)
    ((string= name "shift") '%ingested-shift)
    ((string= name "subst") '%ingested-subst)
    ((string= name "instantiate") '%ingested-instantiate)
    ((string= name "lookup") '%ingested-lookup)
    ((string= name "reduceNatRec") '%ingested-reduceNatRec)
    ((string= name "reduceEqRec") '%ingested-reduceEqRec)
    ((string= name "whnf") '%ingested-whnf)
    ((string= name "conv") '%ingested-conv)
    ((string= name "checkSort") '%ingested-checkSort)
    ((string= name "infer") '%ingested-infer)
    ((string= name "check") '%ingested-check)
    (t
     (kernel-error "no ingested Lean evaluator registered for ~S" name))))

(defun validate-lean-def-program (program)
  (unless (typep program 'lean-def-program)
    (kernel-error "expected Lean def program, got ~S" program))
  (unless (pathnamep (lean-def-program-source-path program))
    (kernel-error "Lean def program source-path must be a pathname, got ~S"
                  (lean-def-program-source-path program)))
  (unless (listp (lean-def-program-functions program))
    (kernel-error "Lean def program functions must be a list, got ~S"
                  (lean-def-program-functions program)))
  (dolist (function (lean-def-program-functions program))
    (unless (typep function 'lean-def-function)
      (kernel-error "Lean def program contains non-function entry: ~S" function))
    (unless (stringp (lean-def-function-name function))
      (kernel-error "Lean def function name must be a string, got ~S"
                    (lean-def-function-name function)))
    (unless (stringp (lean-def-function-source-block function))
      (kernel-error "Lean def function source block must be a string, got ~S"
                    (lean-def-function-source-block function)))
    (unless (or (functionp (lean-def-function-evaluator function))
                (and (symbolp (lean-def-function-evaluator function))
                     (fboundp (lean-def-function-evaluator function))))
      (kernel-error "Lean def function evaluator must name a function, got ~S"
                    (lean-def-function-evaluator function))))
	  program)

(defun %missing-lean-def-block-name (blocks specs)
  (loop for spec in specs
        for name = (first spec)
        unless (%find-lean-def-block blocks name)
          do (return name)))

(defun %ingest-lean-def-program (path specs)
  (let* ((path* (pathname path))
         (source (%read-text-file path*))
         (blocks (%collect-top-level-lean-def-blocks source))
         (missing (%missing-lean-def-block-name blocks specs))
         (functions '()))
    (when (and missing
               (equal path* (pathname *mini-kernel-whnf-lean-source-path*))
               (equal specs *mini-kernel-whnf-lean-def-specs*))
      (generate-lean-whnf-program path*)
      (setf source (%read-text-file path*)
            blocks (%collect-top-level-lean-def-blocks source)
            missing (%missing-lean-def-block-name blocks specs)))
    (when missing
      (kernel-error "missing Lean def block for ~A" missing))
    (dolist (spec specs)
      (let* ((name (first spec))
             (block (%validate-lean-def-block name (%find-lean-def-block blocks name) specs)))
        (push (%make-lean-def-function
               :name name
               :source-block block
               :source-digest (artifact-digest block)
               :evaluator (%lean-def-evaluator-symbol name))
              functions)))
    (validate-lean-def-program
     (%make-lean-def-program
      :source-path path*
      :source-digest (artifact-digest source)
      :functions (nreverse functions)))))

(defun ingest-declarativecore-def-program
    (&optional (path *declarativecore-lean-def-source-path*))
  (%ingest-lean-def-program path *declarativecore-lean-def-specs*))

(defun generate-lean-whnf-program
    (&optional (path *mini-kernel-whnf-lean-source-path*))
  (let ((path* (pathname path)))
    (ensure-directories-exist path*)
    (with-open-file (stream path* :direction :output :if-exists :supersede
                               :if-does-not-exist :create)
      (format stream "import Formal.DeclarativeCore~%~%")
      (format stream "open DeclarativeCore~%~%")
      (format stream "namespace MiniKernelGeneratedWhnf~%~%")
      (format stream "def reduceNatRec (args : List CoreTerm) : CoreTerm :=~%")
      (format stream "  if args.length < 4 then~%")
      (format stream "    List.foldl CoreTerm.app (CoreTerm.const ConstName.natRec) args~%")
      (format stream "  else~%")
      (format stream "    match args with~%")
      (format stream "    | P :: z :: s :: n :: rest =>~%")
      (format stream "        match whnf n with~%")
      (format stream "        | CoreTerm.const ConstName.zero => List.foldl CoreTerm.app z rest~%")
      (format stream "        | CoreTerm.app (CoreTerm.const ConstName.succ) k =>~%")
      (format stream "            let recCall := List.foldl CoreTerm.app (CoreTerm.const ConstName.natRec) [P, z, s, k]~%")
      (format stream "            whnf (List.foldl CoreTerm.app (CoreTerm.app (CoreTerm.app s k) recCall) rest)~%")
      (format stream "        | n' => List.foldl CoreTerm.app (CoreTerm.const ConstName.natRec) (P :: z :: s :: n' :: rest)~%")
      (format stream "    | _ => List.foldl CoreTerm.app (CoreTerm.const ConstName.natRec) args~%~%")
      (format stream "def reduceEqRec (args : List CoreTerm) : CoreTerm :=~%")
      (format stream "  if args.length < 6 then~%")
      (format stream "    List.foldl CoreTerm.app (CoreTerm.const ConstName.eqRec) args~%")
      (format stream "  else~%")
      (format stream "    match args with~%")
      (format stream "    | A :: a :: P :: pr :: rhs :: equality :: rest =>~%")
      (format stream "        match whnf equality with~%")
      (format stream "        | CoreTerm.app (CoreTerm.app (CoreTerm.const ConstName.refl) _) _ =>~%")
      (format stream "            whnf (List.foldl CoreTerm.app pr rest)~%")
      (format stream "        | equality' => List.foldl CoreTerm.app (CoreTerm.const ConstName.eqRec) (A :: a :: P :: pr :: rhs :: equality' :: rest)~%")
      (format stream "    | _ => List.foldl CoreTerm.app (CoreTerm.const ConstName.eqRec) args~%~%")
      (format stream "partial def whnf (t : CoreTerm) : CoreTerm :=~%")
      (format stream "  match t with~%")
      (format stream "  | CoreTerm.letE v A body => whnf (instantiate body v)~%")
      (format stream "  | CoreTerm.app f a =>~%")
      (format stream "      let rec collectApps : CoreTerm → List CoreTerm → CoreTerm × List CoreTerm~%")
      (format stream "        | CoreTerm.app f a, args => collectApps f (a :: args)~%")
      (format stream "        | head, args => (head, args)~%")
      (format stream "      let (head, args) := collectApps t []~%")
      (format stream "      let rec reduceHead : CoreTerm → List CoreTerm → CoreTerm~%")
      (format stream "        | head, [] => head~%")
      (format stream "        | CoreTerm.letE v A body, args => whnf (List.foldl CoreTerm.app (instantiate body v) args)~%")
      (format stream "        | CoreTerm.lam A body, arg :: rest => whnf (List.foldl CoreTerm.app (instantiate body arg) rest)~%")
      (format stream "        | CoreTerm.const ConstName.natRec, args => reduceNatRec args~%")
      (format stream "        | CoreTerm.const ConstName.eqRec, args => reduceEqRec args~%")
      (format stream "        | head, args => List.foldl CoreTerm.app head args~%")
      (format stream "      reduceHead (whnf head) args~%")
      (format stream "  | CoreTerm.const ConstName.add => whnf addValue~%")
      (format stream "  | _ => t~%~%")
      (format stream "partial def conv (ctx : Context) (lhs rhs : CoreTerm) : Bool :=~%")
      (format stream "  match whnf lhs, whnf rhs with~%")
      (format stream "  | CoreTerm.sort u, CoreTerm.sort v => u = v~%")
      (format stream "  | CoreTerm.var k, CoreTerm.var l => k = l~%")
      (format stream "  | CoreTerm.const c ls, CoreTerm.const c' ls' => c = c' && ls = ls'~%")
      (format stream "  | CoreTerm.app f a, CoreTerm.app g b => conv ctx f g && conv ctx a b~%")
      (format stream "  | CoreTerm.pi A B, CoreTerm.pi A' B' => conv ctx A A' && conv (A :: ctx) B B'~%")
      (format stream "  | CoreTerm.lam A b, CoreTerm.lam A' b' => conv ctx A A' && conv (A :: ctx) b b'~%")
      (format stream "  | _, _ => false~%~%")
      (format stream "def checkSort (ctx : Context) (t : CoreTerm) : Nat :=~%")
      (format stream "  match whnf (infer ctx t) with~%")
      (format stream "  | CoreTerm.sort u => u~%")
      (format stream "  | ty => panic! s!\"expected sort, got {ty}\"~%~%")
      (format stream "partial def infer (ctx : Context) (t : CoreTerm) : CoreTerm :=~%")
      (format stream "  match t with~%")
      (format stream "  | CoreTerm.sort u => CoreTerm.sort (u + 1)~%")
      (format stream "  | CoreTerm.var k => match lookup ctx k with | some A => A | none => panic! s!\"unbound var {k}\"~%")
      (format stream "  | CoreTerm.const c ls => instantiateLevels (constType c) ls~%")
      (format stream "  | CoreTerm.pi A B => CoreTerm.sort (max (checkSort ctx A) (checkSort (A :: ctx) B))~%")
      (format stream "  | CoreTerm.lam A b => CoreTerm.pi A (infer (A :: ctx) b)~%")
      (format stream "  | CoreTerm.app f a =>~%")
      (format stream "      match whnf (infer ctx f) with~%")
      (format stream "      | CoreTerm.pi A B => if check ctx a A then instantiate B a else panic! \"argument type mismatch\"~%")
      (format stream "      | ty => panic! s!\"application of non-function {ty}\"~%")
      (format stream "  | CoreTerm.letE v A body =>~%")
      (format stream "      if check ctx v A then instantiate (infer (A :: ctx) body) v else panic! \"let value type mismatch\"~%~%")
      (format stream "partial def check (ctx : Context) (t expected : CoreTerm) : Bool :=~%")
      (format stream "  conv ctx (infer ctx t) expected~%~%")
      (format stream "end MiniKernelGeneratedWhnf~%"))
    path*))

(defun ingest-mini-kernel-whnf-program
    (&optional (path (generate-lean-whnf-program)))
  (%ingest-lean-def-program path *mini-kernel-whnf-lean-def-specs*))

(defun find-ingested-lean-def-function (program name)
  (validate-lean-def-program program)
  (find (%normalize-ingested-def-name name)
        (lean-def-program-functions program)
        :key #'lean-def-function-name
        :test #'string=))

(defun list-ingested-lean-def-functions (program)
  (validate-lean-def-program program)
  (copy-list (lean-def-program-functions program)))

(defun call-ingested-lean-def (program name &rest args)
  (let ((function (find-ingested-lean-def-function program name)))
    (unless function
      (kernel-error "unknown ingested Lean def function: ~S" name))
    (apply (if (symbolp (lean-def-function-evaluator function))
               (symbol-function (lean-def-function-evaluator function))
               (lean-def-function-evaluator function))
           program
           args)))

(defun %ingested-defir-support-functions (function-names)
  (let ((names (copy-list function-names)))
    (when (member "whnf" names :test #'string=)
      (pushnew "reduceHead" names :test #'string=))
    names))

(defun lower-ingested-lean-def-program-to-defir
    (program &key metadata)
  (validate-lean-def-program program)
  (let ((function-names (%ingested-defir-support-functions
                         (mapcar #'lean-def-function-name
                                 (lean-def-program-functions program)))))
    (make-mini-kernel-defir-program
     :function-names function-names
     :metadata (append metadata
                       (list :ingested-source-path
                             (lean-def-program-source-path program)
                             :ingested-source-digest
                             (lean-def-program-source-digest program)
                             :ingested-function-count
                             (length function-names))))))

(defun %ingested-reduceNatRec (program env args)
  (if (< (length args) 4)
      (rebuild-apps (mk-const 'nat-rec) args)
      (destructuring-bind (motive base step n &rest rest) args
        (let ((n* (call-ingested-lean-def program "whnf" env n)))
          (cond
            ((equal n* (mk-const 'zero))
             (call-ingested-lean-def program "whnf" env (rebuild-apps base rest)))
            ((and (eq (term-tag n*) :app)
                  (equal (second n*) (mk-const 'succ)))
             (let* ((k (third n*))
                    (rec-call (rebuild-apps (mk-const 'nat-rec)
                                            (list motive base step k)))
                    (step-app (app* step (list k rec-call))))
               (call-ingested-lean-def program "whnf" env (rebuild-apps step-app rest))))
            (t
             (rebuild-apps (mk-const 'nat-rec)
                           (append (list motive base step n*) rest))))))))

(defun %ingested-reduceEqRec (program env args)
  (if (< (length args) 6)
      (rebuild-apps (mk-const 'eq-rec) args)
      (destructuring-bind (type lhs motive proof rhs equality &rest rest) args
        (let ((equality* (call-ingested-lean-def program "whnf" env equality)))
          (if (and (eq (term-tag equality*) :app)
                   (eq (term-tag (second equality*)) :app)
                   (equal (second (second equality*)) (mk-const 'refl)))
              (call-ingested-lean-def program "whnf" env (rebuild-apps proof rest))
              (rebuild-apps (mk-const 'eq-rec)
                            (append (list type lhs motive proof rhs equality*)
                                    rest)))))))

(defun %ingested-whnf (program env term)
  (labels ((reduce-term (current)
             (case (term-tag current)
               (:let
                (reduce-term (subst-top (second current) (fourth current))))
               (:app
                (multiple-value-bind (head args)
                    (app-head+args current)
                  (reduce-head (reduce-term head) args)))
               (:const
                (let* ((name (second current))
                       (levels (third current))
                       (decl (and env (env-lookup env name))))
                  (if (and decl
                           (eq (decl-kind decl) :def)
                           (decl-reduciblep decl))
                      (reduce-term (instantiate-levels (decl-value decl) levels))
                      current)))
               (otherwise
                current)))
           (reduce-head (head args)
             (cond
               ((null args)
                head)
               ((eq (term-tag head) :let)
                (reduce-term
                 (rebuild-apps (subst-top (second head) (fourth head)) args)))
               ((eq (term-tag head) :lam)
               (reduce-term
                 (rebuild-apps (subst-top (first args) (third head))
                               (rest args))))
               ((and (eq (term-tag head) :const)
                     (eq (second head) 'nat-rec))
                (call-ingested-lean-def program "reduceNatRec" env args))
               ((and (eq (term-tag head) :const)
                     (eq (second head) 'eq-rec))
                (call-ingested-lean-def program "reduceEqRec" env args))
               (t
                (rebuild-apps head args)))))
    (reduce-term term)))

(defun %ingested-conv (program env ctx lhs rhs)
  (let ((lhs* (call-ingested-lean-def program "whnf" env lhs))
        (rhs* (call-ingested-lean-def program "whnf" env rhs)))
    (case (term-tag lhs*)
      (:sort
       (and (eq (term-tag rhs*) :sort)
            (= (second lhs*) (second rhs*))))
      (:var
       (and (eq (term-tag rhs*) :var)
            (= (second lhs*) (second rhs*))))
      (:const
       (and (eq (term-tag rhs*) :const)
            (eq (second lhs*) (second rhs*))
            (equal (third lhs*) (third rhs*))))
      (:app
       (and (eq (term-tag rhs*) :app)
            (call-ingested-lean-def program "conv" env ctx (second lhs*) (second rhs*))
            (call-ingested-lean-def program "conv" env ctx (third lhs*) (third rhs*))))
      (:pi
       (and (eq (term-tag rhs*) :pi)
            (call-ingested-lean-def program "conv" env ctx (second lhs*) (second rhs*))
            (call-ingested-lean-def program
                                    "conv"
                                    env
                                    (cons (second lhs*) ctx)
                                    (third lhs*)
                                    (third rhs*))))
      (:lam
       (and (eq (term-tag rhs*) :lam)
            (call-ingested-lean-def program "conv" env ctx (second lhs*) (second rhs*))
            (call-ingested-lean-def program
                                    "conv"
                                    env
                                    (cons (second lhs*) ctx)
                                    (third lhs*)
                                    (third rhs*))))
      (otherwise
       nil))))

(defun %ingested-checkSort (program env ctx term)
  (let ((type (call-ingested-lean-def program "whnf" env
                                      (call-ingested-lean-def program "infer" env ctx term))))
    (if (eq (term-tag type) :sort)
        (second type)
        (kernel-error "expected a sort, got ~S" type))))

(defun %ingested-infer (program env ctx term)
  (case (term-tag term)
    (:sort
     (mk-sort (1+ (second term))))
    (:var
     (ctx-lookup ctx (second term)))
    (:const
     (let ((decl (env-lookup env (second term))))
       (unless decl
         (kernel-error "unknown constant: ~A" (second term)))
       (instantiate-levels (decl-type decl) (third term))))
    (:pi
     (mk-sort (max (call-ingested-lean-def program "checkSort" env ctx (second term))
                   (call-ingested-lean-def program
                                           "checkSort"
                                           env
                                           (cons (second term) ctx)
                                           (third term)))))
    (:lam
     (call-ingested-lean-def program "checkSort" env ctx (second term))
     (mk-pi (second term)
            (call-ingested-lean-def program
                                    "infer"
                                    env
                                    (cons (second term) ctx)
                                    (third term))))
    (:app
     (let ((function-type (call-ingested-lean-def program
                                                  "whnf"
                                                  env
                                                  (call-ingested-lean-def program
                                                                          "infer"
                                                                          env
                                                                          ctx
                                                                          (second term)))))
       (if (eq (term-tag function-type) :pi)
           (progn
             (unless (call-ingested-lean-def program
                                             "check"
                                             env
                                             ctx
                                             (third term)
                                             (second function-type))
               (kernel-error "argument type mismatch"))
             (subst-top (third term) (third function-type)))
           (kernel-error "application of non-function: ~S" function-type))))
    (:let
     (call-ingested-lean-def program "checkSort" env ctx (third term))
     (unless (call-ingested-lean-def program "check" env ctx (second term) (third term))
       (kernel-error "let value type mismatch"))
     (subst-top (second term)
                (call-ingested-lean-def program
                                        "infer"
                                        env
                                        (cons (third term) ctx)
                                        (fourth term))))
    (otherwise
     (kernel-error "unknown term in ingested Lean infer: ~S" term))))

(defun %ingested-check (program env ctx term expected)
  (call-ingested-lean-def program
                          "conv"
                          env
                          ctx
                          (call-ingested-lean-def program "infer" env ctx term)
                          expected))

(defun check-ingested-lean-def-parity (program name &rest args)
  (let ((normalized-name (%normalize-ingested-def-name name)))
    (cond
      ((string= normalized-name "shiftIndex")
       (= (apply #'call-ingested-lean-def program normalized-name args)
          (let ((delta (first args))
                (k (second args))
                (cutoff (third args)))
            (if (< k cutoff)
                k
                (if (>= delta 0)
                    (+ k delta)
                    (max 0 (- k (- delta))))))))
      ((string= normalized-name "shift")
       (with-kernel-implementation ((native-kernel-implementation))
         (equal (apply #'call-ingested-lean-def program normalized-name args)
                (apply #'shift args))))
      ((string= normalized-name "subst")
       (with-kernel-implementation ((native-kernel-implementation))
         (equal (apply #'call-ingested-lean-def program normalized-name args)
                (apply #'subst args))))
      ((string= normalized-name "instantiate")
       (with-kernel-implementation ((native-kernel-implementation))
         (equal (apply #'call-ingested-lean-def program normalized-name args)
                (subst-top (second args) (first args)))))
      ((string= normalized-name "lookup")
       (with-kernel-implementation ((native-kernel-implementation))
         (let ((actual (apply #'call-ingested-lean-def program normalized-name args)))
           (handler-case
               (equal actual
                      (%make-ingested-some
                       (ctx-lookup (first args) (second args))))
             (kernel-error ()
               (null actual))))))
      ((string= normalized-name "reduceNatRec")
       (with-kernel-implementation ((native-kernel-implementation))
         (let ((env (make-bootstrap-env)))
           (equal (apply #'call-ingested-lean-def program normalized-name env args)
                  (reduce-nat-rec env '() (first args))))))
      ((string= normalized-name "reduceEqRec")
       (with-kernel-implementation ((native-kernel-implementation))
         (let ((env (make-bootstrap-env)))
           (equal (apply #'call-ingested-lean-def program normalized-name env args)
                  (reduce-eq-rec env '() (first args))))))
      ((string= normalized-name "whnf")
       (with-kernel-implementation ((native-kernel-implementation))
         (let ((env (make-bootstrap-env)))
           (equal (apply #'call-ingested-lean-def program normalized-name env args)
                  (whnf env (first args))))))
      ((string= normalized-name "conv")
       (with-kernel-implementation ((native-kernel-implementation))
         (let ((env (make-bootstrap-env)))
           (equal (apply #'call-ingested-lean-def program normalized-name env args)
                  (conv? env (first args) (second args) (third args))))))
      ((string= normalized-name "infer")
       (with-kernel-implementation ((native-kernel-implementation))
         (let ((env (make-bootstrap-env)))
           (equal (apply #'call-ingested-lean-def program normalized-name env args)
                  (infer env (first args) (second args))))))
      ((string= normalized-name "check")
       (with-kernel-implementation ((native-kernel-implementation))
         (let ((env (make-bootstrap-env)))
           (equal (apply #'call-ingested-lean-def program normalized-name env args)
                  (handler-case
                      (progn
                        (check env (first args) (second args) (third args))
                        t)
                    (kernel-error ()
                      nil))))))
      (t
       (kernel-error "no parity relation registered for ingested Lean def ~S"
                     name)))))
