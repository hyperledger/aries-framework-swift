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
        .package(url: "https://github.com/hyperledger/aries-uniffi-wrappers", exact: "0.1.0"),
        .package(url: "https://github.com/bhsw/concurrent-ws", exact: "0.5.0"),
        .package(url: "https://github.com/JohnSundell/CollectionConcurrencyKit", exact: "0.2.0"),
        .package(url: "https://github.com/keefertaylor/Base58Swift", exact: "2.1.7"),
        .package(url: "https://github.com/thecatalinstan/Criollo", exact: "1.1.0")
    ],
    targets: [
        .target(
            name: "AriesFramework",
            dependencies: [
                .product(name: "Anoncreds", package: "aries-uniffi-wrappers"),
                .product(name: "Askar", package: "aries-uniffi-wrappers"),
                .product(name: "IndyVdr", package: "aries-uniffi-wrappers"),
                .product(name: "WebSockets", package: "concurrent-ws"),
                "CollectionConcurrencyKit",
                "Base58Swift"
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
