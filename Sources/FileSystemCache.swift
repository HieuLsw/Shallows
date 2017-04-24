import Foundation

public final class FileSystemCache : CacheProtocol {
    
    public typealias Key = String
    public typealias Value = Data
    
    public let name: String
    public let directoryURL: URL
    
    fileprivate let fileManager = FileManager.default
    fileprivate let queue: DispatchQueue
    
    public init(directoryURL: URL, name: String? = nil) {
        self.directoryURL = directoryURL
        self.name = name ?? "file-system-cache"
        self.queue = DispatchQueue(label: "\(self.name)-file-system-cache-queue")
    }
    
    public static func inDirectory(_ directory: FileManager.SearchPathDirectory,
                                   appending pathComponent: String,
                                   domainMask: FileManager.SearchPathDomainMask = .userDomainMask,
                                   name: String? = nil) -> FileSystemCache {
        let paths = NSSearchPathForDirectoriesInDomains(directory, domainMask, true)
        let url = URL(fileURLWithPath: paths.first!).appendingPathComponent(pathComponent, isDirectory: true)
        return FileSystemCache(directoryURL: url, name: name)
    }
    
    public enum Error : Swift.Error {
        case cantCreateDirectory(Swift.Error)
        case cantCreateFile
    }
    
    public func set(_ value: Data, forKey fileName: String, completion: @escaping (Result<Void>) -> ()) {
        queue.async {
            do {
                try self.createDirectoryURLIfNotExisting()
                let path = self.directoryURL.appendingPathComponent(fileName).path
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
    
    public func retrieve(forKey fileName: String, completion: @escaping (Result<Data>) -> ()) {
        queue.async {
            let path = self.directoryURL.appendingPathComponent(fileName)
            do {
                let data = try Data(contentsOf: path)
                completion(.success(data))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
}
