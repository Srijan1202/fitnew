/**
 * Phase 15 — every word a FITOS notification can say (ADR-021). Copy is a
 * fixed bank of templates written here, never generated (§21: no LLM). The
 * planner picks a variant per send; slots are filled from FITOS's own data.
 *
 * Tone (owner decision 2026-10-21): CHEEKY by default — Duolingo-style
 * teasing, light guilt and streak pressure are allowed. Guardrails that
 * hold in every tone (and are tested):
 *   - the tease is about habits (training, logging, streaks), never about
 *     the body: no weight, size, shape or appearance judgements;
 *   - never "eat less", never food guilt;
 *   - no insults (lazy, pathetic …).
 * GENTLE is the user's choice in settings, and what the planner falls back
 * to on a low-readiness day.
 */
import type { NotifyKind, NotifyTone } from './types.js';

/** Data a template may need (besides `name`, which always has a fallback). */
export type CopySlot = 'session' | 'streak' | 'target' | 'sessions' | 'planned';

export interface Template {
  readonly id: string;
  readonly kind: NotifyKind;
  readonly tone: NotifyTone;
  readonly title: string;
  readonly body: string;
  readonly needs?: readonly CopySlot[];
  /** Comeback only: the day of absence it is written for (2, 4 or 7). */
  readonly stage?: 2 | 4 | 7;
  /**
   * Beta 4.4 (E27): written for a running plan's day; used only then, and
   * the gym's words are not used on such a day.
   */
  readonly run?: boolean;
}

const t = (
  id: string,
  kind: NotifyKind,
  tone: NotifyTone,
  title: string,
  body: string,
  extra: { needs?: readonly CopySlot[]; stage?: 2 | 4 | 7; run?: boolean } = {},
): Template => ({ id, kind, tone, title, body, ...extra });

const S = ['session'] as const;

export const TEMPLATES: readonly Template[] = [
  // ------------------------------------------------- workout reminder --
  t('wr-c1', 'workout-reminder', 'cheeky', '{session} in an hour', "The barbell has been staring at the door, {name}. Don't leave it on read.", { needs: S }),
  t('wr-c2', 'workout-reminder', 'cheeky', 'Your {session} called', "It said it's free in about an hour. Weirdly specific. Go see it.", { needs: S }),
  t('wr-c3', 'workout-reminder', 'cheeky', '{session} o\'clock is near', 'Shoes on in 60. Future you is already bragging about it.', { needs: S }),
  t('wr-c4', 'workout-reminder', 'cheeky', "Plot twist: it's {session} day", "Not really a twist, it's in the plan. One hour, {name}.", { needs: S }),
  t('wr-c5', 'workout-reminder', 'cheeky', 'Gym > scrolling', 'Bold claim, we know. Test it: {session} starts in about an hour.', { needs: S }),
  t('wr-c6', 'workout-reminder', 'cheeky', 'Psst. {session}.', "The weights won't lift themselves. We checked. Twice.", { needs: S }),
  t('wr-c7', 'workout-reminder', 'cheeky', 'The reminder you asked for', "Well, the plan asked. {session} in an hour. Let's not make it awkward.", { needs: S }),
  t('wr-g1', 'workout-reminder', 'gentle', '{session} in about an hour', 'Your session is ready whenever you are.', { needs: S }),
  t('wr-g2', 'workout-reminder', 'gentle', 'Training today: {session}', 'About an hour to go. Some water and a light snack help.', { needs: S }),
  t('wr-g3', 'workout-reminder', 'gentle', 'Time for {session} soon', "Everything's planned. Just show up and start.", { needs: S }),

  // Beta 4.4 (E27): a running plan's day ({session} is the run's title).
  t('wr-r-c1', 'workout-reminder', 'cheeky', '{session} in an hour', 'Shoes by the door, {name}? The road is not going to run itself.', { needs: S, run: true }),
  t('wr-r-c2', 'workout-reminder', 'cheeky', 'Your run is calling', '{session} in about an hour. It says the first kilometre is the hardest. It lies a little.', { needs: S, run: true }),
  t('wr-r-c3', 'workout-reminder', 'cheeky', 'Laces, then legend', "{session} in an hour. Future you is already doing the post-run stretch smugly.", { needs: S, run: true }),
  t('wr-r-c4', 'workout-reminder', 'cheeky', 'Plot twist: run day', "Not a twist, it's in the plan. {session}, one hour, {name}.", { needs: S, run: true }),
  t('wr-r-c5', 'workout-reminder', 'cheeky', 'Pavement > scrolling', 'Bold claim. Test it: {session} starts in about an hour.', { needs: S, run: true }),
  t('wr-r-g1', 'workout-reminder', 'gentle', '{session} in about an hour', 'Your run is ready whenever you are. Easy start, then settle in.', { needs: S, run: true }),
  t('wr-r-g2', 'workout-reminder', 'gentle', 'Running today: {session}', 'About an hour to go. Some water now helps.', { needs: S, run: true }),
  t('wr-r-g3', 'workout-reminder', 'gentle', 'Time to run soon', "{session} is planned. Just get out the door; the rest follows.", { needs: S, run: true }),

  // --------------------------------------------------- missed session --
  t('ms-c1', 'missed-session', 'cheeky', '{session} got ghosted', "Yesterday's session waited all day. It's not mad. Just… disappointed.", { needs: S }),
  t('ms-c2', 'missed-session', 'cheeky', 'So, about yesterday', "{session} didn't happen. We're not saying anything. (We're saying something.)", { needs: S }),
  t('ms-c3', 'missed-session', 'cheeky', 'Missed {session}? Happens.', 'Legends bounce back. Today is a great day to prove it, {name}.', { needs: S }),
  t('ms-c4', 'missed-session', 'cheeky', 'Yesterday: 0. Today: ?', 'One skipped day is a blip. Two is a pattern. You pick.'),
  t('ms-c5', 'missed-session', 'cheeky', '{session} sends its regards', "It's fine. It's totally fine. Open the plan and make it up to it.", { needs: S }),
  t('ms-g1', 'missed-session', 'gentle', "Yesterday's {session} didn't happen", 'No problem. Pick it up when you can; the plan carries on.', { needs: S }),
  t('ms-g2', 'missed-session', 'gentle', 'A fresh start today', 'Missing a day is normal. Your next session is ready.'),
  t('ms-r-c1', 'missed-session', 'cheeky', '{session} ran off without you', "Yesterday's run waited by the door all day. Today's a fine day to catch up.", { needs: S, run: true }),
  t('ms-r-c2', 'missed-session', 'cheeky', 'So, about that run', "{session} didn't happen. The road forgives. Quickly, if you go today.", { needs: S, run: true }),
  t('ms-r-c3', 'missed-session', 'cheeky', 'Yesterday: 0 km', 'One missed run is a blip. Lace up and make it a plot point, {name}.', { needs: S, run: true }),
  t('ms-r-g1', 'missed-session', 'gentle', "Yesterday's {session} didn't happen", 'No problem. Your plan carries on; the next run is ready.', { needs: S, run: true }),
  t('ms-r-g2', 'missed-session', 'gentle', 'A fresh run today', 'Missing a run is normal. Go easy and pick the plan back up.', { run: true }),

  // ------------------------------------------------------ protein gap --
  t('pg-c1', 'protein-gap', 'cheeky', 'Your muscles filed a complaint', 'Re: protein. You are under three quarters of your {target} g today. Dinner can fix this.', { needs: ['target'] }),
  t('pg-c2', 'protein-gap', 'cheeky', 'Protein is lagging', 'Your {target} g target is looking lonely. Make dinner count, {name}.', { needs: ['target'] }),
  t('pg-c3', 'protein-gap', 'cheeky', 'Dinner has one job tonight', 'Protein. Dal, paneer, eggs, chicken, curd: pick a fighter.'),
  t('pg-c4', 'protein-gap', 'cheeky', 'Gains need groceries', "You're short of today's {target} g protein. Tonight's plate can close the gap.", { needs: ['target'] }),
  t('pg-c5', 'protein-gap', 'cheeky', 'Quick protein audit', 'Results: could be better. Dinner is your comeback arc.'),
  t('pg-c6', 'protein-gap', 'cheeky', 'Protein called. You missed it.', `It left a message: "dinner, please". Today's target is {target} g.`, { needs: ['target'] }),
  t('pg-c7', 'protein-gap', 'cheeky', 'Muscles are built at dinner', 'Okay, also in the gym. But tonight it is dinner. Go big on protein, {name}.'),
  t('pg-c8', 'protein-gap', 'cheeky', 'Protein: the sequel', 'Part one (today so far) was slow. Part two (dinner) can be a blockbuster.'),
  t('pg-g1', 'protein-gap', 'gentle', 'A little protein left for today', 'You are under three quarters of your {target} g. A protein-rich dinner would help.', { needs: ['target'] }),
  t('pg-g2', 'protein-gap', 'gentle', 'Dinner idea: add protein', "Today's protein is behind. Paneer, dal, eggs or curd all help."),

  // --------------------------------------------------- streak at risk --
  t('sr-c1', 'streak-at-risk', 'cheeky', "{streak} days. Don't blink.", 'Nothing logged today. Your streak has until midnight.', { needs: ['streak'] }),
  t('sr-c2', 'streak-at-risk', 'cheeky', 'Your {streak}-day streak is sweating', "Log one thing. A meal, a set, anything. It'll calm down.", { needs: ['streak'] }),
  t('sr-c3', 'streak-at-risk', 'cheeky', 'Streak status: nervous', '{streak} days strong and today is still blank. Ten seconds fixes it.', { needs: ['streak'] }),
  t('sr-c4', 'streak-at-risk', 'cheeky', "Today's looking empty", 'Log a meal or a workout before the day runs out. Zero days are the worst days.'),
  t('sr-c5', 'streak-at-risk', 'cheeky', 'Blank day alert', 'Your log is emptier than the gym at 5 am. One entry, {name}.'),
  t('sr-c6', 'streak-at-risk', 'cheeky', 'The day is almost over', "And your log hasn't heard from you. One tap. We'll pretend it was always this easy."),
  t('sr-c7', 'streak-at-risk', 'cheeky', 'Not to be dramatic, but', 'Today has nothing logged and midnight is coming. A meal counts. A set counts.'),
  t('sr-c8', 'streak-at-risk', 'cheeky', 'Your future self asked us to text you', 'Something about "log today" and "you will thank me". Their words.'),
  t('sr-c10', 'streak-at-risk', 'cheeky', 'Tiny favour', 'Log one meal before bed. That is the whole favour. We will stop texting tonight.'),
  t('sr-c9', 'streak-at-risk', 'cheeky', 'Ten-second job', 'Log what you ate today. Then go back to whatever you were pretending not to scroll.'),
  t('sr-g1', 'streak-at-risk', 'gentle', 'Keep your {streak}-day streak', 'Nothing logged yet today. One entry keeps it going.', { needs: ['streak'] }),
  t('sr-g2', 'streak-at-risk', 'gentle', 'Nothing logged today yet', 'If you ate or trained, a quick log keeps your picture complete.'),

  // ----------------------------------------------------------- weigh-in --
  // Beta 3.5 (owner): meal reminders at the person's own times. Never about
  // eating less or what was eaten: only about writing it down.
  t('mb-c1', 'meal-breakfast', 'cheeky', 'Breakfast happened?', 'Your log has not heard about it yet. Ten seconds, {name}.'),
  t('mb-c2', 'meal-breakfast', 'cheeky', 'Morning, food logger', 'Breakfast goes in the log, not in the memory hole. One tap.'),
  t('mb-c3', 'meal-breakfast', 'cheeky', 'The log is waiting', 'Breakfast first, everything else later. Quick log?'),
  t('mb-g1', 'meal-breakfast', 'gentle', 'Log your breakfast?', 'When you have a moment, add what you had this morning.'),
  t('mb-g2', 'meal-breakfast', 'gentle', 'Breakfast check', 'A quick log now keeps today easy to follow.'),
  t('ml-c1', 'meal-lunch', 'cheeky', 'Lunch: logged or legend?', 'If it is not in the log, did it even happen? One tap, {name}.'),
  t('ml-c2', 'meal-lunch', 'cheeky', 'Midday check-in', 'Lunch is done, the log is not. Quick fix.'),
  t('ml-c3', 'meal-lunch', 'cheeky', 'Your log is hungry', 'Feed it your lunch. Mess menu, saved meal or quick add.'),
  t('ml-g1', 'meal-lunch', 'gentle', 'Log your lunch?', 'Add lunch when it suits you. It only takes a moment.'),
  t('ml-g2', 'meal-lunch', 'gentle', 'Lunch check', 'A quick log keeps your day on track.'),
  t('md-c1', 'meal-dinner', 'cheeky', 'Dinner, then the log', 'The last meal of the day deserves a mention. One tap, {name}.'),
  t('md-c2', 'meal-dinner', 'cheeky', 'One more for today', 'Dinner is not in the log yet. Close the day properly.'),
  t('md-c3', 'meal-dinner', 'cheeky', 'Almost a full day logged', 'Just dinner to go. Mess, saved meal or quick add.'),
  t('md-g1', 'meal-dinner', 'gentle', 'Log your dinner?', 'Add dinner when you are ready, and today is complete.'),
  t('md-g2', 'meal-dinner', 'gentle', 'Dinner check', 'A quick log rounds off your day.'),
  t('wi-c1', 'weigh-in', 'cheeky', "Scale o'clock", 'A couple of days without a reading. The trend line is getting curious.'),
  t('wi-c2', 'weigh-in', 'cheeky', 'Your trend wants data', "Step on, step off, done. Single numbers don't matter; the trend does."),
  t('wi-c3', 'weigh-in', 'cheeky', 'Quick weigh-in?', 'Morning, before breakfast, same as always. The graph will thank you.'),
  t('wi-c4', 'weigh-in', 'cheeky', 'The scale misses you', "It's a little dramatic. One reading, and it'll go quiet again."),
  t('wi-c5', 'weigh-in', 'cheeky', 'Data, please', 'Your trend runs on readings, not vibes. A morning weigh-in keeps it honest.'),
  t('wi-c6', 'weigh-in', 'cheeky', 'Thirty-second job', 'Scale, number, log, done. The trend does the thinking.'),
  t('wi-g1', 'weigh-in', 'gentle', 'Morning weigh-in', 'A reading keeps your trend accurate. One number is never the story.'),

  // ---------------------------------------------------- recovery check --
  t('rc-c1', 'recovery-checkin', 'cheeky', "How'd you sleep?", 'Rate your night in ten seconds. Readiness is only as good as your honesty.'),
  t('rc-c2', 'recovery-checkin', 'cheeky', 'Body report, please', 'Sleep, soreness, energy. A few taps and FITOS plans smarter.'),
  t('rc-c3', 'recovery-checkin', 'cheeky', 'Rate your sleep, honestly', '"Fine" is not a number. Ten seconds and today gets planned around it.'),
  t('rc-c4', 'recovery-checkin', 'cheeky', 'Sore? Tired? Unstoppable?', "Tell FITOS before today's session decides for you."),
  t('rc-c5', 'recovery-checkin', 'cheeky', 'Morning status update', 'Sleep, soreness, energy. Faster than replying to the group chat.'),
  t('rc-g1', 'recovery-checkin', 'gentle', 'Morning check-in', 'How are you feeling today? It takes ten seconds.'),

  // ------------------------------------------------------- weekly recap --
  t('wk-c1', 'weekly-recap', 'cheeky', 'Week wrapped: {sessions} of {planned}', 'Come see how it went. Spoiler: you did things.', { needs: ['sessions', 'planned'] }),
  t('wk-c2', 'weekly-recap', 'cheeky', 'Your week in review is ready', 'Some numbers went up. Come take a bow.'),
  t('wk-c3', 'weekly-recap', 'cheeky', 'Sunday report card', 'No grades, just progress. Tap to see your week.'),
  t('wk-g1', 'weekly-recap', 'gentle', 'Your weekly summary', 'See your training and food for the week.'),

  // ----------------------------------------------------------- comeback --
  t('cb-c2a', 'comeback', 'cheeky', 'Still there, {name}?', 'Two days, no logs. We are starting to think you found another fitness app.', { stage: 2 }),
  t('cb-c2b', 'comeback', 'cheeky', 'Your plan is getting dusty', 'Two days off. Come blow on it. One quick session counts.', { stage: 2 }),
  t('cb-c4a', 'comeback', 'cheeky', 'Your gains are packing a bag', "Four days off. They haven't left yet. Come back before they find the door.", { stage: 4 }),
  t('cb-c4b', 'comeback', 'cheeky', "It's been 4 days", 'No judgement. Okay, a little judgement. The plan missed you.', { stage: 4 }),
  t('cb-c7', 'comeback', 'cheeky', "These reminders don't seem to be working", "So we'll stop for now. Your plan will be right here when you're ready.", { stage: 7 }),
  t('cb-g2', 'comeback', 'gentle', 'Ready when you are', 'Your plan is waiting. Even a short session counts.', { stage: 2 }),
  t('cb-g4', 'comeback', 'gentle', 'Your plan is still here', 'Whenever you want to pick it back up, everything is saved.', { stage: 4 }),
  t('cb-g7', 'comeback', 'gentle', "We'll pause reminders", 'Come back any time. Everything is saved.', { stage: 7 }),
];

/**
 * Words no notification may contain, in any tone (the guardrails above).
 * Checked by the tests against every template.
 */
export const BANNED = /\b(fat|fatty|chubby|skinny|belly|obese|ugly|lazy|pathetic|useless|worthless|binge|cheat ?meal|eat less|starv\w*|calories? burn\w*|weight gain|lose weight|gained|shame\w*)\b/i;

export interface CopyData {
  readonly name: string | null;
  readonly session?: string | null;
  /** Beta 4.4 (E27): the session is a running plan's run. */
  readonly run?: boolean;
  readonly streak?: number | null;
  readonly target?: number | null;
  readonly sessions?: number | null;
  readonly planned?: number | null;
}

/** The name a template uses: the first word of the display name, or a tone's stand-in. */
export function nameFor(name: string | null, tone: NotifyTone): string {
  const first = name?.trim().split(/\s+/)[0];
  return first !== undefined && first !== '' ? first : tone === 'cheeky' ? 'legend' : 'there';
}

/** Whether every slot a template needs is filled. */
export function fits(template: Template, data: CopyData): boolean {
  return (template.needs ?? []).every((s) => {
    const v = data[s];
    return v !== null && v !== undefined && v !== '' && !(typeof v === 'number' && !Number.isFinite(v));
  });
}

/** A template with its slots filled. */
export function render(template: Template, data: CopyData): { title: string; body: string } {
  const fill = (s: string): string =>
    s.replace(/\{(name|session|streak|target|sessions|planned)\}/g, (_, k: string) =>
      k === 'name' ? nameFor(data.name, template.tone) : String((data as unknown as Record<string, unknown>)[k] ?? ''),
    );
  return { title: fill(template.title), body: fill(template.body) };
}
