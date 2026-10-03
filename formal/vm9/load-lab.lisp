(require :asdf)
(defparameter *vm9-lab-source-root*
  (or (uiop:getenv "VM9_LAB_FORMAL_ROOT")
      (let* ((here (uiop:pathname-directory-pathname *load-truename*))
             (upstream (merge-pathnames "../" here)))
        (namestring (if (probe-file (merge-pathnames "package.lisp" upstream))
                        upstream (merge-pathnames "../../owners/lab/formal/" here))))))
(dolist (file '("package" "term-env" "backend-protocol" "advisory-artifacts"
                "checked-proposals" "checker-implementation" "subst" "reduce"
                "typecheck" "certificate" "proof-ir" "reference-checker" "bootstrap"))
  (load (merge-pathnames (concatenate 'string file ".lisp")
                        (pathname *vm9-lab-source-root*))))
