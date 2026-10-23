# Beta 3.4 — plan

**Date** 2026-10-24 · **Branch** `phase-19` · **Status: approved by the owner 2026-10-24.**

The owner chose two backlog items for 3.4 and answered four questions on 2026-10-24.

| # | Change | Owner's answer |
|---|---|---|
| F8 | Progress photos, on the phone only | **Free** for everyone; stored **inside FITOS only** |
| F13 | Streak rewards | **New streak-only rewards**, at **7 · 14 · 30 · 60 · 100** days |

---

## F8 — Progress photos (on the phone only)

**Where:** Progress → a new **Photos** section, below the weight trend.

**Taking one:**
- **Add photo** → **Camera** or **From gallery**.
- Choose the pose: **Front · Side · Back** (optional).
- The date defaults to today and can be changed.
- The trend weight for that day, if known, is shown next to the photo. It is read from Progress, never typed again.

**Seeing them:**
- A timeline grid, newest first, filterable by pose.
- Tap a photo to open it full screen with its date, pose and weight.
- **Compare:** pick any two photos (the app suggests the oldest and newest of the same pose). You see them side by side with both dates, the days between them, and the weight change. A slider overlay (drag to reveal) is an option on the same screen.

**Where photos live, and the privacy promises:**
- Photos are kept in FITOS's **private storage**, not the gallery. They are **never uploaded**: no server, no AI, no analytics.
- **Excluded from Android's automatic backup:** new `dataExtractionRules` and `fullBackupContent`. Today the app has no backup rules, so Android may copy app files to the user's Google Drive backup.
- The screen says plainly: *"Photos stay on this phone. Uninstalling FITOS or changing phones loses them. Save any photo to your gallery to keep it."* **Save to gallery / Share** goes through the phone's share sheet (`share_plus`, already a dependency).
- **Delete** removes a photo and its file. **Deleting your account** deletes every photo on the phone. **Signing out** keeps them, because they are filed under the account, and another account on the same phone never sees them.
- They are not in the data export, which is the server's data; the export notes say so.
- **The privacy policy** gains a sentence: progress photos stay on your phone and are never uploaded.

**Technical:**
- A new dependency, **`image_picker`** (camera and gallery). It needs no storage permission on Android 13+.
- Photos are resized to at most 1600 px and saved as JPEG at quality 85, so each is about 300–500 KB.
- A local table, `progress_photos` (id, account, date, pose, file name, created), uses a Drift migration on the phone. There is no server change.

**Behind a switch** (ADR-033): `progress-photos`, on by default.

**Tests:** add from camera and from gallery (faked picker), the pose filter, compare and slider, delete removes the file, account deletion clears them, another account sees none, the backup rules exclude the folder, the switch hides it, and layout at 200 % text.

---

## F13 — Streak rewards (streak-only)

**Earned with the best streak ever** (the 3.3 streak's `best`, which already covers past days). Kept forever, even after the streak breaks. **The same for free and premium users:** these are not premium items.

| Streak | Reward | What it is |
|---|---|---|
| **7 days** | **Spark** | A profile picture: a small lit flame |
| **14 days** | **Ember** theme | A dark theme with warm ember-orange accents |
| **30 days** | **Blaze** app icon | The F in ember orange on carbon |
| **60 days** | **Ember rim** | A glowing orange ring around your picture on Home and Profile; it sits beside the premium gold rim, and the user picks which one to show |
| **100 days** | **Century** | A profile picture with a "100" mark, and a **100-day badge** on Profile |

These names are proposals. The owner can rename them before code.

**How it works:**
- **The server owns earned rewards:** a new table, `user_rewards` (user, reward, earned date; migration and its down migration).
  - When the streak is read (`GET /progress/streak`), any milestone the best streak has reached is recorded. The response gains `rewards: { earned: [...], new: [...] }`.
  - `new` is shown once: a small celebration, "🔥 14 days! You unlocked the Ember theme", with **Use it** and **Later**.
  - Existing users are credited for past runs at once (the best streak is computed from history).
- **Using them:**
  - **Pictures:** `PUT /user/avatar` accepts `spark` or `century` only when earned (403 `reward-locked` otherwise). The `users.avatar_id` check gains the two ids.
  - **The Ember theme and the Blaze icon** appear in the theme and app-icon pickers with a 🔥 lock and "Reach a 14-day streak" until earned.
  - **Ember rim:** a switch in Profile once earned.
- **On Profile:** a "Streak rewards" row lists all five, earned or how many days to go: "Ember theme · 3 more days".
- **Not shaming:** a broken streak never takes anything away, and nothing says "you lost".
- **Behind the `streaks` switch** (ADR-033): when it is off, rewards aren't granted or shown, but anything already earned keeps working.
- **The Blaze icon** is an adaptive icon added the same way as 3.2's icons (an activity-alias, `tool/app_icons.py`). The Ember palette is added to the brand kit's colours.

**Tests:**
- Milestones granted once at each threshold, retroactive from history, and kept after a break.
- `new` shown only once.
- Avatar refusal until earned.
- The pickers' locks.
- The switch-off behaviour.
- Export and deletion include `user_rewards`.

---

## Order and release

1. **F13 first.** It extends the streak just shipped and touches the server (migration 0030).
2. **Then F8,** which is phone only (Drift migration, backup rules, the new plugin).
3. Each part is committed with its tests and the local CI checks.
4. **Release:**
   - the API (migration 0030) and the admin panel (the new `progress-photos` switch);
   - the APK **1.0.0-beta.3.4 (10)**, tagged with a GitHub prerelease;
   - **the website and the update notice only when the owner says**, as for 3.3.

**Docs:**
- an ADR-027 amendment (streak rewards beside premium);
- ADR-035 (progress photos on the phone only, with backup exclusion);
- a privacy policy sentence (in the app and on the website);
- the backlog marks F8 and F13 as in 3.4.
