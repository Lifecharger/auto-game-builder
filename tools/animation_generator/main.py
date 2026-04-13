"""
2D Animation Generator — UI for Grok Imagine asset pipeline.

Wraps the grok_*.py tools with a CustomTkinter interface so you can:
  - Create/select characters
  - Generate base images (text→image via Grok)
  - Derive directional variants (i2i)
  - Pad images for animation room
  - Animate images (i2v)
  - Download favorites from Grok

Everything is organized per character in projects/<name>/
"""
import os
import sys
import threading
from pathlib import Path
from tkinter import filedialog, messagebox

import customtkinter as ctk

# Wire this app into Auto Game Builder's categorized tools layout.
# PROJECT_ROOT is this folder: tools/animation_generator/
# TOOLS_ROOT is its parent: tools/
# The sibling subfolders (grok/, media/, tripo/) hold the library scripts.
PROJECT_ROOT = Path(__file__).parent.resolve()
TOOLS_ROOT = PROJECT_ROOT.parent

# Per-user generated content goes under ~/Documents/AnimationGenerator unless
# the user points PROJECTS_DIR somewhere else via env. Never commit projects/
# alongside the source.
PROJECTS_DIR = Path(
    os.environ.get("ANIMATION_GENERATOR_PROJECTS_DIR", "")
    or (Path.home() / "Documents" / "AnimationGenerator")
).resolve()
PROJECTS_DIR.mkdir(parents=True, exist_ok=True)

# Add vendor subfolders to sys.path so the flat `import grok_generate_image`
# style still works.
for _sub in ("grok", "media", "tripo"):
    _path = TOOLS_ROOT / _sub
    if _path.is_dir():
        sys.path.insert(0, str(_path))

# Import tools as library modules
import grok_generate_image as _gi
import grok_i2i as _i2i
import grok_animate as _anim
import grok_downloader as _dl
import pad_image as _pad

ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")

# Canonical subfolders per character
SUBFOLDERS = [
    "01_south_base",
    "02_east",
    "03_west",
    "04_north",
    "05_padded_for_anim",
    "06_animations",
]


class App(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("2D Animation Generator")
        self.geometry("1400x900")
        self.minsize(1200, 800)

        self.current_character: str | None = None
        self.current_image_path: str | None = None

        self._build_ui()
        self._refresh_character_list()

    # ── UI layout ────────────────────────────────────────────

    def _build_ui(self):
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)

        # ── Left: character sidebar ──
        self.sidebar = ctk.CTkFrame(self, width=220, corner_radius=0)
        self.sidebar.grid(row=0, column=0, rowspan=2, sticky="nsew")
        self.sidebar.grid_rowconfigure(3, weight=1)

        ctk.CTkLabel(self.sidebar, text="CHARACTERS", font=ctk.CTkFont(size=14, weight="bold")).grid(
            row=0, column=0, padx=20, pady=(20, 5), sticky="w"
        )
        ctk.CTkButton(self.sidebar, text="+ New Character", command=self._new_character,
                      fg_color="#2a8c4a", hover_color="#1d6b36").grid(row=1, column=0, padx=20, pady=5, sticky="ew")
        ctk.CTkLabel(self.sidebar, text="(click a character to select)",
                     text_color="gray60", font=ctk.CTkFont(size=10)).grid(row=2, column=0, padx=20, pady=(0, 5))
        self.char_list_frame = ctk.CTkScrollableFrame(self.sidebar, corner_radius=0, fg_color="transparent")
        self.char_list_frame.grid(row=3, column=0, padx=10, pady=5, sticky="nsew")

        # ── Center: folder tree + image preview ──
        self.center = ctk.CTkFrame(self, fg_color="transparent")
        self.center.grid(row=0, column=1, padx=10, pady=(10, 0), sticky="nsew")
        self.center.grid_columnconfigure(0, weight=0, minsize=260)
        self.center.grid_columnconfigure(1, weight=1)
        self.center.grid_rowconfigure(0, weight=1)

        # Folder file list
        self.file_list_frame = ctk.CTkScrollableFrame(self.center, label_text="Files", width=240)
        self.file_list_frame.grid(row=0, column=0, sticky="nsew", padx=(0, 8))

        # Image preview area
        self.preview_frame = ctk.CTkFrame(self.center)
        self.preview_frame.grid(row=0, column=1, sticky="nsew")
        self.preview_frame.grid_columnconfigure(0, weight=1)
        self.preview_frame.grid_rowconfigure(0, weight=1)
        self.preview_label = ctk.CTkLabel(self.preview_frame, text="(no image selected)",
                                           text_color="gray50")
        self.preview_label.grid(row=0, column=0, sticky="nsew", padx=10, pady=10)

        # ── Right: action buttons ──
        self.actions = ctk.CTkFrame(self, width=280, corner_radius=0)
        self.actions.grid(row=0, column=2, rowspan=2, sticky="nsew")
        ctk.CTkLabel(self.actions, text="ACTIONS", font=ctk.CTkFont(size=14, weight="bold")).grid(
            row=0, column=0, padx=20, pady=(20, 10), sticky="w"
        )

        buttons = [
            ("🎨 Generate Base", self._act_generate_base),
            ("🔄 i2i Directional", self._act_i2i),
            ("🖼️ Pad Image", self._act_pad),
            ("🎬 Animate", self._act_animate),
            ("⬇️ Download Favorites", self._act_download),
        ]
        for i, (label, cmd) in enumerate(buttons, start=1):
            ctk.CTkButton(self.actions, text=label, command=cmd, height=40,
                          font=ctk.CTkFont(size=13)).grid(row=i, column=0, padx=20, pady=6, sticky="ew")

        # ── Bottom: status log ──
        self.status = ctk.CTkTextbox(self, height=140, corner_radius=0,
                                      font=ctk.CTkFont(family="Consolas", size=11))
        self.status.grid(row=1, column=1, padx=10, pady=10, sticky="nsew")
        self.log("Ready. Select or create a character to begin.")

    # ── Logging ──────────────────────────────────────────────

    def log(self, text: str):
        self.status.insert("end", text + "\n")
        self.status.see("end")

    # ── Character management ────────────────────────────────

    def _refresh_character_list(self):
        for w in self.char_list_frame.winfo_children():
            w.destroy()
        chars = sorted([p.name for p in PROJECTS_DIR.iterdir() if p.is_dir()])
        if not chars:
            ctk.CTkLabel(self.char_list_frame, text="(no characters yet)",
                         text_color="gray50").pack(pady=10)
            return
        for c in chars:
            b = ctk.CTkButton(
                self.char_list_frame, text=c, anchor="w",
                fg_color="#2b2b2b" if c != self.current_character else "#1f6aa5",
                hover_color="#3a3a3a",
                command=lambda n=c: self._select_character(n),
            )
            b.pack(fill="x", pady=2)

    def _new_character(self):
        dlg = ctk.CTkInputDialog(text="Character name:", title="New Character")
        name = dlg.get_input()
        if not name:
            return
        name = name.strip().replace("/", "_")
        char_dir = PROJECTS_DIR / name
        if char_dir.exists():
            messagebox.showwarning("Exists", f"Character '{name}' already exists.")
            return
        char_dir.mkdir()
        for sub in SUBFOLDERS:
            (char_dir / sub).mkdir()
        self.log(f"Created character '{name}' with {len(SUBFOLDERS)} subfolders")
        self._refresh_character_list()
        self._select_character(name)

    def _select_character(self, name: str):
        self.current_character = name
        self.log(f"Selected character: {name}")
        self._refresh_character_list()
        self._refresh_file_list()
        self.title(f"2D Animation Generator — {name}")

    def _current_char_dir(self) -> Path | None:
        if not self.current_character:
            return None
        return PROJECTS_DIR / self.current_character

    # ── File browser ─────────────────────────────────────────

    def _refresh_file_list(self):
        for w in self.file_list_frame.winfo_children():
            w.destroy()
        char_dir = self._current_char_dir()
        if not char_dir:
            return
        for sub in SUBFOLDERS:
            sub_dir = char_dir / sub
            if not sub_dir.exists():
                continue
            files = sorted([f for f in sub_dir.iterdir() if f.is_file()])
            if not files:
                continue
            ctk.CTkLabel(self.file_list_frame, text=sub, font=ctk.CTkFont(size=11, weight="bold"),
                         text_color="gray70").pack(anchor="w", pady=(8, 2), padx=4)
            for f in files:
                b = ctk.CTkButton(
                    self.file_list_frame, text="  " + f.name, anchor="w", height=26,
                    fg_color="#333333", hover_color="#444444",
                    font=ctk.CTkFont(size=10),
                    command=lambda p=f: self._preview_file(p),
                )
                b.pack(fill="x", pady=1, padx=2)

    def _preview_file(self, path: Path):
        self.current_image_path = str(path)
        self.log(f"Preview: {path.name}")
        ext = path.suffix.lower()
        if ext in (".png", ".jpg", ".jpeg", ".webp"):
            try:
                from PIL import Image
                img = Image.open(path)
                # Fit to preview frame
                self.update_idletasks()
                fw = max(self.preview_frame.winfo_width() - 40, 400)
                fh = max(self.preview_frame.winfo_height() - 40, 400)
                img.thumbnail((fw, fh))
                ctk_img = ctk.CTkImage(light_image=img, dark_image=img, size=img.size)
                self.preview_label.configure(image=ctk_img, text="")
                self.preview_label.image = ctk_img
            except Exception as e:
                self.preview_label.configure(image=None, text=f"Preview error: {e}")
        else:
            self.preview_label.configure(image=None, text=f"{path.name}\n(not an image — open externally)")

    # ── Helpers ─────────────────────────────────────────────

    def _run_bg(self, fn, *args, **kwargs):
        """Run a task on a background thread so the UI doesn't freeze."""
        def worker():
            try:
                fn(*args, **kwargs)
            except Exception as e:
                self.after(0, lambda: self.log(f"ERROR: {e}"))
        threading.Thread(target=worker, daemon=True).start()

    def _require_character(self) -> Path | None:
        if not self.current_character:
            messagebox.showwarning("No character", "Select or create a character first.")
            return None
        return self._current_char_dir()

    # ── Action: generate base ───────────────────────────────

    def _act_generate_base(self):
        char_dir = self._require_character()
        if not char_dir:
            return
        dlg = PromptDialog(self, title="Generate Base Image",
                            prompt_label="Prompt (what to generate):",
                            extra_fields=[
                                ("Aspect ratio", ctk.StringVar(value="1:1"),
                                 ["1:1", "16:9", "9:16", "3:2", "2:3", "4:3", "3:4"]),
                                ("Pro mode (quality)", ctk.BooleanVar(value=True), None),
                            ])
        self.wait_window(dlg)
        if dlg.result is None:
            return
        prompt = dlg.result["prompt"]
        aspect = dlg.result["Aspect ratio"]
        pro = dlg.result["Pro mode (quality)"]
        output_dir = char_dir / "01_south_base"

        self.log(f"Generating base: aspect={aspect}, pro={pro}")
        self._run_bg(self._do_generate, prompt, aspect, pro, output_dir)

    def _do_generate(self, prompt: str, aspect: str, pro: bool, output_dir: Path):
        # grok_generate_image saves to ~/Downloads/grok-generated/, so we pick the
        # 4 new files afterward and move them into the project folder
        before = set((Path.home() / "Downloads" / "grok-generated").glob("*")) \
                   if (Path.home() / "Downloads" / "grok-generated").exists() else set()
        _gi.generate_images(prompt, aspect, 2, "base.png", pro=pro, model=None)
        after = set((Path.home() / "Downloads" / "grok-generated").glob("*"))
        new = sorted(after - before)
        import shutil
        for i, f in enumerate(new, start=1):
            dest = output_dir / f"{self.current_character}_base_{i}{f.suffix}"
            shutil.copy2(f, dest)
            self.after(0, lambda p=dest: self.log(f"  Saved: {p.name}"))
        self.after(0, self._refresh_file_list)
        self.after(0, lambda: self.log(f"Generated {len(new)} base images"))

    # ── Action: i2i ──────────────────────────────────────────

    def _act_i2i(self):
        if not self.current_image_path:
            messagebox.showwarning("No image", "Select an image from the file list first (click it).")
            return
        char_dir = self._require_character()
        if not char_dir:
            return
        dlg = PromptDialog(self, title="i2i Directional Variant",
                            prompt_label="Describe the variation:",
                            extra_fields=[
                                ("Target subfolder", ctk.StringVar(value="02_east"),
                                 ["01_south_base", "02_east", "03_west", "04_north"]),
                            ])
        self.wait_window(dlg)
        if dlg.result is None:
            return
        self.log(f"i2i: {dlg.result['prompt'][:60]}...")
        self._run_bg(self._do_i2i, self.current_image_path, dlg.result["prompt"],
                       char_dir / dlg.result["Target subfolder"])

    def _do_i2i(self, image: str, prompt: str, output_dir: Path):
        ok = _i2i.i2i(image, prompt, headless=True)
        if not ok:
            self.after(0, lambda: self.log("i2i FAILED"))
            return
        self.after(0, lambda: self.log("i2i submitted. Run 'Download Favorites' in ~60s to fetch."))

    # ── Action: pad image ────────────────────────────────────

    def _act_pad(self):
        if not self.current_image_path:
            messagebox.showwarning("No image", "Select an image to pad first.")
            return
        char_dir = self._require_character()
        if not char_dir:
            return
        dlg = PadDialog(self)
        self.wait_window(dlg)
        if dlg.result is None:
            return
        src = self.current_image_path
        dest_dir = char_dir / "05_padded_for_anim"
        dest_name = Path(src).stem + "_padded.png"
        dest = dest_dir / dest_name
        self.log(f"Padding {Path(src).name} --all {dlg.result['amount']}")
        self._run_bg(self._do_pad, src, str(dest), dlg.result["amount"])

    def _do_pad(self, src: str, dest: str, amount: float):
        _pad.pad_image(src, dest, amount, amount, None, None)
        self.after(0, self._refresh_file_list)
        self.after(0, lambda: self.log(f"Padded: {Path(dest).name}"))

    # ── Action: animate ─────────────────────────────────────

    def _act_animate(self):
        if not self.current_image_path:
            messagebox.showwarning("No image", "Select an image to animate first.")
            return
        char_dir = self._require_character()
        if not char_dir:
            return
        dlg = PromptDialog(self, title="Animate Image",
                            prompt_label="Animation prompt:",
                            extra_fields=[
                                ("Length (sec)", ctk.StringVar(value="6"), ["6", "10"]),
                                ("Resolution", ctk.StringVar(value="480p"), ["480p", "720p"]),
                            ])
        self.wait_window(dlg)
        if dlg.result is None:
            return
        prompt = dlg.result["prompt"]
        length = int(dlg.result["Length (sec)"])
        resolution = dlg.result["Resolution"]
        # Append static camera boilerplate
        prompt += " locked side profile view, completely static camera, no camera movement no pan no zoom no follow, character stays centered in frame"
        self.log(f"Animate: {length}s @ {resolution}")
        self._run_bg(self._do_animate, self.current_image_path, prompt, length, resolution)

    def _do_animate(self, image: str, prompt: str, length: int, resolution: str):
        ok = _anim.animate(image, prompt, video_length=length, resolution=resolution, headless=True)
        if ok:
            self.after(0, lambda: self.log("Animation submitted. Run 'Download Favorites' in ~2 min."))
        else:
            self.after(0, lambda: self.log("Animation FAILED"))

    # ── Action: download favorites ──────────────────────────

    def _act_download(self):
        self.log("Fetching latest favorites from Grok...")
        self._run_bg(self._do_download)

    def _do_download(self):
        result = _dl.GrokDownloader().run(since_hours=1)
        if result.get("ok"):
            self.after(0, lambda: self.log(
                f"Downloaded {result.get('new_downloads', 0)} new items to {result.get('folder', '?')}"))
        else:
            self.after(0, lambda: self.log(f"Download error: {result.get('error', '?')}"))


# ── Dialogs ───────────────────────────────────────────────────

class PromptDialog(ctk.CTkToplevel):
    """Generic prompt dialog with a multiline prompt field + optional dropdowns."""
    def __init__(self, parent, title: str, prompt_label: str, extra_fields: list | None = None):
        super().__init__(parent)
        self.title(title)
        self.geometry("640x480")
        self.result = None

        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=1)

        ctk.CTkLabel(self, text=prompt_label, anchor="w").grid(row=0, column=0, padx=20, pady=(20, 5), sticky="ew")
        self.prompt_box = ctk.CTkTextbox(self, height=200, font=ctk.CTkFont(family="Segoe UI", size=12))
        self.prompt_box.grid(row=1, column=0, padx=20, pady=5, sticky="nsew")

        # Extra fields
        self.extras = {}
        extras_frame = ctk.CTkFrame(self, fg_color="transparent")
        extras_frame.grid(row=2, column=0, padx=20, pady=10, sticky="ew")
        extras_frame.grid_columnconfigure(1, weight=1)
        if extra_fields:
            for i, (label, var, options) in enumerate(extra_fields):
                ctk.CTkLabel(extras_frame, text=label).grid(row=i, column=0, padx=5, pady=4, sticky="w")
                if options:
                    om = ctk.CTkOptionMenu(extras_frame, variable=var, values=options)
                    om.grid(row=i, column=1, padx=5, pady=4, sticky="ew")
                elif isinstance(var, ctk.BooleanVar):
                    cb = ctk.CTkCheckBox(extras_frame, text="", variable=var)
                    cb.grid(row=i, column=1, padx=5, pady=4, sticky="w")
                else:
                    entry = ctk.CTkEntry(extras_frame, textvariable=var)
                    entry.grid(row=i, column=1, padx=5, pady=4, sticky="ew")
                self.extras[label] = var

        # Buttons
        btn_frame = ctk.CTkFrame(self, fg_color="transparent")
        btn_frame.grid(row=3, column=0, padx=20, pady=(5, 20), sticky="e")
        ctk.CTkButton(btn_frame, text="Cancel", command=self._cancel, width=100,
                       fg_color="#555555", hover_color="#666666").pack(side="left", padx=5)
        ctk.CTkButton(btn_frame, text="Submit", command=self._submit, width=100).pack(side="left", padx=5)

    def _cancel(self):
        self.result = None
        self.destroy()

    def _submit(self):
        prompt = self.prompt_box.get("1.0", "end").strip()
        if not prompt:
            messagebox.showwarning("Empty", "Prompt cannot be empty.")
            return
        self.result = {"prompt": prompt}
        for k, v in self.extras.items():
            self.result[k] = v.get()
        self.destroy()


class PadDialog(ctk.CTkToplevel):
    def __init__(self, parent):
        super().__init__(parent)
        self.title("Pad Image")
        self.geometry("360x200")
        self.result = None

        ctk.CTkLabel(self, text="Padding amount (fraction of original size):").pack(padx=20, pady=(20, 5))
        self.amount_var = ctk.StringVar(value="0.5")
        options = ["0.25", "0.5", "0.75", "1.0", "1.5"]
        ctk.CTkOptionMenu(self, variable=self.amount_var, values=options).pack(padx=20, pady=5)
        ctk.CTkLabel(self, text="(applied on all 4 sides; background auto-sampled)",
                      text_color="gray60", font=ctk.CTkFont(size=10)).pack(padx=20, pady=5)

        btn_frame = ctk.CTkFrame(self, fg_color="transparent")
        btn_frame.pack(side="bottom", padx=20, pady=20)
        ctk.CTkButton(btn_frame, text="Cancel", command=self._cancel, width=100,
                       fg_color="#555555").pack(side="left", padx=5)
        ctk.CTkButton(btn_frame, text="Pad", command=self._submit, width=100).pack(side="left", padx=5)

    def _cancel(self):
        self.result = None
        self.destroy()

    def _submit(self):
        self.result = {"amount": float(self.amount_var.get())}
        self.destroy()


if __name__ == "__main__":
    app = App()
    app.mainloop()
