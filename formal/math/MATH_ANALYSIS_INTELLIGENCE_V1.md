# Mathematical Analysis Intelligence V1

Lab provides analysis primitives used by the search-intelligence layer without changing theorem authority.

## Implemented

- MathSubsumptionResultV1
- MathTheoremMatchV1
- MathAsymptoticRelationV1
- DominantBalanceV1
- MathExperimentV1
- MathFalsificationResultV1
- MathFalsificationProviderV1
- CounterexampleAnalysisV1
- RepairConditionCandidateV1

The first subsumption provider recognizes canonical expression equality and exact ordered-bound strengthening for the same variable and relation.

The theorem matcher classifies a matched conclusion and distinguishes already-discharged, incompatible, unknown, and genuinely new-subgoal hypotheses.

The falsification pipeline composes cheap providers and stops on a counterexample or domain error while retaining the provider trace.

## Authority boundary

Every object in this tranche has `proof-effect :none`.

No-counterexample-found is not proof.

A counterexample is evidence for search repair, not a direct theorem-status mutation. CounterexampleAnalysisV1 ranks candidate missing conditions by exclusion, positive-example preservation, simplicity, theorem compatibility, and formalizability.

An asymptotic or dominant-balance object is a candidate analysis result until checked by a formal provider.

Experiments guide search only.

Existing MathFormalProjectionLawV1 and FORMAL capability invocation remain the path to mathematical judgment.
