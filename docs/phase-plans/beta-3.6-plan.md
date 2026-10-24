# Beta 3.6 — plan

**Date** 2026-10-24 · **Branch** `phase-19` · **Status: awaiting the owner's approval.**

The owner chose 3.6 on 2026-10-24: four fixes from using 3.5, weekly steps, and two backlog items, and answered four questions.

| # | Change | Owner's answer |
|---|---|---|
| B1 | Remove a set during a workout | — |
| B2 | "+ Add set" sometimes needs two taps | — |
| B3 | A photo taken with the camera is not added (gallery works) | — |
| P1 | Progress photos hidden until you choose to see them | — |
| S1 | Weekly steps, day by day, with a graph | **This week + 4 weeks** |
| F14 | Feedback with pictures, and more | **Up to 3 pictures**; **replies from admin**, **type**, **device info** |
| F15 | AI food guide | From **what you have with you** and **today's mess menu** |

Nothing is released until the owner says 3.6 is ready (as with 3.5).

---

## B1 — Remove a set during a workout

Today a logged set can be un-logged (tap its check again), but a set not logged yet cannot be removed, and neither can an extra row added with "+ Add set".

- **Swipe a set row left → Remove.** It works on any row:
  - a set not logged yet disappears for this workout;
  - a logged set is deleted (as un-logging does today).
  - **Undo** appears for a few seconds.
- **"− Remove set"** sits next to "+ Add set" and removes the last set not logged yet. Swiping is easy to miss, so this is the visible way.
- **This workout only.** The programme keeps its planned sets. (Editing the programme's set counts is a separate screen.)
- **Survives leaving the screen.** Today the extra rows from "+ Add set" are lost if you leave the workout and come back. The session on the phone now remembers each exercise's added and removed rows.
- At least one row stays, so an exercise always has a set to log; "Remove" on the exercise removes the whole exercise, as today.

**Tests:** swipe removes a pending set and a logged set; Undo brings either back; the button removes the last pending set; rows survive leaving and returning; the planned programme is unchanged; the screen stays usable at 360 px and 200 % text.

## B2 — "+ Add set" sometimes needs two taps

No cause is visible in the code, so this starts as an investigation, on the S24 and in tests. The likely suspects:
1. the keyboard is open from typing a weight, and the first tap only closes it and moves the layout;
2. the workout screen redraws every second (the clock) or when a set syncs, and a tap lands mid-redraw;
3. the button sits in a wrapping row that moves as the card grows.

The fix depends on what is found. **The test:** one tap adds exactly one row in each state (keyboard open, while the clock ticks, right after logging a set, right after a sync). The same check covers "Drop set" and the new "− Remove set".

## B3 — A camera photo is not added

Choosing from the gallery works; taking a photo does not. Two causes, both fixed:

1. **FITOS forgets the photo when it comes back.** The camera sends FITOS to the background (the gallery picker does not). On return, FITOS refreshes several things (feature switches, health data, sync). If the screen that started "Add photo" was rebuilt meanwhile, the code sees it is gone and drops the photo. **Fix:** once a photo is picked, finishing it (pose, date, save) no longer depends on that screen. It continues on the app's own navigator.
2. **Android may close FITOS while the camera is open.** This is common on Samsung phones with little free memory. The photo is then lost, because nothing asks the camera for it afterwards. **Fix:** when FITOS starts, it asks for a photo lost this way (`image_picker`'s `retrieveLostData`) and offers *"Finish adding your progress photo"*.

**Tests:** a camera photo is saved even when the starting screen was rebuilt; a lost photo is offered on the next start and saved; a cancelled camera adds nothing. Plus a check on the S24.

## P1 — Progress photos hidden until you choose

So nobody sees your photos over your shoulder:
- **Progress card:** no thumbnails; it shows *"5 photos · hidden"* with **Show photos**.
- **Photos screen:** the grid is hidden behind **Show photos** each time it opens.
- **Hidden again** when you leave the screen or FITOS goes to the background.
- **Compare and full screen** open only after the photos are shown.
- Adding a photo works without showing the others.

**Tests:** hidden on open, shown on the button, hidden again on leaving and on background; 200 % text.

---

## S1 — Weekly steps

**Where:** tap **Steps** on Home, or Health → Steps.

- **Week** (default): a bar for each day, Monday to Sunday, with:
  - the step goal as a line;
  - the **total**, the **daily average**, the **best day**, and **days at goal** (e.g. *4 of 7*);
  - tapping a bar shows that day's steps;
  - arrows go to earlier weeks.
- **4 weeks:** one bar per week (the average per day), the goal line, and the change from the week before.
- **Today** is marked, and so is a day with no data (as opposed to 0 steps).

**Data:** read from Health Connect on the phone, up to 28 days back. It is never uploaded, as with today's steps. FITOS already reads this week's daily steps for the Home score; this reads further back. Without the Health Connect permission, the screen offers **Connect** (as Health does now).

**Tests:** bars and figures from fixed days; a gap day versus 0; goal line; week arrows; 4-week averages; no permission; 360 px at 200 % text.

---

## F14 — Feedback with pictures, and more

**Pictures**
- **Up to 3 per message**, from the gallery (screenshots) or the camera.
- Resized on the phone (≤ 1600 px JPEG, about 300 KB each); the server refuses anything over 1 MB.
- Kept on the FITOS server (in the database, so they are in its backups and move with it if hosting changes, ADR-025).
- **Deleted** with the account, and **after 6 months** (a daily clean-up). The text stays until the account goes.
- **Admin panel:** thumbnails on each card; click to open full size. Only admins can fetch them.

**Type** — already exists (bug, idea, food, training, other). New: a **filter by type** in the admin panel.

**Device info**
- Attached automatically: phone model, Android version, the FITOS version and build, and the screen you came from.
- The form shows it before sending (*"Sent with: Samsung SM-S921B · Android 15 · beta 3.6 (12)"*), with a switch to leave it out.
- New dependency: `device_info_plus`.

**Replies from admin**
- A reply box on each feedback card in the admin panel. Replies are audited.
- **In the app:** Profile → Send feedback gains **Your messages**, with each message's status (new / to do / done) and the replies. A dot marks an unread reply.
- **A push notification** (FCM, as the update notice): *"FITOS replied to your feedback"*. Tapping it opens the message.
- The user answers by sending new feedback. There is no chat thread in 3.6.

**Privacy policy** gains: pictures you attach and when they are deleted, the device details, and replies.

**Server:** migration 0032:
- `feedback_attachments` (picture bytes, type, size; cascade on feedback and account);
- `feedback_replies` (text, admin, time, read time);
- device columns on `feedback`.

New routes: upload with the message; `GET /feedback/mine`; mark replies read; admin `GET` picture and `POST` reply. The feedback limit (20 an hour) still applies.

**Tests:** 0–3 pictures, the 4th refused, oversize refused, non-images refused; only admins fetch pictures; the 6-month clean-up; account deletion removes everything; the reply reaches the app and pushes once; read marks; device info shown and left out on request; the type filter; contract checks.

---

## F15 — AI food guide (premium)

**Where:** Eat → **What should I eat?** Premium only, like all FITOS AI (ADR-028). Free users see what it does and how to get Premium.

**You choose:**
- **Which meal** (defaults from the time: breakfast, lunch, snacks, dinner).
- **From the mess:** today's menu for that meal, if you have a mess set (one tap).
- **What I have:** tick common items (bread, eggs, milk, curd, peanut butter, oats, banana, fruit, paneer, protein powder, chana, nuts and the like) and/or type others.
- Optional, **I feel like…** in your own words (e.g. *something spicy*, *light*).

**You get** 2–3 options, each with:
- the dishes and portions;
- calories and protein, and how it fits **what's left of today's targets** (e.g. *fills 40 g of your 55 g protein gap*);
- one line on why;
- **Log this**, which logs it in one tap.

**Honest numbers.** The AI may only pick foods from the FITOS food database and dishes from today's mess menu (it looks them up with tools, as FITOS AI already does). Calories and protein come from the database, never from the model. A typed item FITOS doesn't know is used only if it matches a database food. Otherwise the option says so and isn't loggable.

**What is sent to the AI:**
- the meal, the menu, what you ticked and typed;
- today's remaining calories and protein, and your diet type and allergies (so it never suggests something you can't eat).

Your name, weight and history are not sent. This needs the existing AI consent and counts as an AI use with its own hourly limit (`food-guide`).

**Behind a switch** (ADR-033): `food-guide`.

**Tests (fake AI provider):**
- options only from the database or menu;
- numbers from the database;
- allergies and diet respected;
- an unknown item isn't loggable;
- Log this logs exactly the shown portions;
- premium-only, consent required, the hourly limit, the switch;
- no mess means no menu option;
- 200 % text.

---

## Order of work, and release

1. **Fixes first:** B3 camera, B2 add set, B1 remove set, P1 hidden photos. They are small and you feel them every day.
2. S1 steps.
3. F14 feedback.
4. F15 food guide.

Each is committed separately with its tests. Nothing is deployed until the owner says 3.6 is ready. The release then follows the 3.5 order: API (migration 0032), admin, APK **1.0.0-beta.3.6 (12)**, GitHub prerelease, website post, then **Announce update**. Announce update needs the Cloud Messaging permission (granted by the owner, 2026-10-24); replies use the same permission.

**Docs:** ADR-035 amendment (P1, B3), feedback ADR amendment (F14), ADR-020 amendment (F15), ADR-033 (two new switches), privacy policy, backlog F14/F15 marked as in 3.6.
