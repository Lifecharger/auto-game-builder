"""Settings dialog for font, uppercase, and other options."""

from tkinter import filedialog
import customtkinter as ctk


class SettingsDialog(ctk.CTkToplevel):
    def __init__(self, parent, cfg: dict, on_save):
        super().__init__(parent)
        self.cfg = cfg
        self.on_save = on_save

        self.title("Settings")
        self.geometry("450x280")
        self.transient(parent)
        self.grab_set()

        pad = {"padx": 16, "pady": 8}

        # Font path
        ctk.CTkLabel(self, text="Comic Font (.ttf):", anchor="w").pack(fill="x", **pad)
        font_frame = ctk.CTkFrame(self)
        font_frame.pack(fill="x", padx=16)

        self.font_entry = ctk.CTkEntry(font_frame)
        self.font_entry.insert(0, cfg.get('font_path', ''))
        self.font_entry.pack(side="left", fill="x", expand=True, padx=(0, 8))

        ctk.CTkButton(font_frame, text="Browse", width=70,
                      command=self._browse_font).pack(side="right")

        # Uppercase toggle
        self.upper_var = ctk.BooleanVar(value=cfg.get('uppercase', True))
        ctk.CTkCheckBox(self, text="UPPERCASE text (comic convention)",
                         variable=self.upper_var).pack(fill="x", **pad)

        # Save
        ctk.CTkButton(self, text="Save Settings",
                      command=self._apply).pack(pady=16)

    def _browse_font(self):
        f = filedialog.askopenfilename(
            title="Select Font",
            filetypes=[("TrueType Font", "*.ttf *.otf"), ("All", "*.*")]
        )
        if f:
            self.font_entry.delete(0, "end")
            self.font_entry.insert(0, f)

    def _apply(self):
        self.cfg['font_path'] = self.font_entry.get().strip()
        self.cfg['uppercase'] = self.upper_var.get()
        self.on_save(self.cfg)
        self.destroy()
