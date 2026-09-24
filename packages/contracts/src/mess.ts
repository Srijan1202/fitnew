/**
 * VIT mess contracts (Phase 9, §14/§31). The app never sees MessIT's wire
 * format: the server mirrors it, parses it with packages/core, and serves
 * these normalised shapes. Every menu says how it was resolved (published,
 * inferred from the cycle, or unavailable) and how fresh the server's copy is.
 */
import { z } from 'zod';

import { dishSlugSchema, messCodeSchema, messDishNutritionSchema } from './mess-common.js';
import { mealSlotSchema } from './nutrition-log.js';
import { isoDateSchema } from './profile.js';

export * from './mess-common.js';

/** packages/core `DietClass`. `unknown` is deliberate: never shown as veg. */
export const DIET_CLASSES = ['veg', 'egg', 'nonveg', 'unknown'] as const;
export const dietClassSchema = z.enum(DIET_CLASSES);
export type DietClass = z.infer<typeof dietClassSchema>;

/** packages/core `DishRole`. */
export const DISH_ROLES = [
  'staple', 'protein', 'legume', 'vegetable', 'dairy', 'fruit', 'sweet', 'fried', 'beverage', 'condiment', 'other',
] as const;
export const dishRoleSchema = z.enum(DISH_ROLES);

export const MESS_PROVIDER_STATUSES = ['active', 'disabled'] as const;
export const messProviderSchema = z.object({
  slug: z.string().min(1),
  displayName: z.string().min(1),
  status: z.enum(MESS_PROVIDER_STATUSES),
});
export type MessProviderInfo = z.infer<typeof messProviderSchema>;

export const messProvidersResponseSchema = z.object({ items: z.array(messProviderSchema) });

export const MIRROR_ERRORS = ['unreachable', 'malformed'] as const;

/**
 * How fresh the server's copy of one endpoint is (owner D4/D19). MessIT has
 * no timestamp of its own; this is when WE last fetched it. `stale` = no
 * successful fetch in 24 h (or ever). `latestPublishedDate` is the last date
 * the stored copies publish.
 */
export const messFreshnessSchema = z.object({
  lastSuccessAt: z.string().datetime().nullable(),
  lastAttemptAt: z.string().datetime().nullable(),
  lastError: z.enum(MIRROR_ERRORS).nullable(),
  stale: z.boolean(),
  latestPublishedDate: isoDateSchema.nullable(),
});
export type MessFreshness = z.infer<typeof messFreshnessSchema>;

export const messSchema = z.object({
  code: messCodeSchema,
  providerSlug: z.string().min(1),
  hostelId: z.string().min(1),
  hostelLabel: z.string().min(1),
  messId: z.string().min(1),
  messLabel: z.string().min(1),
  servesNonVeg: z.boolean(),
  freshness: messFreshnessSchema,
});
export type Mess = z.infer<typeof messSchema>;

export const messesResponseSchema = z.object({
  provider: messProviderSchema,
  items: z.array(messSchema),
});
export type MessesResponse = z.infer<typeof messesResponseSchema>;

export const providerSlugParamsSchema = z.object({ slug: z.string().min(1).max(40) }).strict();

/** packages/core `MenuResolution` — surfaced, never hidden (§14.4). */
export const menuResolutionSchema = z.discriminatedUnion('kind', [
  z.object({ kind: z.literal('exact'), date: isoDateSchema }),
  z.object({
    kind: z.literal('cycle-inferred'),
    date: isoDateSchema,
    sourceDate: isoDateSchema,
    cycleLengthDays: z.number().int().positive(),
  }),
  z.object({ kind: z.literal('unavailable'), date: isoDateSchema, latestAvailable: isoDateSchema.nullable() }),
]);
export type MenuResolution = z.infer<typeof menuResolutionSchema>;

export const messDishSchema = z.object({
  slug: dishSlugSchema,
  name: z.string().min(1),
  /** The mess's own label, e.g. "Non Veg"; null when unlabelled. */
  label: z.string().nullable(),
  diet: dietClassSchema,
  role: dishRoleSchema,
  alternatives: z.array(z.string()),
  /** Bread, tea, jam… present at every meal: loggable, shown quietly. */
  isAmbient: z.boolean(),
  /** Null when there is no estimate for this dish: then it cannot be tap-logged. */
  nutrition: messDishNutritionSchema.nullable(),
  /** You reported this dish's nutrition and the report is awaiting review (owner D17). */
  correctionPending: z.boolean(),
});
export type MessDish = z.infer<typeof messDishSchema>;

export const messMealSchema = z.object({
  slot: mealSlotSchema,
  /** Exactly what the mess published for this meal (owner D20). */
  rawMenu: z.string(),
  dishes: z.array(messDishSchema),
});
export type MessMeal = z.infer<typeof messMealSchema>;

export const messMenuQuerySchema = z
  .object({
    /** yyyy-mm-dd; defaults to today in your zone. */
    date: isoDateSchema.optional(),
    /** A mess code; defaults to your configured mess (owner D14). */
    mess: messCodeSchema.optional(),
  })
  .strict();
export type MessMenuQuery = z.infer<typeof messMenuQuerySchema>;

/** A mess dish you logged on this day (for the "logged" mark). */
export const messLoggedDishSchema = z.object({
  dishSlug: dishSlugSchema,
  mealSlot: mealSlotSchema,
  clientLogId: z.string().uuid(),
});

export const messMenuSchema = z.object({
  mess: messSchema,
  date: isoDateSchema,
  /** Today in your zone. */
  today: isoDateSchema,
  resolution: menuResolutionSchema,
  meals: z.array(messMealSchema),
  logged: z.array(messLoggedDishSchema),
});
export type MessMenu = z.infer<typeof messMenuSchema>;

/* --------------------------------------------------------- corrections -- */

export const MESS_CORRECTION_FIELDS = ['kcal', 'protein', 'carb', 'fat', 'diet', 'other'] as const;
export const messCorrectionFieldSchema = z.enum(MESS_CORRECTION_FIELDS);
export const MESS_CORRECTION_STATUSES = ['pending', 'accepted', 'rejected'] as const;

export const dishSlugParamsSchema = z.object({ slug: dishSlugSchema }).strict();

/**
 * A report that a dish's estimate is wrong (owner D17). Stored as pending; it
 * changes nothing until a later review accepts it. Macro fields give the
 * range you believe (per serving); `diet` gives the right class; `other`
 * needs a note. Retry-safe by `clientCorrectionId`.
 */
export const messCorrectionRequestSchema = z
  .object({
    clientCorrectionId: z.string().uuid(),
    field: messCorrectionFieldSchema,
    low: z.number().finite().nonnegative().max(5000).optional(),
    high: z.number().finite().nonnegative().max(5000).optional(),
    diet: z.enum(['veg', 'egg', 'nonveg']).optional(),
    note: z.string().trim().min(1).max(280).optional(),
  })
  .strict()
  .superRefine((r, ctx) => {
    const macro = r.field === 'kcal' || r.field === 'protein' || r.field === 'carb' || r.field === 'fat';
    if (macro) {
      if (r.low === undefined || r.high === undefined) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['low'], message: 'give the low and high you believe' });
      } else if (r.low > r.high) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['high'], message: 'high must not be below low' });
      }
      if (r.diet !== undefined) ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['diet'], message: 'only for field diet' });
    } else {
      if (r.low !== undefined || r.high !== undefined) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['low'], message: 'only for kcal, protein, carb or fat' });
      }
      if (r.field === 'diet' && r.diet === undefined) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['diet'], message: 'give the right diet class' });
      }
      if (r.field === 'other' && r.note === undefined) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['note'], message: 'say what is wrong' });
      }
      if (r.field === 'other' && r.diet !== undefined) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['diet'], message: 'only for field diet' });
      }
    }
  });
export type MessCorrectionRequest = z.infer<typeof messCorrectionRequestSchema>;

export const messCorrectionSchema = z.object({
  id: z.string().uuid(),
  clientCorrectionId: z.string().uuid(),
  dishSlug: dishSlugSchema,
  field: messCorrectionFieldSchema,
  low: z.number().nullable(),
  high: z.number().nullable(),
  diet: z.enum(['veg', 'egg', 'nonveg']).nullable(),
  note: z.string().nullable(),
  status: z.enum(MESS_CORRECTION_STATUSES),
  createdAt: z.string().datetime(),
});
export type MessCorrection = z.infer<typeof messCorrectionSchema>;
