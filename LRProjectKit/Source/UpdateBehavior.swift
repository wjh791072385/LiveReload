import Foundation
import ExpressiveFoundation

public protocol UpdateRequestType: Equatable {

    func merge(other: Self) -> Self?

}

public extension UpdateRequestType {

    public static func merge(a: Self, _ b: Self) -> Self? {
        if a == b {
            return a
        } else if let c = a.merge(b) {
            return c
        } else if let c = b.merge(a) {
            return c
        } else {
            return nil
        }
    }

}

public enum StdUpdateReason: Int, UpdateRequestType {

    case Initial
    case Periodic
    case ExternalChange
    case UserInitiated

    public func merge(other: StdUpdateReason) -> StdUpdateReason? {
        if other.rawValue > self.rawValue {
            return other
        } else {
            return self
        }
    }

}

public protocol Updatable: EmitterType {

    var isUpdating: Bool { get }

    func update(reason: StdUpdateReason)

}

public struct UpdateDidFinish<UpdateRequest: UpdateRequestType>: EventType {
    public let request: UpdateRequest
}
public struct UpdatableStateDidChange: EventType {
}

public class UpdateBehavior<Owner: EmitterType, UpdateRequest: UpdateRequestType> {

    public unowned var owner: Owner
    public let updateMethod: (Owner) -> () -> Void
    public let childrenMethod: ((Owner) -> () -> [Updatable])?

    public private(set) var runningRequest: UpdateRequest?
    public private(set) var lastRequest: UpdateRequest?
    public private(set) var lastError: ErrorType?
    public private(set) var pendingRequests: [UpdateRequest] = []

    public private(set) var isUpdatingChildren: Bool = false
    private var childrenListeners: [ObjectIdentifier: [(updatable: Updatable, listener: ListenerType)]] = [:]

    public var isUpdatingSelf: Bool {
        return runningRequest != nil
    }

    public var isUpdating: Bool {
        return isUpdatingSelf || isUpdatingChildren
    }

    public init(_ owner: Owner, _ updateMethod: (Owner) -> () -> Void, childrenMethod: ((Owner) -> () -> [Updatable])? = nil) {
        self.owner = owner
        self.updateMethod = updateMethod
        self.childrenMethod = childrenMethod
    }

    public func update(request: UpdateRequest) {
        if let current = runningRequest {
            if let merged = UpdateRequest.merge(current, request) {
                self.runningRequest = merged
            } else {
                addPendingRequest(request)
            }
        } else {
            startUpdate(request)
        }
    }

    private func addPendingRequest(request: UpdateRequest) {
        for (idx, pending) in pendingRequests.enumerate() {
            if let merged = UpdateRequest.merge(pending, request) {
                pendingRequests[idx] = merged
                return
            }
        }
        pendingRequests.append(request)
    }

    private func startUpdate(request: UpdateRequest) {
        let previous = runningRequest
        runningRequest = request

        if previous == nil {
            didStartBatch()
        }
#if true
        if previous != nil {
            print("\(owner)+UpdateBehavior: update continued")
        }
#endif

        updateMethod(owner)()
    }

    private func startNextRequest() {
        if pendingRequests.isEmpty {
            didEndBatch()
        } else {
            startUpdate(pendingRequests.removeFirst())
        }
    }

    public func didSucceed() {
        lastError = nil
        didFinish()
    }

    public func didFail(error: ErrorType) {
        lastError = error
        didFinish()
    }

    private func didFinish() {
        lastRequest = runningRequest
        runningRequest = nil
        owner.emit(UpdateDidFinish(request: lastRequest!))
        startNextRequest()
    }

    private func didStartBatch() {
#if true
        print("\(owner)+UpdateBehavior: update started")
#endif
        owner.emit(UpdatableStateDidChange())
    }

    private func didEndBatch() {
#if true
        print("\(owner)+UpdateBehavior: update finished")
#endif
        runningRequest = nil
        refreshChildren(silent: true)  // just in case
        owner.emit(UpdatableStateDidChange())
    }

    public func refreshChildren() {
        refreshChildren(silent: false)
    }

    private func refreshChildren(silent silent: Bool) {
        let newChildren = childrenMethod?(owner)() ?? []

        let oldMap = childrenListeners
        var newMap = [ObjectIdentifier: [(updatable: Updatable, listener: ListenerType)]]()

#if true
        print("\(owner)+UpdateBehavior: now has \(newChildren.count) children")
#endif

        for child in newChildren {
            let oid = ObjectIdentifier(child)

            let listener: ListenerType
            if let old = oldMap[oid]?.find({ $0.updatable === child })?.listener {
                listener = old
            } else {
                listener = child.subscribe(self, UpdateBehavior.childStateDidChange)
#if true
                print("\(owner)+UpdateBehavior: subscribed to \(child)")
#endif
            }

            if newMap[oid] == nil {
                newMap[oid] = []
            }
            newMap[oid]!.append((child, listener))
        }

        let oldUC = isUpdatingChildren
        isUpdatingChildren = newChildren.contains { $0.isUpdating }
        if oldUC != isUpdatingChildren && !silent {
            owner.emit(UpdatableStateDidChange())
        }

        childrenListeners = newMap
    }

    private func childStateDidChange(event: UpdatableStateDidChange) {
        refreshChildren()
    }

}