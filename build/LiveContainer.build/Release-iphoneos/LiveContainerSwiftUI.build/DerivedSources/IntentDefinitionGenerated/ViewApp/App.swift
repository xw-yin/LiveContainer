//
// App.swift
//
// This file was automatically generated and should not be edited.
//

#if canImport(Intents)

import Intents

@available(iOS 12.0, macOS 11.0, watchOS 5.0, *) @available(tvOS, unavailable)
@objc(App)
public class App: INObject {

    override public class var supportsSecureCoding: Bool { true }

}

@available(iOS 13.0, macOS 11.0, watchOS 6.0, *) @available(tvOS, unavailable)
@objc(AppResolutionResult)
public class AppResolutionResult: INObjectResolutionResult {

    // This resolution result is for when the app extension wants to tell Siri to proceed, with a given App. The resolvedValue can be different than the original App. This allows app extensions to apply business logic constraints.
    // Use notRequired() to continue with a 'nil' value.
    @objc(successWithResolvedApp:)
    public class func success(with resolvedObject: App) -> Self {
        return super.success(with: resolvedObject)
    }

    // This resolution result is to ask Siri to disambiguate between the provided App.
    @objc(disambiguationWithAppsToDisambiguate:)
    public class func disambiguation(with objectsToDisambiguate: [App]) -> Self {
        return super.disambiguation(with: objectsToDisambiguate)
    }

    // This resolution result is to ask Siri to confirm if this is the value with which the user wants to continue.
    @objc(confirmationRequiredWithAppToConfirm:)
    public class func confirmationRequired(with objectToConfirm: App?) -> Self {
        return super.confirmationRequired(with: objectToConfirm)
    }

    @available(*, unavailable)
    override public class func success(with resolvedObject: INObject) -> Self {
        fatalError()
    }

    @available(*, unavailable)
    override public class func disambiguation(with objectsToDisambiguate: [INObject]) -> Self {
        fatalError()
    }

    @available(*, unavailable)
    override public class func confirmationRequired(with objectToConfirm: INObject?) -> Self {
        fatalError()
    }

}

#endif
