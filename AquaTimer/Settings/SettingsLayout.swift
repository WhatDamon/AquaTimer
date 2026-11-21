import AppKit

@MainActor
enum SettingsLayout {
    static let width: CGFloat = 520
    static let controlsWidth: CGFloat = 370
    static let captionIndent = AquaSelectionButton.captionInset

    static func column(_ views: [NSView], spacing: CGFloat = 8) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        return stack
    }

    static func row(_ views: [NSView], spacing: CGFloat = 8) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.alignment = .firstBaseline
        stack.spacing = spacing
        return stack
    }

    static func note(_ text: String, lines: Int? = nil) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = AquaTypography.font(ofSize: 11)
        label.textColor = AquaTypography.secondaryInk
        label.preferredMaxLayoutWidth = controlsWidth - captionIndent
        label.widthAnchor.constraint(equalToConstant: label.preferredMaxLayoutWidth).isActive = true
        if let lines { label.heightAnchor.constraint(equalToConstant: CGFloat(lines) * 14).isActive = true }
        return label
    }

    static func indent(_ content: NSView) -> NSView {
        let container = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: captionIndent),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            content.topAnchor.constraint(equalTo: container.topAnchor),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }
}

@MainActor
class SettingsPaneViewController: NSViewController {
    let settings: AppSettings
    private let form = SettingsLayout.column([], spacing: 20)

    init(settings: AppSettings = .shared) {
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: SettingsLayout.width, height: 330))
        form.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(form)
        NSLayoutConstraint.activate([
            form.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            form.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            form.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            form.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20)
        ])
        buildContents()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: AppSettings.didChange, object: settings)
        render()
    }

    func buildContents() {}
    func render() {}
    func prepareForPresentation() { _ = view; render() }

    func addSection(_ title: String, body: NSView, firstControl: NSView) {
        let row = NSView()
        let label = NSTextField(labelWithString: title)
        label.alignment = .right
        label.font = AquaTypography.font(ofSize: 13)
        [label, body].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; row.addSubview($0) }
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            label.widthAnchor.constraint(equalToConstant: 104),
            label.firstBaselineAnchor.constraint(equalTo: firstControl.firstBaselineAnchor),
            body.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 6),
            body.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            body.topAnchor.constraint(equalTo: row.topAnchor),
            body.bottomAnchor.constraint(equalTo: row.bottomAnchor)
        ])
        form.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: form.widthAnchor).isActive = true
    }

    @objc private func settingsChanged() { render() }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Settings panes use programmatic initialization.") }
}
