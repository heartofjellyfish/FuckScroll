import AppKit
let paper = NSColor(srgbRed:253/255,green:246/255,blue:230/255,alpha:1)
let ink = NSColor(srgbRed:24/255,green:24/255,blue:21/255,alpha:1)
let yellow = NSColor(srgbRed:254/255,green:211/255,blue:54/255,alpha:1)
let muted = NSColor(srgbRed:0.42,green:0.40,blue:0.35,alpha:1)
let duck = NSImage(contentsOfFile:"ScrollStopper/Resources/Assets.xcassets/GroundRulesDuck.imageset/duck.png")!
let output="Design/GroundRules-Proposals"
func font(_ n:String,_ s:CGFloat)->NSFont {NSFont(name:n,size:s) ?? .boldSystemFont(ofSize:s)}
func rect(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ c:NSColor,_ r:CGFloat=0){c.setFill();NSBezierPath(roundedRect:NSRect(x:x,y:y,width:w,height:h),xRadius:r,yRadius:r).fill()}
func text(_ s:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat,_ face:String="AvenirNextCondensed-Heavy",_ c:NSColor=ink,_ width:CGFloat=360,_ alignment:NSTextAlignment = .left){
 let p=NSMutableParagraphStyle();p.alignment=alignment;p.lineSpacing=0;p.lineBreakMode = .byWordWrapping
 (s as NSString).draw(in:NSRect(x:x,y:y,width:width,height:220),withAttributes:[.font:font(face,size),.foregroundColor:c,.paragraphStyle:p])
}
func line(_ x:CGFloat,_ y:CGFloat,_ end:CGFloat,_ thick:CGFloat=1.4,_ c:NSColor=ink,_ v:Int=0){
 c.setStroke();let p=NSBezierPath();p.move(to:NSPoint(x:x,y:y));p.curve(to:NSPoint(x:end,y:y+CGFloat(v%2)*0.3),controlPoint1:NSPoint(x:x+(end-x)*0.34,y:y-0.35),controlPoint2:NSPoint(x:x+(end-x)*0.72,y:y+0.2));p.lineWidth=thick;p.lineCapStyle = .round;p.stroke()
}
func chevron(_ x:CGFloat,_ y:CGFloat){ink.setStroke();let p=NSBezierPath();p.move(to:NSPoint(x:x,y:y-4));p.line(to:NSPoint(x:x+4.5,y:y));p.line(to:NSPoint(x:x,y:y+4));p.lineWidth=2.3;p.lineCapStyle = .round;p.lineJoinStyle = .round;p.stroke()}
func toggle(_ x:CGFloat,_ y:CGFloat){rect(x,y,51,30,NSColor(srgbRed:0.19,green:0.78,blue:0.34,alpha:1),15);rect(x+23,y+3,25,24,.white,12)}
func art(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat){duck.draw(in:NSRect(x:x,y:y,width:w,height:w*567/850),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)}
func base(){
 rect(0,0,393,852,NSColor(srgbRed:0.81,green:0.79,blue:0.73,alpha:1))
 rect(0,62,393,820,paper,29)
 for i in 0..<1800 {let x=CGFloat((i*7919)%10007)/10007*393;let y=CGFloat((i*3571)%10009)/10009*790+62;rect(x,y,0.35,0.35,ink.withAlphaComponent(0.025))}
 text("6:27",31,14,17,"AvenirNextCondensed-DemiBold")
 for i in 0..<4{rect(287+CGFloat(i)*4,26-CGFloat(i)*2,2.5,4+CGFloat(i)*2,ink,0.7)}
 let wifi=NSBezierPath();wifi.move(to:NSPoint(x:309,y:20));wifi.curve(to:NSPoint(x:325,y:20),controlPoint1:NSPoint(x:313,y:16),controlPoint2:NSPoint(x:321,y:16));wifi.move(to:NSPoint(x:312,y:23));wifi.curve(to:NSPoint(x:322,y:23),controlPoint1:NSPoint(x:315,y:20),controlPoint2:NSPoint(x:319,y:20));wifi.lineWidth=1.8;ink.setStroke();wifi.stroke();rect(316,25,2,2,ink,1)
 let batt=NSBezierPath(roundedRect:NSRect(x:334,y:18,width:23,height:12),xRadius:3,yRadius:3);batt.lineWidth=1;ink.setStroke();batt.stroke();rect(336,20,19,8,ink,1.5);rect(358,21,2,6,ink,1)
 let cross=NSBezierPath();cross.move(to:NSPoint(x:353,y:85));cross.line(to:NSPoint(x:365,y:97));cross.move(to:NSPoint(x:365,y:85));cross.line(to:NSPoint(x:353,y:97));cross.lineWidth=3.4;cross.lineCapStyle = .round;ink.setStroke();cross.stroke()
 rect(145,836,103,4,ink.withAlphaComponent(0.18),2)
}
func row(_ title:String,_ y:CGFloat,_ duty:Bool=false,_ language:Bool=false,_ n:String?=nil,_ left:CGFloat=27,_ rule:Bool=true){
 if let n {text(n,left,y+18,13,"AvenirNextCondensed-DemiBold",muted,23)}
 let tx=left+(n == nil ? 0:35)
 text(title,tx,y+13,23,"AvenirNextCondensed-Heavy",ink,280)
 if duty {toggle(315,y+15)} else {if language{text("English",279,y+20,14,"AvenirNextCondensed-DemiBold",muted,65)};chevron(361,y+31)}
 if rule{line(left,y+62,366,1.15,ink,Int(y))}
}
func export(_ name:String,_ render:()->Void){
 let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:786,pixelsHigh:1704,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 let ctx=NSGraphicsContext(bitmapImageRep:rep)!
 ctx.cgContext.translateBy(x:0,y:1704);ctx.cgContext.scaleBy(x:2,y:-2)
 NSGraphicsContext.current=NSGraphicsContext(cgContext:ctx.cgContext,flipped:true)
 render();try! rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"\(output)/\(name).png"))
}
export("A-editorial"){
 base()
 text("GROUND\nRULES.",26,156,47,"AvenirNextCondensed-Heavy",ink,184)
 art(191,137,202)
 line(0,292,393,2.1)
 row("Duck on duty",311,true)
 row("How it works",374)
 row("Edit break screen",437)
 row("Language",500,false,true,nil,27,false)
 // Editorial colophon: one short thought, not another setting.
 text("YOUR TIME.\nYOUR CALL.",27,632,43,"AvenirNextCondensed-Heavy",ink,328)
 line(29,744,223,8,yellow)
 text("The feed can wait.",27,761,17,"Noteworthy-Bold",muted,320)
}
export("B-manifesto"){
 base()
 text("GROUND RULES.",27,116,40,"AvenirNextCondensed-Heavy",ink,335)
 text("YOU’RE A PERSON.",27,178,32,"AvenirNextCondensed-Heavy",ink,340)
 rect(25,220,319,39,yellow)
 text("NOT A SCROLLBAR.",29,217,32,"AvenirNextCondensed-Heavy",ink,340)
 art(49,278,315)
 row("Duck on duty",505,true)
 row("How it works",568)
 row("Edit break screen",631)
 row("Language",694,false,true,nil,27,false)
 text("The internet will survive.",27,788,16,"Noteworthy-Bold",muted,340)
}
export("C-gallery"){
 base()
 yellow.setFill();NSBezierPath(ovalIn:NSRect(x:231,y:123,width:193,height:193)).fill()
 text("GROUND\nRULES.",26,153,50,"AvenirNextCondensed-Heavy",ink,186)
 art(185,151,211)
 line(26,322,366,1.5)
 // A catalogued agreement, with one yellow control and a quiet index.
 rect(25,345,343,68,yellow,3)
 row("Duck on duty",347,true,false,"01",27,false)
 row("How it works",435,false,false,"02")
 row("Edit break screen",498,false,false,"03")
 row("Language",561,false,true,"04",27,false)
 rect(27,671,4,94,yellow)
 text("MY PHONE.\nMY TERMS.",44,654,39,"AvenirNextCondensed-Heavy",ink,310)
 text("Signed, the duck.",45,765,16,"Noteworthy-Bold",muted,310)
}
