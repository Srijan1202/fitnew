CREATE TABLE "shared_programmes" (
	"code" text PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"name" text NOT NULL,
	"snapshot" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"stopped_at" timestamp with time zone,
	CONSTRAINT "shared_programmes_code_format" CHECK ("shared_programmes"."code" ~ '^[2-9A-HJKMNP-Z]{6}$')
);
--> statement-breakpoint
ALTER TABLE "shared_programmes" ADD CONSTRAINT "shared_programmes_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "shared_programmes_user_idx" ON "shared_programmes" USING btree ("user_id","created_at");