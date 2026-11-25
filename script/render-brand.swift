// Run from the repo root with: swift script/render-brand.swift
import AppKit
import ImageIO
import UniformTypeIdentifiers

let catalog = URL(fileURLWithPath: "Vellem/Assets.xcassets", isDirectory: true)
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func gray(_ value: CGFloat) -> CGColor {
    let channel = value / 255
    return CGColor(colorSpace: space, components: [channel, channel, channel, 1])!
}

func polygon(_ points: [(Int, Int)]) -> CGPath {
    let path = CGMutablePath()
    for (index, vertex) in points.enumerated() {
        let point = CGPoint(x: vertex.0, y: vertex.1)
        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
    }
    path.closeSubpath()
    return path
}

let silhouette = polygon([(0,1), (29,1), (54,58), (72,20), (100,8), (66,81), (36,81)])
let fold = polygon([(36,81), (54,58), (84,42), (66,81)])

func fill(_ path: CGPath, with color: CGFloat, in context: CGContext) {
    context.setFillColor(gray(color))
    context.addPath(path)
    context.fillPath()
}

func pdf(_ path: String, size: CGSize, draw: (CGContext) -> Void) throws {
    var page = CGRect(origin: .zero, size: size)
    let sharedMarks = URL(fileURLWithPath: "VellemShared/AgentMarks.xcassets")
    guard let context = CGContext(sharedMarks.appending(path: path) as CFURL, mediaBox: &page, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    context.beginPDFPage(nil)
    context.translateBy(x: 0, y: size.height)
    context.scaleBy(x: 1, y: -1)
    draw(context)
    context.endPDFPage()
    context.closePDF()
}

try pdf("FoldMark.imageset/mark.pdf", size: CGSize(width: 18, height: 18)) { ctx in
    ctx.translateBy(x: 1, y: 2.4)
    ctx.scaleBy(x: 0.16, y: 0.16)
    fill(silhouette, with: 0, in: ctx)
}

try pdf("FoldPaper.imageset/paper.pdf", size: CGSize(width: 210, height: 176)) { ctx in
    func panel(_ points: [(Int, Int)], from: CGFloat, to: CGFloat, edge: CGFloat) {
        let path = polygon(points)
        let gradient = CGGradient(colorsSpace: space, colors: [gray(from), gray(to)] as CFArray, locations: [0, 1])!
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 210, y: 176), options: [])
        ctx.restoreGState()
        ctx.setStrokeColor(gray(edge))
        ctx.setLineWidth(0.85)
        ctx.addPath(path)
        ctx.strokePath()
    }
    panel([(85,120), (126,70), (163,51), (137,109)], from: 79, to: 34, edge: 75)
    panel([(14,21), (72,19), (126,134), (83,161)], from: 254, to: 223, edge: 192)
    panel([(83,161), (128,65), (195,38), (147,134)], from: 228, to: 184, edge: 159)
}

struct IconCatalog: Decodable {
    struct Slot: Decodable {
        var filename: String
        var size: String
        var scale: String
    }
    var images: [Slot]
}

let icons = catalog.appending(path: "VellemFold.appiconset")
let slots = try JSONDecoder().decode(IconCatalog.self, from: Data(contentsOf: icons.appending(path: "Contents.json"))).images
for slot in slots {
    let points = Int(slot.size.prefix { $0.isNumber })!
    let pixels = points * Int(slot.scale.prefix { $0.isNumber })!
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: CGFloat(pixels) / 100, y: -CGFloat(pixels) / 100)
    let tile = CGPath(roundedRect: CGRect(x: 8, y: 8, width: 84, height: 84),
                      cornerWidth: 18.5, cornerHeight: 18.5, transform: nil)
    fill(tile, with: 16, in: ctx)
    ctx.setStrokeColor(gray(50))
    ctx.setLineWidth(0.6)
    ctx.addPath(tile)
    ctx.strokePath()
    ctx.translateBy(x: 22, y: 27)
    ctx.scaleBy(x: 0.56, y: 0.56)
    fill(silhouette, with: 253, in: ctx)
    if points > 16 { fill(fold, with: 175, in: ctx) }
    guard let image = ctx.makeImage(),
          let out = CGImageDestinationCreateWithURL(icons.appending(path: slot.filename) as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(out, image, nil)
    guard CGImageDestinationFinalize(out) else { throw CocoaError(.fileWriteUnknown) }
}

let composerSize = 1024
let layer = CGContext(data: nil, width: composerSize, height: composerSize, bitsPerComponent: 8,
                      bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
layer.translateBy(x: 0, y: CGFloat(composerSize))
layer.scaleBy(x: 10.24, y: -10.24)
layer.translateBy(x: 18, y: 23.8)
layer.scaleBy(x: 0.64, y: 0.64)
fill(silhouette, with: 253, in: layer)
fill(fold, with: 175, in: layer)
let composerFile = catalog.deletingLastPathComponent().appending(path: "VellemFold.icon/Assets/Fold.png")
let target = CGImageDestinationCreateWithURL(composerFile as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(target, layer.makeImage()!, nil)
guard CGImageDestinationFinalize(target) else { throw CocoaError(.fileWriteUnknown) }
