import Foundation

public final class FileSystemCache : CacheProtocol {
        
    public let name: String
    public let directoryURL: URL
    
    internal var pruneOnDeinit: Bool = false
    
    fileprivate let fileManager = FileManager.default
    fileprivate let queue: DispatchQueue
    
    public init(directoryURL: URL, name: String? = nil) {
        self.directoryURL = directoryURL
        self.name = name ?? "file-system-cache"
        self.queue = DispatchQueue(label: "\(self.name)-file-system-cache-queue")
    }
    
    deinit {
        if pruneOnDeinit {
            do { try fileManager.removeItem(at: directoryURL) } catch { }
        }
    }
    
    public static func inDirectory(_ directory: FileManager.SearchPathDirectory,
                                   appending pathComponent: String,
                                   domainMask: FileManager.SearchPathDomainMask = .userDomainMask,
                                   cacheName: String? = nil) -> FileSystemCache {
        let urls = FileManager.default.urls(for: directory, in: domainMask)
        let url = urls.first!.appendingPathComponent(pathComponent, isDirectory: true)
        return FileSystemCache(directoryURL: url, name: cacheName)
    }
    
    public enum Error : Swift.Error {
        case cantCreateDirectory(Swift.Error)
        case cantCreateFile
    }
    
    public func fileName(for key: String) -> String {
        guard let data = key.data(using: .utf8) else { return key }
        return data.base64EncodedString(options: [])
    }
    
    public func set(_ value: Data, forKey key: String, completion: @escaping (Result<Void>) -> ()) {
        queue.async {
            do {
                try self.createDirectoryURLIfNotExisting()
                let path = self.directoryURL.appendingPathComponent(self.fileName(for: key)).path
                if self.fileManager.createFile(atPath: path,
                                               contents: value,
                                               attributes: nil) {
                    completion(.success())
                } else {
                    completion(.failure(Error.cantCreateFile))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    fileprivate func createDirectoryURLIfNotExisting() throws {
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
            } catch {
                throw Error.cantCreateDirectory(error)
            }
        }
    }
    
    public func retrieve(forKey key: String, completion: @escaping (Result<Data>) -> ()) {
        queue.async {
            let path = self.directoryURL.appendingPathComponent(self.fileName(for: key))
            do {
                let data = try Data(contentsOf: path)
                completion(.success(data))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
}

extension CacheProtocol where Value == Data {
    
    public func mapJSON() -> Cache<Key, Any> {
        return mapValues(transformIn: { try JSONSerialization.jsonObject(with: $0, options: []) },
                         transformOut: { try JSONSerialization.data(withJSONObject: $0, options: []) })
    }
    
    public func mapJSONDictionary() -> Cache<Key, [String : Any]> {
        return mapJSON().mapValues(transformIn: throwing({ $0 as? [String : Any] }),
                                   transformOut: { $0 })
    }
    
    public func mapPlist(format: PropertyListSerialization.PropertyListFormat = .xml) -> Cache<Key, Any> {
        return mapValues(transformIn: { data in
            var formatRef = format
            return try PropertyListSerialization.propertyList(from: data, options: [], format: &formatRef)
        }, transformOut: { plist in
            return try PropertyListSerialization.data(fromPropertyList: plist, format: format, options: 0)
        })
    }
    
    public func mapPlistDictionary(format: PropertyListSerialization.PropertyListFormat = .xml) -> Cache<Key, [String : Any]> {
        return mapPlist(format: format).mapValues(transformIn: throwing({ $0 as? [String : Any] }),
                                                  transformOut: { $0 })
    }
    
    public func mapString(withEncoding encoding: String.Encoding = .utf8) -> Cache<Key, String> {
        return mapValues(transformIn: throwing({ String(data: $0, encoding: encoding) }),
                         transformOut: throwing({ $0.data(using: encoding) }))
    }
    
}
