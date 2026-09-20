/**
 * Drop keys whose value is `undefined`, so a Zod-parsed partial (where an
 * omitted optional field is `undefined`) can be handed to a Drizzle `set`
 * (where `undefined` would be a type error under exactOptionalPropertyTypes,
 * and at runtime would mean "do not touch" only by accident).
 */
export function stripUndefined<T extends object>(obj: T): { [K in keyof T]-?: Exclude<T[K], undefined> } {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(obj)) if (v !== undefined) out[k] = v;
  return out as { [K in keyof T]-?: Exclude<T[K], undefined> };
}
