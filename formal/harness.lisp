(load "package.lisp")

(defparameter *mini-kernel-load-order*
  '("json-lite.lisp"
    "backend-protocol.lisp"
    "stage-ir.lisp"
    "advisory-artifacts.lisp"
    "checked-proposals.lisp"
    "def-ir.lisp"
    "checker-implementation.lisp"
    "certificate.lisp"
    "proof-ir.lisp"
    "theorem-ir.lisp"
    "theorem-proof.lisp"
    "lean-schema.lisp"
    "lean-ingest.lisp"
    "certificate-corpus.lisp"
    "ast.lisp"
    "term-env.lisp"
    "subst.lisp"
    "lean-def-ingest.lisp"
    "scripted-alignment.lisp"
    "reduce.lisp"
    "typecheck.lisp"
    "bootstrap.lisp"
    "reference-checker.lisp"
    "frontend.lisp"
    "normalize.lisp"
    "eval.lisp"
    "cnf.lisp"
    "sat-core.lisp"
    "bitblast.lisp"
    "solver-stub.lisp"
    "smtlib.lisp"
    "smt-spec.lisp"
    "cegis.lisp"
    "core-smt-ir.lisp"
    "mir-smt-specs.lisp"
    "external-ingest.lisp"
    "stage1-concept.lisp"
    "spec-core.lisp"
    "kernel-spec.lisp"
    "internal-audit.lisp"
    "search-protocol.lisp"
    "constitutional-runtime.lisp"
    "lsip-preparation.lisp"))

(defparameter *mini-kernel-test-files*
  '("kernel-tests.lisp"
    "reference-checker-tests.lisp"
    "proof-ir-tests.lisp"
    "theorem-ir-tests.lisp"
    "theorem-proof-tests.lisp"
    "lean-schema-tests.lisp"
    "lean-ingest-tests.lisp"
    "lean-def-ingest-tests.lisp"
    "def-ir-tests.lisp"
    "lean-whnf-ingest-tests.lisp"
    "checker-implementation-tests.lisp"
    "scripted-alignment-tests.lisp"
    "certificate-tests.lisp"
    "frontend-tests.lisp"
    "smt-tests.lisp"
    "smt-capability-tests.lisp"
    "smt-spec-tests.lisp"
    "cegis-tests.lisp"
    "kernel-spec-tests.lisp"
    "backend-protocol-tests.lisp"
    "stage1-concept-tests.lisp"
    "internal-audit-tests.lisp"
    "constitutional-runtime-tests.lisp"
    "search-protocol-tests.lisp"
    "lsip-preparation-tests.lisp"))

(defun load-mini-kernel-runtime ()
  (dolist (path *mini-kernel-load-order*)
    (load path))
  t)

(defun load-mini-kernel-tests ()
  (load-mini-kernel-runtime)
  (dolist (path *mini-kernel-test-files*)
    (load path))
  t)

(defun run-all-mini-kernel-tests ()
  (load-mini-kernel-tests)
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-reference-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-proof-ir-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-theorem-ir-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-theorem-proof-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-lean-schema-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-lean-ingest-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-lean-def-ingest-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-def-ir-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-lean-whnf-ingest-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-checker-implementation-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-scripted-alignment-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-certificate-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-frontend-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-smt-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-smt-capability-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-smt-spec-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-cegis-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-backend-protocol-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-stage1-concept-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-internal-audit-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-constitutional-runtime-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-search-protocol-tests))
  (funcall (find-symbol "RUN-TESTS" :mini-kernel-lsip-preparation-tests))
  t)

(defun evaluate-closure-profile (profile-id)
  (load-mini-kernel-runtime)
  (mini-kernel:evaluate-metakernel-closure-profile profile-id))

(defun print-closure-profile-summary (profile-id)
  (let* ((result (evaluate-closure-profile profile-id))
         (artifacts (mini-kernel:backend-result-artifacts result)))
    (format t "~S~%" (list :profile-id profile-id
                           :status (mini-kernel:backend-result-status result)
                           :summary (getf artifacts :summary)))
    result))
