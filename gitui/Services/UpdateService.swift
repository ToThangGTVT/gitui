// MARK: - UpdateService.swift
// A service to check for updates from GitHub Releases.

import Foundation

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let htmlUrl: String
    let body: String
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlUrl = "html_url"
        case body
    }
}

class UpdateService {
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
}
