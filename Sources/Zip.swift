//
//  Zip.swift
//  Shallows
//
//  Created by Олег on 07.05.17.
//  Copyright © 2017 Shallows. All rights reserved.
//

import Dispatch

fileprivate final class CompletionContainer<A, B> {
    
    fileprivate struct Strategy {
        
        private let _check: (inout [A], inout [B], (A, B) -> ()) -> ()
        
        fileprivate init(check: @escaping (inout [A], inout [B], (A, B) -> ()) -> ()) {
            self._check = check
        }
        
        fileprivate func checkContainers(_ a: inout [A], _ b: inout [B], complete: (A, B) -> ()) {
            _check(&a, &b, complete)
        }
        
        fileprivate static var sameOrder: Strategy {
            return Strategy { ase, bis, complete in
                var cnt = 0
                while !ase.isEmpty && !bis.isEmpty {
                    cnt += 1
                    print(cnt)
                    let a = ase.removeFirst()
                    let b = bis.removeFirst()
                    complete(a, b)
                }
            }
        }
        
        fileprivate static var latest: Strategy {
            return Strategy { ase, bis, complete in
                if let lastA = ase.last, let lastB = bis.last {
                    complete(lastA, lastB)
                }
            }
        }
        
    }
    
    private var ase: [A] = []
    private var bis: [B] = []
    private let queue = DispatchQueue(label: "container-completion")
    private let strategy: Strategy
    
    private let completion: (A, B) -> ()
    
    fileprivate init(strategy: Strategy, completion: @escaping (A, B) -> ()) {
        self.strategy = strategy
        self.completion = completion
    }
    
    fileprivate func complete(with a: A...) {
        completeA(with: a)
    }
    
    fileprivate func complete(with b: B...) {
        completeB(with: b)
    }
    
    fileprivate func completeA(with a: [A]) {
        queue.async {
            self.ase.append(contentsOf: a)
            self.check()
        }
    }
    
    fileprivate func completeB(with b: [B]) {
        queue.async {
            self.bis.append(contentsOf: b)
            self.check()
        }
    }

    private func check() {
        strategy.checkContainers(&ase, &bis, complete: self.completion)
    }
    
}

fileprivate extension Result {
    
    var error: Error? {
        if case .failure(let er) = self {
            return er
        }
        return nil
    }
    
}

public struct ZippedResultError : Error {
    
    public let left: Error?
    public let right: Error?
    
    public init(left: Error?, right: Error?) {
        self.left = left
        self.right = right
    }
    
}

public func zip<Value1, Value2>(_ lhs: Result<Value1>, _ rhs: Result<Value2>) -> Result<(Value1, Value2)> {
    switch (lhs, rhs) {
    case (.success(let left), .success(let right)):
        return Result.success((left, right))
    default:
        return Result.failure(ZippedResultError(left: lhs.error, right: rhs.error))
    }
}

public enum ZipCompletionStrategy {
    case latest
    case withSameIndex
    
    fileprivate func containerStrategy<T, U>() -> CompletionContainer<T, U>.Strategy {
        switch self {
        case .latest:
            return .latest
        case .withSameIndex:
            return .sameOrder
        }
    }
}

public func zip<Key, Value1, Value2>(_ lhs: ReadOnlyCache<Key, Value1>, _ rhs: ReadOnlyCache<Key, Value2>, withStrategy strategy: ZipCompletionStrategy = .latest) -> ReadOnlyCache<Key, (Value1, Value2)> {
    return ReadOnlyCache(cacheName: lhs.cacheName + "+" + rhs.cacheName, retrieve: { (key, completion) in
        let container = CompletionContainer<Result<Value1>, Result<Value2>>(strategy: strategy.containerStrategy()) { left, right in
            completion(zip(left, right))
        }
        lhs.retrieve(forKey: key, completion: { container.complete(with: $0) })
        rhs.retrieve(forKey: key, completion: { container.complete(with: $0) })
    })
}

public func zip<Cache1 : CacheProtocol, Cache2 : CacheProtocol>(_ lhs: Cache1, _ rhs: Cache2, withStrategy strategy: ZipCompletionStrategy = .latest) -> Cache<Cache1.Key, (Cache1.Value, Cache2.Value)> where Cache1.Key == Cache2.Key {
    return Cache(cacheName: lhs.cacheName + "+" + rhs.cacheName, retrieve: { (key, completion) in
        let container = CompletionContainer<Result<Cache1.Value>, Result<Cache2.Value>>(strategy: strategy.containerStrategy(), completion: { (left, right) in
            completion(zip(left, right))
        })
        lhs.retrieve(forKey: key, completion: { container.complete(with: $0) })
        rhs.retrieve(forKey: key, completion: { container.complete(with: $0) })
    }, set: { (value, key, completion) in
        let container = CompletionContainer<Result<Void>, Result<Void>>(strategy: strategy.containerStrategy(), completion: { (left, right) in
            let zipped = zip(left, right)
            switch zipped {
            case .success:
                completion(.success())
            case .failure(let error):
                completion(.failure(error))
            }
        })
        lhs.set(value.0, forKey: key, completion: { container.completeA(with: [$0]) })
        rhs.set(value.1, forKey: key, completion: { container.completeB(with: [$0]) })
    })
}

public func flat<Key, T, U, V>(_ notFlatCache: Cache<Key, (T, (U, V))>) -> Cache<Key, (T, U, V)> {
    return notFlatCache.mapValues(transformIn: { ($0, $1.0, $1.1) },
                                  transformOut: { ($0, ($1, $2)) })
}

public func flat<Key, T, U, V>(_ notFlatCache: Cache<Key, ((T, U), V)>) -> Cache<Key, (T, U, V)> {
    return notFlatCache.mapValues(transformIn: { ($0.0, $0.1, $1) },
                                  transformOut: { (($0, $1), $2) })
}

public func flat<Key, T, U, V>(_ notFlatCache: ReadOnlyCache<Key, (T, (U, V))>) -> ReadOnlyCache<Key, (T, U, V)> {
    return notFlatCache.mapValues({ ($0, $1.0, $1.1) })
}

public func flat<Key, T, U, V>(_ notFlatCache: ReadOnlyCache<Key, ((T, U), V)>) -> ReadOnlyCache<Key, (T, U, V)> {
    return notFlatCache.mapValues({ ($0.0, $0.1, $1) })
}
