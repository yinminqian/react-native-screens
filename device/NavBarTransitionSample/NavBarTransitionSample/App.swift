import UIKit

// A navigation bar that is shown or hidden alongside a push / pop does not move together with the view of the
// view controller it belongs to (iOS 26 and later).
//
// Home has no navigation bar, Detail has one. Each view controller says so from viewWillAppear(_:) with
// setNavigationBarHidden(_:animated:). Nothing else touches the navigation bar or the transition.
//
// The "Main thread" control on Home picks what happens while the transition runs:
//   Idle        nothing
//   Busy early  the main thread is blocked for 150 ms, starting 40 ms after viewWillAppear(_:)
//   Busy late   the main thread is blocked for 200 ms, starting 220 ms after viewWillAppear(_:)
// The block stands for work an app does while a screen appears, e.g. laying out content that has just arrived.
//
// Expected: the red bar stays aligned with the left edge of the gray view for the whole push and pop.
// Actual:   the gray view keeps sliding while the main thread is blocked, the red bar does not. With "Busy late"
//           the bar stops about 20 pt short of its place, waits, and jumps there after the view has settled.
//           With "Busy early" the view slides in without a bar and the bar jumps in afterwards.

enum MainThreadLoad: Int, CaseIterable {
    case idle, busyEarly, busyLate

    static var current: MainThreadLoad = .busyLate

    var title: String {
        switch self {
        case .idle: return "Idle"
        case .busyEarly: return "Busy early"
        case .busyLate: return "Busy late"
        }
    }

    /// When the main thread gets blocked, in seconds after viewWillAppear(_:), and for how long.
    private var block: (delay: TimeInterval, duration: TimeInterval)? {
        switch self {
        case .idle: return nil
        case .busyEarly: return (0.04, 0.15)
        case .busyLate: return (0.22, 0.2)
        }
    }

    /// Called from viewWillAppear(_:) of the screen an animated transition is going to.
    static func simulate() {
        guard let block = current.block else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + block.delay) {
            let end = CACurrentMediaTime() + block.duration
            while CACurrentMediaTime() < end {}
        }
    }
}

final class HomeViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = "Push Detail and watch the red navigation bar. It should stay aligned with the gray view."

        let load = UISegmentedControl(items: MainThreadLoad.allCases.map(\.title))
        load.selectedSegmentIndex = MainThreadLoad.current.rawValue
        load.addAction(UIAction { [unowned load] _ in
            MainThreadLoad.current = MainThreadLoad(rawValue: load.selectedSegmentIndex) ?? .idle
        }, for: .valueChanged)

        let caption = UILabel()
        caption.text = "Main thread during the transition"
        caption.font = .preferredFont(forTextStyle: .footnote)
        caption.textColor = .secondaryLabel

        let push = UIButton(configuration: .filled(), primaryAction: UIAction(title: "Push Detail") { [unowned self] _ in
            navigationController?.pushViewController(DetailViewController(), animated: true)
        })

        let stack = UIStackView(arrangedSubviews: [label, caption, load, push])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.setCustomSpacing(32, after: label)
        stack.setCustomSpacing(32, after: load)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        if animated {
            MainThreadLoad.simulate()
        }
    }
}

final class DetailViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Detail"
        view.backgroundColor = UIColor(white: 0.5, alpha: 1)

        // Opaque and red only to make the bar easy to see. The default appearance behaves the same.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .red
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance

        let label = UILabel()
        label.text = "Detail"
        label.font = .preferredFont(forTextStyle: .title1)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        if animated {
            MainThreadLoad.simulate()
        }
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let navigationController = UINavigationController(rootViewController: HomeViewController())
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        self.window = window
    }
}
