//
//  main.swift
//  LicenseList
//
//  Created by lynnswap on 2025/07/24.
//

import Foundation

struct Item: Codable {
    let name: String
    let url: String
    let licenseBody: String
}

/// --- 引数パース -----------------------------------------------------------
enum Arg { static let root = "--workspace"; static let out = "--output" }
let args = CommandLine.arguments
guard let rootIdx = args.firstIndex(of: Arg.root),
      let outIdx  = args.firstIndex(of: Arg.out),
      args.indices.contains(rootIdx+1), args.indices.contains(outIdx+1) else {
    let usage = "Usage: LLGenerateLocalLicenses --workspace <dir> --output <file>\n"
    FileHandle.standardError.write(Data(usage.utf8))
    exit(1)
}
let workspace = URL(fileURLWithPath: args[rootIdx+1])
let outputURL = URL(fileURLWithPath: args[outIdx+1])

/// --- 1) workspace 以下を走査し Package.swift を探す ----------------------
let fm = FileManager.default
let enumerator = fm.enumerator(at: workspace,
                               includingPropertiesForKeys: [.isDirectoryKey],
                               options: [.skipsHiddenFiles])!

var items: [Item] = []

for case let url as URL in enumerator where url.lastPathComponent == "Package.swift" {
    let pkgDir = url.deletingLastPathComponent()
    enumerator.skipDescendants()              // 深追い防止

    // 2) LICENSE / COPYING などを検索
    let cand = try fm.contentsOfDirectory(at: pkgDir,
                                          includingPropertiesForKeys: nil)
        .first(where: { ["license","licence","copying","notice"]
            .contains($0.deletingPathExtension().lastPathComponent.lowercased()) })
    print("Local package licenses 1")
    if let licURL = cand,
       let text = try? String(contentsOf: licURL, encoding: .utf8) {
        let gitConfig = pkgDir.appending(path: ".git/config")
        print("gitConfig",gitConfig)
        var urlString = pkgDir.path
        if let config = try? String(contentsOf: gitConfig, encoding: .utf8),
           let range = config.range(of: #"url\s*=\s*([^\n]+)"#, options: .regularExpression),
           let match = config[range].split(separator: "=").last {
            print("match",match)
            urlString = match.trimmingCharacters(in: .whitespaces)
        }
        items.append(.init(name: pkgDir.lastPathComponent, url: urlString, licenseBody: text))
    }
}

/// --- 3) JSON 出力 ---------------------------------------------------------
let data = try JSONEncoder().encode(items)
try fm.createDirectory(at: outputURL.deletingLastPathComponent(),
                       withIntermediateDirectories: true)
try data.write(to: outputURL)
print("✅  Local package licenses written to \(outputURL.path)")
