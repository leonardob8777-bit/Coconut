// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WallpaperLab",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "WallpaperPackageManager", targets: ["WallpaperPackageManager"]),
        .library(name: "WallpaperInstaller", targets: ["WallpaperInstaller"]),
        .library(name: "CompatibilityManager", targets: ["CompatibilityManager"]),
        .executable(name: "wallpaper-inspect", targets: ["wallpaper-inspect"])
    ],
    dependencies: [.package(path: "Vendor/ZIPFoundation")],
    targets: [
        .target(name: "WallpaperPackageManager", dependencies: ["ZIPFoundation"]),
        .target(name: "WallpaperInstaller", dependencies: ["WallpaperPackageManager"]),
        .target(name: "CompatibilityManager"),
        .executableTarget(name: "wallpaper-inspect", dependencies: ["WallpaperPackageManager", "CompatibilityManager"]),
        .testTarget(name: "CompatibilityManagerTests", dependencies: ["CompatibilityManager"]),
        .testTarget(name: "WallpaperInstallerTests", dependencies: ["WallpaperInstaller"]),
        .testTarget(name: "WallpaperPackageManagerTests", dependencies: ["WallpaperPackageManager"],
                    resources: [.copy("Fixtures")])
    ]
)
