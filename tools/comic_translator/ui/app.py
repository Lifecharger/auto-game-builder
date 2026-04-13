"""Main application window — wires together toolbar, preview, table, and pipeline."""

import os
import json
import threading
from pathlib import Path
from tkinter import filedialog, messagebox

import customtkinter as ctk
import cv2

from pipeline import analyze_and_translate
from detector import clean_all_bubbles
from renderer import render_all
from extractor import is_comic_archive, extract_comic

from ui.toolbar import Toolbar
from ui.preview import PreviewPanel
from ui.table import TranslationTable
from ui.settings import SettingsDialog

# ─── Config ──────────────────────────────────────────────────────────────────

CONFIG_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "config.json")
DEFAULT_CONFIG = {
    "font_path": "",
    "uppercase": True,
    "last_directory": "",
    "window_width": 1400,
    "window_height": 900,
}


def load_config() -> dict:
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
            return {**DEFAULT_CONFIG, **json.load(f)}
    return DEFAULT_CONFIG.copy()


def save_config(cfg: dict):
    with open(CONFIG_PATH, 'w', encoding='utf-8') as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)


# ─── App ─────────────────────────────────────────────────────────────────────

IMAGE_EXTS = {'.png', '.jpg', '.jpeg', '.webp', '.bmp', '.tiff'}


class ComicTranslatorApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.cfg = load_config()

        self.title("Comic Translator \u2014 EN \u2192 TR")
        self.geometry(f"{self.cfg['window_width']}x{self.cfg['window_height']}")
        ctk.set_appearance_mode("dark")
        ctk.set_default_color_theme("blue")

        # State
        self.image_paths: list[str] = []
        self.current_index = 0
        self.results: dict[str, dict] = {}
        self.processing = False
        self._extracted_dir: str | None = None  # temp dir for CBR extraction

        self._build_ui()

    def _build_ui(self):
        callbacks = {
            'open_file': self._open_file,
            'open_cbr': self._open_cbr,
            'open_folder': self._open_folder,
            'translate': self._translate,
            'translate_all': self._translate_all,
            'save': self._save,
            'save_all': self._save_all,
            'settings': self._open_settings,
            'prev_page': self._prev_page,
            'next_page': self._next_page,
        }

        self.toolbar = Toolbar(self, callbacks)
        self.toolbar.pack(fill="x", padx=8, pady=(8, 0))

        content = ctk.CTkFrame(self)
        content.pack(fill="both", expand=True, padx=8, pady=8)

        self.preview = PreviewPanel(content)
        self.preview.pack(fill="both", expand=True)

        self.table = TranslationTable(content, on_rerender=self._rerender)
        self.table.pack(fill="x", pady=(4, 0))

        # Status bar
        status_bar = ctk.CTkFrame(self, height=30)
        status_bar.pack(fill="x", padx=8, pady=(0, 8))
        status_bar.pack_propagate(False)

        self.status_label = ctk.CTkLabel(status_bar, text="Ready", anchor="w",
                                          font=("Arial", 11))
        self.status_label.pack(side="left", padx=8, fill="x", expand=True)

        self.progress = ctk.CTkProgressBar(status_bar, width=200)
        self.progress.pack(side="right", padx=8, pady=6)
        self.progress.set(0)

    # ── File Operations ──────────────────────────────────────────────────

    def _open_file(self):
        paths = filedialog.askopenfilenames(
            title="Select Comic Pages",
            initialdir=self.cfg.get('last_directory') or None,
            filetypes=[
                ("Images", "*.png *.jpg *.jpeg *.webp *.bmp *.tiff"),
                ("All files", "*.*"),
            ]
        )
        if paths:
            self._load_images(sorted(paths))
            self.cfg['last_directory'] = os.path.dirname(paths[0])
            save_config(self.cfg)

    def _open_cbr(self):
        path = filedialog.askopenfilename(
            title="Select Comic Archive",
            initialdir=self.cfg.get('last_directory') or None,
            filetypes=[
                ("Comic Archives", "*.cbr *.cbz *.cb7"),
                ("All files", "*.*"),
            ]
        )
        if path:
            try:
                self._set_status(f"Extracting {os.path.basename(path)}...")
                images = extract_comic(path)
                if not images:
                    self._set_status("No images found in archive")
                    return
                self._extracted_dir = str(
                    Path(path).parent / f".{Path(path).stem}_pages")
                self._load_images(images)
                self.cfg['last_directory'] = os.path.dirname(path)
                save_config(self.cfg)
                self._set_status(
                    f"Extracted {len(images)} pages from {os.path.basename(path)}")
            except Exception as e:
                self._set_status(f"Extraction error: {e}")
                messagebox.showerror("Error", str(e))

    def _open_folder(self):
        folder = filedialog.askdirectory(
            title="Select Folder with Comic Pages",
            initialdir=self.cfg.get('last_directory') or None)
        if folder:
            images = sorted(
                str(p) for p in Path(folder).iterdir()
                if p.suffix.lower() in IMAGE_EXTS
            )
            if images:
                self._load_images(images)
                self.cfg['last_directory'] = folder
                save_config(self.cfg)
            else:
                self._set_status("No image files found in folder")

    def _load_images(self, paths: list[str]):
        self.image_paths = paths
        self.current_index = 0
        self.results.clear()
        self._show_current()

    def _prev_page(self):
        if self.image_paths and self.current_index > 0:
            self.current_index -= 1
            self._show_current()

    def _next_page(self):
        if self.image_paths and self.current_index < len(self.image_paths) - 1:
            self.current_index += 1
            self._show_current()

    def _show_current(self):
        if not self.image_paths:
            return

        self.toolbar.set_page(
            f"{self.current_index + 1} / {len(self.image_paths)}")
        path = self.image_paths[self.current_index]

        self.preview.show_original(path)

        result = self.results.get(path)
        if result and result.get('translated_img') is not None:
            self.preview.show_translated(result['translated_img'])
            self.table.populate(result.get('bubbles', []))
        else:
            self.preview.clear_translated()
            self.table.clear()

    # ── Translation ──────────────────────────────────────────────────────

    def _translate(self):
        if not self.image_paths or self.processing:
            return
        self._run_translation([self.current_index])

    def _translate_all(self):
        if not self.image_paths or self.processing:
            return
        self._run_translation(list(range(len(self.image_paths))))

    def _run_translation(self, indices: list[int]):
        self.processing = True
        self.toolbar.set_processing(True)
        self.progress.set(0)

        def worker():
            total = len(indices)
            for step, idx in enumerate(indices):
                path = self.image_paths[idx]
                name = os.path.basename(path)

                try:
                    self._set_status(f"[{step + 1}/{total}] Analyzing {name}...")
                    bubbles = analyze_and_translate(
                        path,
                        on_status=lambda msg, n=name: self._set_status(
                            f"{n}: {msg}")
                    )

                    if not bubbles:
                        self._set_status(f"{name}: No text found")
                        img = cv2.imread(path)
                        self.results[path] = {
                            'bubbles': [],
                            'cleaned_img': img,
                            'translated_img': img,
                        }
                    else:
                        self._set_status(
                            f"{name}: Cleaning {len(bubbles)} bubbles...")
                        cleaned = clean_all_bubbles(path, bubbles)

                        self._set_status(f"{name}: Rendering Turkish text...")
                        translated = render_all(
                            cleaned, bubbles,
                            font_path=self.cfg.get('font_path') or None,
                            uppercase=self.cfg.get('uppercase', True),
                        )

                        self.results[path] = {
                            'bubbles': bubbles,
                            'cleaned_img': cleaned,
                            'translated_img': translated,
                        }

                except Exception as e:
                    self._set_status(f"Error on {name}: {e}")

                self.after(0, lambda v=(step + 1) / total: self.progress.set(v))

            self.after(0, self._translation_done)

        threading.Thread(target=worker, daemon=True).start()

    def _translation_done(self):
        self.processing = False
        self.toolbar.set_processing(False)
        self._set_status("Translation complete!")
        self._show_current()

    def _rerender(self):
        if not self.image_paths:
            return

        path = self.image_paths[self.current_index]
        result = self.results.get(path)
        if not result or result.get('cleaned_img') is None:
            messagebox.showinfo("Info", "Translate the page first.")
            return

        # Read edited translations from table
        edited = self.table.get_edited_translations()
        bubbles = result['bubbles']
        for i, text in enumerate(edited):
            if i < len(bubbles):
                bubbles[i]['translated'] = text

        self._set_status("Re-rendering with edits...")
        translated = render_all(
            result['cleaned_img'], bubbles,
            font_path=self.cfg.get('font_path') or None,
            uppercase=self.cfg.get('uppercase', True),
        )
        result['translated_img'] = translated
        self.preview.show_translated(translated)
        self._set_status("Re-render complete!")

    # ── Save ─────────────────────────────────────────────────────────────

    def _save(self):
        if not self.image_paths:
            return
        path = self.image_paths[self.current_index]
        result = self.results.get(path)
        if not result or result.get('translated_img') is None:
            messagebox.showinfo("Info", "No translated image to save.")
            return

        out = self._output_path(path)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        cv2.imwrite(out, result['translated_img'])
        self._set_status(f"Saved: {out}")

    def _save_all(self):
        saved = 0
        for path, result in self.results.items():
            if result.get('translated_img') is not None:
                out = self._output_path(path)
                os.makedirs(os.path.dirname(out), exist_ok=True)
                cv2.imwrite(out, result['translated_img'])
                saved += 1
        self._set_status(f"Saved {saved} translated pages")

    def _output_path(self, original: str) -> str:
        p = Path(original)
        out_dir = p.parent / "translated"
        return str(out_dir / p.name)

    # ── Settings ─────────────────────────────────────────────────────────

    def _open_settings(self):
        def on_save(cfg):
            self.cfg = cfg
            save_config(cfg)
            self._set_status("Settings saved")

        SettingsDialog(self, self.cfg, on_save)

    # ── Helpers ──────────────────────────────────────────────────────────

    def _set_status(self, text: str):
        self.after(0, lambda: self.status_label.configure(text=text))
