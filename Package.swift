// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DesktopCatPet",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DesktopCatPet", targets: ["DesktopCatPet"])
    ],
    targets: [
        .executableTarget(
            name: "DesktopCatPet",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
