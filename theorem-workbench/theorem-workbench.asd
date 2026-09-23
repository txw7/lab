(asdf:defsystem "theorem-workbench"
  :description "Generic theorem-domain adapter layer over LSIP search and Lab FORMAL"
  :version "1.0.0"
  :depends-on ("formal-math")
  :serial t
  :components
  ((:file "package")
   (:file "core")
   (:file "topology-adapter")))

(asdf:defsystem "theorem-workbench/tests"
  :depends-on ("theorem-workbench")
  :serial t
  :components ((:file "tests")))
