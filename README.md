# Square Rollo Printer v1.1

Native macOS utility for printing Square-generated multipage PDF price labels to a Rollo X1040 using the working CUPS `lp` route, rather than Preview.

## Requirements

- macOS 13+ and a configured printer
- Xcode on the development Mac only
- 2 × 1 inch label stock

## Run

Open `SquareRolloPrinter.xcodeproj`, choose My Mac, then press Command-R. Drop in a Square PDF, select the printer, adjust scaling, and print.

## Scaling

100% fits each source PDF page proportionally onto a 2 × 1 inch label. Larger values zoom into the label and can crop contents. Preview the first page and verify that the barcode scans before printing a large batch.

## Build a portable app

Run `./build-standalone.command` on a Mac with Xcode. This produces `dist/SquareRolloPrinter.app` and `dist/SquareRolloPrinter-macOS.zip` for internal use. It targets arm64 and x86_64 and uses ad-hoc signing, without App Store distribution or notarization. Configure the printer independently on the destination Mac.

## Technical notes

The app uses SwiftUI, PDFKit, Core Graphics, `lpstat`, and `lp`. It creates a vector-preserving 144 × 72 pt PDF and submits it via CUPS. An accepted print job does not guarantee physical completion. The project has not been compiled against Apple's SDK in this environment.
