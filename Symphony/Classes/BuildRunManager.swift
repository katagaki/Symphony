import Foundation
import Compression
import Observation

@Observable
final class BuildRunManager {
    var buildRun: CiBuildRun?
    var actions: [CiBuildAction] = []
    var artifacts: [String: [CiArtifact]] = [:]
    var logText: String?
    var gitReferences: [GitReference] = []
    var isLoading: Bool = false
    var isStartingBuild: Bool = false
    var isLoadingLog: Bool = false
    var error: String?

    let api: AppStoreConnectAPI

    init(api: AppStoreConnectAPI) {
        self.api = api
    }

    func loadBuildRun(id: String) async {
        isLoading = true
        error = nil
        do {
            buildRun = try await api.getBuildRun(id: id)
            actions = try await api.listBuildActions(forBuildRunID: id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadGitReferences(workflowID: String) async {
        do {
            if let repoID = try await api.getWorkflowRepositoryID(workflowID: workflowID) {
                gitReferences = try await api.listGitReferences(forRepositoryID: repoID)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func startBuild(workflowID: String, gitReferenceID: String) async {
        isStartingBuild = true
        error = nil
        do {
            buildRun = try await api.startBuildRun(
                workflowID: workflowID,
                gitReferenceID: gitReferenceID
            )
        } catch {
            self.error = error.localizedDescription
        }
        isStartingBuild = false
    }

    func pollBuildStatus(id: String) async {
        while buildRun?.attributes.executionProgress != .complete {
            try? await Task.sleep(for: .seconds(10))
            if Task.isCancelled { break }
            do {
                buildRun = try await api.getBuildRun(id: id)
                actions = try await api.listBuildActions(forBuildRunID: id)
            } catch {
                break
            }
        }
    }

    func loadArtifacts(forActionID actionID: String) async {
        do {
            let actionArtifacts = try await api.listArtifacts(forBuildActionID: actionID)
            artifacts[actionID] = actionArtifacts
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadLog(forActionID actionID: String) async {
        isLoadingLog = true
        logText = nil
        do {
            let actionArtifacts = try await api.listArtifacts(forBuildActionID: actionID)

            // Prefer exact .log/.log.gz matches, then fall back to filenames containing "log"
            let logArtifact = actionArtifacts.first(where: {
                $0.attributes.fileName?.hasSuffix(".log") == true
                    || $0.attributes.fileName?.hasSuffix(".log.gz") == true
            }) ?? actionArtifacts.first(where: {
                $0.attributes.fileName?.contains("log") == true
            })

            if let logArtifact,
               let urlString = logArtifact.attributes.downloadUrl,
               let url = URL(string: urlString) {
                let data = try await api.downloadArtifact(url: url)

                // Try ZIP extraction first (crash log bundles are ZIP archives)
                if let text = Self.extractTextFromZip(data: data) {
                    logText = text
                // Try decompressing as gzip
                } else if let decompressed = Self.decompressGzip(data: data),
                          let text = String(data: decompressed, encoding: .utf8) {
                    logText = text
                } else if let text = String(data: data, encoding: .utf8) {
                    logText = text
                } else {
                    logText = String(data: data, encoding: .isoLatin1) ?? "Unable to decode log content."
                }
            } else {
                logText = "No log artifacts found for this action."
            }
        } catch {
            logText = "Failed to load logs: \(error.localizedDescription)"
        }
        isLoadingLog = false
    }

    // MARK: - ZIP Extraction

    private static func extractTextFromZip(data: Data) -> String? {
        // Check for ZIP magic number (PK\x03\x04)
        guard data.count >= 22,
              data[data.startIndex] == 0x50,
              data[data.startIndex + 1] == 0x4B,
              data[data.startIndex + 2] == 0x03,
              data[data.startIndex + 3] == 0x04
        else { return nil }

        // Find End of Central Directory record by scanning backwards
        var eocdOffset: Int?
        let searchStart = max(data.startIndex, data.endIndex - 65557)
        for i in stride(from: data.endIndex - 22, through: searchStart, by: -1) {
            if data[i] == 0x50 && data[i + 1] == 0x4B
                && data[i + 2] == 0x05 && data[i + 3] == 0x06 {
                eocdOffset = i
                break
            }
        }

        guard let eocd = eocdOffset else { return nil }

        let entryCount = Int(readUInt16(data, at: eocd + 10))
        let cdOffset = Int(readUInt32(data, at: eocd + 16))

        // Parse central directory entries
        struct ZipEntry {
            let name: String
            let compressionMethod: UInt16
            let compressedSize: Int
            let localHeaderOffset: Int
        }

        var entries: [ZipEntry] = []
        var pos = cdOffset

        for _ in 0..<entryCount {
            guard pos + 46 <= data.count,
                  data[pos] == 0x50, data[pos + 1] == 0x4B,
                  data[pos + 2] == 0x01, data[pos + 3] == 0x02
            else { break }

            let compMethod = readUInt16(data, at: pos + 10)
            let compSize = Int(readUInt32(data, at: pos + 20))
            let nameLen = Int(readUInt16(data, at: pos + 28))
            let extraLen = Int(readUInt16(data, at: pos + 30))
            let commentLen = Int(readUInt16(data, at: pos + 32))
            let localOffset = Int(readUInt32(data, at: pos + 42))

            let nameEnd = pos + 46 + nameLen
            guard nameEnd <= data.count else { break }
            let name = String(data: data[(pos + 46)..<nameEnd], encoding: .utf8) ?? ""

            entries.append(ZipEntry(
                name: name,
                compressionMethod: compMethod,
                compressedSize: compSize,
                localHeaderOffset: localOffset
            ))
            pos = nameEnd + extraLen + commentLen
        }

        // Extract text-like files
        let textExtensions = [".ips", ".log", ".txt", ".json", ".crash"]
        var extractedTexts: [(name: String, content: String)] = []

        for entry in entries {
            let isTextFile = textExtensions.contains(where: { entry.name.lowercased().hasSuffix($0) })
                && !entry.name.hasSuffix("/")
            guard isTextFile, entry.compressedSize > 0 else { continue }

            // Read local file header to find exact data offset
            let lh = entry.localHeaderOffset
            guard lh + 30 <= data.count else { continue }
            let lhNameLen = Int(readUInt16(data, at: lh + 26))
            let lhExtraLen = Int(readUInt16(data, at: lh + 28))
            let dataStart = lh + 30 + lhNameLen + lhExtraLen
            let dataEnd = dataStart + entry.compressedSize
            guard dataEnd <= data.count else { continue }

            let fileData = data[dataStart..<dataEnd]

            var content: String?
            if entry.compressionMethod == 0 {
                // Stored (uncompressed)
                content = String(data: fileData, encoding: .utf8)
            } else if entry.compressionMethod == 8 {
                // Deflate
                if let decompressed = decompressRawDeflate(data: Data(fileData)) {
                    content = String(data: decompressed, encoding: .utf8)
                }
            }

            if let content {
                extractedTexts.append((name: entry.name, content: content))
            }
        }

        guard !extractedTexts.isEmpty else { return nil }

        if extractedTexts.count == 1 {
            return extractedTexts[0].content
        }

        return extractedTexts.map { entry in
            let name = URL(fileURLWithPath: entry.name).lastPathComponent
            return "--- \(name) ---\n\(entry.content)"
        }.joined(separator: "\n\n")
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    private static func decompressRawDeflate(data: Data) -> Data? {
        guard !data.isEmpty else { return nil }

        let bufferSize = 65536
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }

        var stream = compression_stream(
            dst_ptr: destinationBuffer, dst_size: bufferSize,
            src_ptr: UnsafePointer<UInt8>(bitPattern: 1)!, src_size: 0, state: nil
        )
        let initStatus = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
        guard initStatus == COMPRESSION_STATUS_OK else { return nil }
        defer { compression_stream_destroy(&stream) }

        let sourceArray = Array(data)
        var decompressed = Data()

        sourceArray.withUnsafeBufferPointer { sourceBuffer in
            guard let sourcePointer = sourceBuffer.baseAddress else { return }

            stream.src_ptr = sourcePointer
            stream.src_size = sourceBuffer.count
            stream.dst_ptr = destinationBuffer
            stream.dst_size = bufferSize

            while true {
                let status = compression_stream_process(&stream, 0)
                switch status {
                case COMPRESSION_STATUS_OK:
                    let outputSize = bufferSize - stream.dst_size
                    if outputSize > 0 {
                        decompressed.append(destinationBuffer, count: outputSize)
                    }
                    stream.dst_ptr = destinationBuffer
                    stream.dst_size = bufferSize
                case COMPRESSION_STATUS_END:
                    let outputSize = bufferSize - stream.dst_size
                    if outputSize > 0 {
                        decompressed.append(destinationBuffer, count: outputSize)
                    }
                    return
                default:
                    return
                }
            }
        }

        return decompressed.isEmpty ? nil : decompressed
    }

    // MARK: - Gzip Decompression

    private static func decompressGzip(data: Data) -> Data? {
        // Check for gzip magic number
        guard data.count >= 10, data[data.startIndex] == 0x1f, data[data.startIndex + 1] == 0x8b else {
            return nil
        }

        let bufferSize = 65536
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }

        var stream = compression_stream(dst_ptr: destinationBuffer, dst_size: bufferSize, src_ptr: UnsafePointer<UInt8>(bitPattern: 1)!, src_size: 0, state: nil)
        let initStatus = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
        guard initStatus == COMPRESSION_STATUS_OK else { return nil }
        defer { compression_stream_destroy(&stream) }

        // Skip gzip header (minimum 10 bytes)
        let headerSize = 10
        let sourceData = data.dropFirst(headerSize)
        let sourceArray = Array(sourceData)

        var decompressed = Data()

        sourceArray.withUnsafeBufferPointer { sourceBuffer in
            guard let sourcePointer = sourceBuffer.baseAddress else { return }

            stream.src_ptr = sourcePointer
            stream.src_size = sourceBuffer.count
            stream.dst_ptr = destinationBuffer
            stream.dst_size = bufferSize

            while true {
                let status = compression_stream_process(&stream, 0)

                switch status {
                case COMPRESSION_STATUS_OK:
                    let outputSize = bufferSize - stream.dst_size
                    if outputSize > 0 {
                        decompressed.append(destinationBuffer, count: outputSize)
                    }
                    stream.dst_ptr = destinationBuffer
                    stream.dst_size = bufferSize
                case COMPRESSION_STATUS_END:
                    let outputSize = bufferSize - stream.dst_size
                    if outputSize > 0 {
                        decompressed.append(destinationBuffer, count: outputSize)
                    }
                    return
                default:
                    return
                }
            }
        }

        return decompressed.isEmpty ? nil : decompressed
    }
}
