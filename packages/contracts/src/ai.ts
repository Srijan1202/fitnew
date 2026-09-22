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

/* ------------------------------------------------------------- chat -- */

export const AI_MESSAGE_MAX = 2000;
export const AI_HISTORY_MAX = 20;

export const aiChatMessageSchema = z.object({
  role: z.enum(['user', 'assistant']),
  content: z.string().min(1).max(AI_MESSAGE_MAX),
});
export type AiChatMessage = z.infer<typeof aiChatMessageSchema>;

/**
 * Stateless: the client sends the recent exchange and the new message; the
 * server assembles the FITOS context fresh every call and keeps nothing.
 */
export const aiChatRequestSchema = z
  .object({
    message: z.string().trim().min(1).max(AI_MESSAGE_MAX),
    history: z.array(aiChatMessageSchema).max(AI_HISTORY_MAX).default([]),
  })
  .strict();
export type AiChatRequest = z.infer<typeof aiChatRequestSchema>;

/** Navigation the client may offer under an answer; nothing is changed by it. */
export const AI_ACTION_TYPES = [
  'open-workout',
  'open-plan',
  'open-volume',
  'open-progression',
  'open-profile',
  'open-nutrition',
  'open-exercise',
  'open-history',
] as const;
export const aiActionSchema = z.object({
  type: z.enum(AI_ACTION_TYPES),
  label: z.string().min(1),
  exerciseId: z.string().uuid().optional(),
  sessionId: z.string().uuid().optional(),
});
export type AiAction = z.infer<typeof aiActionSchema>;

export const aiChatResponseSchema = z.object({
  text: z.string().min(1),
  actions: z.array(aiActionSchema),
  /** Allowlisted tool names the answer drew on, for transparency. */
  toolsUsed: z.array(z.string()),
  model: z.string(),
});
export type AiChatResponse = z.infer<typeof aiChatResponseSchema>;
