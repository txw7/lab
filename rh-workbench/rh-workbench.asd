(asdf:defsystem "rh-workbench"
  :description "Riemann-hypothesis domain adapter for the generic theorem workbench"
  :version "1.0.0"
  :depends-on ("theorem-workbench" "formal-math")
  :serial t
  :components
  ((:file "package")
   (:file "core")))

(asdf:defsystem "rh-workbench/tests"
  :depends-on ("rh-workbench")
  :serial t
  :components ((:file "tests")))
