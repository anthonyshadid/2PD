# 2PD Generator

Tools for generating 3D-printable two-point discrimination wheels. Available as a web app and a native iOS app.

---

## Website

A Flask web app deployed via Docker on Render. Users can download preset STL wheels or enter 8 custom distances to generate a wheel on the server using OpenSCAD.

**Live at:** [https://anthonyshadid.github.io/2PD](https://anthonyshadid.github.io/2PD)

### How It Works

1. User enters 8 distances (0-17 mm) in the browser.
2. The server runs OpenSCAD with those distances as parameters against `discriminator.scad`.
3. The generated STL is returned as a file download.

Preset STL files (fine and broad) are served directly as static assets.

### Stack

- Python / Flask
- OpenSCAD (headless, via `xvfb-run` in the container)
- Docker, deployed on Render

### Running Locally

```bash
pip install -r requirements.txt
python app.py
```

The app starts on port 5000 by default. OpenSCAD must be installed and on your PATH.

### Running with Docker

```bash
docker build -t 2pd .
docker run -p 5000:5000 2pd
```

### Project Structure

```
app.py               Flask routes
make_wheel.py        Calls OpenSCAD to produce STL output
discriminator.scad   Parametric wheel model
templates/           HTML templates
static/presets/      Pre-built STL files
Dockerfile
render.yaml
```

### Deployment

The app deploys automatically on push to main via `render.yaml`. No manual steps needed.

---

## iPhone App

A native iOS app that generates STL files entirely on-device, no server or OpenSCAD required. The geometry is reimplemented in Swift using the same parameters as `discriminator.scad`.

**App Store:** [2PD on the App Store](https://apps.apple.com/us/app/2pd/id6761318358)

### How It Works

1. User enters up to 8 distances in the app.
2. `SCADCompatModeler.swift` computes the wheel geometry and writes an STL file.
3. The standard iOS share sheet lets the user save to Files, AirDrop, or open in a slicer app.

All processing is on-device. No network connection needed.

### Stack

- Swift / SwiftUI
- Xcode
- No third-party dependencies

### Project Structure

```
2PDiPhone/
  2PDiPhone/
    TwoPDApp.swift          App entry point, tab structure
    ContentView.swift       Distance input form and STL export
    AboutView.swift         About and usage information
    SCADCompatModeler.swift On-device STL geometry engine
    Assets.xcassets/        App icon and colors
  2PDiPhone.xcodeproj/
```

### Building

Open `2PDiPhone/2PDiPhone.xcodeproj` in Xcode and run on a simulator or device. No additional setup required.

### Modeler Parameters

The on-device modeler matches the SCAD defaults:

| Parameter | Value |
|---|---|
| Wheel diameter (flat-to-flat) | 40 mm |
| Body thickness | 3 mm |
| Prong length | 7 mm |
| Prong thickness | 1.4 mm |
| Hub diameter | 17 mm |
| Lanyard hole | 3.5 mm diameter, at corner |

---

## Contributing

Bug reports and pull requests welcome. The SCAD file and the Swift modeler should stay in sync; if you change `discriminator.scad` geometry, update `SCADCompatModeler.swift` to match.

## Authors

Anthony Shadid and Keyvon Rashidi

## License

Open source. See LICENSE for details.

## Disclaimer

Not for diagnostic use unless validated and approved by your institution. Provided as-is without warranties of any kind.
