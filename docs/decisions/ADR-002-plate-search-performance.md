# ADR-002 — Plate search performance

**Status** Accepted
**Date** 2026-09-08
**Phase** 0 (defect found), fixes a requirement owned by Phase 10
**Supersedes** nothing
**Amends** `packages/core/src/mess/recommend.ts` only
**Sources** MASTER-SPEC.md §15.1 (plate recommender), §31 Phase 10 (<100ms)

---

## Context

Completing the fixture set in Phase 0 added the two women's-hostel endpoints.
The women's special mess lunch of 2026-09-01 became the first real menu to
produce **9 plate candidates**; every fixture before it produced 6.

Nine candidates enumerate **7,374 serving combinations** against 574 for six.
That is roughly 13× the search space — but it took roughly 300× the time. The
recommender did not merely get slower, it fell off a cliff, and the test suite
went from 2s to 39s on the strength of a single test.

Spec §31 Phase 10 requires plate recommendation to complete in **under 100ms**.
The implementation could not meet that on a real, ordinary mess menu.

This was found in Phase 0 because the fixture landed in Phase 0. The
requirement it violates belongs to Phase 10.

## The defects

Both are in `suggestPlates`. Neither is in the search itself — the bounded DFS,
the calorie pruning, the serving caps and the scoring were all correct and are
untouched.

### 1. Quadratic dedupe

```ts
results
  .sort((a, b) => b.score - a.score)
  .filter((plate, i, all) => {
    const key = (p: PlateSuggestion): string =>
      p.items.map((it) => `${it.dishId}x${it.servings}`).sort().join('|');
    return all.findIndex((other) => key(other) === key(plate)) === i;
  })
```

`filter` runs `findIndex` for every element, and `findIndex` rebuilds the key
string on **both** sides of every comparison. Each key build is itself a `map`,
a `sort` and a `join`. At n = 7,374 that is on the order of 5×10⁷ key
constructions to remove a handful of duplicates.

### 2. Reasons built for results that are then thrown away

`buildReasons` ran inside the terminal branch of the search, so a reason set was
constructed for every one of the 7,374 combinations. At most 3 are ever
returned. Over 99.9% of that work was discarded — and `buildReasons` does string
interpolation and an array `find` on each call.

## Decision

Fix both, changing nothing observable.

- **Dedupe with a `Set`, computing each key exactly once.** Walking the
  already-sorted list and keeping the first plate per distinct key is precisely
  what `filter(... findIndex(...) === i)` computed, because `findIndex` returns
  the first match and `Array.prototype.sort` is stable. The length guard is
  placed before the push so `maxResults <= 0` still returns an empty list,
  matching the old trailing `.slice(0, maxResults)`.
- **Defer `buildReasons` until after the survivors are chosen.** The search now
  accumulates an internal `ScoredPlate` that carries `chosen` (the dishes) but
  no reasons; reasons are built in a final `map` over at most `maxResults`
  plates.

Scoring, candidate selection, serving caps and pruning are **not** touched.

## Results

Measured 2026-09-08, Node 26.3.1, median of 5 runs after one warm-up:

| Menu | Candidates | Combinations | Before | After | Speedup |
|---|---|---|---|---|---|
| Men's veg lunch (existing fixture) | 6 | 574 | 152ms | **0.8ms** | 189× |
| Women's non-veg dinner (existing) | 6 | 574 | 170ms | **0.9ms** | 181× |
| **Women's special lunch (the trigger)** | **9** | **7,374** | **89,629ms** | **16.1ms** | **5,572×** |
| Women's veg lunch | 7 | 1,454 | 1,272ms | **1.7ms** | 771× |

All four are inside the 100ms Phase 10 budget, with the worst case at 16.1ms —
about six times under it.

> The original single-shot measurement on 2026-09-07 recorded 38,803ms for the
> 9-candidate menu. The 89,629ms above is the median of five consecutive runs,
> where accumulated GC pressure from repeatedly allocating ~7,374 discarded
> reason sets makes each run cost more than the first. Both numbers describe the
> same defect; the second is the more representative one, and neither is close
> to 100ms.

Full core suite: **101 tests passing, unchanged**. `test/mess.test.ts` fell from
38,718ms to 112ms.

## Verifying that nothing changed but the cost

Tests passing is necessary but not sufficient — the suite could be blind to an
ordering change. So the previous implementation was restored alongside the new
one and both were run over the same four menus, comparing serialised output:

```
Output byte-identical to the previous implementation on all four menus.
```

That is the actual evidence for "behaviour-preserving". The comparison harness
was temporary and is not committed.

## Consequences

**Good**
- A real §31 Phase 10 acceptance criterion is now met, ahead of Phase 10.
- The core test suite runs in ~3s rather than ~40s, so nobody is tempted to
  skip it locally.
- Phase 10 can spend its budget on the scoring work it is actually for —
  carb/fat gap terms, variety, budget tier, meal timing — rather than on
  firefighting.

**Bad / accepted**
- `suggestPlates` now carries an internal `ScoredPlate` type distinct from the
  public `PlateSuggestion`. That is a little more machinery in exchange for not
  computing explanations nobody reads.

**Watch**
- The cost is still exponential in candidate count; this fix removed the
  quadratic factors on top of it. `selectCandidates` caps candidates at 9, and
  that cap is now load-bearing for performance, not just for plate realism. A
  future change that raises it must re-measure.
- The expensive fixture and its test are kept deliberately as the canary. See
  the comment at that test site.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Shrink the test input so the suite is fast | Hides the only evidence the recommender does not scale |
| Memoise the key on `PlateSuggestion` | Still O(n²) comparisons; the allocation stays |
| Cap `results` during the search | Changes which plates survive — not behaviour-preserving |
| Leave it for Phase 10 | A 39s suite gets skipped, and the defect is a two-line fix |
