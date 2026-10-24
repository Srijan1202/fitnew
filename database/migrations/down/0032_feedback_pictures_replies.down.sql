-- Beta 3.6 (ADR-026 amendment): undo 0032_feedback_pictures_replies. The
-- pictures, the replies and the phone details sent with feedback go; the
-- messages stay.
DROP TABLE IF EXISTS "feedback_pictures";
DROP TABLE IF EXISTS "feedback_replies";
ALTER TABLE "feedback" DROP COLUMN IF EXISTS "device_model";
ALTER TABLE "feedback" DROP COLUMN IF EXISTS "device_os";
ALTER TABLE "feedback" DROP COLUMN IF EXISTS "screen";
