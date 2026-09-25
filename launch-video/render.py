"""Render launch.html frame-by-frame to MP4.

usage: python3 render.py out.mp4 [fps]      full video
       python3 render.py --stills 1 5 12     PNG stills at those seconds
"""
import pathlib, subprocess, sys
import imageio_ffmpeg
from playwright.sync_api import sync_playwright

HERE = pathlib.Path(__file__).resolve().parent
URL = (HERE / "launch.html").as_uri() + "?render"


def main():
    with sync_playwright() as pw:
        browser = pw.chromium.launch(executable_path="/opt/pw-browsers/chromium")
        page = browser.new_page(viewport={"width": 1080, "height": 1920})
        page.goto(URL)
        page.evaluate("document.fonts.ready")
        page.wait_for_timeout(300)

        if sys.argv[1] == "--stills":
            for s in sys.argv[2:]:
                page.evaluate(f"render({float(s)})")
                page.screenshot(path=str(HERE / f"still-{s}.png"))
            return

        out, fps = sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 30
        duration = page.evaluate("window.DURATION")
        ff = subprocess.Popen([
            imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error",
            "-f", "image2pipe", "-framerate", str(fps), "-c:v", "png", "-i", "-",
            "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-preset", "slow",
            "-movflags", "+faststart", out], stdin=subprocess.PIPE)
        frames = int(duration * fps)
        for i in range(frames):
            page.evaluate(f"render({i / fps})")
            ff.stdin.write(page.screenshot(type="png"))
            if i % 150 == 0:
                print(f"{i}/{frames}", flush=True)
        ff.stdin.close()
        ff.wait()
        browser.close()


main()
