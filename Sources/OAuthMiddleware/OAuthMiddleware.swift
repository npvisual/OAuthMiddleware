import Foundation
import SwiftRex
import Combine
import os.log

// MARK: - ACTIONS
//sourcery: Prism
public enum OAuthAction {
    case signIn(String, String, String)
    case signOut
    case loggedIn(OAuthState)
    case loggedOut
    case failure(OAuthError)
}

// MARK: - STATE
public struct OAuthState: Equatable {
    var userData: OAuthUserState? = nil
    public var providerData: [OAuthUserState]? = nil
    var metadata: MetadataState? = nil
    var tenantID: String? = nil
    public var isNewUser: Bool? = nil
    var error: OAuthError? = nil
    
    public static let empty: OAuthState = .init()
    
    public init(
        userData: OAuthUserState? = nil,
        providerData: [OAuthUserState]? = nil,
        metadata: MetadataState? = nil,
        tenantID: String? = nil,
        isNewUser: Bool = false
        ) {
        self.userData = userData
        self.providerData = providerData
        self.metadata = metadata
        self.tenantID = tenantID
        self.isNewUser = isNewUser
    }
    
    public init(error: OAuthError) { self.error = error }
}

public struct OAuthUserState: Equatable {
    public var providerID: String = ""
    public var uid: String = ""
    var displayName: String? = nil
    var photoURL: URL? = nil
    var email: String? = nil
    var phoneNumber: String? = nil
    var profile: [String: NSObject]? = nil
    var username: String? = nil
    
    public init(
        providerID: String,
        uid: String,
        displayName: String? = nil,
        photoURL: URL? = nil,
        email: String? = nil,
        phoneNumber: String? = nil,
        tenantID: String? = nil,
        profile: [String: NSObject]? = nil,
        username: String? = nil
    ) {
        self.providerID = providerID
        self.uid = uid
        self.displayName = displayName
        self.photoURL = photoURL
        self.email = email
        self.phoneNumber = phoneNumber
        self.profile = profile
        self.username = username
    }
}

public struct MetadataState: Equatable {
    var lastSignInDate: Date?
    var creationDate: Date?
    
    public init(
        lastSignInDate: Date? = nil,
        creationDate: Date? = nil
    ) {
        self.lastSignInDate = lastSignInDate
        self.creationDate = creationDate
    }
}

public enum OAuthError: Error {
    case InvalidCredential
    case LogoutFailure
    case OperationNotAllowed
    case UserDisabled
}

// MARK: - PROTOCOL
public protocol OAuthFlowOperations {
    func signIn(providerID: String, identityToken: String, nonce: String) -> AnyPublisher<OAuthState, OAuthError>
    func signOut() -> AnyPublisher<Void, OAuthError>
    func stateChanged() -> AnyPublisher<OAuthState, OAuthError>
}

// MARK: - MIDDLEWARE
public class OAuthMiddleware: Middleware {
    public typealias InputActionType = OAuthAction
    public typealias OutputActionType = OAuthAction
    public typealias StateType = OAuthState
    
    private static let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "OAuthMiddleware")

    private var output: AnyActionHandler<OutputActionType>? = nil
    private var getState: () -> StateType = {  StateType.empty }

    private var provider: OAuthFlowOperations

    private var signOutCancellable: AnyCancellable?
    private var signInCancellable: AnyCancellable?
    private var stateChangeCancellable: AnyCancellable?

    public init(provider: OAuthFlowOperations) {
        self.provider = provider
    }
    
    public func receiveContext(getState: @escaping GetState<StateType>, output: AnyActionHandler<OutputActionType>) {
        os_log(
            "Receiving context...",
            log: OAuthMiddleware.logger,
            type: .debug
        )
        self.getState = getState
        self.output = output
        self.stateChangeCancellable = provider
            .stateChanged()
            .sink { (completion: Subscribers.Completion<OAuthError>) in
                var result: String = "success"
                if case Subscribers.Completion.failure = completion {
                    result = "failure"
                }
                os_log(
                    "State change completion with %s...",
                    log: OAuthMiddleware.logger,
                    type: .debug,
                    result
                )
            } receiveValue: { user in
                os_log(
                    "State change receiving value for user : %s...",
                    log: OAuthMiddleware.logger,
                    type: .debug,
                    String(describing: user.userData?.uid)
                )
                self.output?.dispatch(.loggedIn(user))
            }
    }
    
    public func handle(
        action: InputActionType,
        from dispatcher: ActionSource,
        afterReducer : inout AfterReducer
    ) {
        switch action {
            case .signOut:
                signOutCancellable = provider.signOut()
                    .sink { [self] completion in
                        switch completion {
                            case let .failure(error):
                                os_log(
                                    "Failure to sign out with error : %s",
                                    log: OAuthMiddleware.logger,
                                    type: .debug,
                                    String(describing: error)
                                )
                                output?.dispatch(.failure(.LogoutFailure))
                            default: break
                        }
                    } receiveValue: { [self] _ in
                        os_log(
                            "Successfully signed out...",
                            log: OAuthMiddleware.logger,
                            type: .debug
                        )
                        output?.dispatch(.loggedOut)
                    }
            case let .signIn(token, nonce, providerID):
                os_log(
                    "Sign-in with OAuth...",
                    log: OAuthMiddleware.logger,
                    type: .debug
                )
                os_log(
                    "About to exchange identity token...",
                    log: OAuthMiddleware.logger,
                    type: .debug
                )
                signInCancellable = provider
                    .signIn(
                        providerID: providerID,
                        identityToken: token,
                        nonce: nonce
                    )
                    .sink { [self] (completion: Subscribers.Completion<OAuthError>) in
                        switch completion {
                            case let .failure(error):
                                os_log(
                                    "Identity token exchange failed with error : %s",
                                    log: OAuthMiddleware.logger,
                                    type: .debug,
                                    String(describing: error)
                                )
                                output?.dispatch(.failure(error))
                            default: break
                        }
                    } receiveValue: { (value: OAuthState) in
                        // We're already dispatching the proper action from the
                        // stateChanged() signal, so we don't need to dispatch
                        // a new one when we receive a value here. But we're
                        // logging that event anyways.
                        os_log(
                            "Identity token exchange successful for %s...",
                            log: OAuthMiddleware.logger,
                            type: .debug,
                            String(describing: value.userData?.uid)
                        )
                    }
            default:
                os_log(
                    "Not handling this case : %s ...",
                    log: OAuthMiddleware.logger,
                    type: .debug,
                    String(describing: action)
                )
                break
        }
    }
}
