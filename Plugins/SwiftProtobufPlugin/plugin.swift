import PackagePlugin
 
@main
struct SwiftProtobufPlugin: BuildToolPlugin {
    
    func createBuildCommands(context: TargetBuildContext) throws -> [Command] {

        // We will generate an invocation of `protoc` for each input file, passing
        // it the path of the `protoc-gen-swift` generator tool.
        let protocPath = try context.tool(named: "protoc").path
        let protocGenSwiftPath = try context.tool(named: "protoc-gen-swift").path

        // Construct the search paths for the .proto files, which can include any of the
        // targets in the dependency closure. Here we assume that the public ones are in
        // a "protos" directory, but this can be made arbitrarily complex.
        var protoSearchPaths = [context.targetDirectory]
        protoSearchPaths.append(contentsOf: context.dependencies.map { target in
            target.targetDirectory.appending("protos")
        })

        // Add the search path to the system proto files. This sample implementation assumes
        // that they are located relative to the `protoc` compiler provided by the binary
        // target, but real implementation could be more sophisticated.
        protoSearchPaths.append(protocPath.removingLastComponent().removingLastComponent().appending("include"))

        print(protoSearchPaths)

        // Iterate over the .proto input files, creating a command for each.
        let inputFiles = context.inputFiles.filter { $0.path.extension == "proto" }
        return inputFiles.map { inputFile in
            // Construct the `protoc` arguments.
            var arguments = [
                "--plugin=protoc-gen-swift=\(protocGenSwiftPath)",
                "--swift_out=\(context.pluginWorkDirectory)",
                // "--swift_opt=ProtoPathModuleMappings=\(moduleMappingFile)"
            ]
            arguments.append(contentsOf: protoSearchPaths.flatMap { ["-I", "\($0)"] })
            arguments.append("\(inputFile.path)")
            
            // The name of the output file is based on the name of the input file, in a way
            // that's determined by the protoc source generator plug-in we're using.
            let outputName = inputFile.path.stem + ".pb.swift"
            let outputPath = context.pluginWorkDirectory.appending(outputName)
            
            // Construct the command. Specifying the input and output paths lets the build
            // system know when to invoke the command. The output paths are passed on to
            // the rule engine in the build system.
            return .buildCommand(
                displayName: "Generating \(outputName) from \(inputFile.path.lastComponent)",
                executable: protocPath,
                arguments: arguments,
                inputFiles: [protocGenSwiftPath, inputFile.path],
                outputFiles: [outputPath])
        }
    }
}
