import Foundation
import XCTest
@testable import XttyCore

final class BoundedDiffOutputTests: XCTestCase {
    private func limits(
        chunk: Int = 4,
        retained: Int = 64,
        lines: Int = 16,
        currentLine: Int = 16
    ) -> DiffOutputLimits {
        DiffOutputLimits(
            readChunkBytes: chunk,
            maxRetainedBytes: retained,
            maxPhysicalLines: lines,
            maxCurrentLineBytes: currentLine
        )
    }

    func testPreviewDefaultsAreFixed() {
        XCTAssertEqual(DiffOutputLimits.preview.readChunkBytes, 64 * 1024)
        XCTAssertEqual(DiffOutputLimits.preview.maxRetainedBytes, 4 * 1024 * 1024)
        XCTAssertEqual(DiffOutputLimits.preview.maxPhysicalLines, 5_008)
        XCTAssertEqual(DiffOutputLimits.preview.maxCurrentLineBytes, 16 * 1024)
    }

    func testSmallChunksRoundTripByteIdenticallyAcrossUTF8Boundaries() {
        let expected = Data("alpha\nไทย😀\nomega\n".utf8)
        var accumulator = BoundedDiffOutputAccumulator(
            limits: limits(chunk: 3, retained: 128, lines: 8, currentLine: 32)
        )
        for offset in stride(from: 0, to: expected.count, by: 3) {
            accumulator.append(expected[offset..<min(offset + 3, expected.count)])
        }

        let result = accumulator.result()
        XCTAssertEqual(result.data, expected)
        XCTAssertNil(result.cutoffReason)
        XCTAssertFalse(result.wasTruncated)
        XCTAssertEqual(accumulator.physicalLineCount, 3)
        XCTAssertEqual(accumulator.currentLineBytes, 0)
    }

    func testRetainedByteLimitNeedsObservedExcess() {
        var exact = BoundedDiffOutputAccumulator(
            limits: limits(retained: 5, lines: 10, currentLine: 10)
        )
        exact.append(Data("12345".utf8))
        XCTAssertEqual(exact.result().data, Data("12345".utf8))
        XCTAssertNil(exact.cutoffReason)

        exact.append(Data())
        XCTAssertNil(exact.cutoffReason, "EOF at the exact limit is complete")
        XCTAssertEqual(exact.append(Data("6".utf8)), .retainedBytes)
        XCTAssertEqual(exact.retainedData, Data("12345".utf8))
    }

    func testPhysicalLineLimitNeedsObservedExcess() {
        var exact = BoundedDiffOutputAccumulator(
            limits: limits(retained: 64, lines: 2, currentLine: 16)
        )
        exact.append(Data("a\nb\n".utf8))
        XCTAssertNil(exact.cutoffReason)
        XCTAssertEqual(exact.physicalLineCount, 2)

        XCTAssertEqual(exact.append(Data("c\n".utf8)), .physicalLines)
        XCTAssertEqual(exact.retainedData, Data("a\nb\n".utf8))
    }

    func testCurrentLineLimitAllowsNewlineButRejectsAnotherContentByte() {
        var exact = BoundedDiffOutputAccumulator(
            limits: limits(retained: 64, lines: 4, currentLine: 3)
        )
        exact.append(Data("abc\n".utf8))
        XCTAssertNil(exact.cutoffReason)
        XCTAssertEqual(exact.currentLineBytes, 0)

        var over = BoundedDiffOutputAccumulator(
            limits: limits(retained: 64, lines: 4, currentLine: 3)
        )
        XCTAssertEqual(over.append(Data("abcd".utf8)), .currentLineBytes)
        XCTAssertEqual(over.retainedData, Data("abc".utf8))
        XCTAssertEqual(over.currentLineBytes, 3)
    }

    func testEachCutoffReasonFiresIndependently() {
        var bytes = BoundedDiffOutputAccumulator(
            limits: limits(retained: 4, lines: 10, currentLine: 10)
        )
        XCTAssertEqual(bytes.append(Data("12345".utf8)), .retainedBytes)

        var lines = BoundedDiffOutputAccumulator(
            limits: limits(retained: 64, lines: 1, currentLine: 10)
        )
        XCTAssertEqual(lines.append(Data("a\nb".utf8)), .physicalLines)

        var line = BoundedDiffOutputAccumulator(
            limits: limits(retained: 64, lines: 10, currentLine: 2)
        )
        XCTAssertEqual(line.append(Data("abc".utf8)), .currentLineBytes)
    }

    func testRetainedAndCurrentLineInvariantsHoldAsOfferedInputGrows() {
        let bounded = limits(chunk: 64, retained: 1_024, lines: 1_000, currentLine: 32)
        for offeredLineCount in [1, 10, 100, 1_000] {
            var accumulator = BoundedDiffOutputAccumulator(limits: bounded)
            let line = Data((String(repeating: "x", count: 31) + "\n").utf8)
            for _ in 0..<offeredLineCount {
                accumulator.append(line)
            }
            XCTAssertLessThanOrEqual(accumulator.retainedData.count, bounded.maxRetainedBytes)
            XCTAssertLessThanOrEqual(accumulator.currentLineBytes, bounded.maxCurrentLineBytes)
        }
    }

    func testLaterChunksCannotChangeTheFirstCutoff() {
        var accumulator = BoundedDiffOutputAccumulator(
            limits: limits(retained: 4, lines: 10, currentLine: 10)
        )
        accumulator.append(Data("12345".utf8))
        accumulator.append(Data("more\noutput\n".utf8))

        XCTAssertEqual(accumulator.cutoffReason, .retainedBytes)
        XCTAssertEqual(accumulator.retainedData, Data("1234".utf8))
    }
}
