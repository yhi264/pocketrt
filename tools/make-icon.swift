#!/usr/bin/env swift
// PocketRT アプリアイコン生成スクリプト
//
// 用途: AppIcon-1024.png を AppKit のみで生成する（外部ツール・ライブラリ不要）。
// 図案は 17 ラウンドの検討を経て確定した「案W」。スクラブブルーの生地に、
// 左寄せした直線の V ネック（両肩に生地が残る構造）、右寄りの胸ポケット、
// そこに挿さったスマートフォン、画面に "Gy" の文字を描く。
// 色・Vネックの角度・ポケット位置などはすべて意図的に決定済みのため、
// 描画コードは変更しないこと。色や配置を調整したい場合は、このファイル内の
// 該当する定数（fabricColor, collarCenterX, pocketCenterX 等）を編集して
// 再生成する。
//
// 再現性についての注記: 文字描画に NSFont.systemFont のメトリクスを使用し、
// PNG エンコードは AppKit（NSBitmapImageRep）に委ねている。どちらも OS の
// バージョンに依存するため、別のマシンや別の macOS バージョンで再生成すると
// レイアウトは同じでもバイト単位で同一の PNG になる保証はない。生成物は
// リポジトリにコミット済みで通常は再生成不要なため、これは許容している設計
// 判断である。差分に驚いた場合は「壊れた」のではなく環境差によるものと理解
// すること。
//
// 使い方: swift tools/make-icon.swift <出力先パス>
//   例: swift tools/make-icon.swift PocketRT/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
import AppKit
import Foundation

let size = 1024

// 出力先パスの決定。
// `swift tools/make-icon.swift <path>` では Swift ドライバ/フロントエンドが
// ユーザー引数の直前に `--` を挿入するため、セパレータ以降を見ればよい。
// 一方、引数を渡さず `swift tools/make-icon.swift` だけを実行した場合は `--` が
// 挿入されず、CommandLine.arguments は `-frontend` `-interpret` `-sdk` <SDKパス>
// のようなフロントエンド内部フラグで埋まる（実測で確認済み）。これらは `.swift`
// で終わらないため、素朴に「`.swift` で終わらない最初の引数」を出力先とみなすと
// 内部フラグを誤って出力先と解釈し、黙って的外れな場所に書き込んでしまう
// （実際に `-frontend` という名前のファイルが作られる事故を確認済み）。
// これを避けるため、`-interpret` が含まれる=インタプリタモードで `--` が無い
// 場合はユーザー引数なしと判定する。コンパイル済みバイナリとして実行された
// 場合は `--` も `-interpret` も現れないため、dropFirst() がそのままユーザー
// 引数になる。いずれの経路でも指定が無ければ黙ってフォールバックせず異常終了する。
let allArgs = CommandLine.arguments
let candidates: [String]
if let sepIndex = allArgs.lastIndex(of: "--") {
    candidates = Array(allArgs[(sepIndex + 1)...])
} else if allArgs.contains("-interpret") {
    candidates = []
} else {
    candidates = Array(allArgs.dropFirst())
}
guard let outputPath = candidates.first(where: { !$0.hasSuffix(".swift") }) else {
    FileHandle.standardError.write(Data("""
        使い方: swift tools/make-icon.swift <出力先パス>
          例: swift tools/make-icon.swift PocketRT/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
        """.utf8))
    exit(1)
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("ビットマップの作成に失敗しました") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

let w = CGFloat(size)
let h = CGFloat(size)

// --- 配色: 案Rのスクラブブルーをそのまま移植 ---
let fabricColor = CGColor(red: 0.36, green: 0.48, blue: 0.62, alpha: 1.0)
let trimColor = CGColor(red: 0.19, green: 0.29, blue: 0.40, alpha: 1.0)
let openingColor = CGColor(red: 0.96, green: 0.97, blue: 0.97, alpha: 1.0)
let phoneColor = CGColor(red: 0.09, green: 0.17, blue: 0.32, alpha: 1.0)
let screenColor = CGColor(red: 0.30, green: 0.62, blue: 0.90, alpha: 1.0)

// --- 背景: 生地がアイコン全体を覆う ---
ctx.setFillColor(fabricColor)
ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

// --- V字襟(直線・画面幅の約35%に左寄せ=標準) ---
// collarCenterXが開口部の中点(=頂点の真上のX)。Pと同じ「開口部+バインダー」構造。
// 左寄せに伴い、左肩の生地(0〜x1)が狭くなりすぎないよう、Pよりスパン・深さを
// 縮小した(比率は約105°を維持し、鈍角を保つことで矢印化を回避)。
let collarCenterX: CGFloat = 358 // 画面幅の約35%
let collarSpan: CGFloat = 520
let collarDepth: CGFloat = 200
let collarX1: CGFloat = collarCenterX - collarSpan / 2   // 98
let collarX2: CGFloat = collarCenterX + collarSpan / 2   // 618
let collarVY: CGFloat = h - collarDepth                  // 824 (開き角 約105°、鈍角)
let binderWidth: CGFloat = 48

let openingPath = CGMutablePath()
openingPath.move(to: CGPoint(x: collarX1, y: h + 4))
openingPath.addLine(to: CGPoint(x: collarCenterX, y: collarVY))
openingPath.addLine(to: CGPoint(x: collarX2, y: h + 4))
openingPath.closeSubpath()
ctx.setFillColor(openingColor)
ctx.addPath(openingPath)
ctx.fillPath()

let collarStrokePath = CGMutablePath()
collarStrokePath.move(to: CGPoint(x: collarX1, y: h + 2))
collarStrokePath.addLine(to: CGPoint(x: collarCenterX, y: collarVY))
collarStrokePath.addLine(to: CGPoint(x: collarX2, y: h + 2))
ctx.setStrokeColor(trimColor)
ctx.setLineWidth(binderWidth)
ctx.setLineJoin(.round)
ctx.setLineCap(.round)
ctx.addPath(collarStrokePath)
ctx.strokePath()

// --- レイアウト: ポケット中心を右に移動(W=画面幅の約66%、中央やや下) ---
let pocketCenterX: CGFloat = 676
let pocketWidth: CGFloat = 480
let pocketHeight: CGFloat = 340
let pocketX: CGFloat = pocketCenterX - pocketWidth / 2
let pocketY: CGFloat = 40
let pocketRect = CGRect(x: pocketX, y: pocketY, width: pocketWidth, height: pocketHeight)
let pocketRadius: CGFloat = 48
let pocketOutlineWidth: CGFloat = 52
let pocketBandHeight: CGFloat = 76

// --- スマートフォン: ポケット内側ぎりぎりまで拡大(左右にわずかな隙間のみ) ---
let phoneWidth: CGFloat = 400
let phoneHeight: CGFloat = 740
let phoneX = pocketCenterX - phoneWidth / 2
let phoneY: CGFloat = 15
let phoneRect = CGRect(x: phoneX, y: phoneY, width: phoneWidth, height: phoneHeight)

let phonePath = CGPath(roundedRect: phoneRect, cornerWidth: 56, cornerHeight: 56, transform: nil)
ctx.setFillColor(phoneColor)
ctx.addPath(phonePath)
ctx.fillPath()

let screenRect = CGRect(x: phoneX + 30, y: phoneY + 88, width: phoneWidth - 60, height: phoneHeight - 30 - 88)
let screenPath = CGPath(roundedRect: screenRect, cornerWidth: 40, cornerHeight: 40, transform: nil)
ctx.setFillColor(screenColor)
ctx.addPath(screenPath)
ctx.fillPath()

// --- "Gy" 文字(スマホ拡大に比例して拡大) ---
ctx.saveGState()
ctx.addPath(screenPath)
ctx.clip()

let text = "Gy" as CFString
let font = NSFont.systemFont(ofSize: 220, weight: .black)
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white.cgColor
]
let attrString = NSAttributedString(string: text as String, attributes: attrs)
let line = CTLineCreateWithAttributedString(attrString)
let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

let visibleScreenMidY = (screenRect.maxY + pocketRect.maxY) / 2
let textX = pocketCenterX - bounds.width / 2 - bounds.origin.x
let textY = visibleScreenMidY - bounds.height / 2 - bounds.origin.y

ctx.textPosition = CGPoint(x: textX, y: textY)
CTLineDraw(line, ctx)
ctx.restoreGState()

// --- 胸ポケット: 生地と同色で塗り、輪郭線と上辺の帯だけで存在を示す ---
func makePocketPath(rect: CGRect, radius: CGFloat) -> CGMutablePath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
    path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                tangent2End: CGPoint(x: rect.minX + radius, y: rect.minY),
                radius: radius)
    path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
    path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                tangent2End: CGPoint(x: rect.maxX, y: rect.minY + radius),
                radius: radius)
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    return path
}

let pocketOutline = makePocketPath(rect: pocketRect, radius: pocketRadius)
let pocketFillPath = pocketOutline.mutableCopy()!
pocketFillPath.closeSubpath()
ctx.setFillColor(fabricColor)
ctx.addPath(pocketFillPath)
ctx.fillPath()

let bandRect = CGRect(x: pocketRect.minX, y: pocketRect.maxY - pocketBandHeight,
                      width: pocketRect.width, height: pocketBandHeight)
ctx.setFillColor(trimColor)
ctx.fill(bandRect)

ctx.setStrokeColor(trimColor)
ctx.setLineWidth(pocketOutlineWidth)
ctx.setLineJoin(.round)
ctx.setLineCap(.round)
ctx.addPath(pocketOutline)
ctx.strokePath()

NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("PNG 変換に失敗しました\n".utf8))
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: outputPath))
} catch {
    FileHandle.standardError.write(Data("書き込みに失敗しました: \(outputPath) (\(error.localizedDescription))\n".utf8))
    exit(1)
}
print("生成: \(outputPath)")
