// MARK: - CommitGraphView.swift

import Cocoa

enum GraphMetrics {
    static let rowHeight: CGFloat  = 38   // must equal NSTableView rowHeight
    static let laneWidth: CGFloat  = 11   // horizontal spacing between lanes
    static let dotRadius: CGFloat  = 4    // filled circle radius
    static let lineWidth: CGFloat  = 2.0  // stroke width
    static let leftPad: CGFloat    = 10   // padding before lane 0

    // X center of lane N
    static func laneX(_ lane: Int) -> CGFloat {
        leftPad + CGFloat(lane) * laneWidth + laneWidth / 2
    }
}

class CommitGraphView: NSView {
    
    static let laneColors: [NSColor] = [
        NSColor(red: 0x1F/255.0, green: 0x75/255.0, blue: 0xCB/255.0, alpha: 1.0), // #1F75CB darker blue
        NSColor(red: 0x14/255.0, green: 0x80/255.0, blue: 0x5E/255.0, alpha: 1.0), // #14805E darker teal
        NSColor(red: 0x6A/255.0, green: 0x5A/255.0, blue: 0xCD/255.0, alpha: 1.0), // #6A5ACD darker purple
        NSColor(red: 0xC8/255.0, green: 0x46/255.0, blue: 0x1B/255.0, alpha: 1.0), // #C8461B darker coral
        NSColor(red: 0xC2/255.0, green: 0x33/255.0, blue: 0x64/255.0, alpha: 1.0), // #C23364 darker pink
        NSColor(red: 0x4D/255.0, green: 0x7F/255.0, blue: 0x16/255.0, alpha: 1.0), // #4D7F16 darker green
        NSColor(red: 0xA6/255.0, green: 0x65/255.0, blue: 0x0D/255.0, alpha: 1.0), // #A6650D darker amber
        NSColor(red: 0x6A/255.0, green: 0x6A/255.0, blue: 0x6A/255.0, alpha: 1.0)  // #6A6A6A darker gray
    ]
    
    var laneIndex: Int = -1
    var incomingEdges: [GraphEdge] = []
    var outgoingEdges: [GraphEdge] = []
    
    var laneCount: Int = 1 {
        didSet {
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    override var intrinsicContentSize: NSSize {
        let w = GraphMetrics.leftPad
                 + CGFloat(laneCount) * GraphMetrics.laneWidth
                 + GraphMetrics.leftPad
        return NSSize(width: w, height: NSView.noIntrinsicMetric)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let scale = window?.backingScaleFactor ?? 2.0
        
        // Align to pixel grid: snap coordinates to 0.5/scale
        func snap(_ v: CGFloat) -> CGFloat {
            return (v * scale).rounded() / scale
        }
        
        // 1. Configure context for smooth lines
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        context.setLineWidth(GraphMetrics.lineWidth)
        context.setLineCap(.round)
        
        let midY = bounds.height / 2
        let topY: CGFloat = 0
        let botY = bounds.height
        
        // Draw all incoming edges (from topY to midY)
        for edge in incomingEdges {
            let fromLane = edge.fromLane
            let toLane = edge.toLane
            let color = CommitGraphView.laneColors[fromLane % CommitGraphView.laneColors.count]
            context.setStrokeColor(color.cgColor)
            
            let fromX = GraphMetrics.laneX(fromLane)
            let toX = GraphMetrics.laneX(toLane)
            
            context.beginPath()
            let start = CGPoint(x: snap(fromX), y: snap(topY))
            let end = CGPoint(x: snap(toX), y: snap(midY))
            context.move(to: start)
            
            if fromX == toX {
                context.addLine(to: end)
            } else {
                let cp1 = CGPoint(x: start.x, y: start.y + (end.y - start.y) * 0.6)
                let cp2 = CGPoint(x: end.x, y: end.y - (end.y - start.y) * 0.6)
                context.addCurve(to: end, control1: cp1, control2: cp2)
            }
            context.strokePath()
        }
        
        // Draw all outgoing edges (from midY to botY)
        for edge in outgoingEdges {
            let fromLane = edge.fromLane
            let toLane = edge.toLane
            // Use fromLane color for outgoing branches so branch color originates from parent
            let color = CommitGraphView.laneColors[toLane % CommitGraphView.laneColors.count]
            context.setStrokeColor(color.cgColor)
            
            let fromX = GraphMetrics.laneX(fromLane)
            let toX = GraphMetrics.laneX(toLane)
            
            context.beginPath()
            let start = CGPoint(x: snap(fromX), y: snap(midY))
            let end = CGPoint(x: snap(toX), y: snap(botY))
            context.move(to: start)
            
            if fromX == toX {
                context.addLine(to: end)
            } else {
                let cp1 = CGPoint(x: start.x, y: start.y + (end.y - start.y) * 0.6)
                let cp2 = CGPoint(x: end.x, y: end.y - (end.y - start.y) * 0.6)
                context.addCurve(to: end, control1: cp1, control2: cp2)
            }
            context.strokePath()
        }
        
        // Step 2 — draw the dot on top of all lines
        if laneIndex >= 0 {
            let color = CommitGraphView.laneColors[laneIndex % CommitGraphView.laneColors.count]
            drawDot(lane: laneIndex, color: color, ctx: context, snap: snap)
        }
    }
    
    private func drawDot(lane: Int, color: NSColor, ctx: CGContext, snap: (CGFloat) -> CGFloat) {
        let cx = snap(GraphMetrics.laneX(lane))
        let cy = snap(bounds.height / 2)
        let r  = GraphMetrics.dotRadius

        // Colored fill
        color.setFill()
        let fillRect = NSRect(x: cx-r, y: cy-r, width: r*2, height: r*2)
        let fillPath = NSBezierPath(ovalIn: fillRect)
        fillPath.fill()
    }
}
