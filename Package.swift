import PackageDescription

let package = Package(
    name: "SQLite",
    dependencies: [
        .Package(url: "https://github.com/vapor/csqlite.git", majorVersion: 1),
        .Package(url: "https://github.com/vapor/core.git", majorVersion: 1),
        .Package(url: "https://github.com/vapor/node.git", versions: Version(1,0,1)..<Version(2,0,0))

    ]
)
