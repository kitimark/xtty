import Foundation

/// Fixed producer-side limits for one Git-review diff preview.
///
/// These bounds apply before stdout is decoded or split into parser-owned
/// strings, so every later allocation is a fixed function of the retained
/// prefix rather than the total output produced by Git.
public struct DiffOutputLimits: Equatable, Sendable {
    public static let preview = DiffOutputLimits(
        readChunkBytes: 64 * 1024,
        maxRetainedBytes: 4 * 1024 * 1024,
        maxPhysicalLines: 5_008,
        maxCurrentLineBytes: 16 * 1024
    )

    public let readChunkBytes: Int
    public let maxRetainedBytes: Int
    public let maxPhysicalLines: Int
    public let maxCurrentLineBytes: Int

    public init(
        readChunkBytes: Int,
        maxRetainedBytes: Int,
        maxPhysicalLines: Int,
        maxCurrentLineBytes: Int
    ) {
        precondition(readChunkBytes > 0)
        precondition(maxRetainedBytes > 0)
        precondition(maxPhysicalLines > 0)
        precondition(maxCurrentLineBytes > 0)
        self.readChunkBytes = readChunkBytes
        self.maxRetainedBytes = maxRetainedBytes
        self.maxPhysicalLines = maxPhysicalLines
        self.maxCurrentLineBytes = maxCurrentLineBytes
    }
}

/// The first producer-side preview limit crossed by Git stdout.
public enum DiffOutputCutoffReason: String, Equatable, Sendable {
    case retainedBytes
    case physicalLines
    case currentLineBytes
}

/// Bounded stdout returned to the batch diff parser.
public struct BoundedDiffOutput: Equatable, Sendable {
    public let data: Data
    public let cutoffReason: DiffOutputCutoffReason?

    public init(data: Data, cutoffReason: DiffOutputCutoffReason?) {
        self.data = data
        self.cutoffReason = cutoffReason
    }

    public var wasTruncated: Bool { cutoffReason != nil }
}

/// Byte-oriented accumulator for a Git diff's stdout prefix.
///
/// `append(_:)` accepts complete chunks but retains only the prefix before the
/// first exceeded bound. Reaching a bound exactly is not itself truncation:
/// EOF may occur there. A later non-empty append is what proves excess output.
public struct BoundedDiffOutputAccumulator: Sendable {
    public let limits: DiffOutputLimits
    public private(set) var retainedData: Data
    public private(set) var physicalLineCount = 0
    public private(set) var currentLineBytes = 0
    public private(set) var cutoffReason: DiffOutputCutoffReason?

    public init(limits: DiffOutputLimits = .preview) {
        self.limits = limits
        var data = Data()
        data.reserveCapacity(min(limits.readChunkBytes, limits.maxRetainedBytes))
        retainedData = data
    }

    /// Consume the next stdout chunk. Once cut off, later chunks are ignored and
    /// return the original reason.
    @discardableResult
    public mutating func append(_ chunk: Data) -> DiffOutputCutoffReason? {
        if let cutoffReason { return cutoffReason }
        guard !chunk.isEmpty else { return nil }

        var accepted = 0
        var nextReason: DiffOutputCutoffReason?

        // Check order (retainedBytes, physicalLines, currentLineBytes) is a fixed
        // priority for a byte that would cross more than one limit at once. Only
        // `wasTruncated`/`sourceTruncated` (the boolean) reaches the parser and UI;
        // the specific reason is DEBUG-log/observation-only, so this ordering never
        // changes user-visible behavior — it only picks which reason is reported.
        chunk.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            for byte in bytes {
                if retainedData.count + accepted >= limits.maxRetainedBytes {
                    nextReason = .retainedBytes
                    break
                }
                if physicalLineCount >= limits.maxPhysicalLines {
                    nextReason = .physicalLines
                    break
                }
                if byte != 0x0A, currentLineBytes >= limits.maxCurrentLineBytes {
                    nextReason = .currentLineBytes
                    break
                }

                accepted += 1
                if byte == 0x0A {
                    physicalLineCount += 1
                    currentLineBytes = 0
                } else {
                    currentLineBytes += 1
                }
            }
        }

        if accepted > 0 {
            retainedData.append(chunk.prefix(accepted))
        }
        cutoffReason = nextReason
        return nextReason
    }

    public func result() -> BoundedDiffOutput {
        BoundedDiffOutput(data: retainedData, cutoffReason: cutoffReason)
    }
}
