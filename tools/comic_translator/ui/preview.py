"""Side-by-side zoomable image preview panels for original and translated pages."""

import tkinter as tk
import cv2
import numpy as np
import customtkinter as ctk
from PIL import Image, ImageTk


class ZoomableCanvas(ctk.CTkFrame):
    """A canvas that supports zoom (mouse wheel) and pan (click-drag)."""

    def __init__(self, parent, placeholder: str = ""):
        super().__init__(parent, fg_color="gray15", corner_radius=8)
        self._placeholder = placeholder
        self._pil_image: Image.Image | None = None
        self._photo: ImageTk.PhotoImage | None = None
        self._zoom = 1.0
        self._pan_x = 0.0
        self._pan_y = 0.0
        self._drag_start = None

        # Canvas
        self._canvas = tk.Canvas(self, bg="#1a1a1a", highlightthickness=0)
        self._canvas.pack(fill="both", expand=True, padx=2, pady=2)

        # Placeholder text
        self._placeholder_id = self._canvas.create_text(
            0, 0, text=placeholder, fill="gray50",
            font=("Arial", 13), anchor="center")

        # Zoom controls bar
        ctrl = ctk.CTkFrame(self, height=28, fg_color="gray20")
        ctrl.pack(fill="x", side="bottom")
        ctrl.pack_propagate(False)

        ctk.CTkButton(ctrl, text="-", width=28, height=22,
                      font=("Arial", 14, "bold"), fg_color="gray30",
                      command=self._zoom_out).pack(side="left", padx=2, pady=2)
        self._zoom_label = ctk.CTkLabel(ctrl, text="100%", width=50,
                                         font=("Arial", 10))
        self._zoom_label.pack(side="left", padx=2)
        ctk.CTkButton(ctrl, text="+", width=28, height=22,
                      font=("Arial", 14, "bold"), fg_color="gray30",
                      command=self._zoom_in).pack(side="left", padx=2, pady=2)
        ctk.CTkButton(ctrl, text="Fit", width=32, height=22,
                      font=("Arial", 10), fg_color="gray30",
                      command=self._zoom_fit).pack(side="left", padx=4, pady=2)

        # Bindings
        self._canvas.bind("<MouseWheel>", self._on_scroll)          # Windows
        self._canvas.bind("<Button-4>", self._on_scroll_up)         # Linux
        self._canvas.bind("<Button-5>", self._on_scroll_down)       # Linux
        self._canvas.bind("<ButtonPress-1>", self._on_drag_start)
        self._canvas.bind("<B1-Motion>", self._on_drag)
        self._canvas.bind("<Configure>", self._on_resize)

    # ── Public ───────────────────────────────────────────────────────

    def set_image(self, pil_image: Image.Image):
        """Set a new image and fit to view."""
        self._pil_image = pil_image
        self._canvas.delete(self._placeholder_id)
        self._placeholder_id = None
        self._zoom_fit()

    def clear(self):
        """Clear image and show placeholder."""
        self._pil_image = None
        self._photo = None
        self._canvas.delete("all")
        self._zoom = 1.0
        self._pan_x = 0.0
        self._pan_y = 0.0
        self._zoom_label.configure(text="100%")
        self._placeholder_id = self._canvas.create_text(
            self._canvas.winfo_width() // 2,
            self._canvas.winfo_height() // 2,
            text=self._placeholder, fill="gray50",
            font=("Arial", 13), anchor="center")

    # ── Zoom ─────────────────────────────────────────────────────────

    def _zoom_in(self):
        self._set_zoom(self._zoom * 1.25)

    def _zoom_out(self):
        self._set_zoom(self._zoom / 1.25)

    def _zoom_fit(self):
        if self._pil_image is None:
            return
        cw = max(self._canvas.winfo_width(), 100)
        ch = max(self._canvas.winfo_height(), 100)
        iw, ih = self._pil_image.size
        fit = min(cw / iw, ch / ih, 3.0)
        self._pan_x = 0.0
        self._pan_y = 0.0
        self._set_zoom(fit)

    def _set_zoom(self, z: float):
        self._zoom = max(0.1, min(z, 8.0))
        self._zoom_label.configure(text=f"{int(self._zoom * 100)}%")
        self._redraw()

    def _on_scroll(self, event):
        if event.delta > 0:
            self._set_zoom(self._zoom * 1.15)
        else:
            self._set_zoom(self._zoom / 1.15)

    def _on_scroll_up(self, _):
        self._set_zoom(self._zoom * 1.15)

    def _on_scroll_down(self, _):
        self._set_zoom(self._zoom / 1.15)

    # ── Pan ──────────────────────────────────────────────────────────

    def _on_drag_start(self, event):
        self._drag_start = (event.x, event.y)

    def _on_drag(self, event):
        if self._drag_start is None:
            return
        dx = event.x - self._drag_start[0]
        dy = event.y - self._drag_start[1]
        self._drag_start = (event.x, event.y)
        self._pan_x += dx
        self._pan_y += dy
        self._redraw()

    # ── Drawing ──────────────────────────────────────────────────────

    def _on_resize(self, _event):
        if self._pil_image is not None:
            self._redraw()
        elif self._placeholder_id:
            self._canvas.coords(
                self._placeholder_id,
                self._canvas.winfo_width() // 2,
                self._canvas.winfo_height() // 2)

    def _redraw(self):
        if self._pil_image is None:
            return

        iw, ih = self._pil_image.size
        new_w = max(1, int(iw * self._zoom))
        new_h = max(1, int(ih * self._zoom))

        resized = self._pil_image.resize((new_w, new_h), Image.LANCZOS)
        self._photo = ImageTk.PhotoImage(resized)

        cw = self._canvas.winfo_width()
        ch = self._canvas.winfo_height()
        x = cw // 2 + self._pan_x
        y = ch // 2 + self._pan_y

        self._canvas.delete("all")
        self._canvas.create_image(x, y, image=self._photo, anchor="center")


class PreviewPanel(ctk.CTkFrame):
    def __init__(self, parent):
        super().__init__(parent)
        self.columnconfigure(0, weight=1)
        self.columnconfigure(1, weight=1)
        self.rowconfigure(0, weight=0)
        self.rowconfigure(1, weight=1)

        ctk.CTkLabel(self, text="Original", font=("Arial", 14, "bold")).grid(
            row=0, column=0, pady=(4, 0))
        ctk.CTkLabel(self, text="Translated", font=("Arial", 14, "bold")).grid(
            row=0, column=1, pady=(4, 0))

        self._orig = ZoomableCanvas(self, "Open a comic page to begin")
        self._orig.grid(row=1, column=0, sticky="nsew", padx=(4, 2), pady=4)

        self._trans = ZoomableCanvas(self, "Translation will appear here")
        self._trans.grid(row=1, column=1, sticky="nsew", padx=(2, 4), pady=4)

    def show_original(self, path: str):
        try:
            img = Image.open(path).convert("RGB")
            self._orig.set_image(img)
        except Exception as e:
            self._orig.clear()

    def show_translated(self, cv_img: np.ndarray):
        try:
            rgb = cv2.cvtColor(cv_img, cv2.COLOR_BGR2RGB)
            img = Image.fromarray(rgb)
            self._trans.set_image(img)
        except Exception as e:
            self._trans.clear()

    def clear_translated(self):
        self._trans.clear()
