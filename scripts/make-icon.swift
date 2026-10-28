// Generates the layer SVGs for the Icon Composer app icon and, optionally,
// renders preview PNGs of every appearance with Icon Composer's ictool.
//
//   swift scripts/make-icon.swift                 # rewrite the layer SVGs
//   swift scripts/make-icon.swift --preview DIR   # ...and render previews to DIR
//
// The icon is the planner in miniature: three cream bars, staggered left to
// right like places from west to east, crossed by one amber column (the
// meridian) where a meeting time lines up for everyone. The bars and the
// column are separate Icon Composer layers so Liquid Glass gives them depth.
// Background fill, glass, shadow and per-appearance colors live in
// Resources/AppIcon/Meridian.icon/icon.json (editable in Icon Composer);
// this script owns only the geometry.
import Foundation

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconBundle = root.appendingPathComponent("Resources/AppIcon/Meridian.icon")
let assets = iconBundle.appendingPathComponent("Assets")

// MARK: Geometry (1024 x 1024 canvas)

let cream = "#FFF4E3"
let amber = "#FFB938"

let barHeight = 116.0
let barGap = 52.0
let centerY = 512.0
// Each bar's horizontal span, top (west) to bottom (east).
let bars = [(196.0, 652.0), (284.0, 740.0), (372.0, 828.0)]

let column = (centerX: 512.0, width: 172.0, overhang: 64.0, stroke: 40.0)

// MARK: Derived shapes

func f(_ v: Double) -> String { String(format: "%.1f", v) }

let pitch = barHeight + barGap
let firstBarY = centerY - pitch - barHeight / 2
let barRects = bars.enumerated().map { index, span in
    (x: span.0, y: firstBarY + Double(index) * pitch, w: span.1 - span.0, h: barHeight)
}

// The column is an outline, inset by half its stroke so its outer edge
// overhangs the top and bottom bars by `overhang`.
let columnTop = firstBarY - column.overhang + column.stroke / 2
let columnBottom = firstBarY + 2 * pitch + barHeight + column.overhang - column.stroke / 2
let columnX = column.centerX - column.width / 2 + column.stroke / 2
let columnW = column.width - column.stroke
let columnRadius = columnW / 2

let svgHeader = #"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">"#

let barsSVG = """
\(svgHeader)
\(barRects.map { #"  <rect x="\#(f($0.x))" y="\#(f($0.y))" width="\#(f($0.w))" height="\#(f($0.h))" rx="\#(f($0.h / 2))" fill="\#(cream)"/>"# }.joined(separator: "\n"))
</svg>

"""

let meridianSVG = """
\(svgHeader)
  <rect x="\(f(columnX))" y="\(f(columnTop))" width="\(f(columnW))" height="\(f(columnBottom - columnTop))" rx="\(f(columnRadius))" fill="none" stroke="\(amber)" stroke-width="\(f(column.stroke))"/>
</svg>

"""

try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
try barsSVG.write(to: assets.appendingPathComponent("bars.svg"), atomically: true, encoding: .utf8)
try meridianSVG.write(to: assets.appendingPathComponent("meridian.svg"), atomically: true, encoding: .utf8)
print("Wrote bars.svg and meridian.svg to \(assets.path)")

// MARK: Previews

let args = CommandLine.arguments
if let flag = args.firstIndex(of: "--preview"), args.indices.contains(flag + 1) {
    let outDir = URL(fileURLWithPath: args[flag + 1])
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    let ictool = "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
    let renditions = ["Default", "Dark", "TintedLight", "TintedDark", "ClearLight", "ClearDark"]
    for rendition in renditions {
        let out = outDir.appendingPathComponent("icon-\(rendition.lowercased()).png")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: ictool)
        task.arguments = [iconBundle.path, "--export-image", "--output-file", out.path,
                          "--platform", "macOS", "--rendition", rendition,
                          "--width", "1024", "--height", "1024", "--scale", "1"]
        task.standardOutput = FileHandle.nullDevice
        try task.run()
        task.waitUntilExit()
        print(task.terminationStatus == 0 ? "Rendered \(out.path)" : "ictool failed for \(rendition)")
    }
}
