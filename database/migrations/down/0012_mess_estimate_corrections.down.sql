-- Down for 0012_mess_estimate_corrections (Phase 10 Amendment B). Hand-written: drizzle-kit is forward-only (§25).
-- Restores each corrected estimate to its recorded previous values (only rows
-- still holding the corrected values), then drops the provenance table.
UPDATE "mess_dish_nutrition" n SET "serving_label" = r."previous"->>'servingLabel', "serving_grams" = (r."previous"->>'servingGrams')::numeric, "kcal_low" = (r."previous"->>'kcalLow')::numeric, "kcal_high" = (r."previous"->>'kcalHigh')::numeric, "protein_low" = (r."previous"->>'proteinLow')::numeric, "protein_high" = (r."previous"->>'proteinHigh')::numeric, "carb_low" = (r."previous"->>'carbLow')::numeric, "carb_high" = (r."previous"->>'carbHigh')::numeric, "fat_low" = (r."previous"->>'fatLow')::numeric, "fat_high" = (r."previous"->>'fatHigh')::numeric, "confidence" = (r."previous"->>'confidence')::"nutrition_confidence", "updated_at" = now()
FROM "mess_dish_nutrition_revisions" r
WHERE r."dish_slug" = n."dish_slug" AND r."reason" = 'phase-10-estimate-correction'
  AND jsonb_build_object('servingLabel', n."serving_label", 'servingGrams', n."serving_grams", 'kcalLow', n."kcal_low", 'kcalHigh', n."kcal_high", 'proteinLow', n."protein_low", 'proteinHigh', n."protein_high", 'carbLow', n."carb_low", 'carbHigh', n."carb_high", 'fatLow', n."fat_low", 'fatHigh', n."fat_high", 'confidence', n."confidence") = r."current";
DROP TABLE IF EXISTS "mess_dish_nutrition_revisions";
