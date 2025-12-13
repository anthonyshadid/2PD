import os, shutil, subprocess, tempfile
from pathlib import Path

# -------------- Config --------------
SCAD_BASENAME = "discriminator.scad"

# -------------- Helpers --------------
def find_openscad() -> str:
    """Locate openscad binary on PATH in the container."""
    path = shutil.which("openscad")
    if not path:
        raise FileNotFoundError("OpenSCAD not on PATH")
    return path

def _tmpfile(suffix: str) -> str:
    """Create a named temp file in /tmp and return its path (not deleted)."""
    f = tempfile.NamedTemporaryFile(dir="/tmp", suffix=suffix, delete=False)
    f.close()
    return f.name

# -------------- Public API --------------
def generate_wheel_stl(distances, output_stl: str | None = None) -> str:
    """
    Generates an STL in /tmp and returns the path.
    distances: list of numbers (e.g., [2,4,6,8,10,15,20,25])
    output_stl: optional full path; if None, a temp file in /tmp is used.
    """
    openscad_bin = find_openscad()

    scad_path = (Path(__file__).resolve().parent / SCAD_BASENAME)
    if not scad_path.exists():
        raise FileNotFoundError(f"Missing SCAD file: {scad_path}")


    stl_path = output_stl or _tmpfile(".stl")

    dlist = "[" + ",".join(str(float(x)) for x in distances) + "]"

    # Run headless; capture output for debugging
    cmd = ["xvfb-run", "-a", openscad_bin, "-o", stl_path, "-D", f"distances_mm={dlist}", str(scad_path)]
    print("Running:", " ".join(cmd))
    proc = subprocess.run(cmd, capture_output=True, text=True)

    if proc.returncode != 0:
        raise RuntimeError(f"OpenSCAD failed ({proc.returncode}).\nSTDERR:\n{proc.stderr}\nSTDOUT:\n{proc.stdout}")

    if not Path(stl_path).exists() or Path(stl_path).stat().st_size == 0:
        raise RuntimeError("OpenSCAD finished but STL not created or empty.")

    print(f"✅ Wrote {stl_path}")
    return stl_path

# -------------- CLI (local use) --------------
if __name__ == "__main__":
    raw = input("Enter distances (e.g., 2,4,6,8,10,15,20,25):\n> ").strip()
    distances = [float(x) for x in raw.split(",") if x.strip()]
    path = generate_wheel_stl(distances)
    print("STL:", path)
