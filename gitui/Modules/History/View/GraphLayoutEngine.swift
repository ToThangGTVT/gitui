// MARK: - GraphLayoutEngine.swift

import Foundation

class GraphLayoutEngine {
    
    static let shared = GraphLayoutEngine()
    
    private init() {}
    
    func layout(commits: [CommitNode]) -> [CommitNode] {
        var processedCommits: [CommitNode] = []
        
        // Maps parentHash -> [laneIndex] (all lanes that lead into this parent)
        var laneMap: [String: [Int]] = [:]
        
        // Active lanes from previous row
        var activeLanes = Set<Int>()
        var nextFreeLane = 0
        
        for var commit in commits {
            let commitHash = commit.hash
            
            // The lanes coming INTO this commit from the commits above
            let incomingFromAbove = laneMap[commitHash] ?? []
            laneMap.removeValue(forKey: commitHash)
            
            // 1. Assign laneIndex
            let currentLane: Int
            if !incomingFromAbove.isEmpty {
                // Take the lowest lane index as the main lane for this commit
                currentLane = incomingFromAbove.min()!
            } else {
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
            
            // 2. Build incoming edges (from topY to midY)
            var incomingEdges: [GraphEdge] = []
            
            // For passing lanes (must not be converging into currentLane)
            for activeLane in activeLanes {
                if activeLane != currentLane && !incomingFromAbove.contains(activeLane) {
                    incomingEdges.append(GraphEdge(fromLane: activeLane, toLane: activeLane, type: .straight))
                }
            }
            // For lanes converging into this commit
            for incLane in incomingFromAbove {
                let type: EdgeType = (incLane == currentLane) ? .straight : (incLane < currentLane ? .mergeIn : .mergeOut)
                incomingEdges.append(GraphEdge(fromLane: incLane, toLane: currentLane, type: type))
                // Free the other lanes that merged into currentLane
                if incLane != currentLane {
                    activeLanes.remove(incLane)
                }
            }
            
            // Snapshot active lanes before adding new ones for parents
            let oldActiveLanes = activeLanes
            
            // 3. Map parents and build outgoing edges
            var outgoingEdges: [GraphEdge] = []
            var usedCurrentLane = false
            
            for i in 0..<commit.parents.count {
                let parentHash = commit.parents[i]
                
                let targetLane: Int
                if let existingLanes = laneMap[parentHash], let firstExisting = existingLanes.min() {
                    // Reuse the lowest existing lane for this parent
                    targetLane = firstExisting
                } else if !usedCurrentLane {
                    // First unmapped parent gets the current lane
                    targetLane = currentLane
                    usedCurrentLane = true
                } else {
                    // Subsequent unmapped parents get a new lane
                    var foundLane = nextFreeLane
                    for l in 0..<nextFreeLane {
                        if !activeLanes.contains(l) && l != currentLane {
                            foundLane = l
                            break
                        }
                    }
                    targetLane = foundLane
                    if targetLane == nextFreeLane {
                        nextFreeLane += 1
                    }
                }
                
                var plMap = laneMap[parentHash] ?? []
                if !plMap.contains(targetLane) {
                    plMap.append(targetLane)
                }
                laneMap[parentHash] = plMap
                activeLanes.insert(targetLane)
                
                let type: EdgeType = (targetLane == currentLane) ? .straight : (targetLane < currentLane ? .mergeIn : .mergeOut)
                let newEdge = GraphEdge(fromLane: currentLane, toLane: targetLane, type: type)
                if !outgoingEdges.contains(newEdge) {
                    outgoingEdges.append(newEdge)
                }
            }
            
            // For passing lanes (from midY to botY)
            // Only draw passing straight lines for lanes that were ALREADY active
            for activeLane in oldActiveLanes {
                if activeLane != currentLane {
                    outgoingEdges.append(GraphEdge(fromLane: activeLane, toLane: activeLane, type: .straight))
                }
            }
            
            // Clean up dangling active lanes that have no parents waiting for them
            var lanesStillWaiting = Set<Int>()
            for assignedLanes in laneMap.values {
                lanesStillWaiting.formUnion(assignedLanes)
            }
            activeLanes = activeLanes.intersection(lanesStillWaiting)
            
            commit.incomingEdges = incomingEdges
            commit.outgoingEdges = outgoingEdges
            processedCommits.append(commit)
        }
        
        return processedCommits
    }
}
