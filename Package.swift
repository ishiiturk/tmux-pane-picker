// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TmuxPanePicker",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "tmux-pane-picker",
            targets: ["TmuxPanePicker"]
        )
    ],
    targets: [
        .executableTarget(
            name: "TmuxPanePicker"
        ),
        .testTarget(
            name: "TmuxPanePickerTests",
            dependencies: ["TmuxPanePicker"]
        )
    ]
)
