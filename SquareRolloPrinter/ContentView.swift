import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    @AppStorage("selectedPrinter") private var selectedPrinter = ""
    @State private var printerNames: [String] = []
    @State private var pdfURL: URL?
    @State private var pdfDocument: PDFDocument?
    @State private var scaledPreview: PDFDocument?
    @State private var scalePercent = 100.0
    @State private var horizontalOffsetMM = 0.0
    @State private var verticalOffsetMM = 0.0
    @State private var savedCalibration: CalibrationProfile?
    private let labelStockID = "2x1-in"

    @State private var pageRange = ""
    @State private var message = "Select a Square PDF to get started."
    @State private var working = false
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "printer.fill")
                    .font(.title2)
                Text("Square → Rollo Printer")
                    .font(.title2.bold())
                Spacer()
                Button("Refresh Printers") { refreshPrinters() }
            }

            HStack {
                Text("Printer:")
                Picker("Printer", selection: $selectedPrinter) {
                    Text("Choose printer").tag("")
                    ForEach(printerNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 350)
                Spacer()
                Text("Media: 2 × 1 in")
                    .foregroundStyle(.secondary)
            }

            GroupBox {
                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.arrow.up")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(pdfURL?.lastPathComponent ?? "Drop a PDF here, or choose a file")
                        .fontWeight(.medium)
                        .lineLimit(2)
                    Button("Choose PDF…") { choosePDF() }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .background(isDropTargeted ? Color.accentColor.opacity(0.12) : Color.clear)
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url { DispatchQueue.main.async { loadPDF(url) } }
                }
                return true
            }

            HStack {
                Text("\(pdfDocument?.pageCount ?? 0) pages")
                Spacer()
                Text("Page range (optional):")
                TextField("e.g. 1-3 or 1,3", text: $pageRange)
                    .frame(width: 130)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Label content scale")
                    Slider(value: $scalePercent, in: 80...120, step: 1)
                        .onChange(of: scalePercent) { _ in refreshPreview() }
                    Text("\(Int(scalePercent))%")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                    Button("Reset") { scalePercent = 100 }
                }
                Text("100% fits the original Square label onto 2 × 1 inches. Above 100% enlarges the content but can crop its edges. Check the barcode before printing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GroupBox("Position on label") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Horizontal")
                            .frame(width: 78, alignment: .leading)
                        Slider(value: $horizontalOffsetMM, in: -10...10, step: 0.5)
                            .onChange(of: horizontalOffsetMM) { _ in refreshPreview() }
                        Text(String(format: "%+.1f mm", horizontalOffsetMM))
                            .monospacedDigit()
                            .frame(width: 72, alignment: .trailing)
                    }
                    HStack {
                        Text("Vertical")
                            .frame(width: 78, alignment: .leading)
                        Slider(value: $verticalOffsetMM, in: -10...10, step: 0.5)
                            .onChange(of: verticalOffsetMM) { _ in refreshPreview() }
                        Text(String(format: "%+.1f mm", verticalOffsetMM))
                            .monospacedDigit()
                            .frame(width: 72, alignment: .trailing)
                    }
                    HStack {
                        Text("Positive horizontal moves right; positive vertical moves up.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Center") {
                            horizontalOffsetMM = 0
                            verticalOffsetMM = 0
                            refreshPreview()
                        }
                    }
                }
                .padding(.vertical, 3)
            }

            GroupBox("Saved calibration · 2 × 1 in") {
                HStack(spacing: 10) {
                    if savedCalibration != nil {
                        Label(hasUnsavedChanges ? "Unsaved adjustments" : "Saved settings loaded",
                              systemImage: hasUnsavedChanges ? "pencil.circle" : "checkmark.circle")
                            .foregroundColor(hasUnsavedChanges ? Color.orange : Color.secondary)
                    } else {
                        Label("No saved calibration for this printer", systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Load Saved") { loadCalibration() }
                        .disabled(selectedPrinter.isEmpty || savedCalibration == nil)
                    Button("Save Calibration") { saveCalibration() }
                        .disabled(selectedPrinter.isEmpty || working)
                }
                .padding(.vertical, 3)
            }

            GroupBox("Print layout preview (first label)") {
                if let scaledPreview {
                    PDFPreview(document: scaledPreview)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableViewPlaceholder()
                }
            }
            .frame(maxHeight: .infinity)

            HStack(alignment: .center) {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(3)
                Spacer(minLength: 12)
                Button(working ? "Submitting…" : "Print Labels") { printLabels() }
                    .buttonStyle(.borderedProminent)
                    .disabled(working || selectedPrinter.isEmpty || pdfURL == nil)
                    .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding(20)
        .onAppear {
            refreshPrinters()
            loadCalibration()
        }
        .onChange(of: selectedPrinter) { _ in loadCalibration() }
        .onOpenURL { loadPDF($0) }
    }

    private var currentCalibration: CalibrationProfile {
        CalibrationProfile(scalePercent: scalePercent,
                           horizontalOffsetMM: horizontalOffsetMM,
                           verticalOffsetMM: verticalOffsetMM)
    }

    private var hasUnsavedChanges: Bool {
        guard let savedCalibration else { return false }
        return savedCalibration != currentCalibration
    }

    private var calibrationKey: String {
        // Printer queue name identifies a macOS printer; label stock is part of the key.
        // This prevents calibration for one label size from affecting another.
        "calibration.\(labelStockID).\(selectedPrinter)"
    }

    private func loadCalibration() {
        guard !selectedPrinter.isEmpty else {
            savedCalibration = nil
            applyCalibration(.default)
            return
        }
        if let data = UserDefaults.standard.data(forKey: calibrationKey),
           let profile = try? JSONDecoder().decode(CalibrationProfile.self, from: data) {
            savedCalibration = profile
            applyCalibration(profile)
            message = "Loaded saved calibration for \(selectedPrinter) (2 × 1 in)."
        } else {
            savedCalibration = nil
            applyCalibration(.default)
            message = "No saved 2 × 1 in calibration for \(selectedPrinter); using centered defaults."
        }
    }

    private func applyCalibration(_ profile: CalibrationProfile) {
        scalePercent = profile.scalePercent
        horizontalOffsetMM = profile.horizontalOffsetMM
        verticalOffsetMM = profile.verticalOffsetMM
        refreshPreview()
    }

    private func saveCalibration() {
        guard !selectedPrinter.isEmpty else { return }
        let profile = currentCalibration
        guard let data = try? JSONEncoder().encode(profile) else {
            message = "Could not encode calibration."
            return
        }
        UserDefaults.standard.set(data, forKey: calibrationKey)
        savedCalibration = profile
        message = "Saved 2 × 1 in calibration for \(selectedPrinter)."
    }

    private func choosePDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { loadPDF(url) }
    }

    private func loadPDF(_ url: URL) {
        guard url.pathExtension.lowercased() == "pdf" else {
            message = "Choose a PDF file."
            return
        }
        // Copy now so temporary drag-and-drop permissions don't expire before printing.
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        do {
            let file = FileManager.default.temporaryDirectory
                .appendingPathComponent("SquareRolloPrinter-\(UUID().uuidString).pdf")
            try FileManager.default.copyItem(at: url, to: file)
            guard let document = PDFDocument(url: file), document.pageCount > 0 else {
                message = "The PDF could not be opened or contains no pages."
                return
            }
            pdfURL = file
            pdfDocument = document
            refreshPreview()
            pageRange = ""
            message = "Ready to print \(document.pageCount) page(s)."
        } catch {
            message = "Could not open the PDF: \(error.localizedDescription)"
        }
    }

    private func refreshPreview() {
        guard let url = pdfURL else { scaledPreview = nil; return }
        do {
            let renderedURL = try LabelPDFRenderer.render(source: url, scalePercent: scalePercent,
                                                           horizontalOffsetMM: horizontalOffsetMM,
                                                           verticalOffsetMM: verticalOffsetMM,
                                                           firstPageOnly: true)
            scaledPreview = PDFDocument(url: renderedURL)
            // PDFKit retains the loaded document; the generated file is a temporary preview.
        } catch {
            scaledPreview = nil
            message = "Could not render preview: \(error.localizedDescription)"
        }
    }

    private func refreshPrinters() {
        do {
            let found = try PrintService.printers()
            printerNames = found.names
            if !printerNames.contains(selectedPrinter) {
                selectedPrinter = found.defaultName.flatMap { printerNames.contains($0) ? $0 : nil }
                    ?? printerNames.first(where: { $0.localizedCaseInsensitiveContains("rollo") })
                    ?? ""
            }
            if printerNames.isEmpty { message = "No macOS printers found. Add the Rollo in System Settings first." }
        } catch {
            message = "Could not discover printers: \(error.localizedDescription)"
        }
    }

    private func printLabels() {
        guard let url = pdfURL, let document = pdfDocument, !selectedPrinter.isEmpty else { return }
        let range = pageRange.trimmingCharacters(in: .whitespacesAndNewlines)
        if !range.isEmpty && !validRange(range, count: document.pageCount) {
            message = "Invalid page range. Use 1-3 or 1,3 (up to page \(document.pageCount))."
            return
        }
        let printer = selectedPrinter
        let scale = scalePercent
        let xOffset = horizontalOffsetMM
        let yOffset = verticalOffsetMM
        working = true
        message = "Submitting job…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<String, Error>
            do {
                let printURL = try LabelPDFRenderer.render(source: url, scalePercent: scale,
                                                           horizontalOffsetMM: xOffset,
                                                           verticalOffsetMM: yOffset)
                result = .success(try PrintService.submit(pdf: printURL, printer: printer,
                    pageRange: range.isEmpty ? nil : range))
            }
            catch { result = .failure(error) }
            DispatchQueue.main.async {
                working = false
                switch result {
                case .success(let output): message = output
                case .failure(let error): message = "Print failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func validRange(_ input: String, count: Int) -> Bool {
        for part in input.split(separator: ",", omittingEmptySubsequences: false) {
            let bounds = part.split(separator: "-", omittingEmptySubsequences: false)
            guard bounds.count == 1 || bounds.count == 2,
                  let start = Int(bounds[0]), start >= 1, start <= count else { return false }
            if bounds.count == 2 {
                guard let end = Int(bounds[1]), end >= start, end <= count else { return false }
            }
        }
        return !input.isEmpty
    }
}

private struct PDFPreview: NSViewRepresentable {
    let document: PDFDocument
    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.backgroundColor = .windowBackgroundColor
        return view
    }
    func updateNSView(_ view: PDFView, context: Context) {
        if view.document !== document { view.document = document }
    }
}

private struct ContentUnavailableViewPlaceholder: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass").font(.largeTitle)
            Text("Your label preview will appear here")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CalibrationProfile: Codable, Equatable {
    let scalePercent: Double
    let horizontalOffsetMM: Double
    let verticalOffsetMM: Double

    static let `default` = CalibrationProfile(scalePercent: 100,
                                                horizontalOffsetMM: 0,
                                                verticalOffsetMM: 0)
}
