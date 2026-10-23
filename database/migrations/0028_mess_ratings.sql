CREATE TABLE "mess_dish_ratings" (
	"user_id" uuid NOT NULL,
	"mess_id" uuid NOT NULL,
	"dish_slug" text NOT NULL,
	"up" boolean NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "mess_dish_ratings_user_id_mess_id_dish_slug_pk" PRIMARY KEY("user_id","mess_id","dish_slug"),
	CONSTRAINT "mess_dish_ratings_slug_format" CHECK ("dish_slug" ~ '^[a-z0-9]+(-[a-z0-9]+)*$')
);
--> statement-breakpoint
ALTER TABLE "mess_dish_ratings" ADD CONSTRAINT "mess_dish_ratings_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "mess_dish_ratings" ADD CONSTRAINT "mess_dish_ratings_mess_id_messes_id_fk" FOREIGN KEY ("mess_id") REFERENCES "public"."messes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "mess_dish_ratings_dish_idx" ON "mess_dish_ratings" USING btree ("mess_id","dish_slug");