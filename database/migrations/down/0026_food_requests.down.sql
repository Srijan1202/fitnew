-- Beta 3.2 (ADR-032): undo 0026_food_requests. The tally of missing foods
-- and its anonymous marks go; nothing else references them.
DROP TABLE IF EXISTS "food_request_marks";
DROP TABLE IF EXISTS "food_requests";
