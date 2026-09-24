CREATE TABLE "mess_dish_nutrition_revisions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"dish_slug" text NOT NULL,
	"reason" text NOT NULL,
	"previous" jsonb NOT NULL,
	"current" jsonb NOT NULL,
	"revised_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "mess_dish_nutrition_revisions_reason" CHECK (length(btrim("mess_dish_nutrition_revisions"."reason")) > 0)
);
--> statement-breakpoint
ALTER TABLE "mess_dish_nutrition_revisions" ADD CONSTRAINT "mess_dish_nutrition_revisions_dish_slug_mess_dish_nutrition_dish_slug_fk" FOREIGN KEY ("dish_slug") REFERENCES "public"."mess_dish_nutrition"("dish_slug") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "mess_dish_nutrition_revisions_slug_idx" ON "mess_dish_nutrition_revisions" USING btree ("dish_slug","revised_at");
--> statement-breakpoint
-- Phase 10 Amendment B (owner, 2026-09-24; ADR-016, plan §21): four mess dishes
-- whose stored estimate came from the wrong table entry (the first matching
-- term won). Estimates are write-once (the mirror never overwrites), so a fix
-- in core alone would never reach an existing database. Each row is corrected
-- ONLY while it still holds the exact wrong Phase 9 values; an absent or
-- already-different row is left alone. Every change keeps its provenance in
-- mess_dish_nutrition_revisions. Logged snapshots never change.
--> statement-breakpoint
-- curd-rice: was the curd estimate ("curd" matched before "curd rice").
INSERT INTO "mess_dish_nutrition_revisions" ("dish_slug", "reason", "previous", "current")
SELECT "dish_slug", 'phase-10-estimate-correction', jsonb_build_object('servingLabel', "serving_label", 'servingGrams', "serving_grams", 'kcalLow', "kcal_low", 'kcalHigh', "kcal_high", 'proteinLow', "protein_low", 'proteinHigh', "protein_high", 'carbLow', "carb_low", 'carbHigh', "carb_high", 'fatLow', "fat_low", 'fatHigh', "fat_high", 'confidence', "confidence"), jsonb_build_object('servingLabel', '1 katori', 'servingGrams', 180, 'kcalLow', 180, 'kcalHigh', 260, 'proteinLow', 5, 'proteinHigh', 8, 'carbLow', 30, 'carbHigh', 40, 'fatLow', 4, 'fatHigh', 8, 'confidence', 'medium')
FROM "mess_dish_nutrition"
WHERE "dish_slug" = 'curd-rice' AND "serving_label" = '1 cup' AND "serving_grams" = 120 AND "kcal_low" = 65 AND "kcal_high" = 105 AND "protein_low" = 4 AND "protein_high" = 7 AND "carb_low" = 5 AND "carb_high" = 8 AND "fat_low" = 3 AND "fat_high" = 5.5 AND "confidence" = 'medium';
--> statement-breakpoint
UPDATE "mess_dish_nutrition" SET "serving_label" = '1 katori', "serving_grams" = 180, "kcal_low" = 180, "kcal_high" = 260, "protein_low" = 5, "protein_high" = 8, "carb_low" = 30, "carb_high" = 40, "fat_low" = 4, "fat_high" = 8, "confidence" = 'medium', "updated_at" = now()
WHERE "dish_slug" = 'curd-rice' AND "serving_label" = '1 cup' AND "serving_grams" = 120 AND "kcal_low" = 65 AND "kcal_high" = 105 AND "protein_low" = 4 AND "protein_high" = 7 AND "carb_low" = 5 AND "carb_high" = 8 AND "fat_low" = 3 AND "fat_high" = 5.5 AND "confidence" = 'medium';
--> statement-breakpoint
-- rice-papad: was the white-rice estimate ("rice" matched before "rice papad").
INSERT INTO "mess_dish_nutrition_revisions" ("dish_slug", "reason", "previous", "current")
SELECT "dish_slug", 'phase-10-estimate-correction', jsonb_build_object('servingLabel', "serving_label", 'servingGrams', "serving_grams", 'kcalLow', "kcal_low", 'kcalHigh', "kcal_high", 'proteinLow', "protein_low", 'proteinHigh', "protein_high", 'carbLow', "carb_low", 'carbHigh', "carb_high", 'fatLow', "fat_low", 'fatHigh', "fat_high", 'confidence', "confidence"), jsonb_build_object('servingLabel', '1 small portion', 'servingGrams', 25, 'kcalLow', 95, 'kcalHigh', 155, 'proteinLow', 1, 'proteinHigh', 2.5, 'carbLow', 11, 'carbHigh', 17, 'fatLow', 5, 'fatHigh', 10, 'confidence', 'low')
FROM "mess_dish_nutrition"
WHERE "dish_slug" = 'rice-papad' AND "serving_label" = '1 katori' AND "serving_grams" = 150 AND "kcal_low" = 175 AND "kcal_high" = 215 AND "protein_low" = 3.2 AND "protein_high" = 4.5 AND "carb_low" = 38 AND "carb_high" = 48 AND "fat_low" = 0.3 AND "fat_high" = 1.2 AND "confidence" = 'medium';
--> statement-breakpoint
UPDATE "mess_dish_nutrition" SET "serving_label" = '1 small portion', "serving_grams" = 25, "kcal_low" = 95, "kcal_high" = 155, "protein_low" = 1, "protein_high" = 2.5, "carb_low" = 11, "carb_high" = 17, "fat_low" = 5, "fat_high" = 10, "confidence" = 'low', "updated_at" = now()
WHERE "dish_slug" = 'rice-papad' AND "serving_label" = '1 katori' AND "serving_grams" = 150 AND "kcal_low" = 175 AND "kcal_high" = 215 AND "protein_low" = 3.2 AND "protein_high" = 4.5 AND "carb_low" = 38 AND "carb_high" = 48 AND "fat_low" = 0.3 AND "fat_high" = 1.2 AND "confidence" = 'medium';
--> statement-breakpoint
-- chole-bhatura: was chole only ("chole" matched first; the bhatura was lost).
INSERT INTO "mess_dish_nutrition_revisions" ("dish_slug", "reason", "previous", "current")
SELECT "dish_slug", 'phase-10-estimate-correction', jsonb_build_object('servingLabel', "serving_label", 'servingGrams', "serving_grams", 'kcalLow', "kcal_low", 'kcalHigh', "kcal_high", 'proteinLow', "protein_low", 'proteinHigh', "protein_high", 'carbLow', "carb_low", 'carbHigh', "carb_high", 'fatLow', "fat_low", 'fatHigh', "fat_high", 'confidence', "confidence"), jsonb_build_object('servingLabel', '1 plate (2 bhatura + chole)', 'servingGrams', 330, 'kcalLow', 590, 'kcalHigh', 870, 'proteinLow', 17, 'proteinHigh', 27, 'carbLow', 80, 'carbHigh', 112, 'fatLow', 20, 'fatHigh', 41, 'confidence', 'low')
FROM "mess_dish_nutrition"
WHERE "dish_slug" = 'chole-bhatura' AND "serving_label" = '1 katori' AND "serving_grams" = 150 AND "kcal_low" = 150 AND "kcal_high" = 230 AND "protein_low" = 7 AND "protein_high" = 11 AND "carb_low" = 20 AND "carb_high" = 28 AND "fat_low" = 4 AND "fat_high" = 9 AND "confidence" = 'medium';
--> statement-breakpoint
UPDATE "mess_dish_nutrition" SET "serving_label" = '1 plate (2 bhatura + chole)', "serving_grams" = 330, "kcal_low" = 590, "kcal_high" = 870, "protein_low" = 17, "protein_high" = 27, "carb_low" = 80, "carb_high" = 112, "fat_low" = 20, "fat_high" = 41, "confidence" = 'low', "updated_at" = now()
WHERE "dish_slug" = 'chole-bhatura' AND "serving_label" = '1 katori' AND "serving_grams" = 150 AND "kcal_low" = 150 AND "kcal_high" = 230 AND "protein_low" = 7 AND "protein_high" = 11 AND "carb_low" = 20 AND "carb_high" = 28 AND "fat_low" = 4 AND "fat_high" = 9 AND "confidence" = 'medium';
--> statement-breakpoint
-- dahi-vada: was the curd estimate ("dahi" matched before "vada").
INSERT INTO "mess_dish_nutrition_revisions" ("dish_slug", "reason", "previous", "current")
SELECT "dish_slug", 'phase-10-estimate-correction', jsonb_build_object('servingLabel', "serving_label", 'servingGrams', "serving_grams", 'kcalLow', "kcal_low", 'kcalHigh', "kcal_high", 'proteinLow', "protein_low", 'proteinHigh', "protein_high", 'carbLow', "carb_low", 'carbHigh', "carb_high", 'fatLow', "fat_low", 'fatHigh', "fat_high", 'confidence', "confidence"), jsonb_build_object('servingLabel', '2 pieces in curd', 'servingGrams', 230, 'kcalLow', 305, 'kcalHigh', 485, 'proteinLow', 10, 'proteinHigh', 18, 'carbLow', 31, 'carbHigh', 48, 'fatLow', 15, 'fatHigh', 29.5, 'confidence', 'low')
FROM "mess_dish_nutrition"
WHERE "dish_slug" = 'dahi-vada' AND "serving_label" = '1 cup' AND "serving_grams" = 120 AND "kcal_low" = 65 AND "kcal_high" = 105 AND "protein_low" = 4 AND "protein_high" = 7 AND "carb_low" = 5 AND "carb_high" = 8 AND "fat_low" = 3 AND "fat_high" = 5.5 AND "confidence" = 'medium';
--> statement-breakpoint
UPDATE "mess_dish_nutrition" SET "serving_label" = '2 pieces in curd', "serving_grams" = 230, "kcal_low" = 305, "kcal_high" = 485, "protein_low" = 10, "protein_high" = 18, "carb_low" = 31, "carb_high" = 48, "fat_low" = 15, "fat_high" = 29.5, "confidence" = 'low', "updated_at" = now()
WHERE "dish_slug" = 'dahi-vada' AND "serving_label" = '1 cup' AND "serving_grams" = 120 AND "kcal_low" = 65 AND "kcal_high" = 105 AND "protein_low" = 4 AND "protein_high" = 7 AND "carb_low" = 5 AND "carb_high" = 8 AND "fat_low" = 3 AND "fat_high" = 5.5 AND "confidence" = 'medium';
