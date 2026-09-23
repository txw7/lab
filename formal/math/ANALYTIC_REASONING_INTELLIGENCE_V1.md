# Analytic Reasoning Intelligence V1

This slice exposes analytic debt instead of allowing search transformations to assume it away.

Implemented:

- AnalyticSideConditionV1
- analytic-side-conditions-for-transformation-v1
- SaddleAnalysisV1

Supported side-condition kinds include absolute/uniform convergence, dominated convergence, local uniformity, holomorphic domains, pole exclusion, integrability, boundary decay, termwise differentiation/integration, contour admissibility, and distributional validity.

Supported transformation families generate the corresponding side-condition set for differentiation under integrals, limit/integral interchange, infinite-sum exchange, termwise integration, Fourier/Mellin inversion, contour displacement, improper integration by parts, and analytic continuation.

SaddleAnalysisV1 records a candidate stationary point, curvature, width, dominant region, tail estimate, and assumptions.

All carriers in this slice have proof-effect :none. Formal discharge remains separate.
