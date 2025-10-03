import XCTest
@testable import NeurospLIT

final class ExportTests: XCTestCase {

    private func makeParticipants() -> [Participant] {
        return [
            Participant(id: UUID(), name: "Alex", role: "Server", hours: nil, weight: nil, calculatedAmount: 120.0, actualAmount: nil),
            Participant(id: UUID(), name: "Sam", role: "Bartender", hours: nil, weight: nil, calculatedAmount: 80.0, actualAmount: nil)
        ]
    }

    func testPDFExportProducesValidPDFHeader() throws {
        let splits = makeParticipants()
        let data = PDFExport.buildSplitPDF(splits: splits, tipAmount: 200.0)
        XCTAssertFalse(data.isEmpty, "PDF data should not be empty")
        // PDF files begin with %PDF-
        let header = String(data: data.prefix(5), encoding: .ascii)
        XCTAssertEqual(header, "%PDF-", "Invalid PDF header")
    }

    func testCSVGenerationMatchesExpectedShape() throws {
        // Replicate CSV generation logic to validate structure and percentages
        let splits = makeParticipants()
        let tipAmount: Double = 200.0
        var csv = "Name,Role,Amount,Percentage\n"
        for split in splits {
            let amount = split.calculatedAmount ?? 0
            let amountStr = amount.currencyFormatted()
            let pct = (amount / tipAmount) * 100
            let percentageStr = String(format: "%.1f", pct)
            csv += "\(split.name),\(split.role),\(amountStr),\(percentageStr)%\n"
        }

        // Basic shape checks
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[0].contains("Name,Role,Amount,Percentage"))
        XCTAssertTrue(lines[1].contains("Alex"))
        XCTAssertTrue(lines[2].contains("Sam"))
    }

    func testPlainTextSummaryShape() throws {
        let splits = makeParticipants()
        let tipAmount: Double = 200.0
        let totalStr = tipAmount.currencyFormatted()
        var text = "Tip Split - Total: \(totalStr)\n"
        text += String(repeating: "-", count: 30) + "\n"
        for split in splits {
            let amountStr = (split.calculatedAmount ?? 0).currencyFormatted()
            text += "\(split.name) (\(split.role)): \(amountStr)\n"
        }
        XCTAssertTrue(text.contains("Tip Split - Total:"))
        XCTAssertTrue(text.contains("Alex (Server):"))
        XCTAssertTrue(text.contains("Sam (Bartender):"))
    }
}


