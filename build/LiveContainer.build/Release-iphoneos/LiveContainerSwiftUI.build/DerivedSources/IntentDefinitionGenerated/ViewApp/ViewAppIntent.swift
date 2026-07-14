//
// ViewAppIntent.swift
//
// This file was automatically generated and should not be edited.
//

#if canImport(Intents)

import Intents

@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(ViewAppIntent)
public class ViewAppIntent: INIntent {

    @NSManaged public var app: App?

}

/*!
 @abstract Protocol to declare support for handling a ViewAppIntent. By implementing this protocol, a class can provide logic for resolving, confirming and handling the intent.
 @discussion The minimum requirement for an implementing class is that it should be able to handle the intent. The confirmation method is optional. The handling method is always called last, after confirming the intent.
 */
@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(ViewAppIntentHandling)
public protocol ViewAppIntentHandling: NSObjectProtocol {

    /*!
     @abstract Dynamic options methods - provide options for the parameter at runtime
     @discussion Called to query dynamic options for the parameter and this intent in its current form.

     @param  intent The input intent
     @param  completion The response block contains options for the parameter
     */
    @available(iOS 14.0, macOS 11.0, watchOS 7.0, *)
    @available(*, renamed: "provideAppOptionsCollection(for:)")
    @objc(provideAppOptionsCollectionForViewApp:withCompletion:)
    func provideAppOptionsCollection(for intent: ViewAppIntent, with completion: @escaping (INObjectCollection<App>?, Error?) -> Swift.Void)

    @available(iOS 14.0, macOS 11.0, watchOS 7.0, *)
    @objc(provideAppOptionsCollectionForViewApp:withCompletion:)
    func provideAppOptionsCollection(for intent: ViewAppIntent) async throws -> INObjectCollection<App>

    @available(*, renamed: "confirm(intent:)")
    @objc(confirmViewApp:completion:)
    optional func confirm(intent: ViewAppIntent, completion: @escaping (ViewAppIntentResponse) -> Swift.Void)

    /*!
     @abstract Confirmation method - Validate that this intent is ready for the next step (i.e. handling)
     @discussion Called prior to asking the app to handle the intent. The app should return a response object that contains additional information about the intent, which may be relevant for the system to show the user prior to handling. If unimplemented, the system will assume the intent is valid, and will assume there is no additional information relevant to this intent.

     @param  intent The input intent
     @param  completion The response block contains a ViewAppIntentResponse containing additional details about the intent that may be relevant for the system to show the user prior to handling.

     @see ViewAppIntentResponse
     */
    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(confirmViewApp:completion:)
    optional func confirm(intent: ViewAppIntent) async -> ViewAppIntentResponse

    /*!
     @abstract Handling method - Execute the task represented by the ViewAppIntent that's passed in
     @discussion Called to actually execute the intent. The app must return a response for this intent.

     @param  intent The input intent
     @param  completion The response handling block takes a ViewAppIntentResponse containing the details of the result of having executed the intent

     @see  ViewAppIntentResponse
     */
    @available(*, renamed: "handle(intent:)")
    @objc(handleViewApp:completion:)
    optional func handle(intent: ViewAppIntent, completion: @escaping (ViewAppIntentResponse) -> Swift.Void)
    
    @available(iOS 13.0, macOS 11.0, watchOS 6.0, *)
    @objc(handleViewApp:completion:)
    optional func handle(intent: ViewAppIntent) async -> ViewAppIntentResponse

    /*!
     @abstract Default values for parameters with dynamic options
     @discussion Called to query the parameter default value.
     */
    @available(iOS 14.0, macOS 11.0, watchOS 7.0, *)
    @objc(defaultAppForViewApp:)
    optional func defaultApp(for intent: ViewAppIntent) -> App?

    /*!
     @abstract Deprecated dynamic options methods.
     */
    @available(iOS, introduced: 13.0, deprecated: 14.0, message: "")
    @available(watchOS, introduced: 6.0, deprecated: 7.0, message: "")
    @objc(provideAppOptionsForViewApp:withCompletion:)
    optional func provideAppOptions(for intent: ViewAppIntent, with completion: @escaping ([App]?, Error?) -> Swift.Void)

}

/*!
 @abstract Constants indicating the state of the response.
 */
@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc public enum ViewAppIntentResponseCode: Int {
    case unspecified = 0
    case ready
    case continueInApp
    case inProgress
    case success
    case failure
    case failureRequiringAppLaunch
}

@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(ViewAppIntentResponse)
public class ViewAppIntentResponse: INIntentResponse {

    /*!
     @abstract The response code indicating your success or failure in confirming or handling the intent.
     */
    @objc public fileprivate(set) var code: ViewAppIntentResponseCode = .unspecified

    /*!
     @abstract Initializes the response object with the specified code and user activity object.
     @discussion The app extension has the option of capturing its private state as an NSUserActivity and returning it as the 'currentActivity'. If the app is launched, an NSUserActivity will be passed in with the private state. The NSUserActivity may also be used to query the app's UI extension (if provided) for a view controller representing the current intent handling state. In the case of app launch, the NSUserActivity will have its activityType set to the name of the intent. This intent object will also be available in the NSUserActivity.interaction property.

     @param  code The response code indicating your success or failure in confirming or handling the intent.
     @param  userActivity The user activity object to use when launching your app. Provide an object if you want to add information that is specific to your app. If you specify nil, the system automatically creates a user activity object for you, sets its type to the class name of the intent being handled, and fills it with an INInteraction object containing the intent and your response.
     */
    @objc(initWithCode:userActivity:)
    public convenience init(code: ViewAppIntentResponseCode, userActivity: NSUserActivity?) {
        self.init()
        self.code = code
        self.userActivity = userActivity
    }

}

#endif
