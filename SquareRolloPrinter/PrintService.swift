import Foundation

struct CommandResult {
    let status: Int32
    let output: String
}

enum PrintService {
    /// Arguments are passed directly to Process, never through a shell.
    static func run(_ executable: String, arguments: [String]) throws -> CommandResult {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return CommandResult(status: task.terminationStatus,
                             output: String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }

    static func printers() throws -> (names: [String], defaultName: String?) {
        let result = try run("/usr/bin/lpstat", arguments: ["-p"])
        // lpstat may return nonzero if no printers are configured.
        let names = result.output.components(separatedBy: .newlines).compactMap { line -> String? in
            guard line.hasPrefix("printer ") else { return nil }
            return line.dropFirst("printer ".count).split(separator: " ").first.map(String.init)
        }
        let defaultResult = try run("/usr/bin/lpstat", arguments: ["-d"])
        let defaultName = defaultResult.output.components(separatedBy: "system default destination: ").last
        return (Array(Set(names)).sorted(), defaultResult.status == 0 ? defaultName : nil)
    }

    static func submit(pdf: URL, printer: String, pageRange: String?) throws -> String {
        var args = ["-d", printer,
                    "-o", "media=Custom.144x72pt",
                    "-o", "fit-to-page"]
        if let pageRange, !pageRange.isEmpty {
            args += ["-o", "page-ranges=\(pageRange)"]
        }
        args.append(pdf.path)
        let result = try run("/usr/bin/lp", arguments: args)
        guard result.status == 0 else {
            throw NSError(domain: "SquareRolloPrinter", code: Int(result.status),
                          userInfo: [NSLocalizedDescriptionKey: result.output.isEmpty ? "The print command failed." : result.output])
        }
        return result.output.isEmpty ? "Print job submitted." : result.output
    }
}
