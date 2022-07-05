import PackagePlugin
import Foundation

@main
struct SwiftProtobufPlugin: BuildToolPlugin {

    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        // We will generate an invocation of `protoc` for each input file, passing
        // it the path of the `protoc-gen-swift` generator tool.

        // We only generate commands for source targets.
        guard let target = target as? SourceModuleTarget else { return [] }

        // In this case we generate an invocation of `protoc` for each input file,
        // passing it the path of the `protoc-gen-swift` generator tool.
        let protocPath = try context.tool(named: "protoc").path
        let protocGenSwiftPath = try context.tool(named: "protoc-gen-swift").path

        // This example configures the commands to write to a "GeneratedSources"
        // directory.
        let genSourcesDir = context.pluginWorkDirectory.appending("GeneratedSources")

        // Construct the search paths for the .proto files, which can include any of the
        // targets in the dependency closure. Here we assume that the public ones are in
        // a "protos" directory, but this can be made arbitrarily complex.
        var protoSearchPaths = [target.directory] + target.recursiveTargetDependencies.map {
            $0.directory.appending("protos")
        }

        // Add the search path to the system proto files. This implementation assumes
        // that they're located relative to the `protoc` compiler provided by the binary
        // target, but real implementation could be more sophisticated.
        protoSearchPaths.append(protocPath.removingLastComponent().removingLastComponent().appending("include"))

        // Iterate over the .proto input files, creating a command for each.
        let inputFiles = target.sourceFiles.filter { $0.path.extension == "proto" }
        return inputFiles.map { inputFile in            
            // Construct the `protoc` arguments.
            var protocArgs = [
                "--plugin=protoc-gen-swift=\(protocGenSwiftPath)",
                "--swift_out=\(genSourcesDir)",
                // "--swift_opt=ProtoPathModuleMappings=\(moduleMappingFile)"
            ]
            protocArgs.append(contentsOf: protoSearchPaths.flatMap { ["-I", "\($0)"] })
            protocArgs.append("\(inputFile.path)")

            // The name of the output file is based on the name of the input file, in a way
            // that's determined by the protoc source generator plug-in we're using.
            let outputName = inputFile.path.stem + ".pb.swift"
            let outputPath = genSourcesDir.appending(outputName)

            // Construct the command. Specifying the input and output paths lets the build
            // system know when to invoke the command. The output paths are passed on to
            // the rule engine in the build system.
            return .buildCommand(
                displayName: "Generating \(outputName) from \(inputFile.path.lastComponent)",
                executable: protocPath,
                arguments: protocArgs,
                inputFiles: [protocGenSwiftPath, inputFile.path],
                outputFiles: [outputPath])
        }
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension SwiftProtobufPlugin: XcodeBuildToolPlugin {

    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        // We will generate an invocation of `protoc` for each input file, passing
        // it the path of the `protoc-gen-swift` generator tool.

        // In this case we generate an invocation of `protoc` for each input file,
        // passing it the path of the `protoc-gen-swift` generator tool.
        let protocPath = try context.tool(named: "protoc").path
        let protocGenSwiftPath = try context.tool(named: "protoc-gen-swift").path

        // This example configures the commands to write to a "GeneratedSources"
        // directory.
        let genSourcesDir = context.pluginWorkDirectory.appending("GeneratedSources")

        // Add the search path to the system proto files. This implementation assumes
        // that they're located relative to the `protoc` compiler provided by the binary
        // target, but real implementation could be more sophisticated.
        let protoSearchPaths = [protocPath.removingLastComponent().removingLastComponent().appending("include")]

        // Iterate over the .proto input files, creating a command for each.
        let inputFiles = target.inputFiles.filter { $0.path.extension == "proto" }
        return inputFiles.map { inputFile in            
            // Construct the `protoc` arguments.
            var protocArgs = [
                "--plugin=protoc-gen-swift=\(protocGenSwiftPath)",
                "--proto_path=\(inputFile.path.removingLastComponent())",
                "--swift_out=\(genSourcesDir)",
                // "--swift_opt=ProtoPathModuleMappings=\(moduleMappingFile)"
            ]
            protocArgs.append(contentsOf: protoSearchPaths.flatMap { ["-I", "\($0)"] })
            protocArgs.append("\(inputFile.path)")

            // The name of the output file is based on the name of the input file, in a way
            // that's determined by the protoc source generator plug-in we're using.
            let outputName = inputFile.path.stem + ".pb.swift"
            let outputPath = genSourcesDir.appending(outputName)

            // Construct the command. Specifying the input and output paths lets the build
            // system know when to invoke the command. The output paths are passed on to
            // the rule engine in the build system.
            return .buildCommand(
                displayName: "Generating \(outputName) from \(inputFile.path.lastComponent)",
                executable: protocPath,
                arguments: protocArgs,
                inputFiles: [protocGenSwiftPath, inputFile.path],
                outputFiles: [outputPath])
        }
    }
}

#endif
