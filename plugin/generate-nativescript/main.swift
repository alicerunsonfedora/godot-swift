import ArgumentParser
import PackageModel
import PackageLoading
import TSCBasic

extension AbsolutePath:ExpressibleByArgument 
{
    public
    init?(argument:String)
    {
        try? self.init(validating: argument)
    }
}

struct Main:ParsableCommand {    
    @Option(help: "the workspace directory for this tool")
    var workspace:AbsolutePath
    
    @Option(help: "the stage-independent output file to generate")
    var outputCommon:AbsolutePath
    @Option(help: "the stage-dependent output file to generate")
    var outputStaged:AbsolutePath
    
    @Option(help: "the name of the target")
    var target:String
    //@Option(help: "the name of the module")
    //var module:String
    @Option(help: "the path to the package")
    var packagePath:AbsolutePath

    
    private static 
    func product(at path:AbsolutePath, containing target:String, toolchain:AbsolutePath) 
        -> (package:String, product:String, path:AbsolutePath)
    {
        guard let manifest:Manifest = (try? tsc_await 
        { 
            ManifestLoader.loadManifest(at: path, kind: .local, 
                swiftCompiler:      toolchain, 
                swiftCompilerFlags: [], 
                identityResolver:   DefaultIdentityResolver.init(), 
                on:                 .global(), 
                completion:         $0) 
        })
        else 
        {
            fatalError("could not parse manifest")
        }
        
        print("searching for dynamic library products containing the target '\(target)'")
        let candidates:[String] = manifest.products.compactMap
        {
            (product:ProductDescription) -> String? in 
            if case .library(.dynamic) = product.type, product.targets.contains(target)
            {
                print("found product: '\(product.name)'")
                return product.name 
            }
            else 
            {
                return nil 
            }
        }
        
        guard let product:String = candidates.first 
        else 
        {
            fatalError("no dynamic library products containing the target '\(target)' were found")
        }
        if candidates.count > 1 
        {
            print("warning: multiple candidate products found, using '\(product)'")
        }
        else 
        {
            print("using product: '\(product)'")
        }
        
        return (manifest.name, product, path)
    }
    
    private static 
    func toolchain() -> AbsolutePath
    {
        // locate toolchain 
        let invocation:[String]
        
        #if os(macOS)
        invocation = ["xcrun", "--sdk", "macosx", "-f", "swiftc"]
        #else
        invocation = ["which", "swiftc"]
        #endif
        
        guard let output:String = try? Process.checkNonZeroExit(arguments: invocation) 
        else 
        {
            fatalError("could not locate swift toolchain")
        }
        
        return .init(output.spm_chomp())
    }
    
    mutating 
    func run() throws
    {
        // locate toolchain. this gives the `swiftc` tool, not the `swift` tool!
        let toolchain:AbsolutePath = Self.toolchain()
        
    #if BUILD_STAGE_INERT 
        Synthesizer.generate(staged: self.outputStaged)
    #else  
        print(bold: "starting two-stage build...")
        // get basic information about the package 
        let dependency:(package:String, product:String, path:AbsolutePath) = 
            Self.product(at: self.packagePath, containing: self.target, toolchain: toolchain)
        
        let interfaces:[Inspector.Interface] = 
            try Inspector.inspect(workspace: self.workspace, toolchain: toolchain, dependency: dependency)
        
        Synthesizer.generate(staged: self.outputStaged, interfaces: interfaces)
        
        // output library configuration file
        Source.generate(file: self.workspace.appending(component: "library.json")) 
        {
            """
            {
                "product": "\(dependency.product)", 
                "symbols": \(interfaces.flatMap(\.type.symbols))
            }
            """
        }
    
    #endif
        // generate stage-independent code
        Synthesizer.generate(common: self.outputCommon)
    }
}

Main.main()
