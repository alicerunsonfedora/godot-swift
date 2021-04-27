import struct TSCBasic.ByteString
import struct TSCBasic.AbsolutePath
import var TSCBasic.localFileSystem

import class Foundation.JSONDecoder

enum Godot 
{    
    struct Class:Codable 
    {
        enum API:String, Codable 
        {
            case core   = "core"
            case tools  = "tools"
        }
        
        struct Argument:Codable 
        {
            let name:String
            let type:String
            //let defaulted:Bool
            let `default`:String

            enum CodingKeys:String, CodingKey 
            {
                case name       = "name"
                case type       = "type"
                //case defaulted  = "has_default_value"
                case `default`  = "default_value"
            }
        }
        
        struct Signal:Codable 
        {
            let name:String
            let arguments:[Argument]
        }
        
        struct Property:Codable 
        {
            let name:String
            let type:String
            let getter:String
            let setter:String
            let index:Int
        }
        
        struct Method:Codable 
        {
            let name:String 
            let arguments:[Argument]
            let `return`:String
            
            let editor:Bool
            let noscript:Bool
            let nonmutating:Bool
            //let reverse:Bool
            let virtual:Bool 
            let variadic:Bool 
            //let fromScript:Bool

            enum CodingKeys:String, CodingKey 
            {
                case name           = "name"
                case arguments      = "arguments"
                case `return`       = "return_type"
                
                case editor         = "is_editor"
                case noscript       = "is_noscript"
                case nonmutating    = "is_const"
                //case reverse        = "is_reverse"
                case virtual        = "is_virtual"
                case variadic       = "has_varargs"
                // case fromScript     = "is_from_script"
            }
        }
        
        struct Enumeration:Codable 
        {
            let name:String
            let cases:[String: Int]
            
            enum CodingKeys:String, CodingKey 
            {
                case name   = "name"
                case cases  = "values"
            }
        }
        
        let name:String 
        let parent:String
        
        let api:API 
        
        //var singleton:Bool
        let singleton:String
        
        let instantiable:Bool 
        let managed:Bool
        
        let constants:[String: Int]
        
        let properties:[Property]
        let methods:[Method]
        let signals:[Signal]
        let enumerations:[Enumeration]

        enum CodingKeys:String, CodingKey 
        {
            case name           = "name"
            case parent         = "base_class"
            case api            = "api_type"
            case singleton      = "singleton_name"
            case instantiable   = "instanciable"
            case managed        = "is_reference"
            case constants      = "constants" 
            case properties     = "properties"
            case signals        = "signals"
            case methods        = "methods"
            case enumerations   = "enums"
        }
    }
}

struct Words:Equatable, CustomStringConvertible
{
    private 
    var components:[String]
    //let original:String
    
    // symbol name mappings 
    static 
    func name(class original:String) -> Self
    {
        let reconciled:String 
        switch original
        {
        case "Object":          reconciled = "AnyDelegate"
        case "Reference":       reconciled = "AnyObject"
        // fix problematic names 
        case "NativeScript":    reconciled = "NativeScriptDelegate"
        case let original:      reconciled = original 
        }
        
        var words:Self = .split(pascal: reconciled)
        words.normalize()
        
        return words 
    }
    static 
    func name(enumeration original:String, scope:Words) -> Self
    {
        let reconciled:String
        switch ("\(scope)", original)
        {
        // fix problematic names 
        case ("VisualShader", "Type"):  reconciled = "Shader"
        case ("IP", "Type"):            reconciled = "Version"
        case let (_, original):         reconciled = original
        }
        
        var words:Self = .split(pascal: reconciled)
        words.normalize()
        words.factor(out: scope)
        
        return words
    }
    static 
    func name(constant original:String, scope:Words) -> Self
    {
        var words:Self = .split(snake: original)
        words.normalize()
        words.factor(out: scope)
        return words
    }
    
    static 
    func split(pascal:String) -> Self 
    {
        var words:[String]  = []
        var word:String     = ""
        for character:Character in pascal 
        {
            if  character.isUppercase, 
                let last:Character = word.last, last.isLowercase 
            {
                words.append(word)
                word = ""
            }
            // remove internal underscores (keep leading underscores)
            if character == "_", !word.isEmpty
            {
                words.append(word)
                word = ""
            }
            else 
            {
                // if starting a new word, make sure it starts with an 
                // uppercase letter (needed for `Tracking_status`)
                if word.isEmpty, character.isLowercase 
                {
                    word.append(character.uppercased())
                }
                else 
                {
                    word.append(character)
                }
            }
        }
        
        if !word.isEmpty 
        {
            words.append(word)
        }
        //return .init(components: words, original: pascal)
        return .init(components: words)
    }
    
    static 
    func split(snake:String) -> Self
    {
        let components:[String] = snake.uppercased().split(separator: "_").map
        { 
            if let head:Character = $0.first 
            {
                return "\(head)\($0.dropFirst().lowercased())"
            }
            else 
            {
                // should never have empty subsequences 
                return .init($0)
            }
        }
        // preserve leading underscore if present 
        if let head:String = components.first, snake.prefix(1) == "_" 
        {
            //return .init(components: ["_\(head)"] + components.dropFirst(), original: snake)
            return .init(components: ["_\(head)"] + components.dropFirst())
        }
        else 
        {
            //return .init(components: components, original: snake)
            return .init(components: components)
        }
    }
    
    // expands unswifty abbreviations, and fix some strange spellings 
    mutating 
    func normalize() 
    {
        for i:Int in self.components.indices.dropLast() 
        {
            if self.components[i ..< i + 2] == ["Counter", "Clockwise"] 
            {
                self.components[i    ] = "Counterclockwise"
                self.components[i + 1] = ""
            }
        }
        self.components = self.components.compactMap 
        {
            switch $0 
            {
            case "":        return  nil
            case "Func":    return "Function"
            case "Op":      return "Operator"
            case "Len":     return "Length"
            case "Interp":  return "Interpolation"
            case "Mult":    return "Multiplication"
            case "Param":   return "Parameter"
            case "Poly":    return "Polygon"
            case "Assign":  return "Assignment"
            case "Ref":     return "Reference"
            case "Lib":     return "Library"
            case "Mem":     return "Memory"
            case "Tex":     return "Texture"
            case "Subdiv":  return "Subdivision"
            case "Accel":   return "Acceleration"
            case "Anim":    return "Animation"
            case "Expo":    return "Exponential"
            case let word:  return word
            }
        }
    }
    // strips meaningless prefixes
    mutating 
    func factor(out other:Self) 
    {
        // most nested types have the form 
        // scope:   'Foo' 'Bar' 'Baz' 
        // nested:        'Bar' 'Baz' 'Qux'
        // 
        // we want to reduce it to just 'Qux'
        for i:Int in (0 ... min(self.components.count - 1, other.components.count)).reversed()
        {
            // do not factor if it would result in the identifier 'Type', or 
            // an identifier that would begin with a numeral 
            if  self.components.prefix(i)    == other.components.suffix(i), 
                self.components.dropFirst(i) != ["Type"]
            {
                if self.components.dropFirst(i).first?.first?.isNumber ?? true
                {
                    continue 
                }
                
                self.components.removeFirst(i)
                return 
            }
        }
    }
    
    static 
    func greatestCommonPrefix(among group:[Self]) -> Self 
    {
        var prefix:[String] = []
        for i:Int in 0 ..< (group.map(\.components.count).min() ?? 0)
        {
            let unique:Set<String> = .init(group.map(\.components[i]))
            if let first:String = unique.first, unique.count == 1 
            {
                prefix.append(first)
            }
            else 
            {
                break 
            }
        }
        //return .init(components: prefix, original: "")
        return .init(components: prefix)
    }
    
    var description:String 
    {
        self.components.joined()
    }
    var camelcased:String 
    {
        if let head:String = self.components.first?.lowercased() 
        {
            let normalized:String 
            if self.components.dropFirst().isEmpty
            {
                // escape keywords 
                switch head 
                {
                case    "init":
                    normalized = "initialize"
                case    "func":            
                    normalized = "function"
                case    "continue", "class", "default", "in", "import", 
                        "operator", "repeat", "self", "static":  
                    normalized = "`\(head)`"
                case let head: 
                    normalized = head 
                }
            }
            else 
            {
                normalized = head 
            }
            return "\(normalized)\(self.components.dropFirst().joined())"
        }
        else 
        {
            return self.description
        }
    }
}


extension Godot.Class 
{
    final 
    class Node 
    {
        enum KnownType:Hashable 
        {
            case void 
            case bool 
            case int 
            case float 
            case vector2
            case vector3
            case vector4
            
            case quaternion 
            case plane3
            case rectangle2 
            case rectangle3
            case affine2 
            case affine3
            case linear3
            case resourceIdentifier
            
            case list 
            case map 
            case nodePath
            case string 
            
            case uint8Array
            case int32Array
            case float32Array
            case stringArray
            case vector2Array
            case vector3Array
            case vector4Array
            
            case object(String)
            case enumeration(String)
            
            case variant
        }
        
        enum Namespace:String, CustomStringConvertible
        {
            case root       = "Godot"
            case unmanaged  = "Godot.Unmanaged"
            case singleton  = "Godot.Singleton"
            
            var description:String 
            {
                self.rawValue
            }
        }
        
        struct Property 
        {
            struct Key:Hashable 
            {
                let symbol:String 
                var name:Words 
                {
                    .split(snake: self.symbol)
                }
            }
            
            struct Accessor 
            {
                unowned  
                let node:Node
                let index:Dictionary<Method.Key, Method>.Index
            }
            
            let get:Accessor,
                set:Accessor? 
            let index:Int?
            let type:KnownType 
            
            var `is`:(final:Bool, override:Bool)
        } 
        struct Method 
        {
            struct Key:Hashable 
            {
                let symbol:String 
                var name:Words 
                {
                    .split(snake: self.symbol)
                }
            }
            
            var parameters:[(label:String, type:KnownType)]
            let `return`:KnownType
             
            var `is`:(final:Bool, override:Bool, hidden:Bool)
        }
        
        struct Enumeration 
        {
            let symbol:String
            let name:Words 
            let cases:[(name:Words, rawValue:Int)]
        }
        
        let symbol:String 
        let name:Words, 
            namespace:Namespace 
        let `is`:(instantiable:Bool, singleton:Bool, managed:Bool)
        
        private(set) weak
        var parent:Node?
        private(set)
        var children:[Node]
        
        // members 
        let enumerations:[Enumeration]
        let constants:[(name:Words, value:Int)]
        private(set)
        var properties:[Property.Key: Property], 
            methods:[Method.Key: Method] 
        
        // member descriptors
        private 
        var unresolved:
        (
            properties:[Godot.Class.Property],
            functions:[Godot.Class.Method]
        )
        
        init(descriptor:Godot.Class) 
        {    
            self.symbol     = descriptor.name
            self.parent     = nil 
            self.children   = []
            
            let namespace:Namespace, 
                name:Words 
            if descriptor.singleton.isEmpty 
            {
                self.is = 
                (
                    instantiable:  descriptor.instantiable,
                    singleton:      false, 
                    // https://github.com/godotengine/godot-cpp/issues/432
                    // api.json bug: 
                    //      `Godot::Reference` is not tagged as managed, but is actually managed
                    managed:       descriptor.managed || descriptor.name == "Reference"
                )
                namespace   = self.is.managed || descriptor.name == "Object" ? .root : .unmanaged
                name        = .name(class: descriptor.name)
            }
            else 
            {
                self.is =
                (
                    instantiable:   false,
                    singleton:      true,
                    // https://github.com/godotengine/godot/pull/36506 
                    // api.json bug: 
                    //      `Godot::_Marshalls` is tagged as subclass of 
                    //      `Godot::Reference` (Godot.Object), but is actually a 
                    //      subclass of `Godot::Object` (Godot.Unmanaged). 
                    //      
                    //      however, this only affects singletons, which we import as 
                    //      unmanaged anyway.
                    managed:        false
                ) 
                namespace   = .singleton 
                name        = .name(class: descriptor.singleton)
            }
            
            self.enumerations = descriptor.enumerations.map 
            {
                (enumeration:Godot.Class.Enumeration) in 
                
                var cases:[(name:Words, rawValue:Int)] = enumeration.cases.map 
                {
                    var name:Words = .split(snake: $0.key)
                    name.normalize()
                    return (name, $0.value)
                }
                .sorted 
                {
                    $0.rawValue < $1.rawValue
                }
                let prefix:Words    = .greatestCommonPrefix(among: cases.map(\.name))
                for i:Int in cases.indices 
                {
                    cases[i].name.factor(out: prefix)
                }
                return .init(symbol: enumeration.name, 
                    name: .name(enumeration: enumeration.name, scope: name), 
                    cases: cases)
            }
            self.constants = descriptor.constants.map 
            {
                (.name(constant: $0.key, scope: name), $0.value)
            }
            .sorted 
            {
                $0.name.camelcased < $1.name.camelcased
            }
            
            self.namespace  = namespace 
            self.name       = name 
            self.properties = [:]
            self.methods    = [:]
            
            self.unresolved = 
            (
                properties: descriptor.properties, 
                functions:  descriptor.methods
            )
        }
    }
}
extension Godot.Class.Node 
{
    func append(child:Godot.Class.Node) 
    {
        child.parent = self
        self.children.append(child)
    }
    
    var preorder:[Godot.Class.Node] 
    {
        [self] + self.children.flatMap(\.preorder)
    }
    var leaves:[Godot.Class.Node] 
    {
        self.children.isEmpty ? [self] : self.children.flatMap(\.leaves)
    }
}
extension Godot.Class.Node 
{
    func resolve() 
    {
        // build type database 
        var types:[String: KnownType] = 
        [
            "void"              :   .void,
            "bool"              :   .bool,
            "int"               :   .int,
            "float"             :   .float,
            "Vector2"           :   .vector2,
            "Vector3"           :   .vector3,
            "Color"             :   .vector4,
            
            "Quat"              :   .quaternion,
            "Plane"             :   .plane3,
            "Rect2"             :   .rectangle2,
            "AABB"              :   .rectangle3,
            "Transform2D"       :   .affine2,
            "Transform"         :   .affine3,
            "Basis"             :   .linear3,
            "RID"               :   .resourceIdentifier,
            
            "NodePath"          :   .nodePath,
            "String"            :   .string,
            "Array"             :   .list,
            "Dictionary"        :   .map,
            
            "PoolByteArray"     :   .uint8Array,
            "PoolIntArray"      :   .int32Array,
            "PoolRealArray"     :   .float32Array,
            "PoolStringArray"   :   .stringArray,
            "PoolVector2Array"  :   .vector2Array,
            "PoolVector3Array"  :   .vector3Array,
            "PoolColorArray"    :   .vector4Array,
            
            "Variant"           :   .variant,
            // hacks
            //"enum.Variant::Type"        :   .unsupported,
            //"enum.Variant::Operator"    :   .unsupported,
            //"enum.Error"                :   .unsupported,
        ]
        
        for node:Godot.Class.Node in self.preorder
        {
            let symbol:String   = node.symbol, 
                type:KnownType  = .object("\(node.namespace).\(node.name)")
            guard types.updateValue(type, forKey: symbol) == nil 
            else 
            {
                fatalError("duplicate class 'Godot::\(symbol)'")
            }
            
            for enumeration:Enumeration in node.enumerations
            {
                let symbol:String = "enum.\(symbol)::\(enumeration.symbol)", 
                    type:KnownType = .enumeration(
                        "\(node.namespace).\(node.name).\(enumeration.name)")
                guard types.updateValue(type, forKey: symbol) == nil
                else 
                {
                    fatalError("duplicate enum '\(symbol)'")
                }
            }
        }
        
        self.resolve(types: types)
    }
    private 
    func resolve(types:[String: KnownType]) 
    {
        outer:
        for method:Godot.Class.Method in self.unresolved.functions
        {
            var description:String 
            {
                "Godot::\(self.symbol)::\(method.name)"
            }
            
            var parameters:[(label:String, type:KnownType)] = []
            for argument:Godot.Class.Argument in method.arguments
            {
                guard let type:KnownType = types[argument.type]
                else 
                {
                    print("skipping method '\(description)' (unknown parameter type: \(argument.type))")
                    continue outer 
                }
                
                // fix problematic labels 
                let label:String 
                if  argument.name.prefix(3) == "arg", 
                    argument.name.dropFirst(3).allSatisfy(\.isNumber)
                {
                    label = "_"
                }
                else 
                {
                    label = Words.split(snake: argument.name).camelcased 
                }
                parameters.append((label, type))
            }
            guard let `return`:KnownType = types[method.return] 
            else 
            {
                print("skipping method '\(description)' (unknown return type: \(method.return))")
                continue outer 
            }
            
            var method:(key:Method.Key, value:Method) = 
            (
                .init(symbol: method.name), 
                .init(parameters: parameters, return: `return`, 
                    is: (final: true, override: false, hidden: false))
            )
            // look for overridden methods 
            var current:Godot.Class.Node = self 
            while let superclass:Godot.Class.Node = current.parent 
            {
                if let overridden:Dictionary<Method.Key, Method>.Index = 
                    superclass.methods.index(forKey: method.key)
                {
                    // sanity check 
                    guard                            method.value.parameters.map(\.type) == 
                            superclass.methods.values[overridden].parameters.map(\.type),
                                                     method.value.return == 
                            superclass.methods.values[overridden].return
                    else 
                    {
                        print("skipping method '\(description)' (mismatched signatures)")
                        continue outer 
                    }
                    
                    // replace labels, since swift requires all overriding 
                    // methods to have the same argument labels
                    method.value.is.override  = true 
                    method.value.parameters   = superclass.methods.values[overridden].parameters 
                    
                    superclass.methods.values[overridden].is.final = false 
                    break 
                }
                current = superclass 
            }
            
            guard self.methods.updateValue(method.value, forKey: method.key) == nil 
            else 
            {
                fatalError("duplicate method '\(description)'")
            }
        }
        
        // frame properties in Godot::AnimatedTexture seem to be specialized 
        // by index from 0 ... 255, ignore for now 
        outer:
        for property:Godot.Class.Property in self.unresolved.properties
            where !property.name.contains("/") 
        {
            var description:String
            {
                "property 'Godot::\(self.symbol)::\(property.name)'"
            }
            
            let index:Int? = property.index == -1 ? nil : property.index 
            let accessor:(get:Property.Accessor, set:Property.Accessor?)
            let getter:Method, 
                setter:Method?
            
            // find getter 
            if let get:Property.Accessor = self.lookup(method: .init(symbol: property.getter))
            {
                accessor.get    = get 
                getter          = get.node.methods.values[get.index]
                
                get.node.methods.values[get.index].is.hidden = true 
            }
            else 
            {
                print("skipping \(description) (could not find getter)")
                continue outer
            }
            // find setter 
            if property.setter.isEmpty 
            {
                accessor.set    = nil 
                setter          = nil 
            }
            else if let set:Property.Accessor = self.lookup(method: .init(symbol: property.setter))
            {
                accessor.set    = set 
                setter          = set.node.methods.values[set.index]
                
                set.node.methods.values[set.index].is.hidden = true 
            }
            else 
            {
                print("skipping \(description) (could not find setter)")
                continue outer
            }
            
            // sanity check 
            if let _:Int = index 
            {
                guard   case .int? = getter.parameters.first?.type, 
                        getter.parameters.count == 1
                else 
                {
                    fatalError("malformed getter for \(description)")
                }
            }
            else 
            {
                guard   getter.parameters.isEmpty 
                else 
                {
                    fatalError("malformed getter for \(description)")
                }
            }
            if let setter:Method = setter
            {
                guard let other:KnownType = setter.parameters.last?.type
                else 
                {
                    fatalError("malformed setter for \(description)")
                }
                if let _:Int = index 
                {
                    guard   case .int? = setter.parameters.first?.type,
                            setter.parameters.count == 2
                    else 
                    {
                        fatalError("malformed setter for \(description)")
                    }
                }
                else 
                {
                    guard   setter.parameters.count == 1
                    else 
                    {
                        fatalError("malformed setter for \(description)")
                    }
                }
                // some setters seem to have return values, skip them for now 
                guard case .void = setter.return
                else 
                {
                    print("skipping \(description) (unsupported setter return type: \(setter.return))")
                    continue outer 
                }
                
                switch (getter.return, other)
                {
                case (.enumeration, .int): 
                    break // okay 
                case (let get, let set):
                    guard get == set 
                    else 
                    {
                        fatalError("getter type (\(get)) for \(description) does not match setter type (\(set))")
                    }
                }
            }
            
            var property:(key:Property.Key, value:Property) = 
            (
                .init(symbol: property.name), 
                .init(get: accessor.get, set: accessor.set, index: index, 
                    type: getter.return, is: (final: true, override: false))
            )
            // look for overridden properties 
            var current:Godot.Class.Node = self 
            while let superclass:Godot.Class.Node = current.parent 
            {
                if let overridden:Dictionary<Property.Key, Property>.Index = 
                    superclass.properties.index(forKey: property.key)
                {
                    // sanity check 
                    guard property.value.type == superclass.properties.values[overridden].type
                    else 
                    {
                        print("skipping property '\(description)' (mismatched override signature)")
                        continue outer 
                    }
                    
                    property.value.is.override                          = true 
                    superclass.properties.values[overridden].is.final   = false 
                    break 
                }
                current = superclass 
            }
            
            guard self.properties.updateValue(property.value, forKey: property.key) == nil 
            else 
            {
                fatalError("duplicate property '\(description)'")
            }
        } 
        
        // hide builtins 
        for symbol:(class:String, function:String) in 
        [
            ("Object",      "emit_signal"),
            ("Reference",   "unreference"),
            ("Reference",   "reference"),
        ]
            where symbol.class == self.symbol 
        {
            guard let index:Dictionary<Method.Key, Method>.Index = 
                self.methods.index(forKey: .init(symbol: symbol.function))
            else 
            {
                fatalError("could not find builtin symbol 'Godot::\(symbol.class)::\(symbol.function)'")
            }
            
            self.methods.values[index].is.hidden = true 
        }
        
        // recurse over children 
        for child:Godot.Class.Node in self.children 
        {
            child.resolve(types: types)
        }
    }
    private 
    func lookup(method key:Method.Key) -> Property.Accessor?
    {
        var current:Godot.Class.Node = self
        while true 
        {
            if let index:Dictionary<Method.Key, Method>.Index = 
                current.methods.index(forKey: key)
            {
                return .init(node: current, index: index)
            }
            if let next:Godot.Class.Node = current.parent 
            {
                current = next
            }
            else 
            {
                return nil 
            }
        }
    } 
}
extension Godot
{
    private static 
    func loadAPIDescription() -> [String: Class]
    {
        let path:AbsolutePath = AbsolutePath.init(#filePath)
            .parentDirectory.appending(component: "godot-api.json")
        
        guard let file:ByteString = try? TSCBasic.localFileSystem.readFileContents(path)
        else 
        {
            fatalError("could not find or read 'godot-api.json' file")
        }
        
        do 
        {
            let classes:[Class] = try JSONDecoder.init()
                .decode([Class].self, from: .init(file.contents))
            return .init(uniqueKeysWithValues: classes.map 
            {
                ($0.name, $0)
            })
        }
        catch let error 
        {
            fatalError("could not parse 'godot-api.json' file (\(error))")
        }
    }
    private static 
    func tree(descriptors:[String: Class]) -> Class.Node  
    {
        // construct inheritance tree. 
        let nodes:[String: (node:Class.Node, parent:String?)] = descriptors.mapValues 
        {
            (.init(descriptor: $0), parent: $0.parent.isEmpty ? nil : $0.parent)
        }
        // sort to provide stability in generated code 
        for (node, parent):(Class.Node, String?) in nodes.values
            .sorted(by: { "\($0.node.name)" < "\($1.node.name)" }) 
        {
            if let parent:String = parent
            {
                guard let parent:Class.Node = nodes[parent]?.node
                else 
                {
                    fatalError("missing class descriptor for class 'Godot::\(parent)'")
                }
                
                parent.append(child: node)
            }
        }
        
        guard let root:Class.Node = nodes["Object"]?.node
        else 
        {
            fatalError("missing class descriptor for class 'Godot::Object'")
        }
        
        root.resolve()
        
        return root
    }
    private static 
    func constants(descriptors:[String: Class]) -> String
    {
        guard let constants:[String: Int] = descriptors["GlobalConstants"]?.constants 
        else 
        {
            fatalError("missing class descriptor for class 'Godot::GlobalConstants'")
        }
        
        let errors:[(name:Words, code:Int)] = constants.compactMap 
        {
            // ignore "printer on fire", it seems to be an april fools joke
            if $0.key.prefix(4) == "ERR_", $0.key != "ERR_PRINTER_ON_FIRE"
            {
                return (.split(snake: .init($0.key.dropFirst(4))), $0.value)
            }
            else 
            {
                return nil 
            }
        }
        .sorted 
        {
            $0.code < $1.code
        }
        
        return Source.fragment 
        {
            "extension Godot"
            Source.block 
            {
                "enum Error:Swift.Error"
                Source.block 
                {
                    """
                    case unknown(code:Int)
                    
                    """
                    for error:(name:Words, code:Int) in errors 
                    {
                        "case \(error.name.camelcased)"
                    }
                }
            }
            "extension Godot.Error"
            Source.block 
            {
                "init(code:Int)"
                Source.block 
                {
                    """
                    switch code
                    {
                    """
                    for (name, code):(Words, Int) in errors 
                    {
                        """
                        case \(code): self = .\(name.camelcased)
                        """
                    }
                    """
                    case let unknown: self = .unknown(code: unknown)
                    }
                    """
                }
            }
        }
    }
    
    @Source.Code 
    static 
    var swift:String
    {
        let descriptors:[String: Class] = Self.loadAPIDescription()
        let root:Class.Node             = Self.tree(descriptors: descriptors)
        // `withExtendedLifetime` is important because properties hold `unowned`
        //  references to upstream nodes 
        let classes:[(node:Class.Node, definition:String)] = withExtendedLifetime(root)
        {
            root.preorder.compactMap
            {
                switch $0.name 
                {
                case    .split(pascal: "AnyDelegate"),
                        .split(pascal: "AnyObject"  ),
                        .split(pascal: "Resource"   ),
                        .split(pascal: "Node"),
                        .split(pascal: "Spatial"),
                        .split(pascal: "VisualInstance"),
                        .split(pascal: "GeometryInstance"),
                        .split(pascal: "MeshInstance"):
                    return ($0, $0.definition)
                default:
                    return nil 
                }
            }
        }
        
        Source.section(name: "global.swift.part")
        {
            Self.constants(descriptors: descriptors)
        }
        
        Source.section(name: "raw.swift.part")
        {
            for (name, unpacked):(String, String) in 
            [
                ("vector2",         "Vector2<Float32>"), 
                ("vector3",         "Vector3<Float32>"), 
                ("color",           "Vector4<Float32>"), 
                ("quat",            "Quaternion<Float32>"), 
                ("plane",           "Godot.Plane3<Float32>"), 
                ("rect2",           "Vector2<Float32>.Rectangle"), 
                ("aabb",            "Vector3<Float32>.Rectangle"), 
                ("transform2d",     "Godot.Transform2<Float32>.Affine"), 
                ("transform",       "Godot.Transform3<Float32>.Affine"), 
                ("basis",           "Godot.Transform3<Float32>.Linear"), 
                ("rid",             "Godot.ResourceIdentifier"), 
            ]
            {
                """
                extension godot_\(name):Godot.RawValue 
                {
                    static 
                    var variantCode:godot_variant_type 
                    {
                        GODOT_VARIANT_TYPE_\(name.uppercased())
                    }
                    static 
                    func unpacked(variant:Godot.Variant.Unmanaged) -> \(unpacked)? 
                    {
                        variant.load(where: Self.variantCode)
                        {
                            Godot.api.1.0.godot_variant_as_\(name)($0).unpacked
                        } 
                    }
                    static 
                    func variant(packing value:\(unpacked)) -> Godot.Variant.Unmanaged
                    {
                        withUnsafePointer(to: Self.init(packing: value)) 
                        {
                            .init(value: $0, Godot.api.1.0.godot_variant_new_\(name))
                        }
                    }
                }
                """
            }
            for name:String in 
            [
                "node_path", "string", "array", "dictionary", 
                "pool_byte_array", 
                "pool_int_array",
                "pool_real_array",
                "pool_string_array",
                "pool_vector2_array",
                "pool_vector3_array",
                "pool_color_array",
            ]
            {
                """
                extension godot_\(name):Godot.RawReference
                {
                    mutating 
                    func `deinit`()
                    {
                        Godot.api.1.0.godot_\(name)_destroy(&self)
                    }
                    
                    static 
                    var variantCode:godot_variant_type 
                    {
                        GODOT_VARIANT_TYPE_\(name.uppercased())
                    }
                }
                """
            }
            
            // generate variant hooks for pool arrays 
            for (swift, godot, array, storage):(String, String?, String, String?) in 
            [
                ("UInt8",                   nil,                "pool_byte_array",      nil),
                ("Int32",                   nil,                "pool_int_array",       nil),
                ("Float32",                 nil,                "pool_real_array",      nil),
                ("String",                  "godot_string",     "pool_string_array",    nil),
                ("Vector<Self, Scalar>",    "godot_vector2",    "pool_vector2_array",   "SIMD2"),
                ("Vector<Self, Scalar>",    "godot_vector3",    "pool_vector3_array",   "SIMD3"),
                ("Vector<Self, Scalar>",    "godot_color",      "pool_color_array",     "SIMD4"),
            ]
            {
                let type:String = storage == nil ? "Self" : swift
                if let storage:String = storage 
                {
                    "extension \(storage):Godot.ArrayElementStorage where Scalar == Float32"
                }
                else 
                {
                    "extension \(swift):Godot.ArrayElement"
                }
                Source.block 
                {
                    """
                    typealias RawArrayReference = godot_\(array)
                    
                    static 
                    func downcast(array value:Godot.Variant.Unmanaged) -> RawArrayReference?
                    {
                        value.load(where: RawArrayReference.variantCode, 
                            Godot.api.1.0.godot_variant_as_\(array))
                    }
                    static 
                    func upcast(array value:RawArrayReference) -> Godot.Variant.Unmanaged
                    {
                        withUnsafePointer(to: value) 
                        {
                            .init(value: $0, Godot.api.1.0.godot_variant_new_\(array))
                        }
                    }
                    static 
                    func convert(array godot:RawArrayReference) -> [\(type)]
                    """
                    Source.block
                    {
                        """
                        guard let lock:UnsafeMutablePointer<godot_\(array)_read_access> = 
                            withUnsafePointer(to: godot, Godot.api.1.0.godot_\(array)_read)
                        else 
                        {
                            fatalError("recieved nil pointer from `godot_\(array)_read(_:)`")
                        }
                        defer 
                        {
                            Godot.api.1.0.godot_\(array)_read_access_destroy(lock)
                        }
                        let count:Int = .init(
                            withUnsafePointer(to: godot, Godot.api.1.0.godot_\(array)_size))
                        return .init(unsafeUninitializedCapacity: count) 
                        """
                        Source.block
                        {
                            """
                            guard let source:UnsafePointer<\(godot ?? "Self")> = 
                                Godot.api.1.0.godot_\(array)_read_access_ptr(lock)
                            else 
                            {
                                fatalError("recieved nil pointer from `godot_\(array)_read_access_ptr(_:)`")
                            }
                            """
                            if let _:String = godot
                            {
                                """
                                if let base:UnsafeMutablePointer<\(type)> = $0.baseAddress 
                                {
                                    for i:Int in 0 ..< count 
                                    {
                                        (base + i).initialize(to: source[i].unpacked)
                                    }
                                }
                                """
                            }
                            else 
                            {
                                """
                                $0.baseAddress?.initialize(from: source, count: count)
                                """
                            }
                            """
                            $1 = count 
                            """
                        }
                    }
                    """
                    static 
                    func convert(array swift:[\(type)]) -> RawArrayReference
                    """
                    Source.block 
                    {
                        """
                        var array:godot_\(array) = .init(with: Godot.api.1.0.godot_\(array)_new)
                        Godot.api.1.0.godot_\(array)_resize(&array, .init(swift.count))
                        
                        guard let lock:UnsafeMutablePointer<godot_\(array)_write_access> = 
                            Godot.api.1.0.godot_\(array)_write(&array)
                        else 
                        {
                            fatalError("recieved nil pointer from `godot_\(array)_write(_:)`")
                        }
                        defer 
                        {
                            Godot.api.1.0.godot_\(array)_write_access_destroy(lock)
                        }
                        
                        guard let destination:UnsafeMutablePointer<\(godot ?? "Self")> = 
                            Godot.api.1.0.godot_\(array)_write_access_ptr(lock)
                        else 
                        {
                            fatalError("recieved nil pointer from `godot_\(array)_write_access_ptr(_:)`")
                        }
                        """
                        if let _:String = godot
                        {
                            "for (i, element):(Int, \(type)) in swift.enumerated()"
                            Source.block
                            {
                                if swift == "String" 
                                {
                                    "destination[i].deinit() // is this needed?"
                                }
                                "destination[i] = .init(packing: element)"
                            }
                        }
                        else 
                        {
                            """
                            swift.withUnsafeBufferPointer 
                            {
                                guard let base:UnsafePointer<Self> = $0.baseAddress
                                else 
                                {
                                    return 
                                }
                                destination.initialize(from: base, count: swift.count)
                            }
                            """
                        }
                        """
                        return array
                        """
                    }
                }
            }
            
            // vector conformances 
            """
            // huge amount of meaningless boilerplate needed to make numeric conversions work, 
            // since swift does not support generic associated types.
            extension Godot 
            {
                typealias VectorElement     = _GodotVectorElement
                typealias VectorStorage     = _GodotVectorStorage
                
                typealias RectangleElement  = _GodotRectangleElement
                typealias RectangleStorage  = _GodotRectangleStorage
            }
            protocol _GodotVectorElement:SIMDScalar 
            """
            Source.block 
            {
                for n:Int in 2 ... 4 
                {
                    "associatedtype Vector\(n)Aggregate:Godot.RawAggregate"
                }
                for n:Int in 2 ... 4 
                {
                    """
                    static 
                    func generalize(_ specific:Vector\(n)Aggregate.Unpacked) -> Vector\(n)<Self> 
                    """
                }
                for n:Int in 2 ... 4 
                {
                    """
                    static 
                    func specialize(_ general:Vector\(n)<Self>) -> Vector\(n)Aggregate.Unpacked 
                    """
                }
            }
            """
            protocol _GodotRectangleElement:Godot.VectorElement 
            """
            Source.block 
            {
                for n:Int in 2 ... 3 
                {
                    """
                    associatedtype Rectangle\(n)Aggregate:Godot.RawAggregate
                        where   Rectangle\(n)Aggregate.Unpacked:VectorFiniteRangeExpression, 
                                Rectangle\(n)Aggregate.Unpacked.Bound == Vector\(n)Aggregate.Unpacked
                    """
                }
            }
            """
            protocol _GodotVectorStorage:SIMD where Scalar:SIMDScalar 
            {
                associatedtype VectorAggregate:Godot.RawAggregate
                
                static 
                func generalize(_ specific:VectorAggregate.Unpacked) -> Vector<Self, Scalar> 
                static 
                func specialize(_ general:Vector<Self, Scalar>) -> VectorAggregate.Unpacked 
            }
            protocol _GodotRectangleStorage:Godot.VectorStorage 
            {
                associatedtype RectangleAggregate:Godot.RawAggregate
                    where   RectangleAggregate.Unpacked:VectorFiniteRangeExpression, 
                            RectangleAggregate.Unpacked.Bound == VectorAggregate.Unpacked
            }
            
            // need to work around type system limitations
            extension BinaryFloatingPoint where Self:SIMDScalar
            """
            Source.block 
            {
                """
                typealias Vector2Aggregate = godot_vector2
                typealias Vector3Aggregate = godot_vector3
                typealias Vector4Aggregate = godot_color
                
                typealias Rectangle2Aggregate = godot_rect2
                typealias Rectangle3Aggregate = godot_aabb
                
                """
                for n:Int in 2 ... 4 
                {
                    """
                    static 
                    func generalize(_ specific:Vector\(n)<Float32>) -> Vector\(n)<Self> 
                    {
                        .init(specific)
                    }
                    """
                }
                for n:Int in 2 ... 4 
                {
                    """
                    static 
                    func specialize(_ general:Vector\(n)<Self>) -> Vector\(n)<Float32> 
                    {
                        .init(general)
                    }
                    """
                }
            }
            for n:Int in 2 ... 4 
            {
                """
                extension SIMD\(n):Godot.VectorStorage where Scalar:Godot.VectorElement
                {
                    typealias VectorAggregate = Scalar.Vector\(n)Aggregate
                    static 
                    func generalize(_ specific:VectorAggregate.Unpacked) -> Vector\(n)<Scalar> 
                    {
                        Scalar.generalize(specific)
                    }
                    static 
                    func specialize(_ general:Vector\(n)<Scalar>) -> VectorAggregate.Unpacked
                    {
                        Scalar.specialize(general)
                    }
                }
                """
            }
            for n:Int in 2 ... 3 
            {
                """
                extension SIMD\(n):Godot.RectangleStorage where Scalar:Godot.RectangleElement
                {
                    typealias RectangleAggregate = Scalar.Rectangle\(n)Aggregate
                }
                """
            }
            for type:String in ["Float16", "Float32", "Float64"] 
            {
                "extension \(type):Godot.VectorElement, Godot.RectangleElement {}"
            }
        }
        
        Source.section(name: "passable.swift.part")
        {
            // generate `Godot.Function.Passable` conformances 
            """
            // “icall” types. these are related, but orthogonal to `Variant`/`VariantRepresentable`
            extension Godot 
            {
                struct Function 
                {
                    typealias Passable = _GodotFunctionPassable
                    
                    private 
                    let function:UnsafeMutablePointer<godot_method_bind>
                }
            }
            protocol _GodotFunctionPassable
            {
                associatedtype RawValue 
                
                static 
                func take(_ body:(UnsafeMutablePointer<RawValue>) -> ()) -> Self 
                func pass(_ body:(UnsafePointer<RawValue>?) -> ())
            }
            extension Godot.Function.Passable 
                where RawValue:Godot.RawAggregate, RawValue.Unpacked == Self
            {
                static 
                func take(_ body:(UnsafeMutablePointer<RawValue>) -> ()) -> Self 
                {
                    RawValue.init(with: body).unpacked
                }
                func pass(_ body:(UnsafePointer<RawValue>?) -> ())
                {
                    withUnsafePointer(to: .init(packing: self), body)
                }
            }
            
            // variant existential container, since protocols cannot directly 
            // conform to other protocols 
            extension Godot
            {
                fileprivate 
                struct VariantExistential 
                {
                    let variant:Variant?
                }
            }
            extension Godot.VariantExistential:Godot.Function.Passable 
            {
                static 
                func take(_ body:(UnsafeMutablePointer<godot_variant>) -> ()) -> Self 
                {
                    var unmanaged:Godot.Variant.Unmanaged = .init(with: body)
                    defer 
                    {
                        unmanaged.release()
                    }
                    return .init(variant: unmanaged.take(unretained: Godot.Variant?.self))
                }
                func pass(_ body:(UnsafePointer<godot_variant>?) -> ()) 
                {
                    Godot.Variant.Unmanaged.pass(guaranteeing: self.variant, body)
                }
            }
            extension Optional:Godot.Function.Passable where Wrapped:Godot.AnyDelegate
            {
                // for some reason, godot bound methods return objects as double pointers, 
                // but pass them as direct pointers
                static 
                func take(_ body:(UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> ()) -> Self 
                {
                    var core:UnsafeMutableRawPointer? = nil 
                    body(&core)
                    // assume caller has already retained the object
                    if  let core:UnsafeMutableRawPointer    = core,
                        let delegate:Wrapped                = 
                        Godot.type(of: core).init(retained: core) as? Wrapped
                    {
                        return delegate
                    }
                    else 
                    {
                        return nil 
                    }
                }
                func pass(_ body:(UnsafePointer<UnsafeMutableRawPointer?>?) -> ())
                {
                    withExtendedLifetime(self)
                    {
                        body(self?.core.bindMemory(to: UnsafeMutableRawPointer?.self, capacity: 1))
                    }
                }
            }
            """
            for swift:String in ["Bool", "Int64", "Float64"] 
            {
                "extension \(swift):Godot.Function.Passable"
                Source.block 
                {
                    """
                    static 
                    func take(_ body:(UnsafeMutablePointer<Self>) -> ()) -> Self 
                    {
                        var value:Self = .init()
                        body(&value)
                        return value
                    }
                    func pass(_ body:(UnsafePointer<Self>?) -> ())
                    {
                        withUnsafePointer(to: self, body)
                    }
                    """
                }
            }
            """
            extension Vector:Godot.Function.Passable 
                where Storage:Godot.VectorStorage, Storage.VectorAggregate.Unpacked == Self
            {
                typealias RawValue = Storage.VectorAggregate
            }
            extension Vector.Rectangle:Godot.Function.Passable 
                where Storage:Godot.RectangleStorage, Storage.RectangleAggregate.Unpacked == Self
            {
                typealias RawValue = Storage.RectangleAggregate
            }
            """
            for (swift, godot, conditions):(String, String, String) in 
            [
                ("Quaternion",              "godot_quat",       "where T == Float32"),
                ("Godot.Plane3",            "godot_plane",      "where T == Float32"),
                ("Godot.Transform2.Affine", "godot_transform2d","where T == Float32"),
                ("Godot.Transform3.Affine", "godot_transform",  "where T == Float32"),
                ("Godot.Transform3.Linear", "godot_basis",      "where T == Float32"),
                ("Godot.ResourceIdentifier","godot_rid",        ""),
            ]
            {
                """
                extension \(swift):Godot.Function.Passable \(conditions)
                {
                    typealias RawValue = \(godot)
                }
                """
            }
            for (swift, godot):(String, String) in 
            [
                ("Godot.List",      "godot_array"),
                ("Godot.Map",       "godot_dictionary"),
                ("Godot.NodePath",  "godot_node_path"),
                ("Godot.String",    "godot_string"),
                ("Godot.Array",     "Element.RawArrayReference"),
            ]
            {
                """
                extension \(swift):Godot.Function.Passable 
                {
                    static 
                    func take(_ body:(UnsafeMutablePointer<\(godot)>) -> ()) -> Self 
                    {
                        .init(retained: .init(with: body))
                    }
                    func pass(_ body:(UnsafePointer<\(godot)>?) -> ())
                    {
                        withExtendedLifetime(self)
                        {
                            withUnsafePointer(to: self.core, body)
                        }
                    }
                }
                """
            }
            """
            extension String:Godot.Function.Passable 
            {
                static 
                func take(_ body:(UnsafeMutablePointer<godot_string>) -> ()) -> Self 
                {
                    var core:godot_string = .init(with: body)
                    defer 
                    {
                        core.deinit()
                    }
                    return core.unpacked
                }
                func pass(_ body:(UnsafePointer<godot_string>?) -> ())
                {
                    var core:godot_string = .init(packing: self)
                    withUnsafePointer(to: core, body)
                    core.deinit()
                }
            }
            extension Array:Godot.Function.Passable where Element:Godot.ArrayElement
            {
                static 
                func take(_ body:(UnsafeMutablePointer<Element.RawArrayReference>) -> ()) -> Self 
                {
                    var core:Element.RawArrayReference = .init(with: body)
                    defer 
                    {
                        core.deinit()
                    }
                    return Element.convert(array: core)
                }
                func pass(_ body:(UnsafePointer<Element.RawArrayReference>?) -> ())
                {
                    var core:Element.RawArrayReference = Element.convert(array: self)
                    withUnsafePointer(to: core, body)
                    core.deinit()
                }
            }
            """
        }
        
        Source.section(name: "convention.swift.part")
        {
            // determine longest required icall template 
            let arity:Int = root.preorder
                .flatMap{ $0.methods.values.map(\.parameters.count) }
                .max() ?? 0
            """
            extension Godot.Function 
            """
            Source.block 
            {
                """
                func callAsFunction(delegate:Godot.AnyDelegate, variants:[Godot.Variant.Unmanaged]) 
                {
                    withExtendedLifetime(delegate) 
                    {
                        variants.withUnsafeBufferPointer
                        {
                            $0.withMemoryRebound(to: godot_variant.self) 
                            {
                                guard let base:UnsafePointer<godot_variant> = $0.baseAddress 
                                else 
                                {
                                    return 
                                }
                                var pointers:[UnsafePointer<godot_variant>?] = $0.indices.map 
                                {
                                    base + $0
                                }
                                // discard the return value 
                                var result:godot_variant = pointers.withUnsafeMutableBufferPointer 
                                {
                                    Godot.api.1.0.godot_method_bind_call(self.function, delegate.core, 
                                        $0.baseAddress, .init($0.count), nil)
                                }
                                Godot.api.1.0.godot_variant_destroy(&result)
                            }
                        }
                    }
                }
                """
                for k:Int in 0 ... arity 
                {
                    Self.template(arity: k)
                }
            }
        }
        
        Source.section(name: "delegates.swift.part")
        {
            "extension Godot"
            Source.block 
            {
                """
                enum Unmanaged 
                {
                }
                enum Singleton 
                {
                }
                
                // type metadata table
                static 
                let DelegateTypes:[AnyDelegate.Type] =
                """
                Source.block(delimiters: ("[", "]"))
                {
                    for node:Class.Node in classes.map(\.node)
                    {
                        "\(node.namespace).\(node.name).self,"
                    }
                }
            }
        }
        
        for (node, definition):(Class.Node, String) in classes
        {
            Source.section(name: "\(node.name).swift.part")
            {
                definition 
            }
        }
    }
    
    private static 
    func template(arity:Int) -> String 
    {
        func nest(level:Int, result:String) -> String 
        {
            if      arity == 0
            {
                return
                    """
                    withExtendedLifetime(delegate)
                    {
                        Godot.api.1.0.godot_method_bind_ptrcall(self.function, 
                            delegate.core, nil, \(result))
                    }
                    """
            }
            else if arity == level 
            {
                return Source.fragment 
                {
                    """
                    withExtendedLifetime(delegate)
                    """
                    Source.block
                    {
                        """
                        var arguments:[UnsafeRawPointer?] = 
                        """
                        Source.block(delimiters: ("[", "]"))
                        {
                            for i:Int in 0 ..< arity 
                            {
                                ".init(u\(i)),"
                            }
                        }
                        """
                        arguments.withUnsafeMutableBufferPointer 
                        {
                            Godot.api.1.0.godot_method_bind_ptrcall(self.function, 
                                delegate.core, $0.baseAddress, \(result))
                        }
                        """
                    }
                }
            }
            else 
            {
                return Source.fragment 
                {
                    "u\(level).pass"
                    Source.block 
                    {
                        "(u\(level):UnsafePointer<U\(level).RawValue>?) in "
                        nest(level: level + 1, result: result)
                    }
                }
            }
        }
        
        return Source.fragment 
        {
            for void:Bool in [true, false] 
            {
                let generics:[String]   = (0 ..< arity).map{ "U\($0)" } + (void ? [] : ["V"])
                let arguments:[String]  = ["self delegate:Godot.AnyDelegate"] + (0 ..< arity).map 
                {
                    "_ u\($0):U\($0)"
                }
                """
                func callAsFunction\(Source.inline(angled: generics, else: ""))\
                \(Source.inline(list: arguments)) \(void ? "" : "-> V ")\ 
                \(Source.constraints(generics.map{ "\($0):Passable" }))
                """
                Source.block 
                {
                    if void 
                    {
                        nest(level: 0, result: "nil")
                    }
                    else 
                    {
                        ".take"
                        Source.block 
                        {
                            "(result:UnsafeMutablePointer<V.RawValue>) in "
                            nest(level: 0, result: ".init(result)")
                        }
                    }
                }
            }
        }
    }
}

extension Godot.Class.Node 
{
    var definition:String
    {
        // comma-separated `let` statements in a result builder 
        // currently crashes the compiler
        let properties:[(key:Property.Key, value:Property)]   = self.properties
        .sorted 
        {
            $0.key.name.camelcased < $1.key.name.camelcased
        }
        let methods:[(key:Method.Key, value:Method)]          = self.methods
        .sorted 
        {
            $0.key.name.camelcased < $1.key.name.camelcased
        }
        
        return Source.fragment
        {
            "extension \(self.namespace)"
            Source.block 
            {
                if let parent:Godot.Class.Node = self.parent 
                {
                    if self.children.isEmpty 
                    {
                    "final" 
                    }
                    "class \(self.name):\(parent.namespace).\(parent.name)"
                }
                else 
                {
                    "class \(self.name)"
                }
                Source.block 
                {
                    """
                    \(self.parent == nil ? "" : "override ")class 
                    var symbol:Swift.String { "\(self.symbol)" }
                    """
                    
                    if      self.namespace  == .root, 
                            self.name       == .split(pascal: "AnyDelegate")
                    {
                        // Godot.AnyDelegate has special behavior:
                        """
                        final 
                        let core:UnsafeMutableRawPointer 
                        // non-failable init assumes instance has been type-checked!
                        required
                        init(retained core:UnsafeMutableRawPointer) 
                        {
                            self.core = core
                        }
                        required
                        init(unretained core:UnsafeMutableRawPointer) 
                        {
                            self.core = core
                        }
                        
                        final 
                        func emit<Signal>(signal value:Signal.Value, as _:Signal.Type)
                            where Signal:Godot.Signal 
                        {
                            var variants:[Godot.Variant.Unmanaged] = 
                                [.pass(retaining: Signal.name)]
                                +
                                Signal.interface.arguments.map
                                {
                                    $0.witness(value)
                                }
                            defer 
                            {
                                for i:Int in variants.indices 
                                {
                                    variants[i].release()
                                }
                            }
                            
                            AnyDelegate.emitSignal(delegate: self, variants: variants)
                        }
                        """
                    }
                    else if self.namespace  == .root, 
                            self.name       == .split(pascal: "AnyObject")
                    {
                        // Godot.AnyObject has special behavior:
                        #"""
                        required
                        init(retained core:UnsafeMutableRawPointer) 
                        {
                            super.init(retained: core)
                        }
                        required 
                        init(unretained core:UnsafeMutableRawPointer) 
                        {
                            super.init(unretained: core)
                            guard self.retain()
                            else 
                            {
                                fatalError(
                                    """
                                    could not retain delegate of type \
                                    '\(Swift.String.init(reflecting: Self.self))' at <\(self.core)>
                                    """)
                            }
                        }
                        deinit
                        { 
                            self.release()
                        }
                        
                        // builtins 
                        @discardableResult
                        final
                        func retain() -> Bool 
                        {
                            Self.reference(self: self) 
                        }
                        @discardableResult
                        final
                        func release() -> Bool 
                        {
                            Self.unreference(self: self) 
                        }
                        """#
                    } 
                    
                    if !methods.isEmpty
                    {
                        """
                        
                        private static 
                        var \(methods.map 
                        {
                            """
                            \($0.key.name.camelcased):Godot.Function = 
                                    Godot.Function.bind(method: "\($0.key.symbol)", from: \(self.name).self)
                            """
                        }.joined(separator: ",\n    "))
                        """
                    }
                    if !self.constants.isEmpty 
                    {
                        """
                        
                        private static 
                        let \(self.constants.map 
                        {
                            "\($0.name.camelcased):Int = \($0.value)"
                        }.joined(separator: ",\n    "))
                        """
                    }
                    
                    for enumeration:Enumeration in self.enumerations 
                    {
                        """
                        
                        struct \(enumeration.name):Hashable  
                        """
                        Source.block 
                        {
                            """
                            let value:Int64
                            
                            static 
                            let \(enumeration.cases.map 
                            {
                                "\($0.name.camelcased):Self = .init(value: \($0.rawValue))"
                            }.joined(separator: ",\n    "))
                            """
                        }
                    }
                    """
                    
                    """
                    /* for (key, property):(Property.Key, Property) in properties
                    {
                        property.define(as: key.name.camelcased)
                    } 
                    
                    for (key, method):(Method.Key, Method) in methods 
                        where !method.is.hidden
                    {
                        method.define(as: key.name.camelcased, in: self.name)
                    }  */
                }
            }
        } 
    }
}
extension Godot.Class.Node.Property 
{
    func define(as name:String) -> String 
    {
        let ((_, parameterization), generics, constraints):
        (
            (
                body:[Godot.SwiftType.Parameterized], 
                tail:Godot.SwiftType.Parameterized
            ), 
            [String], 
            [String]
        ) 
        = 
        Godot.SwiftType.parameterize(([], self.type.type))
        {
            "T\($0)"
        }
        
        let getter:String = 
            """
            \(self.get.node.namespace).\
            \(self.get.node.name).\
            \(self.get.node.methods[self.get.index].key.name)
            """
        let setter:String? = self.set.map 
        {
            """
            \($0.node.namespace).\
            \($0.node.name).\
            \($0.node.methods[$0.index].key.name)
            """
        }
        
        let modifiers:[String]      = (self.is.final ? ["final"] : []) + (self.is.override ? ["override"] : [])
        let expressions:[String]    = ["self: self"] + (self.index.map{ ["\($0)"] } ?? [])
        let body:(get:String, set:String?) 
        body.get = Source.block 
        {
            """
            let result:\(parameterization.inner) = \(getter)\(Source.inline(list: expressions))
            return \(parameterization.expression(result: "result"))
            """
        }
        body.set = setter.map 
        {
            (setter:String) -> String in 
            Source.block 
            {
                """
                \(setter)\(Source.inline(list: 
                    expressions + [parameterization.expression(argument: "value")]))
                """
            }
        }
        if generics.isEmpty 
        {
            return Source.fragment 
            {
                if !modifiers.isEmpty
                {
                    modifiers.joined(separator: " ")
                }
                """
                var \(name):\(parameterization.outer)
                """
                if let set:String = body.set 
                {
                    Source.block 
                    {
                        "get" 
                        body.get 
                        "set(value)"
                        set
                    }
                }
                else 
                {
                    body.get 
                }
            }
        }
        else 
        {
            return Source.fragment 
            {
                if !modifiers.isEmpty
                {
                    modifiers.joined(separator: " ")
                }
                """
                var \(name):\(self.type.canonical)
                """
                if let _:String = body.set 
                {
                    Source.block 
                    {
                        """
                        get 
                        {
                            self.\(name)(as: \(self.type.canonical).self)
                        }
                        set(value) 
                        {
                            self.set(\(name): value)
                        }
                        """
                    }
                }
                else 
                {
                    Source.block 
                    {
                        "self.\(name)(as: \(self.type.canonical).self)"
                    }
                } 
                
                if !modifiers.isEmpty
                {
                    modifiers.joined(separator: " ")
                }
                """
                func \(name)\(Source.inline(angled: generics))(as _:\(parameterization.outer).Type) \
                -> \(parameterization.outer) \(Source.constraints(constraints))
                """
                body.get
                if let set:String = body.set
                {
                    if !modifiers.isEmpty
                    {
                        modifiers.joined(separator: " ")
                    }
                    """
                    func set\(Source.inline(angled: generics))\
                    (\(name != "value" ? "\(name) " : "")value:\(parameterization.outer)) \
                    \(Source.constraints(constraints))
                    """
                    set
                }
            }
        }
    } 
}
extension Godot.Class.Node.Method 
{
    func define(as name:String, in host:Words) -> String 
    {
        let (parameterization, generics, constraints):
        (
            (
                body:[Godot.SwiftType.Parameterized], 
                tail:Godot.SwiftType.Parameterized
            ), 
            [String], 
            [String]
        ) 
        = 
        Godot.SwiftType.parameterize((self.parameters.map(\.type.type), self.return.type))
        {
            "T\($0)"
        }
        
        let modifiers:[String] = (self.is.final ? ["final"] : []) + (self.is.override ? ["override"] : [])
        let arguments:[(label:String, name:String, type:Godot.SwiftType.Parameterized)] = 
            zip(self.parameters.map(\.label), parameterization.body).enumerated().map
        {
            ($0.1.0, "t\($0.0)", $0.1.1)
        }
        return Source.fragment 
        {
            if !modifiers.isEmpty
            {
                modifiers.joined(separator: " ")
            }
            """
            func \(name)\(Source.inline(angled: generics, else: ""))\
            \(Source.inline(list: arguments.map{ "\($0.label) \($0.name):\($0.type.outer)" })) \
            -> \(parameterization.tail.outer) \(Source.constraints(constraints))
            """
            Source.block 
            {
                let expressions:[String] = ["self: self"] + arguments.map 
                {
                    $0.type.expression(argument: $0.name)
                }
                if case .concrete(type: "()") = parameterization.tail 
                {
                    "\(host).\(name)\(Source.inline(list: expressions))"
                }
                else 
                {
                    """
                    let result:\(parameterization.tail.inner) = 
                        \(host).\(name)\(Source.inline(list: expressions))
                    return \(parameterization.tail.expression(result: "result"))
                    """ 
                }
            }
        }
    } 
}
extension Godot 
{
    enum SwiftType 
    {
        case concrete   (type:String)
        case narrowed   (type:String, generic:(String) -> String, constraints:(String) -> String)
        case generic    (             generic:(String) -> String, constraints:(String) -> String)
        case enumeration(type:String)
        case variant 
        
        enum Parameterized 
        {
            case concrete   (type:String)
            case narrowed   (type:String, outer:String, constraints:String?)
            case generic    (type:String,               constraints:String)
            case enumeration(type:String)
            case variant 
        }
    }
}
extension Godot.SwiftType.Parameterized 
{
    var outer:String 
    {
        switch self 
        {
        case    .concrete   (           type: let type),
                .narrowed   (type: _,  outer: let type, constraints: _),
                .generic    (           type: let type, constraints: _),
                .enumeration(           type: let type):
            return type 
        case .variant: 
            return "Godot.Variant?"
        }
    }
    var inner:String 
    {
        switch self 
        {
        case    .concrete   (type: let type),
                .narrowed   (type: let type, outer: _,  constraints: _),
                .generic    (type: let type,            constraints: _):
            return type 
        case    .enumeration(type: _):
            return "Int64" 
        case .variant: 
            return "Godot.VariantExistential"
        }
    }
    var constraints:String? 
    {
        switch self 
        {
        case    .concrete, .enumeration, .variant:
            return nil
        case    .narrowed   (type: _, outer: _, constraints: let constraints):
            return constraints 
        case    .generic    (type: _,           constraints: let constraints):
            return constraints 
        }
    }
    func expression(argument:String) -> String 
    {
        switch self 
        {
        case .concrete, .generic: 
            return argument 
        case .narrowed(type: let type, outer: _, constraints: _):
            return "\(type).init(\(argument))"
        case .enumeration:
            return "\(argument).value"
        case .variant:
            return "Godot.VariantExistential.init(variant: \(argument))"
        }
    }
    func expression(result:String) -> String 
    {
        switch self 
        {
        case .concrete, .generic: 
            return result 
        case .narrowed      (type: _, outer: let type, constraints: _):
            return "\(type).init(\(       result))"
        case .enumeration   (type: let type):
            return "\(type).init(value: \(result))"
        case .variant:
            return "\(result).variant"
        }
    }
}
extension Godot.SwiftType 
{
    static 
    func parameterize(_ types:(body:[Self], tail:Self), parameter:(Int) -> String) 
        -> 
        (
            parameterized:(body:[Parameterized], tail:Parameterized), 
            generics:[String],
            constraints:[String]
        ) 
    {
        var counter:Int = 0
        var body:[Parameterized] = []
        for type:Self in types.body 
        {
            body.append(type.parameterized(counter: &counter, parameter: parameter))
        }
        let tail:Parameterized = types.tail.parameterized(counter: &counter, parameter: parameter)
        return 
            (
                (body, tail), 
                (0 ..< counter).map(parameter),
                (body + [tail]).compactMap(\.constraints) 
            )
    }
    
    private 
    func parameterized(counter:inout Int, parameter:(Int) -> String) -> Parameterized 
    {
        switch self 
        {
        case .concrete(type: let type):
            return .concrete(type: type)
        case .narrowed(type: let type, generic: let generic, constraints: let constraints):
            defer { counter += 1 }
            return .narrowed(
                type:           generic(type), 
                outer:          generic(parameter(counter)), 
                constraints:    constraints(parameter(counter)))
        case .generic(generic: let generic, constraints: let constraints):
            defer { counter += 1 }
            return .generic(
                type:           generic(parameter(counter)), 
                constraints:    constraints(parameter(counter)))
        case .enumeration(type: let type):
            return .enumeration(type: type)
        case .variant:
            return .variant
        }
    }
}
extension Godot.Class.Node.KnownType 
{
    var type:Godot.SwiftType
    {
        switch self 
        {
        case .void:
            return .concrete(type: "()")
        case .bool:
            return .concrete(type: "Bool")
        case .int:
            return .narrowed(type: "Int64"){ $0 } 
            constraints:    { "\($0):FixedWidthInteger" }
        case .float:
            return .narrowed(type: "Float64"){ $0 }
            constraints:    { "\($0):BinaryFloatingPoint" }
        case .vector2:
            return .narrowed(type: "Float32"){ "Vector2<\($0)>" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .vector3:
            return .narrowed(type: "Float32"){ "Vector3<\($0)>" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .vector4:
            return .narrowed(type: "Float32"){ "Vector4<\($0)>" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        
        case .quaternion:
            return .narrowed(type: "Float32"){ "Quaternion<\($0)>" }
            constraints:    { "\($0):SIMDScalar & Numerics.Real & BinaryFloatingPoint" }
        case .plane3:
            return .narrowed(type: "Float32"){ "Godot.Plane3<\($0)>" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .rectangle2:
            return .narrowed(type: "Float32"){ "Vector2<\($0)>.Rectangle" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .rectangle3:
            return .narrowed(type: "Float32"){ "Vector3<\($0)>.Rectangle" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .affine2:
            return .narrowed(type: "Float32"){ "Godot.Transform2<\($0)>.Affine" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .affine3:
            return .narrowed(type: "Float32"){ "Godot.Transform3<\($0)>.Affine" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .linear3:
            return .narrowed(type: "Float32"){ "Godot.Transform3<\($0)>.Linear" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .resourceIdentifier:   
            return .concrete(type: "Godot.ResourceIdentifier")
        
        case .list:
            return .concrete(type: "Godot.List")
        case .map:
            return .concrete(type: "Godot.Map")
        case .nodePath:
            return .concrete(type: "Godot.NodePath")
        case .string:               
            return .generic { $0 }
            constraints:    { "\($0):Godot.Function.Passable, \($0).RawValue == Godot.String.RawValue" }
        
        case .uint8Array:
            return .generic { $0 }
            constraints:    { "\($0):Godot.Function.Passable, \($0).RawValue == Godot.Array<UInt8>.RawValue" }
        case .int32Array:
            return .generic { $0 }
            constraints:    { "\($0):Godot.Function.Passable, \($0).RawValue == Godot.Array<Int32>.RawValue" }
        case .float32Array:
            return .generic { $0 }
            constraints:    { "\($0):Godot.Function.Passable, \($0).RawValue == Godot.Array<Float32>.RawValue" }
        case .stringArray:
            return .generic { $0 }
            constraints:    { "\($0):Godot.Function.Passable, \($0).RawValue == Godot.Array<String>.RawValue" }
        case .vector2Array:
            return .generic { $0 }
            constraints:    { "\($0):Godot.Function.Passable, \($0).RawValue == Godot.Array<Vector2<Float32>>.RawValue" }
        case .vector3Array:
            return .generic { $0 }
            constraints:    { "\($0):Godot.Function.Passable, \($0).RawValue == Godot.Array<Vector3<Float32>>.RawValue" }
        case .vector4Array:
            return .generic { $0 }
            constraints:    { "\($0):Godot.Function.Passable, \($0).RawValue == Godot.Array<Vector4<Float32>>.RawValue" }
        case .object(let type): 
            return .concrete(type: "\(type)?")
        case .enumeration(let type):
            return .enumeration(type: type)
        case .variant:
            return .variant
        }
    }
    var canonical:String
    {
        switch self 
        {
        case .void:                 return "()"
        case .bool:                 return "Bool"
        case .int:                  return "Int64"
        case .float:                return "Float64"
        case .vector2:              return "Vector2<Float32>"
        case .vector3:              return "Vector3<Float32>"
        case .vector4:              return "Vector4<Float32>"
        case .quaternion:           return "Quaterinion<Float32>"
        case .plane3:               return "Godot.Plane3<Float32>"
        case .rectangle2:           return "Vector2<Float32>.Rectangle"
        case .rectangle3:           return "Vector3<Float32>.Rectangle"
        case .affine2:              return "Godot.Transform2<Float32>.Affine"
        case .affine3:              return "Godot.Transform3<Float32>.Affine"
        case .linear3:              return "Godot.Transform3<Float32>.Linear"
        case .resourceIdentifier:   return "Godot.ResourceIdentifier"
        case .list:                 return "Godot.List"
        case .map:                  return "Godot.Map"
        case .nodePath:             return "Godot.NodePath"
        case .string:               return "Godot.String"
        case .uint8Array:           return "Godot.Array<UInt8>"
        case .int32Array:           return "Godot.Array<Int32>"
        case .float32Array:         return "Godot.Array<Float32>"
        case .stringArray:          return "Godot.Array<Swift.String>"
        case .vector2Array:         return "Godot.Array<Vector2<Float32>>"
        case .vector3Array:         return "Godot.Array<Vector3<Float32>>"
        case .vector4Array:         return "Godot.Array<Vector4<Float32>>"
        case .object(let type):     return "\(type)?"
        case .enumeration(let type):return type
        case .variant:              return "Godot.Variant?"
        } 
    } 
}
