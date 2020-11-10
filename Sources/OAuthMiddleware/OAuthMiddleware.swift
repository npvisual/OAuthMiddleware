import Foundation
import SwiftRex
import Combine
import os.log

// MARK: - ACTIONS
//sourcery: Prism
public enum OAuthAction {
    case signIn
    case signOut
    case loggedIn(Bool)
    case loggedOut
    case failure(OAuthError)
}

// MARK: - STATE
public struct OAuthState: Equatable {
    var userData: UserState? = nil
    var providerData: [UserState]? = nil
    var metadata: MetadataState? = nil
    public var inputData: InputData? = nil
    var error: OAuthError? = nil
    
    public static let empty: OAuthState = .init()
    
    public init(
        userData: UserState? = nil,
        providerData: [UserState]? = nil,
        metadata: MetadataState? = nil,
        inputData: InputData? = nil
        ) {
        self.userData = userData
        self.providerData = providerData
        self.metadata = metadata
        self.inputData = inputData
    }
    
    public init(
        error: OAuthError
    ) {
        self.error = error
    }
}

public struct UserState: Equatable {
    var providerID: String = ""
    var uid: String = ""
    var displayName: String? = nil
    var photoURL: URL? = nil
    var email: String? = nil
    var phoneNumber: String? = nil
    var tenantID: String? = nil
    var profile: [String: NSObject]? = nil
    var username: String? = nil
    var isNewUser: Bool? = nil
    
    public init(
        providerID: String,
        uid: String,
        displayName: String? = nil,
        photoURL: URL? = nil,
        email: String? = nil,
        phoneNumber: String? = nil,
        tenantID: String? = nil,
        profile: [String: NSObject]? = nil,
        username: String? = nil,
        isNewUser: Bool = false
    ) {
        self.providerID = providerID
        self.uid = uid
        self.displayName = displayName
        self.photoURL = photoURL
        self.email = email
        self.phoneNumber = phoneNumber
        self.tenantID = tenantID
        self.profile = profile
        self.username = username
        self.isNewUser = isNewUser
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

public struct InputData: Equatable {
    var identityToken: String
    var nonce: String
    var providerID: String
    
    public init(
        identityToken: String,
        nonce: String,
        providerID: String
    ) {
        self.identityToken = identityToken
        self.nonce = nonce
        self.providerID = providerID
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
    func signIn(providerID: String, identityToken: String, nonce: String) -> AnyPublisher<Bool, OAuthError>
    func signOut() -> AnyPublisher<Void, OAuthError>
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
                    os_log(
                        "Failure to sign out...",
                        log: OAuthMiddleware.logger,
                        type: .debug
                    )
                    output?.dispatch(.failure(.LogoutFailure))
                } receiveValue: { [self] _ in
                    os_log(
                        "Successfully signed out...",
                        log: OAuthMiddleware.logger,
                        type: .debug
                    )
                    output?.dispatch(.loggedOut)
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

        afterReducer = .do { [self] in
            let newState = getState()
            os_log(
                "Calling afterReducer closure...",
                log: OAuthMiddleware.logger,
                type: .debug
            )
            switch action {
            case .signIn:
                os_log(
                    "Sign-in with OAuth...",
                    log: OAuthMiddleware.logger,
                    type: .debug
                )
                if let providerID = newState.inputData?.providerID,
                   let identityToken = newState.inputData?.identityToken,
                   let nonce = newState.inputData?.nonce {
                    os_log(
                        "About to exchange identity token...",
                        log: OAuthMiddleware.logger,
                        type: .debug
                    )
                    signInCancellable = provider.signIn(
                        providerID: providerID,
                        identityToken: identityToken,
                        nonce: nonce
                    ).sink { (completion: Subscribers.Completion<OAuthError>) in
                        switch completion {
                        case let .failure(error):
                            os_log(
                                "Identity token exchange failed...",
                                log: OAuthMiddleware.logger,
                                type: .debug
                            )
                            output?.dispatch(.failure(error))
                        default: break
                        }
                    } receiveValue: { (value: Bool) in
                        os_log(
                            "Identity token exchange successful...",
                            log: OAuthMiddleware.logger,
                            type: .debug
                        )
                        output?.dispatch(.loggedIn(value))
                    }
                } else {
                    os_log(
                        "Something went wrong...",
                        log: OAuthMiddleware.logger,
                        type: .debug
                    )
                    output?.dispatch(.failure(.InvalidCredential))
                }
            case .signOut:
                os_log(
                    "Just signing out...",
                    log: OAuthMiddleware.logger,
                    type: .debug
                )
                break
            default:
                os_log(
                    "Apparently not handling this case either : %s...",
                    log: OAuthMiddleware.logger,
                    type: .debug,
                    String(describing: action)
                )
                break
            }
        }
    }
}
