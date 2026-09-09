// 和紙の質感を背景に敷くための部品

import SwiftUI

/// 和紙の質感を描く背景。生成りの地に、短い繊維を散らして紙の風合いを出す。
///
/// 画像を持たずベクターで描くので、どの解像度でも粒が潰れない。
/// 繊維は固定の乱数列から作り、再描画のたびに模様が変わらないようにする
struct WashiBackground: View {
    let colorScheme: ColorScheme
    /// 角の丸み。画面幅いっぱいに敷くときは 0 にして角を立てる
    var cornerRadius: CGFloat = 0
    /// 縁に線を引くか。枠として見せたいときだけ true にする
    var showsBorder: Bool = false
    /// 地を沈める量（0〜1）。広告の下など、アプリの面ではないと
    /// 示したい場所で一段暗くするために使う
    var recess: Double = 0

    /// 和紙の地色。生成り（ごくわずかに黄みのある白）を基準にする。
    /// ダークでは白い紙にはできないため、墨を含んだ濃い和紙に置き換える
    private var paperColor: Color {
        Self.paperColor(colorScheme, recess: recess)
    }

    /// 繊維を描けない場所（ナビゲーションバーの地など）で
    /// 紙と同じ色を使うための地色
    static func paperColor(_ colorScheme: ColorScheme, recess: Double = 0) -> Color {
        let (r, g, b) = colorScheme == .dark
            ? (0.16, 0.15, 0.13)
            : (0.98, 0.96, 0.92)
        // 沈める量。ダークは元が暗いので浅く、ライトは影として分かる程度に落とす
        let amount = recess * (colorScheme == .dark ? 0.35 : 0.055)
        return Color(red: r * (1 - amount), green: g * (1 - amount), blue: b * (1 - amount))
    }

    /// 繊維の色。地より少しだけ濃くして、透かしたときの繊維に見せる
    private var fiberColor: Color {
        colorScheme == .dark
            ? Color(red: 0.35, green: 0.33, blue: 0.29)
            : Color(red: 0.80, green: 0.75, blue: 0.66)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        shape
            .fill(paperColor)
            .overlay {
                Canvas { context, size in
                    drawFibers(in: context, size: size)
                }
                // 繊維が角の外へはみ出さないように切り抜く
                .clipShape(shape)
                .allowsHitTesting(false)
            }
            .overlay {
                // 縁を内側からごく薄く陰らせ、紙が置かれている厚みを出す
                if showsBorder {
                    shape.strokeBorder(fiberColor.opacity(colorScheme == .dark ? 0.45 : 0.55), lineWidth: 0.5)
                }
            }
    }

    /// 短い繊維を敷き詰める。長さと向きをばらつかせると紙らしくなる
    private func drawFibers(in context: GraphicsContext, size: CGSize) {
        // 同じ模様を再現するため、毎回同じ種から乱数を作る
        var generator = SeededGenerator(seed: 20260909)
        // 面積に比例させ、細い帯でも太い帯でも密度をそろえる
        let count = Int(size.width * size.height / 90)

        for _ in 0..<count {
            let x = Double.random(in: 0...size.width, using: &generator)
            let y = Double.random(in: 0...size.height, using: &generator)
            let length = Double.random(in: 3...11, using: &generator)
            // 和紙の繊維は漉くときの流れでやや横向きに寝る
            let angle = Double.random(in: -0.5...0.5, using: &generator)
            let opacity = Double.random(in: 0.10...0.30, using: &generator)

            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length))

            context.stroke(
                path,
                with: .color(fiberColor.opacity(opacity)),
                lineWidth: Double.random(in: 0.4...0.9, using: &generator)
            )
        }
    }
}

/// 種を決めて同じ乱数列を作る。再描画で模様が動かないようにするために使う
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // 0 は次の値も 0 になるため、種が 0 でも進む値にずらす
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        // SplitMix64。状態が小さくても偏りが少なく、実装も短い
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
