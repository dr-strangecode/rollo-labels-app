# Square Rollo Printer v1.3

Native macOS utility for printing Square-generated multipage PDF price labels to a Rollo X1040 using the working CUPS `lp` route, rather than Preview.

## Requirements

- macOS 13+ and a configured printer
- Xcode on the development Mac only
- 2 × 1 inch label stock

## Run

Open `SquareRolloPrinter.xcodeproj`, choose My Mac, then press Command-R. Drop in a Square PDF, select the printer, adjust scaling and positioning, and print.

## Scaling

100% fits each source PDF page proportionally onto a 2 × 1 inch label. Larger values zoom into the label and can crop contents. Preview the first page and verify that the barcode scans before printing a large batch.

## Positioning

Artwork is centered by default. Use the horizontal and vertical sliders to shift the printed artwork up to 10 mm in either direction in 0.5 mm steps, or press **Center** to restore zero offsets. Positive horizontal values move right; positive vertical values move up. Offsets are stored locally on each Mac. The preview uses the same render function as printing. Recenter before changing label stock, and run a one-label test to ensure the barcode remains entirely within the printable area.

## Saved printer calibration

The **Save Calibration** button stores the current scale, horizontal shift, and vertical shift in macOS UserDefaults, scoped to the selected macOS printer queue name and the 2 × 1 inch stock size. **Load Saved** restores the last saved values; selecting a different printer automatically loads its saved calibration (or centered 100% defaults if none exists). Unsaved edits are discarded when switching printers, so save first. The app indicates when settings differ from the saved profile.

Calibration settings are local to each Mac. Transferring the standalone app does **not** transfer calibration; calibrate and save separately on the playplace laptop. The app currently supports only 2 × 1 inch stock. If more sizes are added, their profiles will remain independent.

## Build a portable app

Run `./build-standalone.command` on a Mac with Xcode. This produces `dist/SquareRolloPrinter.app` and `dist/SquareRolloPrinter-macOS.zip` for internal use. It targets arm64 and x86_64 and uses ad-hoc signing, without App Store distribution or notarization. Configure the printer independently on the destination Mac.

## Technical notes

The app uses SwiftUI, PDFKit, Core Graphics, `lpstat`, and `lp`. It creates a vector-preserving 144 × 72 pt PDF and submits it via CUPS. An accepted print job does not guarantee physical completion. The project has not been compiled against Apple's SDK in this environment.
