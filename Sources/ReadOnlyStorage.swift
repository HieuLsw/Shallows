public protocol ReadableStorageProtocol : StorageDesign {
    
    associatedtype Key
    associatedtype Value
    
    func retrieve(forKey key: Key, completion: @escaping (Result<Value>) -> ())
    
}

public protocol ReadOnlyStorageProtocol : ReadableStorageProtocol {  }

//@available(*, deprecated, renamed: "ReadOnlyStorage")
//public typealias ReadOnlyStorage<Key, Value> = ReadOnlyStorage<Key, Value>

public struct ReadOnlyStorage<Key, Value> : ReadOnlyStorageProtocol {
    
    public let storageName: String
    
    private let _retrieve: (Key, @escaping (Result<Value>) -> ()) -> ()
    
    public init(storageName: String, retrieve: @escaping (Key, @escaping (Result<Value>) -> ()) -> ()) {
        self._retrieve = retrieve
        self.storageName = storageName
    }
    
    public init<CacheType : ReadableStorageProtocol>(_ cache: CacheType) where CacheType.Key == Key, CacheType.Value == Value {
        self._retrieve = cache.retrieve
        self.storageName = cache.storageName
    }
    
    public func retrieve(forKey key: Key, completion: @escaping (Result<Value>) -> ()) {
        _retrieve(key, completion)
    }
    
}

extension ReadableStorageProtocol {
    
    public func asReadOnlyStorage() -> ReadOnlyStorage<Key, Value> {
        return ReadOnlyStorage(self)
    }
    
}

extension ReadOnlyStorageProtocol {
    
    public func backed<CacheType : ReadableStorageProtocol>(by cache: CacheType) -> ReadOnlyStorage<Key, Value> where CacheType.Key == Key, CacheType.Value == Value {
        return ReadOnlyStorage(storageName: "\(self.storageName)-\(cache.storageName)", retrieve: { (key, completion) in
            self.retrieve(forKey: key, completion: { (firstResult) in
                if firstResult.isFailure {
                    shallows_print("Cache (\(self.storageName)) miss for key: \(key). Attempting to retrieve from \(cache.storageName)")
                    cache.retrieve(forKey: key, completion: completion)
                } else {
                    completion(firstResult)
                }
            })
        })
    }
    
    public func mapKeys<OtherKey>(_ transform: @escaping (OtherKey) throws -> Key) -> ReadOnlyStorage<OtherKey, Value> {
        return ReadOnlyStorage<OtherKey, Value>(storageName: storageName, retrieve: { key, completion in
            do {
                let newKey = try transform(key)
                self.retrieve(forKey: newKey, completion: completion)
            } catch {
                completion(.failure(error))
            }
        })
    }
    
    public func mapValues<OtherValue>(_ transform: @escaping (Value) throws -> OtherValue) -> ReadOnlyStorage<Key, OtherValue> {
        return ReadOnlyStorage<Key, OtherValue>(storageName: storageName, retrieve: { (key, completion) in
            self.retrieve(forKey: key, completion: { (result) in
                switch result {
                case .success(let value):
                    do {
                        let newValue = try transform(value)
                        completion(.success(newValue))
                    } catch {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            })
        })
    }
    
}

extension ReadOnlyStorageProtocol {
    
    public func mapValues<OtherValue : RawRepresentable>() -> ReadOnlyStorage<Key, OtherValue> where OtherValue.RawValue == Value {
        return mapValues(throwing(OtherValue.init(rawValue:)))
    }
    
    public func mapKeys<OtherKey : RawRepresentable>() -> ReadOnlyStorage<OtherKey, Value> where OtherKey.RawValue == Key {
        return mapKeys({ $0.rawValue })
    }
    
}

extension ReadOnlyStorageProtocol {
    
    public func singleKey(_ key: Key) -> ReadOnlyStorage<Void, Value> {
        return mapKeys({ key })
    }
    
}

public enum UnsupportedTransformationReadOnlyCacheError : Error {
    case cacheIsReadOnly
}

extension ReadOnlyStorageProtocol {
    
    public func usingUnsupportedTransformation<OtherKey, OtherValue>(_ transformation: (Storage<Key, Value>) -> Storage<OtherKey, OtherValue>) -> ReadOnlyStorage<OtherKey, OtherValue> {
        let fullCache = Storage<Key, Value>(cacheName: self.storageName, retrieve: self.retrieve) { (_, _, completion) in
            completion(fail(with: UnsupportedTransformationReadOnlyCacheError.cacheIsReadOnly))
        }
        return transformation(fullCache).asReadOnlyStorage()
    }
    
}
