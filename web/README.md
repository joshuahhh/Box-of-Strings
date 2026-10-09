# Box of Strings in the browser

This folder holds the web version of Box of Strings. It runs the same Haskell
code as the desktop app, compiled to JavaScript with GHC's JavaScript backend,
so the two behave the same.

## How it works

- **Graphics.** The desktop app draws with the [gloss](https://hackage.haskell.org/package/gloss)
  library (OpenGL). `web/gloss/` is a small stand-in with the same modules and
  functions that draws on an HTML canvas instead, including gloss's text font
  (the GLUT stroke font, `static/stroke-roman.js`). The app's own code is
  compiled unchanged against it.
- **Files.** A browser has no file system, so `app/Platform.hs` sends file
  access in the browser build to a small virtual file system (`static/glue.js`).
  It starts out with the theory files from `input/`, bundled at build time.
  Files the program writes (new operations, saved relations and proofs, TikZ
  and code exports) are kept in the browser's local storage. In the desktop
  build, `Platform` uses the real file system as before.
- **Terminal output** (what the desktop app prints) appears in the page's
  Console panel, and questions it would ask on the terminal open a dialog box.

## Building

You need GHC's JavaScript backend. The easiest way to get it is
[Nix](https://nixos.org/download/), which downloads a pre-built compiler
pinned in `shell.nix`:

```sh
nix-shell web/shell.nix --run web/build.sh
python3 -m http.server -d web/dist   # then open http://localhost:8000
```

The result in `web/dist/` is a plain static site. The page must be served over
HTTP (opening `index.html` straight from disk won't work).

## Publishing on GitHub Pages

`.github/workflows/pages.yml` builds the site and publishes it on every push
to `main`. To turn it on, go to the repository's **Settings → Pages** and set
**Source** to **GitHub Actions**. The site then appears at
`https://<owner>.github.io/<repository>/`.

## Differences from the desktop app

- Esc doesn't quit (there is nothing to quit to); close the tab instead.
- Changes to files are saved only in the browser you made them in. Use
  **Download changes** to get them as files, **Open file…** to add your own
  theory files (they appear in the file list under `uploads/`), and **Reset**
  to go back to the original files.
- Backspace and Delete both act as gloss's Delete key.
- On a Mac, Ctrl+click works as a right click.
- Touch screens can click and drag, but rewriting needs a mouse wheel (or the
  arrow keys) and right click, so a mouse or trackpad is needed in practice.
- If an action fails with an error, the web version undoes it and reports
  the error in the Console instead of crashing.
