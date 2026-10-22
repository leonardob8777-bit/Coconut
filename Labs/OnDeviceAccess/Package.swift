// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OnDeviceAccessProbeCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "OnDeviceAccessProbeCore", targets: ["OnDeviceAccessProbeCore"])],
    targets: [
        .target(name: "OnDeviceAccessProbeCore"),
        .testTarget(name: "OnDeviceAccessProbeCoreTests", dependencies: ["OnDeviceAccessProbeCore"])
    ]
)
