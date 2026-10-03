# Releasing Bunny Hop on Google Play

## 1. Create your upload key (once)

Google Play uses **Play App Signing**: Google holds the key that signs the app on users' phones, and you sign each upload with your own **upload key**. If you ever lose the upload key, you can ask Google to reset it from Play Console. That's a hassle, though, so back it up.

Make a folder for it, outside the project so it can never end up in git:

```
mkdir $env:USERPROFILE\keys
```

Create the key. It asks for a password (twice) and some name fields; your name is enough, and you can press Enter for the rest:

```
& "C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot\bin\keytool.exe" -genkeypair -v -keystore $env:USERPROFILE\keys\bunnyhop-upload.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

**Back up** `bunnyhop-upload.keystore` and its password together, somewhere safe outside this PC: a password manager is ideal.

## 2. Build the release bundle

```
.\release.ps1
```

It asks for the key password, builds `build\bunnyhop-<version>-<code>.aab`, and checks it's signed. Nothing is saved.

**For each later update,** Google Play needs a higher version code. Give a new version name and the script bumps the code for you:

```
.\release.ps1 -Version 1.0.1
```

Commit `export_presets.cfg` afterwards so the version number is saved.

## 3. Set up Play Console

1. Sign up at https://play.google.com/console (one-time US$25 fee, plus identity verification).
2. **Create app**: name *Bunny Hop*, default language, **Game**, **Free**. Accept the declarations.
3. Work through the **Dashboard** checklist. The answers for this game are below.

### Store listing (Grow > Store presence > Main store listing)

- Text: copy from `docs/store_listing.md`.
- App icon: `store/icon_512.png`
- Feature graphic: `store/feature_graphic.png`
- Phone screenshots: `store/screenshot_1.png` to `screenshot_6.png`, uploaded in that order
- Regenerate the art any time: `C:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . --audio-driver Dummy --script tools/make_store_art.gd`

#### AI asset declaration

After you upload the graphics and click **Next**, Play Console shows an **AI asset declaration** step. Select **Don't label assets**, and check it's still selected before you click **Save**. (The step may look different from this description, which comes from a guide dated August 2026. The choice is the same: don't apply the AI label.)

Why: Google asks you to label only the assets you judge to be covered by AI-labelling regulations ([help page](https://support.google.com/googleplay/android-developer/answer/17262077)). It doesn't name them. The ones it most likely means are the EU AI Act (Article 50) and the rules in India and New York that Google names for its ads products. They cover realistic content that could pass as real, such as deepfakes and human-like AI performers. Bunny Hop's store images are cartoon scenes built from the real game, so they are out of scope.

"Don't label assets" is a judgement about scope, not a claim that no AI was used. Labelling would also be truthful. It puts an AI mark on the images, which Google has so far documented only for phone users in the EU.

How the store images were made, as a record in case Google asks:

- **Screenshots 1 to 6:** staged scenes rendered by the game engine from the real game by `tools/make_store_art.gd`, with a caption banner added.
- **Feature graphic:** key art composed by the same script from the game's own sprites.
- **Icon:** composed by `tools/make_icons.gd`.
- **Human-made art in them:** the bunny, carrots, jetpack, wings, bubble, grass, mushrooms and hills, from the Kenney Jumper Pack (CC0), plus the engine's default font.
- **AI-written parts:** the birds, clouds, hats, planet, UFO, satellite and the other art in `assets/art` and `assets/ui`, the captions, and both scripts were written as code by an AI assistant (Claude). No image-generation model was used.
- Nothing is photorealistic or shows real people, places or events.

Check again if any of these happen:

- Google defines "AI-generated or edited", or shows the label outside the EU.
- South Korea's proposed rule for people who post AI-generated images becomes law (it had not as of 30 September 2026).
- You add realistic AI-made images, or a promo video. YouTube asks its own disclosure question at upload; animated content is exempt.

Checked on 3 October 2026. This is research, not legal advice.

### Privacy policy

Play Console needs a web address for it. The text is ready in `docs/privacy_policy.md`; add your contact email, then publish it somewhere public, for example:

- a page on your own domain,
- GitHub Pages (if the repository is public), or
- a Google Doc shared with **File > Share > Publish to web**.

### App content questionnaires (Policy > App content)

| Section | Answer for Bunny Hop |
|---|---|
| Privacy policy | The URL from above |
| Ads | **No**, the app does not contain ads |
| App access | All functionality is available without special access |
| Content rating | Fill in the IARC questionnaire: category **Game**; no violence, fear, sexuality, gambling, language or drugs; no user interaction or chat; no sharing of location; no purchases. It should come out as Everyone / PEGI 3. |
| Target audience | Include the under-13 age groups. Google treats cartoon animals as appealing to children, so a cute bunny game listed as **13+ only** is likely to be questioned in review. Including children puts the app under Google's Families policy, which Bunny Hop already meets: no ads, no data collection, no internet permission, no outside links, and a privacy policy with a section on children. If you still choose 13+ only, answer **Yes** to "Could your store listing unintentionally appeal to children?" and expect a closer review. |
| Data safety | **No** data collected, **no** data shared. (The accelerometer is only used on the device while playing.) |
| Government apps / financial features / health | Not applicable |

## 4. Internal testing release

1. **Testing > Internal testing > Testers**: create an email list with your testers' Google account emails (up to 100).
2. **Create new release**, upload the `.aab`, add release notes such as "First test build", then **Review** and **Start rollout**.
3. Copy the **opt-in link** from the Testers tab and send it to testers. They accept, then install from the Play Store. It can take a little while to show up the first time.

Internal testing doesn't need Google's full review, so it's the quickest way to get the game onto friends' phones.

## Going public later

Google requires new personal developer accounts to run a **closed test** before a production release. At the time of writing that was **at least 12 testers for 14 days**, but the rule has changed before, so check the current requirement in Play Console. Internal testing doesn't count toward it. When you're ready, move the build to **Closed testing**, gather testers, and after 14 days apply for production access in Play Console.
