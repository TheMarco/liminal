from __future__ import annotations

from pathlib import Path
import tempfile

from PIL import Image, ImageTk

from ..config import bundled_presets_dir, bundled_profiles_dir, list_json_ids
from ..pipeline import EXTRACTORS, process_image


def launch() -> None:
    """Launch the deliberately thin desktop front-end over the pipeline API."""
    import tkinter as tk
    from tkinter import filedialog, messagebox, ttk

    root = tk.Tk()
    root.title("Liminal Environment Lab — Phase 2")
    root.geometry("1180x760")
    root.configure(bg="#151719")
    source = tk.StringVar()
    output = tk.StringVar()
    profile = tk.StringVar(value="annex")
    preset = tk.StringVar(value="balanced")
    effect = tk.StringVar(value="all enabled")
    status = tk.StringVar(value="Choose an image to inspect environmental damage channels.")

    controls = ttk.Frame(root, padding=12)
    controls.pack(fill="x")
    preview = ttk.Label(root, anchor="center")
    preview.pack(fill="both", expand=True, padx=12, pady=(0, 8))
    ttk.Label(root, textvariable=status).pack(fill="x", padx=12, pady=(0, 12))

    def choose_source() -> None:
        chosen = filedialog.askopenfilename(filetypes=[("Images", "*.png *.jpg *.jpeg *.webp *.tif *.tiff")])
        if chosen:
            source.set(chosen)
            if not output.get():
                output.set(str(Path(chosen).with_suffix("").with_name(Path(chosen).stem + "_damage")))

    def choose_output() -> None:
        chosen = filedialog.askdirectory()
        if chosen:
            output.set(chosen)

    def run_preview() -> None:
        if not source.get():
            messagebox.showerror("No source", "Choose a source image first.")
            return
        selected = None if effect.get() == "all enabled" else effect.get()
        destination = Path(output.get()) if output.get() else Path(tempfile.mkdtemp(prefix="liminal-lab-"))
        try:
            result = process_image(Path(source.get()), destination, profile.get(), preset.get(), selected)
            sheet = result.outputs["contact_sheet"]
            image = Image.fromarray(sheet)
            image.thumbnail((1140, 610), Image.Resampling.LANCZOS)
            rendered = ImageTk.PhotoImage(image)
            preview.configure(image=rendered)
            preview.image = rendered
            status.set(f"Wrote {len(result.outputs)} image assets and a Godot manifest to {destination}")
        except Exception as error:
            messagebox.showerror("Processing failed", str(error))

    ttk.Button(controls, text="Source…", command=choose_source).grid(row=0, column=0, padx=4)
    ttk.Entry(controls, textvariable=source, width=42).grid(row=0, column=1, padx=4)
    ttk.Button(controls, text="Output…", command=choose_output).grid(row=0, column=2, padx=4)
    ttk.Entry(controls, textvariable=output, width=32).grid(row=0, column=3, padx=4)
    ttk.Combobox(controls, textvariable=profile, width=16, state="readonly",
                 values=list_json_ids(bundled_profiles_dir())).grid(row=1, column=1, pady=8)
    ttk.Combobox(controls, textvariable=preset, width=16, state="readonly",
                 values=list_json_ids(bundled_presets_dir())).grid(row=1, column=2, pady=8)
    ttk.Combobox(controls, textvariable=effect, width=20, state="readonly",
                 values=["all enabled", *EXTRACTORS.keys()]).grid(row=1, column=3, pady=8)
    ttk.Button(controls, text="Generate preview", command=run_preview).grid(row=1, column=0, padx=4)
    root.mainloop()
