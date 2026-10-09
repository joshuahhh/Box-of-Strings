// Browser runtime for the web build of Box of Strings.
//
// The Haskell program (compiled with GHC's JavaScript backend) talks to this
// file through the global `BoS` object:
//   BoS.gfx    – canvas renderer used by the gloss stand-in (web/gloss)
//   BoS.events – input event queue drained by the gloss stand-in every frame
//   BoS.fs     – virtual file system used by app/Platform.hs
// It also provides the page chrome: console panel, file buttons and help.
"use strict";

(function () {
  const BoS = (window.BoS = {});
  const $ = (id) => document.getElementById(id);

  // ---------------------------------------------------------------------------
  // Virtual file system
  //
  // Base files come from input-files.js (generated at build time from the
  // repository's "input" folder). Files written by the program, or uploaded by
  // the user, are kept in localStorage as an overlay on top of the base files.

  const STORAGE_KEY = "box-of-strings:files:v1";
  const base = window.BOS_INPUT_FILES || {};
  let overlay = {};
  try {
    overlay = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}") || {};
  } catch (e) {
    overlay = {};
  }

  function normPath(p) {
    p = String(p).replace(/\\/g, "/").replace(/\/+/g, "/");
    while (p.startsWith("./")) p = p.slice(2);
    if (p.endsWith("/")) p = p.slice(0, -1);
    return p;
  }

  function persist() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(overlay));
    } catch (e) {
      BoS.log("Warning: could not save changes in browser storage (" + e.message + ")\n", "error");
    }
  }

  function allPaths() {
    const s = new Set(Object.keys(base));
    for (const k of Object.keys(overlay)) s.add(k);
    return s;
  }

  BoS.fs = {
    read(p) {
      p = normPath(p);
      if (Object.prototype.hasOwnProperty.call(overlay, p)) return overlay[p];
      if (Object.prototype.hasOwnProperty.call(base, p)) return base[p];
      return null;
    },
    write(p, s) {
      p = normPath(p);
      overlay[p] = s;
      persist();
      fileWritten(p);
    },
    exists(p) {
      return BoS.fs.read(p) !== null;
    },
    // Entries directly inside a directory (like getDirectoryContents),
    // or null if the directory does not exist.
    list(dir) {
      dir = normPath(dir);
      const prefix = dir === "" ? "" : dir + "/";
      const names = new Set();
      for (const p of allPaths()) {
        if (p.startsWith(prefix)) names.add(p.slice(prefix.length).split("/")[0]);
      }
      if (names.size === 0) return null;
      return [".", ".."].concat([...names]);
    },
    changedPaths() {
      return Object.keys(overlay)
        .filter((p) => overlay[p] !== base[p])
        .sort();
    },
    reset() {
      overlay = {};
      persist();
    },
  };

  // ---------------------------------------------------------------------------
  // Canvas renderer

  const canvas = $("stage-canvas");
  const ctx = canvas.getContext("2d");
  const gfx = (BoS.gfx = {
    ctx,
    lw: 900, // logical (gloss window) size
    lh: 600,
    fit: 1, // CSS pixels per logical pixel
    dpr: 1,
    bg: "#fff",
    color: "",
  });

  function cssColor(r, g, b, a) {
    const c = (x) => Math.round(Math.min(1, Math.max(0, x)) * 255);
    return "rgba(" + c(r) + "," + c(g) + "," + c(b) + "," + Math.min(1, Math.max(0, a)) + ")";
  }

  function stageSize() {
    const stage = $("stage");
    return { w: Math.max(100, stage.clientWidth), h: Math.max(100, stage.clientHeight) };
  }

  function layout() {
    const { w, h } = stageSize();
    gfx.fit = Math.min(w / gfx.lw, h / gfx.lh);
    gfx.dpr = window.devicePixelRatio || 1;
    const cw = Math.floor(gfx.lw * gfx.fit);
    const ch = Math.floor(gfx.lh * gfx.fit);
    canvas.style.width = cw + "px";
    canvas.style.height = ch + "px";
    canvas.width = Math.round(cw * gfx.dpr);
    canvas.height = Math.round(ch * gfx.dpr);
    if (BoS.placeTapMarker) BoS.placeTapMarker();
  }

  gfx.screenWidth = () => stageSize().w;
  gfx.screenHeight = () => stageSize().h;

  gfx.init = function (w, h, r, g, b, a) {
    gfx.lw = w;
    gfx.lh = h;
    gfx.bg = cssColor(r, g, b, a);
    layout();
    window.addEventListener("resize", layout);
    $("loading").hidden = true;
    canvas.hidden = false;
    canvas.focus();
  };

  gfx.beginFrame = function () {
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.fillStyle = gfx.bg;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    // Gloss coordinates: origin in the centre, y pointing up.
    const k = gfx.fit * gfx.dpr;
    ctx.setTransform(k, 0, 0, -k, canvas.width / 2, canvas.height / 2);
    gfx.color = "";
  };

  // The current colour is cached to avoid re-parsing CSS colours; restore()
  // can change the canvas colour behind the cache's back, so it resets it.
  gfx.save = function () {
    ctx.save();
  };
  gfx.restore = function () {
    ctx.restore();
    gfx.color = "";
  };

  gfx.setColor = function (r, g, b, a) {
    const c = cssColor(r, g, b, a);
    if (c !== gfx.color) {
      gfx.color = c;
      ctx.fillStyle = c;
      ctx.strokeStyle = c;
    }
  };

  // Gloss draws lines one pixel wide regardless of the current scale, so the
  // path is built in the current transform but stroked in device space.
  function strokeThin() {
    ctx.save();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.lineWidth = gfx.dpr * Math.max(1, gfx.fit);
    ctx.lineJoin = "round";
    ctx.lineCap = "round";
    ctx.stroke();
    ctx.restore();
  }

  gfx.polygon = function (pts) {
    if (pts.length < 4) return;
    ctx.beginPath();
    ctx.moveTo(pts[0], pts[1]);
    for (let i = 2; i < pts.length; i += 2) ctx.lineTo(pts[i], pts[i + 1]);
    ctx.closePath();
    ctx.fill();
  };

  gfx.line = function (pts) {
    if (pts.length < 4) return;
    ctx.beginPath();
    ctx.moveTo(pts[0], pts[1]);
    for (let i = 2; i < pts.length; i += 2) ctx.lineTo(pts[i], pts[i + 1]);
    strokeThin();
  };

  // Arc from a1 to a2 degrees (counter-clockwise) with radius r. A thickness
  // of 0 draws a thin line; otherwise a filled band of that width.
  gfx.arc = function (a1, a2, r, t) {
    const full = Math.abs(a2 - a1) >= 360;
    const s = (a1 * Math.PI) / 180;
    const e = full ? s + 2 * Math.PI : (a2 * Math.PI) / 180;
    r = Math.abs(r);
    ctx.beginPath();
    if (t === 0) {
      ctx.arc(0, 0, r, s, e, false);
      strokeThin();
    } else {
      const outer = r + Math.abs(t) / 2;
      const inner = Math.max(0, r - Math.abs(t) / 2);
      ctx.arc(0, 0, outer, s, e, false);
      if (full) ctx.moveTo(inner, 0);
      ctx.arc(0, 0, inner, full ? 2 * Math.PI : e, full ? 0 : s, true);
      ctx.closePath();
      ctx.fill("evenodd");
    }
  };

  // Text in the GLUT stroke font, like gloss: baseline at the origin and
  // capital letters 100 units tall.
  gfx.text = function (str) {
    const font = window.STROKE_ROMAN || {};
    let x = 0;
    ctx.beginPath();
    for (const ch of str) {
      const glyph = font[ch.codePointAt(0)];
      if (!glyph) continue;
      for (const strip of glyph[1]) {
        ctx.moveTo(x + strip[0], strip[1]);
        for (let i = 2; i < strip.length; i += 2) ctx.lineTo(x + strip[i], strip[i + 1]);
      }
      x += glyph[0];
    }
    strokeThin();
  };

  // ---------------------------------------------------------------------------
  // Input events
  //
  // Each queued event is an array:
  //   [type (0 key, 1 motion), keyKind (0 char, 1 special, 2 mouse),
  //    keyCode, keyName, state (0 down, 1 up), shift, ctrl, alt, x, y]

  const events = (BoS.events = []);
  const mouse = { x: 0, y: 0 };
  const mods = { shift: 1, ctrl: 1, alt: 1 };

  function toLogical(clientX, clientY) {
    const rect = canvas.getBoundingClientRect();
    return {
      x: (clientX - rect.left - rect.width / 2) / gfx.fit,
      y: (rect.height / 2 - (clientY - rect.top)) / gfx.fit,
    };
  }

  function readMods(e) {
    mods.shift = e.shiftKey ? 0 : 1;
    mods.ctrl = e.ctrlKey || e.metaKey ? 0 : 1;
    mods.alt = e.altKey ? 0 : 1;
  }

  function pushKey(kind, code, name, state) {
    events.push([0, kind, code, name, state, mods.shift, mods.ctrl, mods.alt, mouse.x, mouse.y]);
  }

  function pushMotion() {
    events.push([1, 0, 0, "", 0, 1, 1, 1, mouse.x, mouse.y]);
  }

  function updateMouse(e) {
    const p = toLogical(e.clientX, e.clientY);
    mouse.x = p.x;
    mouse.y = p.y;
  }

  // Gloss mouse button codes: 0 left, 1 middle, 2 right. On a Mac,
  // Ctrl+click counts as a right click (as it does elsewhere on macOS).
  const isMac = /Mac/.test(navigator.platform || navigator.userAgent);
  let dragButton = 0;
  let lastRightDown = -Infinity;
  function glossButton(e) {
    if (e.pointerType !== "mouse") return 0;
    if (e.button === 0 && e.ctrlKey && isMac) return 2;
    return e.button <= 2 ? e.button : e.button + 2;
  }

  let dragging = false;
  canvas.addEventListener("pointerdown", (e) => {
    canvas.focus();
    readMods(e);
    updateMouse(e);
    pushMotion();
    dragButton = glossButton(e);
    if (dragButton === 0) setTapTarget();
    pushKey(2, dragButton, "", 0);
    if (dragButton === 2) lastRightDown = e.timeStamp;
    dragging = true;
    try {
      canvas.setPointerCapture(e.pointerId);
    } catch (err) {
      /* ignore */
    }
    e.preventDefault();
  });
  canvas.addEventListener("pointermove", (e) => {
    readMods(e);
    updateMouse(e);
    pushMotion();
  });
  const pointerUp = (e) => {
    if (!dragging) return;
    dragging = false;
    readMods(e);
    updateMouse(e);
    pushKey(2, dragButton, "", 1);
  };
  canvas.addEventListener("pointerup", pointerUp);
  canvas.addEventListener("pointercancel", pointerUp);
  // Some browsers deliver a Mac Ctrl+click only as a "contextmenu" event, so
  // treat that as a right click too, unless the pointer events already did.
  canvas.addEventListener("contextmenu", (e) => {
    e.preventDefault();
    if (e.timeStamp - lastRightDown < 1000) return;
    readMods(e);
    updateMouse(e);
    pushMotion();
    pushKey(2, 2, "", 0);
    pushKey(2, 2, "", 1);
  });

  // Turn wheel movement into discrete wheel clicks: one click per notch of a
  // mouse wheel, and a steady stream for smooth (trackpad) scrolling.
  let wheelAcc = 0;
  let lastWheel = 0;
  canvas.addEventListener(
    "wheel",
    (e) => {
      e.preventDefault();
      readMods(e);
      updateMouse(e);
      const unit = e.deltaMode === 1 ? 33 : e.deltaMode === 2 ? 400 : 1;
      const dy = e.deltaY * unit;
      const click = (up) => {
        pushKey(2, up ? 3 : 4, "", 0);
        pushKey(2, up ? 3 : 4, "", 1);
      };
      const step = 100;
      if (e.timeStamp - lastWheel > 250) {
        // Start of a new scroll gesture: react straight away.
        wheelAcc = 0;
        if (dy !== 0) click(dy < 0);
      } else {
        wheelAcc += dy;
        while (Math.abs(wheelAcc) >= step) {
          const up = wheelAcc < 0;
          wheelAcc += up ? step : -step;
          click(up);
        }
      }
      lastWheel = e.timeStamp;
    },
    { passive: false }
  );

  // On-screen buttons for touch and pen: scroll wheel and right click,
  // sent at the last pointer position over the diagram. They react on
  // pointerdown and never take focus, so a hovering pen keeps its place.
  // The buttons act on the last place tapped/clicked on the diagram (shown
  // with a small marker), not the last hover position: a hovering pen would
  // otherwise drag that position along on its way to the buttons.
  const touchControls = $("touch-controls");
  const tapMarker = $("tap-marker");
  let tapTarget = null;
  function setTapTarget() {
    tapTarget = { x: mouse.x, y: mouse.y };
    BoS.placeTapMarker();
  }
  BoS.placeTapMarker = function () {
    if (!tapTarget || canvas.hidden) return;
    const rect = canvas.getBoundingClientRect();
    tapMarker.style.left = rect.left + rect.width / 2 + tapTarget.x * gfx.fit + "px";
    tapMarker.style.top = rect.top + rect.height / 2 - tapTarget.y * gfx.fit + "px";
    tapMarker.hidden = false;
  };
  window.addEventListener("scroll", BoS.placeTapMarker, true);
  touchControls.addEventListener("pointerdown", (e) => {
    e.preventDefault();
    const btn = e.target.closest("button");
    if (!btn) return;
    const button = { "wheel-up": 3, "wheel-down": 4, "right-click": 2 }[btn.dataset.action];
    if (tapTarget) {
      // Point the app at the tapped spot again (this also refreshes which
      // rewrites it offers there).
      mouse.x = tapTarget.x;
      mouse.y = tapTarget.y;
      pushMotion();
    }
    pushKey(2, button, "", 0);
    pushKey(2, button, "", 1);
    btn.classList.add("pressed");
    setTimeout(() => btn.classList.remove("pressed"), 150);
  });
  touchControls.addEventListener("click", (e) => e.preventDefault());
  touchControls.addEventListener("dblclick", (e) => e.preventDefault());
  touchControls.addEventListener("contextmenu", (e) => e.preventDefault());

  const SPECIAL_KEYS = {
    " ": "KeySpace",
    Escape: "KeyEsc",
    Enter: "KeyEnter",
    Tab: "KeyTab",
    Backspace: "KeyDelete",
    Delete: "KeyDelete",
    ArrowUp: "KeyUp",
    ArrowDown: "KeyDown",
    ArrowLeft: "KeyLeft",
    ArrowRight: "KeyRight",
    Insert: "KeyInsert",
    Home: "KeyHome",
    End: "KeyEnd",
    PageUp: "KeyPageUp",
    PageDown: "KeyPageDown",
    NumLock: "KeyNumLock",
  };
  const MODIFIER_KEYS = {
    ShiftLeft: "KeyShiftL",
    ShiftRight: "KeyShiftR",
    ControlLeft: "KeyCtrlL",
    ControlRight: "KeyCtrlR",
    AltLeft: "KeyAltL",
    AltRight: "KeyAltR",
  };

  function onKey(e, state) {
    if (e.target instanceof Element && e.target.closest("dialog, input, textarea, select")) return;
    if (e.isComposing) return;
    readMods(e);
    if (e.metaKey) return; // leave browser shortcuts alone (Cmd+R, ...)
    let name = SPECIAL_KEYS[e.key] || MODIFIER_KEYS[e.code];
    if (!name && /^F([1-9]|1[0-9]|2[0-5])$/.test(e.key)) name = "Key" + e.key;
    if (name) {
      pushKey(1, 0, name, state);
    } else if ([...e.key].length === 1) {
      let code = e.key.codePointAt(0);
      // Like GLUT: Ctrl+letter gives a control character.
      if (e.ctrlKey && /^[a-zA-Z]$/.test(e.key)) code = code & 31;
      pushKey(0, code, "", state);
    } else {
      return;
    }
    e.preventDefault();
  }
  window.addEventListener("keydown", (e) => onKey(e, 0));
  window.addEventListener("keyup", (e) => onKey(e, 1));

  // ---------------------------------------------------------------------------
  // Console panel (program output) and notifications

  const consoleEl = $("console-output");
  let unread = 0;

  BoS.log = function (text, cls) {
    const atBottom = consoleEl.scrollHeight - consoleEl.scrollTop - consoleEl.clientHeight < 30;
    const span = document.createElement("span");
    if (cls) span.className = cls;
    span.textContent = text;
    consoleEl.appendChild(span);
    // Keep the panel from growing without bound.
    while (consoleEl.childNodes.length > 5000) consoleEl.removeChild(consoleEl.firstChild);
    if (atBottom) consoleEl.scrollTop = consoleEl.scrollHeight;
    if ($("console").hidden) {
      unread++;
      $("console-badge").textContent = unread > 99 ? "99+" : String(unread);
      $("console-badge").hidden = false;
    }
  };

  function logLink(label, onclick) {
    const a = document.createElement("a");
    a.href = "#";
    a.textContent = label;
    a.addEventListener("click", (e) => {
      e.preventDefault();
      onclick();
    });
    consoleEl.appendChild(a);
    consoleEl.appendChild(document.createTextNode("\n"));
    consoleEl.scrollTop = consoleEl.scrollHeight;
  }

  function toast(msg) {
    const t = $("toast");
    t.textContent = msg;
    t.hidden = false;
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => (t.hidden = true), 4000);
  }

  // Route the Haskell program's stdout/stderr into the console panel.
  BoS.hookStdout = function () {
    /* global h$base_fds, h$decodeUtf8 */
    if (typeof h$base_fds === "undefined" || typeof h$decodeUtf8 === "undefined") return;
    const writer = (cls) => (fd, fdo, buf, off, n, c) => {
      const s = h$decodeUtf8(buf, n, off);
      BoS.log(s, cls);
      console.log(s.replace(/\n$/, ""));
      c(n);
    };
    if (h$base_fds[1]) h$base_fds[1].write = writer("");
    if (h$base_fds[2]) h$base_fds[2].write = writer("error");
  };

  BoS.reportError = function (msg) {
    console.error(msg);
    BoS.log("Error: " + msg + "\n", "error");
    toast("Something went wrong; the last action was undone. See the console for details.");
  };

  BoS.exited = function () {
    $("exited").hidden = false;
  };

  BoS.prompt = function (msg) {
    const r = window.prompt(msg);
    canvas.focus();
    return r;
  };

  function download(path) {
    const content = BoS.fs.read(path);
    if (content === null) return;
    const blob = new Blob([content], { type: "text/plain;charset=utf-8" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = path.split("/").pop();
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 10000);
  }

  function fileWritten(path) {
    BoS.log("[saved " + path + " in this browser] ", "note");
    logLink("download", () => download(path));
    updateChanged();
  }

  // ---------------------------------------------------------------------------
  // Toolbar

  function updateChanged() {
    const n = BoS.fs.changedPaths().length;
    $("btn-download").disabled = n === 0;
    $("btn-reset").disabled = n === 0;
    $("btn-download").title = n
      ? "Download the " + n + " file(s) changed or added in this browser"
      : "No changed files yet";
  }

  function toggle(id, show) {
    const el = $(id);
    el.hidden = show === undefined ? !el.hidden : !show;
    return !el.hidden;
  }

  $("btn-console").addEventListener("click", () => {
    if (toggle("console")) {
      unread = 0;
      $("console-badge").hidden = true;
      consoleEl.scrollTop = consoleEl.scrollHeight;
    }
    layout();
    canvas.focus();
  });
  $("btn-console-clear").addEventListener("click", () => {
    consoleEl.textContent = "";
    canvas.focus();
  });

  $("btn-help").addEventListener("click", () => $("help").showModal());
  $("help").addEventListener("close", () => canvas.focus());

  $("btn-upload").addEventListener("click", () => $("file-input").click());
  $("file-input").addEventListener("change", async (e) => {
    const added = [];
    for (const f of e.target.files) {
      const name = f.name.replace(/[^\w.\-]+/g, "_").replace(/\.txt$/i, "") + ".txt";
      const path = "input/uploads/" + name;
      overlay[path] = await f.text();
      added.push("uploads/" + name.replace(/\.txt$/, ""));
    }
    e.target.value = "";
    persist();
    updateChanged();
    if (added.length) {
      toast("Added " + added.join(", ") + ". Open the file list (Load in the right bar) to use it.");
      BoS.log("Added " + added.join(", ") + "\n", "note");
    }
    canvas.focus();
  });

  $("btn-download").addEventListener("click", () => {
    const paths = BoS.fs.changedPaths();
    paths.forEach((p, i) => setTimeout(() => download(p), i * 300));
    canvas.focus();
  });

  $("btn-reset").addEventListener("click", () => {
    const paths = BoS.fs.changedPaths();
    if (!paths.length) return;
    const ok = window.confirm(
      "Discard these changes saved in this browser and reload?\n\n" + paths.join("\n")
    );
    if (ok) {
      BoS.fs.reset();
      location.reload();
    }
  });

  updateChanged();

  window.addEventListener("error", (e) => {
    BoS.log("Error: " + (e.message || e) + "\n", "error");
  });
})();
