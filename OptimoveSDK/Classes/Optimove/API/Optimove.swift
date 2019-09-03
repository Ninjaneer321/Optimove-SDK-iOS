//  Copyright © 2017 Optimove. All rights reserved.

import UIKit
import UserNotifications
import OptimoveCore

/// The entry point of Optimove.
/// Initialize and configure SDK using `Optimove.shared.configure(for:)`.
@objc public final class Optimove: NSObject {

    private let serviceLocator: ServiceLocator
    private var storage: OptimoveStorage
    private let handlers: HandlersPool
    private let stateListener: DeprecatedStateListener

    // MARK: - Initializers

    /// The shared instance of OptimoveSDK.
    @objc public static let shared: Optimove = {
        return Optimove()
    }()

    private override init() {
        serviceLocator = ServiceLocator()
        handlers = serviceLocator.handlersPool()
        storage = serviceLocator.storage()
        stateListener = DeprecatedStateListener()
        super.init()

        setup()
    }

    /// The starting point of the Optimove SDK.
    ///
    /// - Parameter tenantInfo: Basic client information received on the onboarding process with Optimove.
    @objc public static func configure(for tenantInfo: OptimoveTenantInfo) {
        shared.configureLogger()
        Logger.warn("Tenant config \(tenantInfo.configName)")
        shared.storeTenantInfo(tenantInfo)
        Logger.debug("Configure started.")
        shared.startNormalInitProcess { (sucess) in
            guard sucess else {
                Logger.error("Configure failed. 🛑")
                return
            }
            Logger.info("Configure finished. ✅")
        }
    }

    // MARK: - Deep Link

    private var deepLinkResponders = [OptimoveDeepLinkResponder]()

    var deepLinkComponents: OptimoveDeepLinkComponents? {
        didSet {
            guard let dlc = deepLinkComponents else {
                return
            }
            for responder in deepLinkResponders {
                responder.didReceive(deepLinkComponent: dlc)
            }
        }
    }
}

// MARK: - Initialization API

extension Optimove {

    func startNormalInitProcess(didSucceed: @escaping ResultBlockWithBool) {
        Logger.info("Start initialization from remote.")
        if RunningFlagsIndication.isSdkRunning {
            Logger.debug("Skip normal initializtion since SDK already running.")
            didSucceed(true)
            return
        }
        let initializer = serviceLocator.initializer()
        initializer.initializeFromRemoteServer { [initializer] success in
            if success {
                didSucceed(success)
                self.didFinishInitializationSuccessfully()
            } else {
                initializer.initializeFromLocalConfigs { success in
                    didSucceed(success)
                }
            }
        }
    }

    func startUrgentInitProcess(didSucceed: @escaping ResultBlockWithBool) {
        Logger.info("Start urgent initiazlition process.")
        if RunningFlagsIndication.isSdkRunning {
            Logger.debug("Skip urgent initializtion since SDK already running")
            didSucceed(true)
            return
        }
        let initializer = serviceLocator.initializer()
        initializer.initializeFromLocalConfigs { success in
            didSucceed(success)
            if success {
                self.didFinishInitializationSuccessfully()
            }
        }
    }

    func didFinishInitializationSuccessfully() {
        RunningFlagsIndication.isInitializerRunning = false
        RunningFlagsIndication.isSdkRunning = true
        stateListener.onInitializationSuccessfully(self)
    }
}

// MARK: - SDK state observing

//TODO: expose to  @objc
extension Optimove {

    @available(*, deprecated, message: "This method will be deleted in the next version. Instead of subscribing as an listener use Optimove SDK directly.")
    public func registerSuccessStateListener(_ listener: OptimoveSuccessStateListener) {
        stateListener.registerSuccessStateListener(optimove: self, listener: listener)
    }

    @available(*, deprecated, message: "This method will be deleted in the next version. Instead of subscribing as an listener use Optimove SDK directly.")
    public func unregisterSuccessStateListener(_ listener: OptimoveSuccessStateListener) {
        stateListener.unregisterSuccessStateListener(optimove: self, listener: listener)
    }

}

// MARK: - Notification related API
extension Optimove {
    /// Validate user notification permissions and sends the payload to the message handler
    ///
    /// - Parameters:
    ///   - userInfo: the data payload as sends by the the server
    ///   - completionHandler: an indication to the OS that the data is ready to be presented by the system as a notification
    @objc public func didReceiveRemoteNotification(
        userInfo: [AnyHashable: Any],
        didComplete: @escaping (UIBackgroundFetchResult) -> Void
        ) -> Bool {
        Logger.info("Receive remote notification.")
        guard userInfo[OptimoveKeys.Notification.isOptimoveSdkCommand.rawValue] as? String == "true" else {
            return false
        }
        serviceLocator.notificationListener().didReceiveRemoteNotification(
            userInfo: userInfo,
            didComplete: didComplete
        )
        return true
    }

    @objc public func willPresent(
        notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
        ) -> Bool {
        Logger.info("Received notification in foreground mode.")
        guard notification.request.content.userInfo[OptimoveKeys.Notification.isOptipush.rawValue] as? String == "true"
            else {
                Logger.debug("Notification should not be handled by optimove")
                return false
        }
        completionHandler([.alert, .sound, .badge])
        return true
    }

    /// Report user response to optimove notifications and send the client the related deep link to open
    ///
    /// - Parameters:
    ///   - response: The user response
    ///   - completionHandler: Indication about the process ending
    @objc public func didReceive(
        response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
        ) -> Bool {
        let userInfo = response.notification.request.content.userInfo
        guard userInfo[OptimoveKeys.Notification.isOptipush.rawValue] as? String == "true" else {
            Logger.debug("User respond to non optimove notification")
            return false
        }
        serviceLocator.notificationListener().didReceive(
            response: response,
            withCompletionHandler: completionHandler
        )
        return true
    }
}

// MARK: - OptiPush related API
extension Optimove {

    /// Request to handle APNS <-> FCM regisration process
    ///
    /// - Parameter deviceToken: A token that was received in the appDelegate callback
    @objc public func application(didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        try? handlers.pushableHandler.handle(PushableOperationContext(.deviceToken(token: deviceToken)))
    }

    private var optimoveTestTopic: String {
        return "test_ios_\(Bundle.main.bundleIdentifier ?? "")"
    }

    /// Request to subscribe to test campaign topics
    @objc public func startTestMode() {
        registerToOptipushTopic(optimoveTestTopic)
    }

    /// Request to unsubscribe from test campaign topics
    @objc public func stopTestMode() {
        unregisterFromOptipushTopic(optimoveTestTopic)
    }

    /// Request to register to topic
    ///
    /// - Parameter topic: The topic name
    func registerToOptipushTopic(_ topic: String) {
        try? handlers.pushableHandler.handle(PushableOperationContext(.subscribeToTopic(topic: topic)))
    }

    /// Request to unregister from topic
    ///
    /// - Parameter topic: The topic name
    func unregisterFromOptipushTopic(_ topic: String) {
        try? handlers.pushableHandler.handle(PushableOperationContext(.unsubscribeFromTopic(topic: topic)))
    }

    func performRegistration() {
        try? handlers.pushableHandler.handle(PushableOperationContext(.performRegistration))
    }
}

extension Optimove: OptimoveDeepLinkResponding {

    @objc public func register(deepLinkResponder responder: OptimoveDeepLinkResponder) {
        if let dlc = self.deepLinkComponents {
            responder.didReceive(deepLinkComponent: dlc)
        } else {
            deepLinkResponders.append(responder)
        }
    }

    @objc public func unregister(deepLinkResponder responder: OptimoveDeepLinkResponder) {
        if let index = self.deepLinkResponders.firstIndex(of: responder) {
            deepLinkResponders.remove(at: index)
        }
    }
}

// MARK: - OptiTrack related API

extension Optimove {

    /// Validate the permissions of the client to use Optitrack component and if permit sends the
    /// report to the appropriate handler.
    ///
    /// - Parameters:
    ///   - event: optimove event object
    @objc public func reportEvent(_ event: OptimoveEvent) {
        do {
            try handlers.eventableHandler.handle(EventableOperationContext(.report(event: event)))
        } catch {
            Logger.error(error.localizedDescription)
        }
    }

    @objc public func reportEvent(name: String, parameters: [String: Any]) {
        let customEvent = SimpleCustomEvent(name: name, parameters: parameters)
        reportEvent(customEvent)
    }

    func dispatchQueuedEventsNow() {
        try? handlers.eventableHandler.handle(EventableOperationContext(.dispatchNow))
    }

}

// MARK: - set user id API
extension Optimove {

    enum UserIdValidationResult {
        case valid
        case notValid
        case alreadySetIn
    }

    private func validateNewUserID(_ userId: String) -> UserIdValidationResult {
        guard isValid(userId: userId) else {
            Logger.error("Optimove: User id '\(userId)' is not valid.")
            return .notValid
        }
        guard userId != storage.customerID else {
            Logger.warn("Optimove: User id '\(userId)' was already set in.")
            return .alreadySetIn
        }
        return .valid
    }

    private func updateStorage(userId: String) {
        if storage.customerID == nil {
            storage.isFirstConversion = true
        } else if userId != storage.customerID {
            Logger.debug("user id changed from '\(storage.customerID ?? "nil")' to '\(userId)'")
            if storage.isRegistrationSuccess == true {
                // send the first_conversion flag only if no previous registration has succeeded
                storage.isFirstConversion = false
            }
        }
        storage.isRegistrationSuccess = false
        storage.visitorID = userId.sha1().prefix(16).description.lowercased()
        storage.customerID = userId
    }

    /// validate the permissions of the client to use optitrack component and if permit validate the sdkId content and sends:
    /// - conversion request to the DB
    /// - new customer registraion to the registration end point
    ///
    /// - Parameter sdkId: the client unique identifier
    @objc public func setUserId(_ sdkId: String) {
        let userId = sdkId.trimmingCharacters(in: .whitespaces)
        let validationResult = validateNewUserID(userId)
        guard validationResult == .valid else { return }
        updateStorage(userId: userId)
        do {
            try handlers.eventableHandler.handle(EventableOperationContext(.setUserId(userId: userId)))
            let setUserIdEvent = SetUserIdEvent(
                originalVistorId: try storage.getInitialVisitorId(),
                userId: userId,
                updateVisitorId: try storage.getVisitorID()
            )
            reportEvent(setUserIdEvent)

            try handlers.pushableHandler.handle(PushableOperationContext(.performRegistration))
        } catch {
            Logger.error(error.localizedDescription)
        }
    }



    /// Produce a 16 characters string represents the visitor ID of the client
    ///
    /// - Parameter userId: The user ID which is the source
    /// - Returns: THe generated visitor ID
    private func getVisitorId(from userId: String) -> String {
        return userId.sha1().prefix(16).description.lowercased()
    }

    /// Send the sdk id and the user email
    ///
    /// - Parameters:
    ///   - sdkId: The user ID
    ///   - email: The user email
    @objc public func registerUser(sdkId: String, email: String) {
        setUserId(sdkId)
        setUserEmail(email: email)
    }

    /// Call for the SDK to send the user email to its components
    ///
    /// - Parameter email: The user email
    @objc public func setUserEmail(email: String) {
        guard isValid(email: email) else {
            Logger.error("Optimove: Email is not valid")
            return
        }
        storage.userEmail = email
        reportEvent(SetUserEmailEvent(email: email))
    }

    /// Validate that the user id that provided by the client, feets with optimove conditions for valid user id
    ///
    /// - Parameter userId: the client user id
    /// - Returns: An indication of the validation of the provided user id
    private func isValid(userId: String) -> Bool {
        return !userId.isEmpty && (userId != "none") && (userId != "undefined") && !userId.contains("undefine") && !(
            userId == "null"
        )
    }

    private func isValid(email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailTest.evaluate(with: email)
    }
}

extension Optimove {

    // MARK: - Report screen visit

    @objc public func setScreenVisit(screenPathArray: [String], screenTitle: String, screenCategory: String? = nil) {
        Logger.debug("Report screen event w/ title: \(screenTitle)")
        guard !screenTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
            Logger.error("Failed to report screen visit. Reason: empty title")
            return
        }
        let path = screenPathArray.joined(separator: "/")
        setScreenVisit(screenPath: path, screenTitle: screenTitle, screenCategory: screenCategory)
    }

    @objc public func setScreenVisit(screenPath: String, screenTitle: String, screenCategory: String? = nil) {
        let screenTitle = screenTitle.trimmingCharacters(in: .whitespaces)
        var screenPath = screenPath.trimmingCharacters(in: .whitespaces)
        guard !screenTitle.isEmpty else {
            Logger.error("Failed to report screen visit. Reason: empty title")
            return
        }
        guard !screenPath.isEmpty else {
            Logger.error("Failed to report screen visit. Reason: empty path")
            return
        }

        if screenPath.starts(with: "/") {
            screenPath = String(screenPath[screenPath.index(after: screenPath.startIndex)...])
        }
        if let customUrl = removeUrlProtocol(path: screenPath)
            .lowercased()
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {

            var path = customUrl.last != "/" ? "\(customUrl)/" : "\(customUrl)"

            path = "\(Bundle.main.bundleIdentifier!)/\(path)".lowercased()

            try? handlers.eventableHandler.handle(
                EventableOperationContext(
                    .reportScreenEvent(
                        customURL: path,
                        pageTitle: screenTitle,
                        category: screenCategory
                    )
                )
            )
        }
    }

    private func removeUrlProtocol(path: String) -> String {
        var result = path
        for prefix in ["https://www.", "http://www.", "https://", "http://"] {
            if result.hasPrefix(prefix) {
                result.removeFirst(prefix.count)
                break
            }
        }
        return result
    }
}

private extension Optimove {

    // MARK: - Private Methods

    /// Stores the user information that was provided during configuration.
    ///
    /// - Parameter info: user unique info
    func storeTenantInfo(_ info: OptimoveTenantInfo) {
        storage.tenantToken = info.tenantToken
        storage.version = info.configName
        storage.configurationEndPoint = Endpoints.Remote.TenantConfig.url

        Logger.debug(
            """
            Stored user info in local storage. Source:
            endpoint: \(Endpoints.Remote.TenantConfig.url.absoluteString)
            token: \(info.tenantToken)
            version: \(info.configName)
            """
        )
    }

    func configureLogger() {
        MultiplexLoggerStream.add(stream: ConsoleLoggerStream())
        if SDK.isStaging {
            MultiplexLoggerStream.add(stream: RemoteLoggerStream(tenantId: storage.siteID ?? -1))
        }
    }

    func setup() {
        setUserAgent()
        setVisitorIdIfNeeded()
    }

    func setUserAgent() {
        storage.userAgent = SDKDevice.evaluateUserAgent()
    }

    func setVisitorIdIfNeeded() {
        if storage.visitorID == nil {
            let uuid = UUID().uuidString
            let sanitizedUUID = uuid.replacingOccurrences(of: "-", with: "")
            let start = sanitizedUUID.startIndex
            let end = sanitizedUUID.index(start, offsetBy: 16)
            storage.initialVisitorId = String(sanitizedUUID[start..<end]).lowercased()
            storage.visitorID = storage.initialVisitorId
        }
    }

}
