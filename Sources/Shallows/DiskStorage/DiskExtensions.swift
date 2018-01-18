//
//  DiskExtensions.swift
//  Shallows
//
//  Created by Олег on 18.01.2018.
//  Copyright © 2018 Shallows. All rights reserved.
//

import Foundation

extension StorageProtocol where Value == Data {
    
    public func mapJSON(readingOptions: JSONSerialization.ReadingOptions = [],
                        writingOptions: JSONSerialization.WritingOptions = []) -> Storage<Key, Any> {
        return mapValues(transformIn: { try JSONSerialization.jsonObject(with: $0, options: readingOptions) },
                         transformOut: { try JSONSerialization.data(withJSONObject: $0, options: writingOptions) })
    }
    
    public func mapJSONDictionary(readingOptions: JSONSerialization.ReadingOptions = [],
                                  writingOptions: JSONSerialization.WritingOptions = []) -> Storage<Key, [String : Any]> {
        return mapJSON(readingOptions: readingOptions,
                       writingOptions: writingOptions).mapValues(transformIn: throwing({ $0 as? [String : Any] }),
                                                                 transformOut: { $0 })
    }
    
    public func mapJSONObject<JSONObject : Codable>(_ objectType: JSONObject.Type,
                                                    decoder: JSONDecoder = JSONDecoder(),
                                                    encoder: JSONEncoder = JSONEncoder()) -> Storage<Key, JSONObject> {
        return mapValues(transformIn: { try decoder.decode(objectType, from: $0) },
                         transformOut: { try encoder.encode($0) })
    }
    
    public func mapPlist(format: PropertyListSerialization.PropertyListFormat = .xml) -> Storage<Key, Any> {
        return mapValues(transformIn: { data in
            var formatRef = format
            return try PropertyListSerialization.propertyList(from: data, options: [], format: &formatRef)
        }, transformOut: { plist in
            return try PropertyListSerialization.data(fromPropertyList: plist, format: format, options: 0)
        })
    }
    
    public func mapPlistDictionary(format: PropertyListSerialization.PropertyListFormat = .xml) -> Storage<Key, [String : Any]> {
        return mapPlist(format: format).mapValues(transformIn: throwing({ $0 as? [String : Any] }),
                                                  transformOut: { $0 })
    }
    
    public func mapPlistObject<PlistObject : Codable>(_ objectType: PlistObject.Type,
                                                      decoder: PropertyListDecoder = PropertyListDecoder(),
                                                      encoder: PropertyListEncoder = PropertyListEncoder()) -> Storage<Key, PlistObject> {
        return mapValues(transformIn: { try decoder.decode(objectType, from: $0) },
                         transformOut: { try encoder.encode($0) })
    }
    
    public func mapString(withEncoding encoding: String.Encoding = .utf8) -> Storage<Key, String> {
        return mapValues(transformIn: throwing({ String(data: $0, encoding: encoding) }),
                         transformOut: throwing({ $0.data(using: encoding) }))
    }
    
}

extension ReadOnlyStorageProtocol where Value == Data {
    
    public func mapJSON(options: JSONSerialization.ReadingOptions = []) -> ReadOnlyStorage<Key, Any> {
        return mapValues({ try JSONSerialization.jsonObject(with: $0, options: options) })
    }
    
    public func mapJSONDictionary(options: JSONSerialization.ReadingOptions = []) -> ReadOnlyStorage<Key, [String : Any]> {
        return mapJSON(options: options).mapValues(throwing({ $0 as? [String : Any] }))
    }
    
    public func mapJSONObject<JSONObject : Decodable>(_ objectType: JSONObject.Type,
                                                      decoder: JSONDecoder = JSONDecoder()) -> ReadOnlyStorage<Key, JSONObject> {
        return mapValues({ try decoder.decode(objectType, from: $0) })
    }
    
    public func mapPlist(format: PropertyListSerialization.PropertyListFormat = .xml,
                         options: PropertyListSerialization.ReadOptions = []) -> ReadOnlyStorage<Key, Any> {
        return mapValues({ data in
            var formatRef = format
            return try PropertyListSerialization.propertyList(from: data, options: options, format: &formatRef)
        })
    }
    
    public func mapPlistDictionary(format: PropertyListSerialization.PropertyListFormat = .xml,
                                   options: PropertyListSerialization.ReadOptions = []) -> ReadOnlyStorage<Key, [String : Any]> {
        return mapPlist(format: format, options: options).mapValues(throwing({ $0 as? [String : Any] }))
    }
    
    public func mapPlistObject<PlistObject : Decodable>(_ objectType: PlistObject.Type,
                                                        decoder: PropertyListDecoder = PropertyListDecoder()) -> ReadOnlyStorage<Key, PlistObject> {
        return mapValues({ try decoder.decode(objectType, from: $0) })
    }
    
    public func mapString(withEncoding encoding: String.Encoding = .utf8) -> ReadOnlyStorage<Key, String> {
        return mapValues(throwing({ String(data: $0, encoding: encoding) }))
    }
    
}

extension WriteOnlyStorageProtocol where Value == Data {
    
    public func mapJSON(options: JSONSerialization.WritingOptions = []) -> WriteOnlyStorage<Key, Any> {
        return mapValues({ try JSONSerialization.data(withJSONObject: $0, options: options) })
    }
    
    public func mapJSONDictionary(options: JSONSerialization.WritingOptions = []) -> WriteOnlyStorage<Key, [String : Any]> {
        return mapJSON(options: options).mapValues({ $0 as Any })
    }
    
    public func mapJSONObject<JSONObject : Encodable>(_ objectType: JSONObject.Type,
                                                      encoder: JSONEncoder = JSONEncoder()) -> WriteOnlyStorage<Key, JSONObject> {
        return mapValues({ try encoder.encode($0) })
    }
    
    public func mapPlist(format: PropertyListSerialization.PropertyListFormat = .xml,
                         options: PropertyListSerialization.WriteOptions = 0) -> WriteOnlyStorage<Key, Any> {
        return mapValues({ try PropertyListSerialization.data(fromPropertyList: $0, format: format, options: options) })
    }
    
    public func mapPlistDictionary(format: PropertyListSerialization.PropertyListFormat = .xml,
                                   options: PropertyListSerialization.WriteOptions = 0) -> WriteOnlyStorage<Key, [String : Any]> {
        return mapPlist(format: format, options: options).mapValues({ $0 as Any })
    }
    
    public func mapPlistObject<PlistObject : Encodable>(_ objectType: PlistObject.Type,
                                                        encoder: PropertyListEncoder = PropertyListEncoder()) -> WriteOnlyStorage<Key, PlistObject> {
        return mapValues({ try encoder.encode($0) })
    }
    
    public func mapString(withEncoding encoding: String.Encoding = .utf8) -> WriteOnlyStorage<Key, String> {
        return mapValues(throwing({ $0.data(using: encoding) }))
    }
    
}

extension StorageProtocol where Key == Filename {
    
    public func usingStringKeys() -> Storage<String, Value> {
        return mapKeys(Filename.init(rawValue:))
    }
    
}

extension ReadOnlyStorageProtocol where Key == Filename {
    
    public func usingStringKeys() -> ReadOnlyStorage<String, Value> {
        return mapKeys(Filename.init(rawValue:))
    }
    
}

extension WriteOnlyStorageProtocol where Key == Filename {
    
    public func usingStringKeys() -> WriteOnlyStorage<String, Value> {
        return mapKeys(Filename.init(rawValue:))
    }
    
}

