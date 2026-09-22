/**
 * Phase 6.6 — FITOS AI (ADR-010). Gate 3 defines the status shape only;
 * the chat and program-request shapes arrive with Gates 4–5. The client
 * uses status to say honestly when AI is not set up on the server rather
 * than showing a chat that cannot answer.
 */
import { z } from 'zod';

export const aiStatusResponseSchema = z.object({
  /** False when the server has no model credentials; chat answers 503. */
  configured: z.boolean(),
  /** Provider and model names — never credentials. */
  provider: z.string(),
  model: z.string().nullable(),
  /**
   * What the assistant will not see, stated so the client can explain it
   * to the user. Phase 6.6: Health Connect data stays on the phone.
   */
  excludes: z.array(z.enum(['health-connect', 'food-log'])),
});
export type AiStatusResponse = z.infer<typeof aiStatusResponseSchema>;
