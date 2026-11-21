import AppKit

@MainActor
final class WindowContentViewController: NSViewController {
    static let titlebarHeight: CGFloat = 28
    private let content: NSViewController
    private let titlebar = WindowTitlebarView()
    private let focusOverlay = AquaFocusRingOverlay(frame: .zero)

    init(content: NSViewController) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }

    override func loadView() {
        view = BrushedMetalBackgroundView()
        titlebar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titlebar)
        addChild(content)
        let contentView = content.view
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)
        focusOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(focusOverlay, positioned: .above, relativeTo: nil)
        NSLayoutConstraint.activate([
            titlebar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            titlebar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            titlebar.topAnchor.constraint(equalTo: view.topAnchor),
            titlebar.heightAnchor.constraint(equalToConstant: Self.titlebarHeight),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: titlebar.bottomAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            focusOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            focusOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            focusOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            focusOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func setMetalLightingHeight(_ height: CGFloat) {
        (view as? BrushedMetalBackgroundView)?.lightingHeight = height
    }

    func updateTitle(_ title: String) {
        titlebar.updateTitle(title)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("WindowContentViewController uses programmatic initialization.")
    }
}

