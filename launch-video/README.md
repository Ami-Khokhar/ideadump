# TapLog launch video

`taplog-launch.mp4`: 40 s, 1080×1920 (9:16), 30 fps, silent. Sized for Reels, TikTok,
Shorts and X. Add music in your editor or in the app you post from.

| Time | Scene |
|---|---|
| 0–3 s | Hook: "You just spent money. Did you write it down?" |
| 3–7 s | The problem: bank logins, accounts, $10 a month (struck out) |
| 7–10 s | Logo: TapLog, fast, private spending log |
| 10–17 s | Live capture: type 4.50, tap Chai, Log, "Logged" toast |
| 17–21 s | Other ways in: Siri, Action Button, widgets, Lock Screen, share sheet, undo |
| 21–29 s | Budget trees and the weekly recap (App Store screenshots) |
| 29–33 s | Private by design |
| 33–36 s | Free, and Pro is one payment with no subscription |
| 36–40 s | End card: "Log it before you forget." / "Coming soon on iPhone" |

## Edit and re-render

The video is `launch.html` rendered frame by frame. Open the file in a browser to watch
it play live. Scene timings are in `SCENES`, and the copy is plain HTML.

```sh
pip install playwright imageio-ffmpeg
python3 render.py taplog-launch.mp4          # full video (about 2 min)
python3 render.py --stills 12 24             # PNG stills at those seconds
```

`render.py` uses the Chromium at `/opt/pw-browsers/chromium`. Change `executable_path`
in the script to use another Chromium, or remove it after running `playwright install chromium`.
When the app is live, change the end-card button text (`#cta`).
