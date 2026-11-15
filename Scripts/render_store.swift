import AppKit
import Foundation

struct Listing: Decodable { let captions: [String]; let firstScreenshotDetail: String }
let base = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("AppStore")
let listings = try JSONDecoder().decode([String:Listing].self,from: Data(contentsOf: base.appendingPathComponent("listings.json")))
let size = CGSize(width:1290,height:2796)
let pages = ["01-break","02-limits","03-walk","04-rules"]
for (market, listing) in listings {
    let lang = ["en-US":"en","es-ES":"es","de-DE":"de","fr-FR":"fr"][market] ?? market
    for (index,page) in pages.enumerated() {
        let src = base.appendingPathComponent("Captures/\(lang)/\(page).png")
        guard let ui = NSImage(contentsOf:src) else { fatalError(src.path) }
        let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1290,pixelsHigh:2796,bitsPerSample:8,samplesPerPixel:3,hasAlpha:false,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:32)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:rep)
        let paper = NSColor(srgbRed:253.0/255,green:246.0/255,blue:230.0/255,alpha:1)
        let bg = [paper, NSColor(srgbRed:254.0/255,green:211.0/255,blue:54.0/255,alpha:1), paper, paper][index]
        bg.setFill(); NSBezierPath(rect:CGRect(origin:.zero,size:size)).fill()
        let ink = NSColor(red:0.105,green:0.103,blue:0.091,alpha:1)
        if index == 0 {
            // Optical alignment matters more here than matching the secondary cards' index.
            var top: CGFloat = 2716
            func drawLines(_ lines: [String], fontName: String, maximum: CGFloat) {
                var pointSize = maximum
                func attributes() -> [NSAttributedString.Key:Any] {
                    [.font: NSFont(name: fontName, size: pointSize) ?? NSFont.systemFont(ofSize: pointSize), .foregroundColor: ink]
                }
                while lines.contains(where: { ($0 as NSString).size(withAttributes: attributes()).width > 1140 }) {
                    pointSize -= 1
                }
                for line in lines {
                    let text = line as NSString
                    let height = ceil(text.size(withAttributes: attributes()).height)
                    text.draw(at: CGPoint(x: 74, y: top - height), withAttributes: attributes())
                    top -= height * 0.90
                }
            }
            drawLines(listing.captions[0].components(separatedBy: "\n"),
                      fontName: "AvenirNextCondensed-Heavy", maximum: 132)
            top -= 32
            drawLines([listing.firstScreenshotDetail], fontName: "AvenirNextCondensed-DemiBold", maximum: 59)
        } else {
            // A small index, then a benefit large enough to read in the store grid.
            let number = String(format:"%02d   /   04",index+1) as NSString
            number.draw(at:CGPoint(x:76,y:2630),withAttributes:[.font:NSFont.monospacedSystemFont(ofSize:31,weight:.semibold),.foregroundColor:ink])
            let rule = NSBezierPath(); rule.move(to:CGPoint(x:327,y:2648));rule.line(to:CGPoint(x:1214,y:2648));rule.lineWidth=3;ink.setStroke();rule.stroke()
            let heading = listing.captions[index] as NSString
            var fontSize: CGFloat = 126
            let style = NSMutableParagraphStyle();style.lineBreakMode = .byWordWrapping
            func attrs(_ s:CGFloat)->[NSAttributedString.Key:Any] {
                [.font:NSFont(name:"AvenirNextCondensed-Heavy",size:s) ?? NSFont.boldSystemFont(ofSize:s),.foregroundColor:ink,.paragraphStyle:style]
            }
            var box = heading.boundingRect(with:CGSize(width:1140,height:999),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:attrs(fontSize))
            while box.height>290 && fontSize>75 {
                fontSize -= 2
                box=heading.boundingRect(with:CGSize(width:1140,height:999),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:attrs(fontSize))
            }
            heading.draw(with:CGRect(x:74,y:2582-box.height,width:1142,height:box.height+3),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:attrs(fontSize))
        }
        let h: CGFloat = index == 0 ? 2188 : 2245
        let w = h * ui.size.width / ui.size.height
        let rect=CGRect(x:(1290-w)/2,y:34,width:w,height:h)
        let frame=NSBezierPath(roundedRect:rect,xRadius:79,yRadius:79)
        NSGraphicsContext.saveGraphicsState();frame.addClip()
        NSGraphicsContext.current?.imageInterpolation = .high
        ui.draw(in:rect,from:.zero,operation:.sourceOver,fraction:1)
        NSGraphicsContext.restoreGraphicsState()
        frame.lineWidth=5;ink.setStroke();frame.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let dest=base.appendingPathComponent("Screenshots/\(market)/\(page).png")
        try FileManager.default.createDirectory(at:dest.deletingLastPathComponent(),withIntermediateDirectories:true)
        try rep.representation(using:.png,properties:[:])!.write(to:dest)
    }
}
