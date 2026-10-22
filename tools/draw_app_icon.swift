// Coconut: original flat two-dimensional icon. SVG source in docs/icon-review.
import AppKit
let n=1024
let ctx=CGContext(data:nil,width:n,height:n,bitsPerComponent:8,bytesPerRow:n*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ r:CGFloat,_ g:CGFloat,_ b:CGFloat)->CGColor { CGColor(red:r/255,green:g/255,blue:b/255,alpha:1) }
ctx.setFillColor(color(238,233,222));ctx.fill(CGRect(x:0,y:0,width:n,height:n))
ctx.translateBy(x:0,y:1024);ctx.scaleBy(x:1,y:-1);ctx.translateBy(x:512,y:512);ctx.rotate(by:-18 * .pi/180);ctx.translateBy(x:-512,y:-512)
let shell=CGMutablePath();shell.move(to:CGPoint(x:222,y:437));shell.addCurve(to:CGPoint(x:512,y:790),control1:CGPoint(x:222,y:640),control2:CGPoint(x:325,y:790));shell.addCurve(to:CGPoint(x:802,y:437),control1:CGPoint(x:699,y:790),control2:CGPoint(x:802,y:640));shell.closeSubpath();ctx.setFillColor(color(73,49,39));ctx.addPath(shell);ctx.fillPath()
ctx.setStrokeColor(color(140,103,80));ctx.setLineWidth(20);ctx.setLineCap(.round)
let marks=CGMutablePath();marks.move(to:CGPoint(x:270,y:537));marks.addCurve(to:CGPoint(x:431,y:738),control1:CGPoint(x:294,y:650),control2:CGPoint(x:358,y:715));marks.move(to:CGPoint(x:676,y:656));marks.addCurve(to:CGPoint(x:731,y:541),control1:CGPoint(x:705,y:620),control2:CGPoint(x:723,y:579));ctx.addPath(marks);ctx.strokePath()
func ellipse(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ c:CGColor){ctx.setFillColor(c);ctx.fillEllipse(in:CGRect(x:x,y:y,width:w,height:h))}
ellipse(222,228,580,418,color(73,49,39));ellipse(256,251,512,356,color(255,252,244));ellipse(344,322,336,214,color(216,196,164))
let inset=CGMutablePath();inset.move(to:CGPoint(x:344,y:429));inset.addCurve(to:CGPoint(x:512,y:536),control1:CGPoint(x:344,y:488),control2:CGPoint(x:419,y:536));inset.addCurve(to:CGPoint(x:680,y:429),control1:CGPoint(x:605,y:536),control2:CGPoint(x:680,y:488));inset.addCurve(to:CGPoint(x:512,y:485),control1:CGPoint(x:655,y:467),control2:CGPoint(x:586,y:485));inset.addCurve(to:CGPoint(x:344,y:429),control1:CGPoint(x:438,y:485),control2:CGPoint(x:369,y:467));inset.closeSubpath();ctx.setFillColor(color(192,167,137));ctx.addPath(inset);ctx.fillPath()
try NSBitmapImageRep(cgImage:ctx.makeImage()!).representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
