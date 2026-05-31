// MARK: - CommitGraphView.swift

import Cocoa

enum GraphMetrics {
    static let rowHeight: CGFloat  = 28   // must equal NSTableView rowHeight
    static let laneWidth: CGFloat  = 18   // horizontal spacing between lanes
    static let dotRadius: CGFloat  = 4    // filled circle radius
    static let lineWidth: CGFloat  = 1.5  // stroke width
    static let leftPad: CGFloat    = 10   // padding before lane 0

    // X center of lane N
    static func laneX(_ lane: Int) -> CGFloat {
        leftPad + CGFloat(lane) * laneWidth + laneWidth / 2
    }
}

class CommitGraphView: NSView {
    
    static let laneColors: [NSColor] = [
        NSColor(red: 0x37/255.0, green: 0x8A/255.0, blue: 0xDD/255.0, alpha: 1.0), // #378ADD blue
        NSColor(red: 0x1D/255.0, green: 0x9E/255.0, blue: 0x75/255.0, alpha: 1.0), // #1D9E75 teal
        NSColor(red: 0x7F/255.0, green: 0x77/255.0, blue: 0xDD/255.0, alpha: 1.0), // #7F77DD purple
        NSColor(red: 0xD8/255.0, green: 0x5A/255.0, blue: 0x30/255.0, alpha: 1.0), // #D85A30 coral
        NSColor(red: 0xD4/255.0, green: 0x53/255.0, blue: 0x7E/255.0, alpha: 1.0), // #D4537E pink
        NSColor(red: 0x63/255.0, green: 0x99/255.0, blue: 0x22/255.0, alpha: 1.0), // #639922 green
        NSColor(red: 0xBA/255.0, green: 0x75/255.0, blue: 0x17/255.0, alpha: 1.0), // #BA7517 amber
        NSColor(red: 0x88/255.0, green: 0x87/255.0, blue: 0x80/255.0, alpha: 1.0)  // #888780 gray
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
        
        let midY = GraphMetrics.rowHeight / 2
        let topY: CGFloat = 0
        let botY = GraphMetrics.rowHeight
        
        // Draw all incoming edges (from topY to midY)
        for edge in incomingEdges {
            let fromLane = edge.fromLane
            let toLane = edge.toLane
            let color = CommitGraphView.laneColors[fromLane % CommitGraphView.laneColors.count]
            context.setStrokeColor(color.cgColor)
            
            let fromX = GraphMetrics.laneX(fromLane)
            let toX = GraphMetrics.laneX(toLane)
            
            context.beginPath()
            context.move(to: CGPoint(x: snap(fromX), y: snap(topY)))
            context.addLine(to: CGPoint(x: snap(toX), y: snap(midY)))
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
            context.move(to: CGPoint(x: snap(fromX), y: snap(midY)))
            context.addLine(to: CGPoint(x: snap(toX), y: snap(botY)))
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
        let cy = snap(GraphMetrics.rowHeight / 2)
        let r  = GraphMetrics.dotRadius

        // Knockout ring (hides lines behind dot) using background color instead of hardcoded white
        NSColor.controlBackgroundColor.setFill()
        let knockoutRect = NSRect(x: cx-r-1.5, y: cy-r-1.5, width: (r+1.5)*2, height: (r+1.5)*2)
        let knockoutPath = NSBezierPath(ovalIn: knockoutRect)
        knockoutPath.fill()
        
        // Colored fill
        color.setFill()
        let fillRect = NSRect(x: cx-r, y: cy-r, width: r*2, height: r*2)
        let fillPath = NSBezierPath(ovalIn: fillRect)
        fillPath.fill()
    }
}
