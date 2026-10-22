# FITOS beta on Google Play internal testing: runbook (ADR-026)

The beta app is `me.tryfitos.app`, signed with **your** upload key, and talks to `https://api.tryfitos.me` (ADR-025). Google Play's **internal testing** track delivers it to up to 100 testers by email, with no store review wait.

**Rules**
- **You** run every step that creates an account, a key or a listing, or that costs money.
- Keystore passwords go only into `android/key.properties` on this PC (gitignored), never into the chat or the repo.

| Step | What | Who |
|---|---|---|
| 1 | Upload key | you (one command) |
| 2 | Firebase: register the new package name | you (console) |
| 3 | Crashlytics on | you (console) |
| 4 | Play Console account and app | you (US$25 once) |
| 5 | Build the bundle | you (one script) |
| 6 | Internal testing release | you (console) |
| 7 | Testers | you |
| 8 | Acceptance checks | you + the phone |

---

## 1. Upload key (once)

`keytool` comes with the JDK that Android Studio installs. If PowerShell doesn't find it, use `"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"`.

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\FitOS-keys" | Out-Null
keytool -genkeypair -v -keystore "$env:USERPROFILE\FitOS-keys\fitos-upload.jks" -alias fitos-upload -keyalg RSA -keysize 2048 -validity 10000
```

It asks for a password and a name. Then:
1. Copy `apps/mobile/android/key.properties.example` to `apps/mobile/android/key.properties`.
2. Fill in your path and the passwords.
3. Back up the `.jks` file and the password somewhere safe, outside this PC. Play App Signing (step 6) holds the key that actually signs the installed app, but losing the upload key means asking Google to reset it.

## 2. Firebase: the new package name

The app was `com.example.fitos` until Phase 19. Sign-in on new builds works only after this step.

1. Firebase console → project `fitos-dev-3208b` → Project settings → **Add app** → Android.
   - Package name: `me.tryfitos.app`
   - Nickname: FITOS
2. Add the **SHA-1** of each key that signs the app. To print the debug and upload fingerprints:
   ```
   cd apps\mobile\android; .\gradlew signingReport
   ```
   After step 6, also add the **App signing key** SHA-1 from Play Console → Test and release → Setup → App signing.
3. Copy the new app's **App ID** (`1:256732696671:android:...`) into `FIREBASE_APP_ID` in `apps/mobile/alpha.env`. Add it to `hosted.env` too, if you keep one.
4. Leave the old `com.example.fitos` app registered until nobody runs an old build.

## 3. Crashlytics on

Firebase console → Crashlytics → **Enable**.

The app sends crash reports only from release builds, and only while the user hasn't turned them off in Privacy & data. Reports show in the console a few minutes after a crash, once the app restarts.

## 4. Play Console account and app (once)

1. **Create the developer account:** play.google.com/console, a personal account, US$25 once. Verify your identity when asked.
2. **Create the app:**
   - Name: FITOS
   - Default language: English (India)
   - App
   - Free
   - Accept the declarations.
3. Under App content, fill in what internal testing needs:
   - **privacy policy URL:** `https://tryfitos.me/privacy/` (the FITOS website, a separate repository: its `/privacy/` page carries `docs/legal/privacy-policy.md`; keep the two in step);
   - **data safety:** see the table below;
   - **target audience:** 18+;
   - **ads:** no;
   - **app access:** Google sign-in.

**Data safety answers:**

| Question | Answer |
|---|---|
| Collects or shares data | Collects: name, email, health and fitness, app activity, crash logs and diagnostics. Shared: no (service providers only) |
| Encrypted in transit | Yes |
| Users can request deletion | Yes, in-app: Privacy & data → Delete my account |

## 5. Build the bundle

From `apps/mobile`:
```powershell
.\tool\hosted.ps1 -AppBundle -Version 1.0.0-beta.1 -BuildNumber 4
```
This:
- refuses to build without `key.properties`;
- checks that `https://api.tryfitos.me/health` answers;
- builds, then scans the bundle for secrets.

Output: `build\app\outputs\bundle\release\fitos-1.0.0-beta.1-4.aab`.

**Every later upload needs a higher `-BuildNumber`.**

## 6. Internal testing release

Play Console → Test and release → Testing → **Internal testing** → Create new release:
1. Accept **Play App Signing**. Google keeps the app signing key; you keep the upload key.
2. Upload the `.aab` and write the release notes.
3. Save → Review → **Roll out**.

## 7. Testers

Internal testing → Testers → create an email list (the 20 VIT students), save, and copy the **opt-in link**. Testers:
1. open the link while signed in to Play with a listed email;
2. accept;
3. install FITOS from Play.

## 8. Acceptance checks (§31 Phase 19)

1. A tester installs from Play, signs in with Google, onboards, and logs a workout and a meal.
2. **Profile → Send feedback** → it shows in the admin panel → Feedback.
3. **Crash reports:** Firebase → Crashlytics shows the app (and crash-free users) after the first sessions. The §31 target is a crash-free rate above 99% over one week with 20 real users.
4. **Forcing an update:**
   ```
   .\scripts\aws\set-parameter.ps1 -Name MIN_APP_BUILD -Value <build number>
   ```
   then release the server. Older builds then show only "Update FITOS". Set it to `0` to switch the check off.

---

## Every new app version

1. Raise `-BuildNumber`, and `-Version` if you like.
2. Run step 5, then step 6 with the new bundle.
3. When a server change needs the new app, set `MIN_APP_BUILD` to the new build number after the release has reached the testers.
