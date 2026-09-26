// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CatClans",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
    ],
    products: [
        .library(name: "CatClansKit", targets: ["CatClansKit"]),
        .executable(name: "CatClansDemo", targets: ["CatClansDemo"]),
    ],
    targets: [
        // Игровое ядро: чистый Swift, работает на iOS, macOS и Linux.
        .target(name: "CatClansKit"),
        // Консольное демо: играет партию без графики и печатает журнал боя.
        .executableTarget(
            name: "CatClansDemo",
            dependencies: ["CatClansKit"]
        ),
        .testTarget(
            name: "CatClansKitTests",
            dependencies: ["CatClansKit"]
        ),
    ]
)
