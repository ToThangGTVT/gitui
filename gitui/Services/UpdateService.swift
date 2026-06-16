// MARK: - UpdateService.swift
// A service to check for updates from GitHub Releases.

import Foundation

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let htmlUrl: String
    let body: String
    let assets: [GitHubReleaseAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlUrl = "html_url"
        case body
        case assets
    }
}

struct GitHubReleaseAsset: Codable {
    let name: String
    let contentType: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case contentType = "content_type"
        case browserDownloadURL = "browser_download_url"
    }
}

struct PreparedUpdate {
    let workingDirectoryURL: URL
    let extractedAppURL: URL
    let targetAppURL: URL
    let bundleIdentifier: String
}

enum UpdateError: LocalizedError {
    case noDownloadableAsset
    case invalidAssetURL
    case appTranslocated
    case extractedAppNotFound
    case unsupportedBundleLocation
    case installLaunchFailed(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .noDownloadableAsset:
            return "No downloadable app archive was found in the latest GitHub release."
        case .invalidAssetURL:
            return "The update archive URL is invalid."
        case .appTranslocated:
            return "gitui is running from a translocated location. Move the app to /Applications or another normal folder before using auto-update."
        case .extractedAppNotFound:
            return "The downloaded update did not contain a macOS app bundle."
        case .unsupportedBundleLocation:
            return "gitui is not running from a writable .app bundle location, so auto-update cannot replace it safely."
        case .installLaunchFailed(let reason):
            return reason
        case .commandFailed(let output):
            return output
        }
    }
}

final class UpdateService {
    static let shared = UpdateService()
    
    private let repoOwner = "ToThangGTVT"
    private let repoName = "gitui"
    
    private init() {}
    
    /// Fetches the latest release info from the GitHub Releases API.
    func getLatestRelease() async throws -> GitHubRelease {
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        // GitHub API requires a User-Agent header, otherwise it rejects with a 403.
        request.setValue("gitui-update-checker", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            // Can be 404 if no release exists yet, or 403 for rate limits
            throw NSError(domain: "UpdateService", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Failed to fetch update from GitHub (HTTP \(httpResponse.statusCode))."
            ])
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(GitHubRelease.self, from: data)
    }
    
    /// Retrieves the current application version.
    func getCurrentVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "1.0.0"
    }
    
    /// Safely compares two version strings (semver).
    /// Handles forms like "1.0", "v1.2.3", "10.0.1", etc.
    func isNewerVersion(current: String, latest: String) -> Bool {
        let cleanCurrent = current.trimmingCharacters(in: CharacterSet(charactersIn: "vV ")).split(separator: ".").compactMap { Int($0) }
        let cleanLatest = latest.trimmingCharacters(in: CharacterSet(charactersIn: "vV ")).split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(cleanCurrent.count, cleanLatest.count) {
            let currPart = i < cleanCurrent.count ? cleanCurrent[i] : 0
            let latePart = i < cleanLatest.count ? cleanLatest[i] : 0
            
            if latePart > currPart {
                return true
            } else if currPart > latePart {
                return false
            }
        }
        return false
    }

    func prepareUpdate(for release: GitHubRelease) async throws -> PreparedUpdate {
        let targetAppURL = try currentAppBundleURL()
        let asset = try preferredAsset(for: release)

        guard let assetURL = URL(string: asset.browserDownloadURL) else {
            throw UpdateError.invalidAssetURL
        }

        let fileManager = FileManager.default
        let workingDirectoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("gitui-update-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: workingDirectoryURL, withIntermediateDirectories: true)

        let archiveURL = workingDirectoryURL.appendingPathComponent(asset.name)
        let extractedDirectoryURL = workingDirectoryURL.appendingPathComponent("extracted", isDirectory: true)
        try fileManager.createDirectory(at: extractedDirectoryURL, withIntermediateDirectories: true)

        var request = URLRequest(url: assetURL)
        request.setValue("gitui-auto-updater", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 60.0

        let (downloadedURL, response) = try await URLSession.shared.download(for: request)
        try validateDownloadResponse(response)
        try fileManager.moveItem(at: downloadedURL, to: archiveURL)

        try runCommand(
            executableURL: URL(fileURLWithPath: "/usr/bin/ditto"),
            arguments: ["-x", "-k", archiveURL.path, extractedDirectoryURL.path]
        )

        let extractedAppURL = try locateExtractedApp(in: extractedDirectoryURL)
        return PreparedUpdate(
            workingDirectoryURL: workingDirectoryURL,
            extractedAppURL: extractedAppURL,
            targetAppURL: targetAppURL,
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "\(repoOwner).\(repoName)"
        )
    }

    func installPreparedUpdate(_ preparedUpdate: PreparedUpdate) throws {
        let fileManager = FileManager.default
        let scriptURL = preparedUpdate.workingDirectoryURL.appendingPathComponent("install-update.sh")
        let script = """
        #!/bin/sh
        set -eu

        TARGET_APP="$1"
        SOURCE_APP="$2"
        WORK_DIR="$3"
        APP_PID="$4"
        BUNDLE_ID="$5"

        request_quit() {
          osascript -e "tell application id \\"$BUNDLE_ID\\" to quit" >/dev/null 2>&1 || true
        }

        wait_for_exit() {
          ATTEMPTS="$1"
          COUNT=0
          while kill -0 "$APP_PID" 2>/dev/null; do
            COUNT=$((COUNT + 1))
            if [ "$COUNT" -ge "$ATTEMPTS" ]; then
              return 1
            fi
            sleep 1
          done
          return 0
        }

        request_quit
        if ! wait_for_exit 15; then
          kill "$APP_PID" >/dev/null 2>&1 || true
        fi
        if ! wait_for_exit 10; then
          kill -9 "$APP_PID" >/dev/null 2>&1 || true
        fi
        wait_for_exit 5 || true

        TARGET_DIR=$(dirname "$TARGET_APP")
        TARGET_NAME=$(basename "$TARGET_APP")
        STAGED_APP="$TARGET_DIR/$TARGET_NAME.update"
        BACKUP_APP="$TARGET_DIR/$TARGET_NAME.backup"

        cleanup() {
          rm -rf "$STAGED_APP"
          rm -rf "$WORK_DIR"
        }

        restore_backup() {
          if [ -d "$BACKUP_APP" ] && [ ! -d "$TARGET_APP" ]; then
            mv "$BACKUP_APP" "$TARGET_APP"
          fi
          cleanup
        }

        trap restore_backup EXIT HUP INT TERM

        rm -rf "$STAGED_APP"
        rm -rf "$BACKUP_APP"
        ditto "$SOURCE_APP" "$STAGED_APP"

        if [ -d "$TARGET_APP" ]; then
          mv "$TARGET_APP" "$BACKUP_APP"
        fi

        mv "$STAGED_APP" "$TARGET_APP"
        rm -rf "$BACKUP_APP"
        xattr -dr com.apple.quarantine "$TARGET_APP" >/dev/null 2>&1 || true

        trap - EXIT HUP INT TERM
        cleanup
        open -n "$TARGET_APP"
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let logURL = preparedUpdate.workingDirectoryURL.appendingPathComponent("install-update.log")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "nohup \"$1\" \"$2\" \"$3\" \"$4\" \"$5\" \"$6\" >\"$7\" 2>&1 &",
            "install-update-launcher",
            scriptURL.path,
            preparedUpdate.targetAppURL.path,
            preparedUpdate.extractedAppURL.path,
            preparedUpdate.workingDirectoryURL.path,
            String(ProcessInfo.processInfo.processIdentifier),
            preparedUpdate.bundleIdentifier,
            logURL.path
        ]

        let stderrPipe = Pipe()
        process.standardOutput = nil
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            let errorOutput = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let reason = errorOutput?.isEmpty == false ? errorOutput! : error.localizedDescription
            throw UpdateError.installLaunchFailed("Failed to start the installer: \(reason)")
        }
    }

    private func preferredAsset(for release: GitHubRelease) throws -> GitHubReleaseAsset {
        if let appZip = release.assets.first(where: {
            $0.name.lowercased().hasSuffix(".zip") &&
            ($0.name.lowercased().contains("gitui") || $0.contentType == "application/zip")
        }) {
            return appZip
        }

        throw UpdateError.noDownloadableAsset
    }

    private func currentAppBundleURL() throws -> URL {
        let bundleURL = Bundle.main.bundleURL.standardizedFileURL

        guard bundleURL.pathExtension == "app" else {
            throw UpdateError.unsupportedBundleLocation
        }

        guard !bundleURL.path.contains("/AppTranslocation/") else {
            throw UpdateError.appTranslocated
        }

        return bundleURL
    }

    private func locateExtractedApp(in directoryURL: URL) throws -> URL {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            throw UpdateError.extractedAppNotFound
        }

        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "app" {
                return fileURL
            }
        }

        throw UpdateError.extractedAppNotFound
    }

    private func validateDownloadResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "UpdateService", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Failed to download update archive (HTTP \(httpResponse.statusCode))."
            ])
        }
    }

    private func runCommand(executableURL: URL, arguments: [String]) throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw UpdateError.commandFailed(output?.isEmpty == false ? output! : "A required update command failed.")
        }
    }
}
