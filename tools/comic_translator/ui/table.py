"""Editable translation table showing detected bubbles with original and translated text."""

import customtkinter as ctk


TYPE_COLORS = {
    "speech": "#3a8a4f",
    "thought": "#4a6a9f",
    "caption": "#8a6a3a",
    "sfx": "#8a3a3a",
}


class TranslationTable(ctk.CTkFrame):
    def __init__(self, parent, on_rerender):
        super().__init__(parent, height=220)
        self.pack_propagate(False)
        self.on_rerender = on_rerender
        self._entries: list[ctk.CTkEntry] = []
        self._build()

    def _build(self):
        # Header
        header = ctk.CTkFrame(self, fg_color="gray25", height=30)
        header.pack(fill="x")
        header.pack_propagate(False)
        ctk.CTkLabel(header, text="#", width=30,
                     font=("Arial", 11, "bold")).pack(side="left", padx=4)
        ctk.CTkLabel(header, text="Type", width=60,
                     font=("Arial", 11, "bold")).pack(side="left", padx=4)
        ctk.CTkLabel(header, text="Original (EN)", width=300,
                     font=("Arial", 11, "bold"), anchor="w").pack(side="left", padx=4)
        ctk.CTkLabel(header, text="Translation (TR) \u2014 click to edit",
                     font=("Arial", 11, "bold"), anchor="w").pack(
            side="left", padx=4, fill="x", expand=True)

        # Scrollable body
        self.body = ctk.CTkScrollableFrame(self, fg_color="gray17")
        self.body.pack(fill="both", expand=True)

        # Bottom bar
        btn_bar = ctk.CTkFrame(self, height=36)
        btn_bar.pack(fill="x")
        btn_bar.pack_propagate(False)
        ctk.CTkButton(btn_bar, text="Re-render with Edits", width=180,
                      fg_color="#8c6c2d", hover_color="#715823",
                      command=self.on_rerender).pack(side="left", padx=8, pady=4)

    def populate(self, bubbles: list[dict]):
        self.clear()
        for i, b in enumerate(bubbles):
            row = ctk.CTkFrame(self.body,
                               fg_color="gray20" if i % 2 == 0 else "gray17")
            row.pack(fill="x", pady=1)

            ctk.CTkLabel(row, text=str(i + 1), width=30,
                         font=("Arial", 11)).pack(side="left", padx=4)

            tc = TYPE_COLORS.get(b.get('type', 'speech'), "#555")
            ctk.CTkLabel(row, text=b.get('type', '?'), width=60,
                         font=("Arial", 10), fg_color=tc,
                         corner_radius=4).pack(side="left", padx=4)

            ctk.CTkLabel(row, text=b['original'], width=300, anchor="w",
                         font=("Arial", 11),
                         wraplength=290).pack(side="left", padx=4)

            entry = ctk.CTkEntry(row, font=("Arial", 11))
            entry.insert(0, b['translated'])
            entry.pack(side="left", padx=4, fill="x", expand=True)
            self._entries.append(entry)

    def clear(self):
        for w in self.body.winfo_children():
            w.destroy()
        self._entries.clear()

    def get_edited_translations(self) -> list[str]:
        return [e.get() for e in self._entries]
