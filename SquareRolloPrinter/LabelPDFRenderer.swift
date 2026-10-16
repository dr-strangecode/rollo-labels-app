import Foundation
import CoreGraphics
import PDFKit

/// Builds a vector-preserving, 2 × 1 inch PDF for the Rollo.
/// 100% = proportionally fit the source page inside a 2 × 1 inch label.
/// Larger values zoom the content about the center and may clip its edges.
/// Horizontal/vertical offsets are in millimeters; positive is right/up.
enum LabelPDFRenderer {
    static let labelSize = CGSize(width: 144, height: 72) // PDF points (72 points/inch)

    enum RenderError: LocalizedError {
        case unreadablePDF, cannotCreatePDF, missingPage(Int)
        var errorDescription: String? {
            switch self {
            case .unreadablePDF: return "The source PDF could not be read."
            case .cannotCreatePDF: return "Could not create the print-ready PDF."
            case .missingPage(let index): return "PDF page \(index + 1) is missing."
            }
        }
    }

    static func render(source: URL, scalePercent: Double,
                       horizontalOffsetMM: Double = 0, verticalOffsetMM: Double = 0,
                       firstPageOnly: Bool = false) throws -> URL {
        guard let document = CGPDFDocument(source as CFURL), document.numberOfPages > 0 else {
            throw RenderError.unreadablePDF
        }
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("SquareRollo-\(UUID().uuidString).pdf")
        var mediaBox = CGRect(origin: .zero, size: labelSize)
        guard let context = CGContext(output as CFURL, mediaBox: &mediaBox, nil) else {
            throw RenderError.cannotCreatePDF
        }
        let count = firstPageOnly ? 1 : document.numberOfPages
        let zoom = CGFloat(scalePercent / 100)
        let pointsPerMM: CGFloat = 72.0 / 25.4
        for index in 1...count {
            guard let page = document.page(at: index) else { throw RenderError.missingPage(index - 1) }
            context.beginPDFPage(nil)
            context.saveGState()
            // Center by default. Move the artwork relative to the physical label.
            context.translateBy(x: CGFloat(horizontalOffsetMM) * pointsPerMM,
                                y: CGFloat(verticalOffsetMM) * pointsPerMM)
            // Zoom around the center of the new label, not the bottom-left corner.
            context.translateBy(x: labelSize.width / 2, y: labelSize.height / 2)
            context.scaleBy(x: zoom, y: zoom)
            context.translateBy(x: -labelSize.width / 2, y: -labelSize.height / 2)
            let transform = page.getDrawingTransform(.mediaBox, rect: mediaBox, rotate: 0,
                                                     preserveAspectRatio: true)
            context.concatenate(transform)
            context.drawPDFPage(page)
            context.restoreGState()
            context.endPDFPage()
        }
        context.closePDF()
        return output
    }
}
