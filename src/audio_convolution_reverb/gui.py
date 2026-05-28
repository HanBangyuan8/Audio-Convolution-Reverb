from __future__ import annotations

import queue
import subprocess
import sys
import threading
from pathlib import Path
from tkinter import Button, DoubleVar, Entry, Label, Scale, StringVar, Tk, filedialog, messagebox
from tkinter import HORIZONTAL, N, S, E, W

from .core import apply_convolution_reverb, load_impulse_response


class ReverbApp:
    def __init__(self, root: Tk) -> None:
        self.root = root
        self.root.title("Audio Convolution Reverb")
        self.root.minsize(620, 260)

        self.dry_path = StringVar()
        self.ir_path = StringVar()
        self.output_path = StringVar(value=str(Path("output/rendered_reverb.wav")))
        self.wet_level = DoubleVar(value=0.5)
        self.dry_level = DoubleVar(value=0.5)
        self.status = StringVar(value="Ready")
        self.events: queue.Queue[tuple[str, str]] = queue.Queue()

        self._build()
        self._poll_events()

    def _build(self) -> None:
        self.root.columnconfigure(1, weight=1)
        labels = ["Dry audio", "Impulse response", "Output WAV", "Wet level", "Dry level"]
        for row, text in enumerate(labels):
            Label(self.root, text=text).grid(row=row, column=0, sticky=E, padx=12, pady=8)

        Entry(self.root, textvariable=self.dry_path).grid(row=0, column=1, sticky=E + W, padx=6)
        Button(self.root, text="Browse", command=self._pick_dry).grid(row=0, column=2, padx=12)

        Entry(self.root, textvariable=self.ir_path).grid(row=1, column=1, sticky=E + W, padx=6)
        Button(self.root, text="Browse", command=self._pick_ir).grid(row=1, column=2, padx=12)

        Entry(self.root, textvariable=self.output_path).grid(row=2, column=1, sticky=E + W, padx=6)
        Button(self.root, text="Save As", command=self._pick_output).grid(row=2, column=2, padx=12)

        Scale(
            self.root,
            from_=0,
            to=1,
            resolution=0.05,
            orient=HORIZONTAL,
            variable=self.wet_level,
        ).grid(row=3, column=1, sticky=E + W, padx=6)

        Scale(
            self.root,
            from_=0,
            to=1,
            resolution=0.05,
            orient=HORIZONTAL,
            variable=self.dry_level,
        ).grid(row=4, column=1, sticky=E + W, padx=6)

        Button(self.root, text="Render", command=self._render).grid(row=5, column=1, sticky=E, padx=6, pady=12)
        Button(self.root, text="Open Output", command=self._open_output).grid(row=5, column=2, padx=12, pady=12)
        Label(self.root, textvariable=self.status).grid(row=6, column=0, columnspan=3, sticky=W, padx=12, pady=8)

        for row in range(7):
            self.root.rowconfigure(row, weight=0)
        self.root.rowconfigure(6, weight=1)

    def _pick_dry(self) -> None:
        path = filedialog.askopenfilename(filetypes=[("Audio files", "*.wav *.aif *.aiff *.flac"), ("All files", "*")])
        if path:
            self.dry_path.set(path)

    def _pick_ir(self) -> None:
        path = filedialog.askopenfilename(filetypes=[("Audio files", "*.wav *.aif *.aiff *.flac"), ("All files", "*")])
        if path:
            self.ir_path.set(path)

    def _pick_output(self) -> None:
        path = filedialog.asksaveasfilename(defaultextension=".wav", filetypes=[("WAV files", "*.wav")])
        if path:
            self.output_path.set(path)

    def _render(self) -> None:
        if not self.dry_path.get() or not self.ir_path.get() or not self.output_path.get():
            messagebox.showerror("Missing files", "Choose a dry audio file, an impulse response, and an output path.")
            return
        self.status.set("Rendering...")
        threading.Thread(target=self._render_worker, daemon=True).start()

    def _render_worker(self) -> None:
        try:
            impulse_response, impulse_sample_rate = load_impulse_response(self.ir_path.get())
            apply_convolution_reverb(
                self.dry_path.get(),
                impulse_response,
                self.output_path.get(),
                wet_level=self.wet_level.get(),
                dry_level=self.dry_level.get(),
                impulse_sample_rate=impulse_sample_rate,
            )
            self.events.put(("ok", f"Rendered {self.output_path.get()}"))
        except Exception as exc:
            self.events.put(("error", str(exc)))

    def _poll_events(self) -> None:
        try:
            kind, message = self.events.get_nowait()
        except queue.Empty:
            self.root.after(150, self._poll_events)
            return
        self.status.set(message)
        if kind == "error":
            messagebox.showerror("Render failed", message)
        self.root.after(150, self._poll_events)

    def _open_output(self) -> None:
        path = self.output_path.get()
        if not path:
            return
        if sys.platform == "darwin":
            subprocess.run(["open", path], check=False)
        elif sys.platform.startswith("win"):
            subprocess.run(["cmd", "/c", "start", path], check=False)
        else:
            subprocess.run(["xdg-open", path], check=False)


def main() -> None:
    root = Tk()
    ReverbApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
