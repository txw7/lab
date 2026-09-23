# Canonical Certificate Schema

This file freezes the canonical certificate carrier for the current Lisp kernel implementation `KL`.

Scope:

- current fixed configuration `π0`
- monomorphic universes
- explicit core terms only
- supported judgment kind: `:typing`
- intended consumers: current Lisp kernel `KL` and future reference checker `KR`

The target acceptance equation is:

```text
KL(c, π0) = accept  iff  J(c, π0)
KR(c, π0) = accept  iff  J(c, π0)
```

where `J` is the declarative typing judgment encoded by the frozen core calculus.

## Certificate Object

A canonical certificate is a record with these fields:

```text
schema_version : Nat
judgment_kind  : Keyword
context        : List(CoreTerm)
term           : CoreTerm
type           : CoreTerm
env_digest     : Digest
config_digest  : Digest
checker_ids    : List(Symbol)
metadata       : PropertyList
```

Current fixed values:

- `schema_version = 1`
- `judgment_kind = :typing`
- `config_digest = (:config-id :pi0
                    :universe-policy :monomorphic
                    :conversion :whnf-structural
                    :inductives (:nat :eq)
                    :levels :identity)`

## CoreTerm Grammar

The certificate carrier uses the same authoritative core grammar as the kernel:

```lisp
(:sort u)
(:var k)
(:const c levels)
(:app f a)
(:lam A body)
(:pi A B)
(:let v A body)
```

`context` stores local binder types innermost-first, matching the kernel convention.

## Intended Judgment

For a certificate `c`, the intended declarative reading is:

```text
c.context ⊢ c.term : c.type
```

under:

- global environment identified by `c.env_digest`
- fixed kernel configuration identified by `c.config_digest`

## Validation Rules

A certificate is well-formed only if:

1. `schema_version = 1`
2. `judgment_kind = :typing`
3. `context` is a list of core terms
4. `term` is a core term
5. `type` is a core term
6. `env_digest` is present
7. `config_digest` exactly matches the current frozen configuration for `π0`
8. `checker_ids` is a list, possibly empty

Well-formedness is not acceptance.
Acceptance still requires the kernel to check:

```text
check(env, context, term, type)
```

## Digests

This schema freezes the presence of digests even before cryptographic hashing is implemented.

- `env_digest` identifies the declaration environment the certificate expects
- `config_digest` identifies the metacompile and kernel configuration `π`

For the current codebase, digests are symbolic structural values, not hashed byte strings.
That is acceptable for the current audit stage because the goal is to freeze the carrier first.

## Checker IDs

`checker_ids` records provenance claims, not truth.

Examples:

```lisp
(kl)
(kr)
(kl kr)
```

These fields are metadata until a differential checking pipeline exists.

## Metadata

`metadata` is non-authoritative and may contain:

- corpus id
- source reference
- stage provenance
- explanatory tags

Kernel acceptance must not depend on metadata.

## Minimal Example

Theorem certificate for `Π n : Nat, Eq Nat n n` with proof `λ n, refl Nat n`:

```lisp
(:schema-version 1
 :judgment-kind :typing
 :context ()
 :term (:lam (:const nat ())
        (:app
         (:app (:const refl ()) (:const nat ()))
         (:var 0)))
 :type (:pi (:const nat ())
        (:app
         (:app
          (:app (:const eq ()) (:const nat ()))
          (:var 0))
         (:var 0)))
 :env-digest :bootstrap-v1
 :config-digest (:config-id :pi0
                 :universe-policy :monomorphic
                 :conversion :whnf-structural
                 :inductives (:nat :eq)
                 :levels :identity)
 :checker-ids (kl)
 :metadata (:corpus demo-proof))
```

## Immediate Use In Code

The executable schema for this document lives in:

- [certificate.lisp](/home/user0/FORMAL/certificate.lisp:1)

The current Lisp API is:

- `make-typing-certificate`
- `validate-certificate`
- `check-certificate`

## Next Step

Build the tiny reference checker `KR` against this exact carrier, not a looser one.
Then freeze an accepted/rejected certificate corpus and require exact `KR = KL` agreement under `π0`.
