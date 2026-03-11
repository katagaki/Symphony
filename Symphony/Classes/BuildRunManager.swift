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

            // Find the log artifact
            if let logArtifact = actionArtifacts.first(where: {
                $0.attributes.fileName?.hasSuffix(".log") == true
                    || $0.attributes.fileName?.hasSuffix(".log.gz") == true
                    || $0.attributes.fileName?.contains("log") == true
            }),
               let urlString = logArtifact.attributes.downloadUrl,
               let url = URL(string: urlString) {
                let data = try await api.downloadArtifact(url: url)

                // Try UTF-8 first, then try decompressing as gzip
                if let text = String(data: data, encoding: .utf8) {
                    logText = text
                } else if let decompressed = Self.decompressGzip(data: data),
                          let text = String(data: decompressed, encoding: .utf8) {
                    logText = text
                } else {
                    // Try latin1 as last resort
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

    private static func decompressGzip(data: Data) -> Data? {
        // Check for gzip magic number
        guard data.count >= 2, data[data.startIndex] == 0x1f, data[data.startIndex + 1] == 0x8b else {
            return nil
        }

        let bufferSize = 65536
        var decompressed = Data()

        let result: Data? = data.withUnsafeBytes { rawBuffer -> Data? in
            guard let sourcePointer = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return nil
            }

            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { destinationBuffer.deallocate() }

            let stream = compression_stream_init(COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
            guard stream == COMPRESSION_STATUS_OK else { return nil }

            var compressionStream = compression_stream()
            let initStatus = compression_stream_init(&compressionStream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
            guard initStatus == COMPRESSION_STATUS_OK else { return nil }
            defer { compression_stream_destroy(&compressionStream) }

            // Skip gzip header (minimum 10 bytes)
            let headerSize = 10
            guard data.count > headerSize else { return nil }

            compressionStream.src_ptr = sourcePointer.advanced(by: headerSize)
            compressionStream.src_size = data.count - headerSize
            compressionStream.dst_ptr = destinationBuffer
            compressionStream.dst_size = bufferSize

            while true {
                let status = compression_stream_process(&compressionStream, 0)

                switch status {
                case COMPRESSION_STATUS_OK:
                    let outputSize = bufferSize - compressionStream.dst_size
                    if outputSize > 0 {
                        decompressed.append(destinationBuffer, count: outputSize)
                    }
                    compressionStream.dst_ptr = destinationBuffer
                    compressionStream.dst_size = bufferSize
                case COMPRESSION_STATUS_END:
                    let outputSize = bufferSize - compressionStream.dst_size
                    if outputSize > 0 {
                        decompressed.append(destinationBuffer, count: outputSize)
                    }
                    return decompressed
                default:
                    return nil
                }
            }
        }

        return result
    }
}
