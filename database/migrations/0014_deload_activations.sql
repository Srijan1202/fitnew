CREATE TABLE "deload_activations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"program_id" uuid NOT NULL,
	"started_at" timestamp with time zone NOT NULL,
	"recorded_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "deload_activations" ADD CONSTRAINT "deload_activations_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "deload_activations" ADD CONSTRAINT "deload_activations_program_id_programs_id_fk" FOREIGN KEY ("program_id") REFERENCES "public"."programs"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "deload_activations_program_started" ON "deload_activations" USING btree ("program_id","started_at");--> statement-breakpoint
CREATE INDEX "deload_activations_user_started_idx" ON "deload_activations" USING btree ("user_id","started_at");--> statement-breakpoint
-- Phase 11: keep every deload activation. Phase 6 sets programs.deload_started_at on
-- POST /training/deload/accept and clears it when the week closes; this records each
-- value it is set to, without changing that lifecycle or its code.
CREATE FUNCTION "record_deload_activation"() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW."deload_started_at" IS NOT NULL
     AND (TG_OP = 'INSERT' OR NEW."deload_started_at" IS DISTINCT FROM OLD."deload_started_at") THEN
    INSERT INTO "deload_activations" ("user_id", "program_id", "started_at")
    VALUES (NEW."user_id", NEW."id", NEW."deload_started_at")
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;--> statement-breakpoint
CREATE TRIGGER "programs_deload_activation"
  AFTER INSERT OR UPDATE OF "deload_started_at" ON "programs"
  FOR EACH ROW EXECUTE FUNCTION "record_deload_activation"();--> statement-breakpoint
-- Deload weeks already running when this migration applies.
INSERT INTO "deload_activations" ("user_id", "program_id", "started_at")
SELECT "user_id", "id", "deload_started_at" FROM "programs" WHERE "deload_started_at" IS NOT NULL
ON CONFLICT DO NOTHING;
