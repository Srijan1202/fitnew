-- Beta 3.3 (ADR-034): undo 0029_shared_programmes. Every share code goes;
-- programmes people already copied stay theirs.
DROP TABLE IF EXISTS "shared_programmes";
