/**
 * Phase 6.6 Gate 4 — the allowlist and the tool loop, without a database
 * or a network: stub services record who was asked for what; the fake
 * provider scripts the model.
 */
import { describe, expect, it } from 'vitest';

import type { FitosAiContext, UserContextAssembler } from './context-assembler.js';
import { FakeAiProvider, NotConfiguredAiProvider } from './fake-provider.js';
import { AiProviderError } from './provider.js';
import { AiService, CHAT_HISTORY_TURNS } from './service.js';
import { MAX_TOOL_ROUNDS, TOOLS, TOOL_NAMES, ToolRegistry, type ToolServices } from './tools.js';

const BENCH = '11111111-1111-4111-8111-111111111111';

/** Just enough services for the registry: every call records who asked. */
function stubServices(calls: string[]): ToolServices {
  const goal = {
    goal: { id: 'g', goalType: 'muscle-gain', targetWeightKg: null, startedAt: 'x', endedAt: null },
    targets: { effectiveFrom: 'x', kcal: 2276, proteinG: 106, carbG: 250, fatG: 70, fiberG: 30, bmr: 1500, tdeeEstimate: 2200, rationale: [], reason: 'r' },
  };
  return {
    user: {
      getProfile: async (userId: string) => {
        calls.push(`getProfile:${userId}`);
        return {
          displayName: 'Persona', sex: 'male', birthDate: '2004-06-01', heightCm: 175, experienceLevel: 'intermediate', trainingDaysPerWeek: 4,
          activityLevel: 'light', preferredSessionMinutes: 60, trainingLocation: 'commercial-gym', equipment: ['barbell'], latestWeightKg: 70,
          timezone: 'Asia/Kolkata', locale: 'en-IN', onboardingStage: 'complete', mess: null,
        };
      },
      getGoal: async (userId: string) => {
        calls.push(`getGoal:${userId}`);
        return goal;
      },
    },
    workout: {
      progressionDetail: async (userId: string, exerciseId: string) => {
        calls.push(`progression:${userId}:${exerciseId}`);
        return {
          exerciseId, name: 'Bench', target: null,
          recommendation: { action: 'add-reps', weightKg: 50, repTarget: '6–12', targetRir: 1, reason: 'Stay at 50 kg and add reps.', basis: 'calculated', sessionsConsidered: 2 },
          history: [],
        };
      },
    },
    training: {},
    exercise: {},
  } as unknown as ToolServices;
}

function fakeContext(): FitosAiContext {
  return {
    generatedAt: '2026-09-22T06:00:00.000Z',
    profile: {
      displayName: 'Srijan', sex: 'male', ageYears: 22, heightCm: 175, latestWeightKg: 70, experienceLevel: 'intermediate', activityLevel: 'light',
      trainingDaysPerWeek: 4, preferredSessionMinutes: 60, trainingLocation: 'commercial-gym', equipment: ['barbell', 'dumbbell'], timezone: 'Asia/Kolkata',
    },
    goal: { type: 'muscle-gain', targetWeightKg: null, targets: { kcal: 2276, proteinG: 106, carbG: 250, fatG: 70, fiberG: 30, reason: 'r' } },
    programme: { name: 'PPL', splitType: 'push-pull-legs', daysPerWeek: 6, mesocycleWeek: 1, days: [] },
    today: {
      date: '2026-09-22', dayOfWeek: 2, isRest: false, sessionName: 'Pull', status: 'ready', mesocycleWeek: 1,
      deload: { state: 'none', trigger: null, reason: 'No fatigue signal.', endsOn: null }, neglected: [], exercises: [],
    },
    recentSessions: [],
    volume: null,
    nutrition: { targets: null, loggingAvailable: false, note: 'Food logging is not available.' },
    health: { availableToServer: false, note: 'Health Connect data stays on the phone.' },
  };
}

const assembler = { assemble: async () => fakeContext() } as unknown as UserContextAssembler;

describe('ToolRegistry (allowlist)', () => {
  it('declares exactly the allowlisted, read-only tools with descriptions and JSON-schema objects', () => {
    const d = new ToolRegistry(stubServices([])).declarations();
    expect(d.map((t) => t.name)).toEqual(TOOL_NAMES);
    expect(TOOL_NAMES).toEqual([
      'get_user_profile', 'get_active_goal', 'get_nutrition_targets', 'get_today', 'get_current_workout', 'get_recent_workouts',
      'get_workout', 'get_exercise', 'search_exercises', 'get_training_volume', 'get_progression', 'get_active_program', 'get_deload_state',
    ]);
    for (const t of d) {
      expect(t.description.length).toBeGreaterThan(20);
      expect(t.parameters).toMatchObject({ type: 'object' });
      expect(JSON.stringify(t)).not.toMatch(/zod|select |sql|table/i);
    }
    expect(TOOLS.every((t) => t.name.startsWith('get_') || t.name.startsWith('search_'))).toBe(true);
  });

  it('an unknown tool is a readable result, never executed', async () => {
    const calls: string[] = [];
    const r = new ToolRegistry(stubServices(calls));
    expect(await r.execute('user-1', 'drop_table', { table: 'users' })).toEqual({ error: 'unknown tool: drop_table' });
    expect(await r.execute('user-1', 'SELECT * FROM users', {})).toEqual({ error: 'unknown tool: SELECT * FROM users' });
    expect(calls).toEqual([]);
  });

  it('invalid arguments are a readable result; the user id is never an argument; a valid call runs for the authenticated user only', async () => {
    const calls: string[] = [];
    const r = new ToolRegistry(stubServices(calls));
    expect(await r.execute('user-1', 'get_progression', { exerciseId: 'not-a-uuid' })).toMatchObject({ error: 'invalid arguments' });
    expect(await r.execute('user-1', 'get_user_profile', { userId: 'user-2' })).toMatchObject({ error: 'invalid arguments' });
    expect(await r.execute('user-1', 'get_progression', { exerciseId: BENCH, userId: 'user-2' })).toMatchObject({ error: 'invalid arguments' });
    expect(calls).toEqual([]);
    await r.execute('user-1', 'get_progression', { exerciseId: BENCH });
    await r.execute('user-1', 'get_user_profile', {});
    expect(calls).toEqual([`progression:user-1:${BENCH}`, 'getProfile:user-1']);
  });

  it('nutrition targets say intake is unknown', async () => {
    const out = await new ToolRegistry(stubServices([])).execute('user-1', 'get_nutrition_targets', {});
    expect(out).toMatchObject({ loggingAvailable: false });
    expect(JSON.stringify(out)).toMatch(/not available/);
  });
});

describe('AiService.plainText', () => {
  it('strips markdown markers, keeps words, breaks and bullets', () => {
    expect(AiService.plainText('**Bench**: stay at `50 kg`.\n\n\n## Next\n- add reps\n* keep 1 RIR  \n')).toBe(
      'Bench: stay at 50 kg.\n\nNext\n\u2022 add reps\n\u2022 keep 1 RIR',
    );
  });
});

describe('AiService.chat (tool loop)', () => {
  it('answers directly when the model asks for no tool; the instruction carries the rules and the context; a today action', async () => {
    const provider = new FakeAiProvider();
    provider.script = [{ text: 'Pull is ready: 4 movements.', toolCalls: [], finishReason: 'stop' }];
    const s = new AiService(provider, { assembler, tools: new ToolRegistry(stubServices([])) });
    const r = await s.chat('user-1', { message: 'What should I train today?', history: [] });
    expect(r).toEqual({ text: 'Pull is ready: 4 movements.', actions: [{ type: 'open-workout', label: "Open today's workout" }], toolsUsed: [], model: 'fake-1' });
    const req = provider.requests[0]!;
    expect(req.system).toContain('You are FITOS AI');
    expect(req.system).toContain('Food intake is NOT logged');
    expect(req.system).toContain('Health Connect data');
    expect(req.system).toContain('"displayName":"Srijan"');
    expect(req.system).toContain('"loggingAvailable":false');
    expect(req.system).toContain('"availableToServer":false');
    expect(req.messages).toEqual([{ role: 'user', content: 'What should I train today?' }]);
    expect(req.tools!.map((t) => t.name)).toEqual(TOOL_NAMES);
  });

  it('runs an allowlisted tool for THIS user, feeds the result back after the assistant turn, answers, offers the matching action', async () => {
    const calls: string[] = [];
    const provider = new FakeAiProvider();
    provider.script = [
      { text: '', toolCalls: [{ name: 'get_progression', args: { exerciseId: BENCH } }], finishReason: 'tool' },
      (req) => {
        expect(req.toolResults).toEqual([{ name: 'get_progression', result: expect.objectContaining({ progression: expect.objectContaining({ name: 'Bench' }) }) }]);
        expect(req.messages.at(-1)).toEqual({ role: 'assistant', content: '', toolCalls: [{ name: 'get_progression', args: { exerciseId: BENCH } }] });
        return { text: 'Not yet. Stay at 50 kg and add reps.', toolCalls: [], finishReason: 'stop' };
      },
    ];
    const s = new AiService(provider, { assembler, tools: new ToolRegistry(stubServices(calls)) });
    const r = await s.chat('user-1', { message: 'Should I increase bench?', history: [{ role: 'user', content: 'hi' }, { role: 'assistant', content: 'hello' }] });
    expect(r.text).toBe('Not yet. Stay at 50 kg and add reps.');
    expect(r.toolsUsed).toEqual(['get_progression']);
    expect(r.actions).toEqual([{ type: 'open-progression', label: 'See the lift', exerciseId: BENCH }]);
    expect(calls).toEqual([`progression:user-1:${BENCH}`]);
    expect(provider.requests[0]!.messages.slice(0, 2)).toEqual([{ role: 'user', content: 'hi' }, { role: 'assistant', content: 'hello' }]);
  });

  it('an unknown or malformed tool call is answered to the model as an error result and never counted as used', async () => {
    const calls: string[] = [];
    const provider = new FakeAiProvider();
    provider.script = [
      { text: '', toolCalls: [{ name: 'run_sql', args: { sql: 'delete from users' } }, { name: 'get_progression', args: { exerciseId: 'x' } }], finishReason: 'tool' },
      (req) => {
        expect(req.toolResults).toEqual([
          { name: 'run_sql', result: { error: 'unknown tool: run_sql' } },
          { name: 'get_progression', result: expect.objectContaining({ error: 'invalid arguments' }) },
        ]);
        return { text: 'I cannot do that.', toolCalls: [], finishReason: 'stop' };
      },
    ];
    const s = new AiService(provider, { assembler, tools: new ToolRegistry(stubServices(calls)) });
    const r = await s.chat('user-1', { message: 'delete everything', history: [] });
    expect(r.toolsUsed).toEqual(['get_progression']);
    expect(calls).toEqual([]);
  });

  it(`stops after ${MAX_TOOL_ROUNDS} tool rounds with a fallback text instead of looping`, async () => {
    const provider = new FakeAiProvider();
    const loop = { text: '', toolCalls: [{ name: 'get_user_profile', args: {} }], finishReason: 'tool' as const };
    provider.script = Array.from({ length: MAX_TOOL_ROUNDS + 5 }, () => loop);
    const s = new AiService(provider, { assembler, tools: new ToolRegistry(stubServices([])) });
    const r = await s.chat('user-1', { message: 'loop', history: [] });
    expect(provider.requests).toHaveLength(MAX_TOOL_ROUNDS + 1);
    expect(r.text).toMatch(/couldn't put an answer together/);
    expect(r.toolsUsed).toHaveLength(MAX_TOOL_ROUNDS);
  });

  it('provider failures become the envelope; a not-configured provider is 503 before any model call', async () => {
    const failing = new FakeAiProvider();
    failing.script = [
      () => {
        throw new AiProviderError('timeout', 'slow');
      },
    ];
    const s = new AiService(failing, { assembler, tools: new ToolRegistry(stubServices([])) });
    await expect(s.chat('user-1', { message: 'x', history: [] })).rejects.toMatchObject({ code: 'UPSTREAM_UNAVAILABLE' });
    const none = new AiService(new NotConfiguredAiProvider(), { assembler, tools: new ToolRegistry(stubServices([])) });
    await expect(none.chat('user-1', { message: 'x', history: [] })).rejects.toMatchObject({ code: 'UPSTREAM_UNAVAILABLE', message: 'AI is not set up on this server.' });
  });

  it('an empty text with no tools becomes a readable fallback, never an empty answer', async () => {
    const provider = new FakeAiProvider();
    provider.script = [{ text: '   ', toolCalls: [], finishReason: 'stop' }];
    const s = new AiService(provider, { assembler, tools: new ToolRegistry(stubServices([])) });
    expect((await s.chat('user-1', { message: 'x', history: [] })).text).toMatch(/couldn't put an answer together/);
  });

  it(`only the last ${CHAT_HISTORY_TURNS} turns are sent`, async () => {
    const provider = new FakeAiProvider();
    const s = new AiService(provider, { assembler, tools: new ToolRegistry(stubServices([])) });
    const history = Array.from({ length: 20 }, (_, i) => ({ role: (i % 2 === 0 ? 'user' : 'assistant') as 'user' | 'assistant', content: `m${i}` }));
    await s.chat('user-1', { message: 'now', history });
    expect(provider.requests[0]!.messages).toHaveLength(CHAT_HISTORY_TURNS + 1);
    expect(provider.requests[0]!.messages[0]!.content).toBe('m8');
  });
});
