// MARK: - HistoryInteractor.swift

import Foundation

protocol HistoryInteractorInputProtocol: AnyObject {
    func loadHistory(repoPath: String, limit: Int)
    func checkout(repoPath: String, hash: String)
    func createBranch(repoPath: String, hash: String, name: String)
    func createTag(repoPath: String, hash: String, name: String, message: String)
    func cherryPick(repoPath: String, hash: String)
    func revert(repoPath: String, hash: String)
    func reset(repoPath: String, hash: String, mode: ResetMode)
}

protocol HistoryInteractorOutputProtocol: AnyObject {
    func didLoadHistory(_ commits: [CommitNode])
    func didOperationSuccess(message: String)
    func didOperationError(_ error: Error)
}

class HistoryInteractor: HistoryInteractorInputProtocol {
    
    weak var presenter: HistoryInteractorOutputProtocol?
    
    func loadHistory(repoPath: String, limit: Int) {
        DispatchQueue.global(qos: .userInitiated).async {
            Task {
                do {
                    // Fetch git log in format: hash|parents|authorName|authorEmail|authorDate|refs|subject
                    let format = "%H|%P|%an|%ae|%ai|%D|%s"
                    let output = try await GitService.shared.runGit(["log", "--all", "--pretty=format:\(format)", "-n", "\(limit)"], in: repoPath)
                    
                    var commits: [CommitNode] = []
                    let lines = output.components(separatedBy: .newlines)
                    
                    let dateFieldFormatter = DateFormatter()
                    dateFieldFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                    
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { continue }
                        
                        let fields = trimmed.components(separatedBy: "|")
                        guard fields.count >= 7 else { continue }
                        
                        let hash = fields[0].trimmingCharacters(in: .whitespaces)
                        let shortHash = String(hash.prefix(7))
                        let parents = fields[1].components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        let author = fields[2].trimmingCharacters(in: .whitespaces)
                        
                        let dateString = fields[4].trimmingCharacters(in: .whitespaces)
                        let date = dateFieldFormatter.date(from: dateString) ?? Date()
                        
                        let refString = fields[5].trimmingCharacters(in: .whitespaces)
                        let refs = self.parseRefs(refString)
                        
                        // Handle potential multiple pipes inside subject line
                        let message = fields[6...].joined(separator: "|").trimmingCharacters(in: .whitespaces)
                        
                        commits.append(CommitNode(
                            hash: hash,
                            shortHash: shortHash,
                            message: message,
                            author: author,
                            date: date,
                            parents: parents,
                            refs: refs,
                            laneIndex: 0,
                            edges: []
                        ))
                    }
                    
                    // Apply graph layout calculations!
                    let laidOutCommits = GraphLayoutEngine.shared.layout(commits: commits)
                    
                    await MainActor.run {
                        self.presenter?.didLoadHistory(laidOutCommits)
                    }
                } catch {
                    await MainActor.run {
                        self.presenter?.didOperationError(error)
                    }
                }
            }
        }
    }
    
    func checkout(repoPath: String, hash: String) {
        Task {
            do {
                _ = try await GitService.shared.runGit(["checkout", hash], in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Checked out commit \(hash) (Detached HEAD)")
                }
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func createBranch(repoPath: String, hash: String, name: String) {
        Task {
            do {
                _ = try await GitService.shared.runGit(["branch", name, hash], in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Successfully created branch '\(name)' at \(hash).")
                }
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func createTag(repoPath: String, hash: String, name: String, message: String) {
        Task {
            do {
                var args = ["tag", "-a", name, hash]
                if !message.isEmpty {
                    args.append("-m")
                    args.append(message)
                }
                _ = try await GitService.shared.runGit(args, in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Successfully created tag '\(name)' at \(hash).")
                }
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func cherryPick(repoPath: String, hash: String) {
        Task {
            do {
                try await GitService.shared.cherryPick(hash: hash, in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Successfully cherry-picked commit \(hash)")
                }
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func revert(repoPath: String, hash: String) {
        Task {
            do {
                try await GitService.shared.revert(hash: hash, in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Successfully reverted commit \(hash)")
                }
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    func reset(repoPath: String, hash: String, mode: ResetMode) {
        Task {
            do {
                _ = try await GitService.shared.runGit(["reset", mode.rawValue, hash], in: repoPath)
                await MainActor.run {
                    self.presenter?.didOperationSuccess(message: "Successfully reset current branch to \(hash) (\(mode.rawValue.replacingOccurrences(of: "--", with: "")) mode).")
                }
            } catch {
                await MainActor.run {
                    self.presenter?.didOperationError(error)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func parseRefs(_ refsText: String) -> [GitRef] {
        var refs: [GitRef] = []
        guard !refsText.isEmpty else { return refs }
        
        // Example: HEAD -> main, origin/main, tag: v1.0
        let parts = refsText.components(separatedBy: ",")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            if trimmed.hasPrefix("HEAD ->") {
                refs.append(.head)
                let localBranch = trimmed.replacingOccurrences(of: "HEAD ->", with: "").trimmingCharacters(in: .whitespaces)
                if !localBranch.isEmpty {
                    refs.append(.localBranch(localBranch))
                }
            } else if trimmed == "HEAD" {
                refs.append(.head)
            } else if trimmed.hasPrefix("tag:") {
                let tagName = trimmed.replacingOccurrences(of: "tag:", with: "").trimmingCharacters(in: .whitespaces)
                if !tagName.isEmpty {
                    refs.append(.tag(tagName))
                }
            } else if trimmed.contains("/") {
                refs.append(.remoteBranch(trimmed))
            } else {
                refs.append(.localBranch(trimmed))
            }
        }
        
        return refs
    }
}
