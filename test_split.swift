import Foundation

let total: CGFloat = 500
let divT: CGFloat = 1

let stagedMin: CGFloat = 80
let unstagedMin: CGFloat = 80
let commitMin: CGFloat = 100

var pos0 = (total * 0.35).rounded()
var pos1 = (total * 0.70).rounded()

print("Initial: pos0=\(pos0), pos1=\(pos1)")

pos0 = max(pos0, stagedMin)
pos0 = min(pos0, total - unstagedMin - commitMin - divT * 2)

pos1 = max(pos1, pos0 + divT + unstagedMin)
pos1 = min(pos1, total - commitMin - divT)

print("Clamped: pos0=\(pos0), pos1=\(pos1)")

