(asdf:defsystem "formal-math"
  :description "Scientific mathematics IR and FORMAL projection seam for Lab"
  :version "1.0.0"
  :serial t
  :components
  ((:file "package")
   (:file "core")
   (:file "math-subsumption")
   (:file "math-asymptotics")
   (:file "math-analytic-analysis")
   (:file "math-experiment-protocol")
   (:file "math-falsification")
   (:file "math-counterexample-analysis")
   (:file "math-theorem-match")
   (:file "projection")
   (:file "formal-native")
   (:file "research-wire")
   (:file "search-wire")))

(asdf:defsystem "formal-math/tests"
  :depends-on ("formal-math")
  :serial t
  :components ((:file "tests")))
