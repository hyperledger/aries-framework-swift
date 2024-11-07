// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "aries-framework-swift",
    platforms: [
        .macOS(.v11),
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "AriesFramework",
            targets: ["AriesFramework"])
    ],
    dependencies: [
        .package(url: "https://github.com/hyperledger/aries-uniffi-wrappers", exact: "0.2.1"),
        .package(url: "https://github.com/bhsw/concurrent-ws", exact: "0.5.0"),
        .package(url: "https://github.com/JohnSundell/CollectionConcurrencyKit", exact: "0.2.0"),
        .package(url: "https://github.com/heckj/Base58Swift", exact: "2.1.15"),
        .package(url: "https://github.com/thecatalinstan/Criollo", exact: "1.1.0"),
        .package(url: "https://github.com/groue/Semaphore", exact: "0.0.8"),
        .package(url: "https://github.com/beatt83/peerdid-swift", exact: "3.0.0"),
        .package(url: "https://github.com/apple/swift-algorithms", exact: "1.2.0"),
        .package(url: "https://github.com/conanoc/BlueSwift", exact: "1.1.7")
    ],
    targets: [
        .target(
            name: "AriesFramework",
            dependencies: [
                .product(name: "Anoncreds", package: "aries-uniffi-wrappers"),
                .product(name: "Askar", package: "aries-uniffi-wrappers"),
                .product(name: "IndyVdr", package: "aries-uniffi-wrappers"),
                .product(name: "WebSockets", package: "concurrent-ws"),
                .product(name: "PeerDID", package: "peerdid-swift"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                "CollectionConcurrencyKit",
                "Base58Swift",
                "Semaphore",
                "BlueSwift"
            ]),
        .testTarget(
            name: "AriesFrameworkTests",
            dependencies: ["AriesFramework", "Criollo"],
            resources: [
                .copy("resources/local-genesis.txn"),
                .copy("resources/bcovrin-genesis.txn")
            ])
    ]
)
