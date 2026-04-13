"""Toolbar with file operations, translate/save buttons, and page navigation."""

import customtkinter as ctk


class Toolbar(ctk.CTkFrame):
    def __init__(self, parent, callbacks: dict):
        super().__init__(parent, height=50)
        self.callbacks = callbacks
        self._build()

    def _build(self):
        cb = self.callbacks

        ctk.CTkButton(self, text="Open File", width=100,
                      command=cb['open_file']).pack(side="left", padx=4)
        ctk.CTkButton(self, text="Open CBR/CBZ", width=120,
                      command=cb['open_cbr']).pack(side="left", padx=4)
        ctk.CTkButton(self, text="Open Folder", width=110,
                      command=cb['open_folder']).pack(side="left", padx=4)

        self._sep(self)

        self.btn_translate = ctk.CTkButton(
            self, text="Translate", width=110,
            fg_color="#2d8c3c", hover_color="#23712f",
            command=cb['translate'])
        self.btn_translate.pack(side="left", padx=4)

        self.btn_translate_all = ctk.CTkButton(
            self, text="Translate All", width=120,
            fg_color="#2d6e8c", hover_color="#235a71",
            command=cb['translate_all'])
        self.btn_translate_all.pack(side="left", padx=4)

        self._sep(self)

        ctk.CTkButton(self, text="Save", width=80,
                      command=cb['save']).pack(side="left", padx=4)
        ctk.CTkButton(self, text="Save All", width=90,
                      command=cb['save_all']).pack(side="left", padx=4)

        # Right side: settings + page nav
        ctk.CTkButton(self, text="Settings", width=90, fg_color="gray30",
                      hover_color="gray40",
                      command=cb['settings']).pack(side="right", padx=4)

        nav = ctk.CTkFrame(self)
        nav.pack(side="right", padx=12)
        ctk.CTkButton(nav, text="\u25C0", width=35,
                      command=cb['prev_page']).pack(side="left", padx=2)
        self.page_label = ctk.CTkLabel(nav, text="- / -", width=70)
        self.page_label.pack(side="left", padx=4)
        ctk.CTkButton(nav, text="\u25B6", width=35,
                      command=cb['next_page']).pack(side="left", padx=2)

    def _sep(self, parent):
        ctk.CTkFrame(parent, width=2, height=30,
                     fg_color="gray40").pack(side="left", padx=8)

    def set_page(self, text: str):
        self.page_label.configure(text=text)

    def set_processing(self, busy: bool):
        state = "disabled" if busy else "normal"
        self.btn_translate.configure(state=state)
        self.btn_translate_all.configure(state=state)
