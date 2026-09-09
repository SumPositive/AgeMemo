// Google Mobile Ads導入前後で同じバナー表示口を提供する

import SwiftUI

#if canImport(GoogleMobileAds)
@preconcurrency import GoogleMobileAds

enum AdMobConfig {
    #if DEBUG
    static let bannerUnitID = "ca-app-pub-3940256099942544/2435281174"
    #else
    static let bannerUnitID = Bundle.main.object(forInfoDictionaryKey: "NenrinBannerUnitID") as? String ?? ""
    #endif
}

@MainActor
private func nonPersonalizedAdRequest() -> Request {
    let request = Request()
    let extras = Extras()
    extras.additionalParameters = ["npa": "1"]
    request.register(extras)
    return request
}

struct HeaderBannerView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if hidesBannerForSnapshot {
            // App Store用スクリーンショットには広告枠を含めない
            Color.clear.frame(height: 0)
        } else if !AdMobConfig.bannerUnitID.isEmpty {
            AdMobBannerRepresentable(adUnitID: AdMobConfig.bannerUnitID)
                .frame(width: 320, height: 50)
                .frame(maxWidth: .infinity)
                // 上下のタップできる要素（ヘルプの(?)・列見出し）との間を空ける。
                // 誤タップを防ぐだけでなく、広告がアプリの操作面と地続きに
                // 見えないようにするためにも要る
                .padding(.vertical, 16)
                // 広告の載る面だけ地を一段沈め、アプリのUIではないと分かるようにする。
                // 背景を共有したままだと広告が画面の一部に見えてしまう
                .background(WashiBackground(colorScheme: colorScheme, recess: 1))
        } else {
            // ユニットID未設定時にEmptyViewを返すとsafeAreaInsetが破綻するため高さ0の実体を返す
            Color.clear.frame(height: 0)
        }
    }

    private var hidesBannerForSnapshot: Bool {
        #if DEBUG
        SnapshotSetup.isActive
        #else
        false
        #endif
    }
}

private struct AdMobBannerRepresentable: UIViewControllerRepresentable {
    let adUnitID: String

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = controller
        banner.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
            banner.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor),
        ])
        banner.load(nonPersonalizedAdRequest())
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // 表示中のバナーは更新不要
    }
}

#else
struct HeaderBannerView: View {
    // safeAreaInset に EmptyView を渡すとレイアウトが確定できず
    // インセットが画面全体に膨張して一覧が隠れるため、高さ0の実体を返す
    var body: some View { Color.clear.frame(height: 0) }
}
#endif
