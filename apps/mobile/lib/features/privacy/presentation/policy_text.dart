/// The privacy policy as the app shows it (Phase 17, §23.6). The same text
/// as docs/legal/privacy-policy.md; a test checks the two stay in step and
/// that the version is the server's CURRENT_POLICY_VERSION.
library;

const kPolicyVersion = '2026-10-22';

const kPolicySections = <(String, String)>[
  (
    'Who we are',
    'FITOS is a fitness and nutrition app for VIT students, built and run by '
        'its developer. It is in a closed alpha: a small group of testers, with '
        'the server running on the developer\'s computer on a local Wi-Fi network.',
  ),
  (
    'What FITOS keeps',
    'Your account (email and name, through Google Firebase sign-in). Your '
        'profile: sex, birth date, height, weight, goal, diet, allergies and any '
        'limitations you add. What you log: workouts and sets, meals, weigh-ins '
        'and body measurements, recovery check-ins, your mess. Your reminder '
        'settings and this phone\'s notification token. A count of FITOS AI uses '
        '(not what was said). Your consent records, with a one-way scrambled '
        'form of the network address you consented from.',
  ),
  (
    'What stays on your phone',
    'Health Connect data (steps, sleep, heart rate and the rest) is read on '
        'your phone and shown there. It is never sent to the FITOS server or to '
        'any AI.',
  ),
  (
    'Why',
    'To run the app (required): your plan, your targets, your logs and the '
        'suggestions built from them. To process health-related data (required): '
        'the app cannot work without it. FITOS AI (optional, asked when you first '
        'use it): see below.',
  ),
  (
    'FITOS AI',
    'Only if you allow it. FITOS AI answers with Google\'s Gemini, so what you '
        'ask is sent to Google: for chat, your message and the FITOS data it needs; '
        'for describing a meal, only your words; for "Explain simply", that one '
        'suggestion. During the alpha FITOS uses Google\'s free tier, where Google '
        'may use what is sent to improve its products; this will change before a '
        'public release. You can withdraw this any time in Privacy & data.',
  ),
  (
    'Who else',
    'Google Firebase handles sign-in. Google Gemini handles FITOS AI, only with '
        'your consent. Nobody else: no advertising, no selling, no sharing with '
        'other companies. No data of yours is used to train an AI model by FITOS.',
  ),
  (
    'How long',
    'Until you delete your account. Backups of the server are kept on the '
        'developer\'s computer (the 14 most recent); deleted data leaves them as '
        'they are replaced, within about two weeks.',
  ),
  (
    'Your rights',
    'See and download everything FITOS holds about you (Download my data). '
        'Correct it in the app. Delete your account and every record of it at once '
        '(Delete account). Withdraw your FITOS AI consent at any time. Questions or '
        'complaints: write to the developer through the alpha group; a published '
        'contact and grievance officer will be named before any public launch.',
  ),
  (
    'Age',
    'FITOS is for people aged 18 or over; onboarding checks your birth date.',
  ),
  (
    'Security',
    'Your identity is checked by Google on every request, and FITOS only ever '
        'shows you your own data. During the alpha the app talks to the server '
        'over your local Wi-Fi without encryption; a hosted version will use '
        'encrypted connections (HTTPS) only.',
  ),
  (
    'Changes',
    'This policy has a version. When it changes, FITOS asks you to accept the '
        'new one.',
  ),
];
