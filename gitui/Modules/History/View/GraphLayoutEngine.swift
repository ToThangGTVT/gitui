// MARK: - GraphLayoutEngine.swift

import Foundation

class GraphLayoutEngine {
    
    static let shared = GraphLayoutEngine()
    
    private init() {}
    
    func layout(commits: [CommitNode]) -> [CommitNode] {
        var processedCommits: [CommitNode] = []
        
        // Maps parentHash -> laneIndex
        var laneMap: [String: Int] = [:]
        
        // Set of active lane indices
        var activeLanes = Set<Int>()
        
        // High water mark for free lanes
        var nextFreeLane = 0
        
        for var commit in commits {
            let commitHash = commit.hash
            
            // 1. Assign or reuse lane
            let currentLane: Int
            if let assignedLane = laneMap[commitHash] {
                currentLane = assignedLane
                // Remove from laneMap as we've reached this commit
                laneMap.removeValue(forKey: commitHash)
            } else {
                // Find first free lane or use nextFreeLane
                var foundLane = nextFreeLane
                for l in 0..<nextFreeLane {
                    if !activeLanes.contains(l) {
                        foundLane = l
                        break
                    }
                }
                currentLane = foundLane
                if currentLane == nextFreeLane {
                    nextFreeLane += 1
                }
            }
            
            commit.laneIndex = currentLane
            activeLanes.insert(currentLane)
            
            // 2. Map parents to lanes
            var parentLanes: [Int] = []
            
            if !commit.parents.isEmpty {
                // First parent continues on the current lane if no other commit is waiting on it
                let firstParent = commit.parents[0]
                if laneMap[firstParent] == nil {
                    laneMap[firstParent] = currentLane
                    parentLanes.append(currentLane)
                } else if let existing = laneMap[firstParent] {
                    parentLanes.append(existing)
                }
                
                // Other parents get new free lanes (merges)
                for i in 1..<commit.parents.count {
                    let otherParent = commit.parents[i]
                    if let existing = laneMap[otherParent] {
                        parentLanes.append(existing)
                    } else {
                        var foundLane = nextFreeLane
                        for l in 0..<nextFreeLane {
                            if !activeLanes.contains(l) && l != currentLane {
                                foundLane = l
                                break
                            }
                        }
                        let newLane = foundLane
                        if newLane == nextFreeLane {
                            nextFreeLane += 1
                        }
                        laneMap[otherParent] = newLane
                        parentLanes.append(newLane)
                        activeLanes.insert(newLane)
                    }
                }
            }
            
            // 3. Build edges for this row
            var edges: [GraphEdge] = []
            
            // Draw lines for current commit to its parents
            for pLane in parentLanes {
                let type: EdgeType
                if pLane == currentLane {
                    type = .straight
                } else if pLane < currentLane {
                    type = .mergeIn
                } else {
                    type = .mergeOut
                }
                edges.append(GraphEdge(fromLane: currentLane, toLane: pLane, type: type))
            }
            
            // Draw continuation lines for all other active lanes that are not this commit
            for activeLane in activeLanes {
                if activeLane != currentLane {
                    // Only continue if there are parents registered in laneMap on this lane
                    if laneMap.values.contains(activeLane) {
                        edges.append(GraphEdge(fromLane: activeLane, toLane: activeLane, type: .straight))
                    }
                }
            }
            
            // 4. Free lanes that have no active references waiting for them
            var lanesStillWaiting = Set<Int>()
            for assignedLane in laneMap.values {
                lanesStillWaiting.insert(assignedLane)
            }
            
            activeLanes = activeLanes.intersection(lanesStillWaiting)
            
            commit.edges = edges
            processedCommits.append(commit)
        }
        
        return processedCommits
    }
}
