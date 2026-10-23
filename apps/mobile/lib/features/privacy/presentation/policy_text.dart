/// The privacy policy as the app shows it (Phase 17, §23.6; beta text Phase 19,
/// ADR-026). The same text as docs/legal/privacy-policy.md; a test checks the
/// two stay in step and that the version is the server's CURRENT_POLICY_VERSION.
library;

const kPolicyVersion = '2026-10-22.2';

const kPolicySections = <(String, String)>[
  (
    'Who we are',
    'FITOS is a fitness and nutrition app for VIT students, built and run '
        'by its developer. It is in a closed beta: a small group of invited '
        'testers. The FITOS server and its database run on Amazon Web Services '
        'in Mumbai, India.',
  ),
  (
    'What FITOS keeps',
    'Your account (email and name, through Google Firebase sign-in). Your '
        'profile: sex, birth date, height, weight, goal, diet, allergies and '
        'any limitations you add. What you log: workouts and sets, meals, '
        'weigh-ins and body measurements, recovery check-ins, your mess. Your '
        'reminder settings and this phone\'s notification token. Feedback you '
        'send from the app, with the app\'s version. Your profile picture '
        'choice, and any request for Premium with the answer to it. A count of '
        'FITOS AI uses (not what was said). Your consent records, with a one-'
        'way scrambled form of the network address you consented from. Foods '
        'you add from a label; if you share one with everyone, other people '
        'can find and log it, marked Community and never with your name, and '
        'it is deleted with your account. A food search that finds nothing is '
        'counted without your name, so missing foods can be added. A thumbs '
        'up or down you give a mess dish is counted in totals everyone sees, '
        'never with your name, and deleted with your account. A programme you '
        'share as a code shows its days, exercises, sets and reps to anyone '
        'with the code, never your weights or your name; you can stop sharing '
        'it, and the codes are deleted with your account.',
  ),
  (
    'What stays on your phone',
    'Health Connect data (steps, sleep, heart rate and the rest) is read on'
        ' your phone and shown there. It is never sent to the FITOS server or '
        'to any AI.',
  ),
  (
    'Why',
    'To run the app (required): your plan, your targets, your logs and the '
        'suggestions built from them. To process health-related data '
        '(required): the app cannot work without it. FITOS AI (optional, asked '
        'when you first use it) and crash reports (on unless you turn them '
        'off): see below.',
  ),
  (
    'FITOS AI',
    'Only if you allow it. FITOS AI answers with Google\'s Gemini, so what '
        'you ask is sent to Google: for chat, your message and the FITOS data '
        'it needs; for describing a meal, only your words; for "Explain '
        'simply", that one suggestion. While FITOS uses Google\'s free tier, '
        'Google may use what is sent to improve its products; this will change '
        'before a public release. You can withdraw this any time in Privacy & '
        'data.',
  ),
  (
    'Crash reports',
    'When the app crashes or hits an error, it sends Google Firebase '
        'Crashlytics a report: what went wrong, where in the app\'s code, the '
        'app\'s version and the phone\'s model and Android version. A report '
        'never holds your account, your health, food or workout data, or '
        'anything you typed. They are on unless you turn them off in Privacy & '
        'data; turning them off also deletes any report not yet sent.',
  ),
  (
    'Who else',
    'Amazon Web Services hosts the FITOS server and database, in India. '
        'Google Firebase handles sign-in, notifications and crash reports. '
        'Google Gemini handles FITOS AI, only with your consent. Nobody else: '
        'no advertising, no selling, no sharing with other companies. No data '
        'of yours is used to train an AI model by FITOS.',
  ),
  (
    'How long',
    'Until you delete your account. The database keeps automatic backups '
        'for one day, so deleted data leaves them within a day. Before a risky '
        'change the developer may take one extra snapshot of the database, '
        'deleted within 30 days.',
  ),
  (
    'Your rights',
    'See and download everything FITOS holds about you (Download my data). '
        'Correct it in the app. Delete your account and every record of it at '
        'once (Delete account). Withdraw your FITOS AI consent and turn crash '
        'reports off at any time. Questions or complaints: write to the '
        'developer through Send feedback or the beta group; a published contact'
        ' and grievance officer will be named before any public launch.',
  ),
  (
    'Age',
    'FITOS is for people aged 18 or over; onboarding checks your birth '
        'date.',
  ),
  (
    'Security',
    'Your identity is checked by Google on every request, and FITOS only '
        'ever shows you your own data. The app talks to the server only over '
        'encrypted connections (HTTPS); the database is encrypted and cannot be'
        ' reached from the internet.',
  ),
  (
    'Changes',
    'This policy has a version. When it changes, FITOS asks you to accept '
        'the new one.',
  ),
];
