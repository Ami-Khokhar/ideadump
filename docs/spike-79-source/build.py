#!/usr/bin/env python3
"""Build the publishable spike page from index.html + style.css.

The artifact content origin sends `default-src 'self'` with no `style-src`, so an
inline <style> block is blocked and the page renders unstyled (agent-relay #287).
A `data:` stylesheet is allowed, so the CSS goes in as a data URI and the page
needs no inline style and no script at all.
"""
import pathlib
import urllib.parse

here = pathlib.Path(__file__).parent
css = (here / "style.css").read_text()
uri = "data:text/css;charset=utf-8," + urllib.parse.quote(css, safe="")
out = here.parent / "assistant-access-spike.html"
out.write_text((here / "index.html").read_text().replace("__CSS_DATA_URI__", uri))
print(f"wrote {out} ({out.stat().st_size} bytes)")
