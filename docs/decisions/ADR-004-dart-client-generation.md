# ADR-004 — Dart API client: hand-written DTOs with a contract-conformance test, not openapi-generator

**Status** PROPOSED — awaiting the owner's decision (contract rule 4)
**Date** 2026-09-21
**Phase** 2
**Affects** MASTER-SPEC.md §7.1 ("API client: openapi-generator (Dart) — generated from backend OpenAPI, contracts can't drift")

---

## Context

§7.1 chooses `openapi-generator` for the Dart client, with the stated reason:
*contracts can't drift*. Phase 1 deferred it with one endpoint. Phase 2 has
fourteen operations, so it was tried for real on 2026-09-21 against the
committed `packages/contracts/openapi.json` with generator 7.14.0, target
`dart-dio`.

## What the generator actually produced

It ran cleanly (exit 0) and the output is unusable — not because of the
generator, but because of what the API emits.

**1. Every model is named after its route.** `fastify-type-provider-zod`
inlines each Zod schema into the operation that uses it. The document has
**zero** `components/schemas`. So the generator has nothing to name models
after except paths:

```
AuthSessionPost200ResponseUser
UserProfileGet200Response
OnboardingCompletePost200ResponseTargets
UserGoalGet200ResponseTargets
```

`UserProfile` — one contract type — became three unrelated Dart classes with
identical fields. `NutritionTargets` became two. Every new endpoint that
returns a profile will add another.

**2. The onboarding answer union is lost.** `onboardingAnswerSchema` is a Zod
discriminated union on `step`. It arrived as:

```dart
/// Any Of [OnboardingAnswerPostRequestAnyOf], [...AnyOf1], ... [...AnyOf5]
AnyOf get anyOf;
@BuiltValueSerializer(custom: true)
```

`built_value` has no discriminated-union support; the six screens' payloads
become `AnyOf`…`AnyOf5` with a hand-maintained custom serializer — which is
hand-written code with a worse name.

**3. A second modelling system.** The app already uses `freezed` for every
entity (§7.1 mandates it). `dart-dio` output is `built_value`, with its own
`build_runner` builders, serializers registry and immutability idiom.
Two systems for fourteen operations.

## The property §7.1 actually wants

"Contracts can't drift" is a *test*, not a *tool*. The question is whether a
Dart DTO can silently disagree with the OpenAPI document. It can be answered
mechanically without generating anything.

## Proposal

1. **Keep hand-written `freezed` DTOs** in `apps/mobile/lib/features/*/data/dtos/`,
   the pattern Phase 1 established. One modelling system; unions are real
   sealed classes.
2. **Add a contract-conformance test** to `apps/mobile/test/contracts/`. It
   reads `packages/contracts/openapi.json` at test time and, for each DTO the
   app declares as bound to an operation, asserts:
   - every key the DTO serialises is a property of the operation's schema;
   - every `required` property of the schema is a non-nullable DTO field;
   - every enum literal list in Dart equals the schema's `enum`.
   A change to any contract that the app has not matched fails `ci-mobile`.
   That is "cannot drift", enforced.
3. **Schedule the backend fix that would make generation viable** — emit
   named `components/schemas` from the API (`fastify-type-provider-zod`
   supports `createJsonSchemaTransformObject` with a schema registry) — as a
   Phase 3 task, because it improves the document for humans regardless.
   Revisit generation after that, with a generator that handles `oneOf` +
   discriminator properly (`dart` with `json_serializable` templates, or a
   freezed-targeting generator), *if* the conformance test proves
   insufficient in practice.

## Consequences

**If accepted:** §7.1's "API client" row changes to *hand-written DTOs +
OpenAPI conformance test*; the reason column ("contracts can't drift") is
preserved and now backed by a CI check rather than an assumption.

**If rejected:** the backend must first emit named components (Phase 3), then
a generated package with `built_value` sits alongside `freezed`, with a
mapping layer between generated wire types and domain entities, and the
onboarding union is hand-serialised anyway.

## What was done in Phase 2 pending the decision

Hand-written DTOs and the conformance test, per the proposal — because the
phase could not otherwise complete and it is the pattern already in the
codebase. If the owner rejects this ADR, the generated client replaces the
DTOs; the conformance test remains useful either way.
