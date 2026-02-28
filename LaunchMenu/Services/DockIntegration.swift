import AppKit
import Foundation

protocol DockIntegrating {
    func addAppToDock(appPath: String) throws
}

enum DockIntegrationError: LocalizedError {
    case invalidAppPath
    case duplicateEntry
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidAppPath:
            return L10n.t("error.dock.invalid.path")
        case .duplicateEntry:
            return L10n.t("error.dock.duplicate")
        case let .executionFailed(message):
            return L10n.f("error.dock.execution", message)
        }
    }
}

final class AppleScriptDockIntegration: DockIntegrating {
    func addAppToDock(appPath: String) throws {
        let standardizedPath = URL(fileURLWithPath: appPath).standardizedFileURL.path
        guard standardizedPath.hasSuffix(".app") else {
            throw DockIntegrationError.invalidAppPath
        }
        guard FileManager.default.fileExists(atPath: standardizedPath) else {
            throw DockIntegrationError.invalidAppPath
        }

        let fileURLString = URL(fileURLWithPath: standardizedPath).absoluteString
        if try isAlreadyPinned(fileURLString: fileURLString, appPath: standardizedPath) {
            throw DockIntegrationError.duplicateEntry
        }
        let xmlPayload = "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>\(fileURLString)</string><key>_CFURLStringType</key><integer>15</integer></dict></dict><key>tile-type</key><string>file-tile</string></dict>"

        try runCommand(
            executablePath: "/usr/bin/defaults",
            arguments: [
                "write",
                "com.apple.dock",
                "persistent-apps",
                "-array-add",
                xmlPayload
            ]
        )
        try runCommand(
            executablePath: "/usr/bin/killall",
            arguments: ["Dock"]
        )
    }

    private func isAlreadyPinned(fileURLString: String, appPath: String) throws -> Bool {
        let existingEntries = try runCommand(
            executablePath: "/usr/bin/defaults",
            arguments: ["read", "com.apple.dock", "persistent-apps"],
            captureStandardOutput: true
        )

        let candidates: [String] = [
            fileURLString,
            fileURLString.hasSuffix("/") ? String(fileURLString.dropLast()) : fileURLString + "/",
            appPath,
            appPath.hasSuffix("/") ? String(appPath.dropLast()) : appPath + "/"
        ]

        return candidates.contains { existingEntries.contains($0) }
    }

    @discardableResult
    private func runCommand(
        executablePath: String,
        arguments: [String],
        captureStandardOutput: Bool = false
    ) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe
        let outputPipe = Pipe()
        if captureStandardOutput {
            process.standardOutput = outputPipe
        }

        do {
            try process.run()
        } catch {
            throw DockIntegrationError.executionFailed(error.localizedDescription)
        }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let message = (output?.isEmpty == false)
                ? output!
                : "Process failed with exit code \(process.terminationStatus)"
            throw DockIntegrationError.executionFailed(message)
        }

        if captureStandardOutput {
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: outputData, encoding: .utf8) ?? ""
        }
        return ""
    }
}
