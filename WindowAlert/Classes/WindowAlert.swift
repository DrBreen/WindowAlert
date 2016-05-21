import Foundation
import UIKit

/**
 WindowAlertAction describes single action that will be shown in WindowAlert.
 This objects describes action configuration, such as title of the action,
 it's style and behavior when tapping on button corresponding to this action.
 Please note that you must not call WindowAlert hide() method in WindowAlertAction handler,
 as WindowAlert will be hidden automatically after action invocation.
 */
public class WindowAlertAction {
    
    /**
     Creates and returns action with specified indentifier, title, style and action handler.
     - parameter id: Unique identifier for current action.
     - parameter title: Text that will be displayed on action button. Must be localized.
     - parameter style: Action button style.
     - parameter handler: Action to execute when action button will be selected.
     - returns: New WindowAlertAction object.
     */
    init(id: String?, title: String, style: UIAlertActionStyle, handler: ((WindowAlertAction) -> Void)?) {
        self.id = id
        self.title = title
        self.style = style
        self.action = handler
    }
    
    /**
     Creates and returns action with specified title, style and action handler, but without identifier.
     - parameter title: Text that will be displayed on action button. Must be localized.
     - parameter style: Action button style.
     - parameter handler: Action to execute when action button will be selected.
     - returns: New WindowAlertAction object.
     */
    convenience init(title: String, style: UIAlertActionStyle, handler: ((WindowAlertAction) -> Void)?) {
        self.init(id: nil, title: title, style: style, handler: handler)
    }
    
    /**
     Unique string identifier for this action.
     */
    public private(set) var id: String?
    
    /**
     Title that will be displayed on corresponding button.
     */
    public private(set) var title: String
    
    /**
     Style for WindowAlertAction. All the styles that are supported in UIAlertAction are also supported here.
     */
    public private(set) var style: UIAlertActionStyle
    
    private var action: ((WindowAlertAction) -> Void)?
}

/**
 WindowAlert is a helper object that wraps UIAlertController and UIWindow classes to simplify UIAlertController presentation logic.
 It creates new UIWindow at UIWindowLevelAlert window level(or another one,
 if you wish to redefine it via defaultWindowLevel property of WindowAlert class),
 and sets empty root UIViewController to present UIAlertController from it.
 
 This class uses APIs very similar to UIViewController APIs, but instead of presenting you'll have to call show() method, which makes it
 somewhat similar to UIAlertView.
 
 This class is not thread-safe, calling it's method from threads different from main one will lead
 to weird and buggy behavior.
 */
public class WindowAlert {
    
    /**
     Default window level for UIWindow that holds UIAlertController.
     Only change this value if you want to change WindowAlert window level globally,
     for per-alert basis please use windowLevel property of WindowAlert.
     */
    public static var defaultWindowLevel: UIWindowLevel = UIWindowLevelAlert
    
    /**
     Window level for UIWindow that holds UIAlertController.
     Changing this won't affect already shown WindowAlerts.
     */
    public var windowLevel = WindowAlert.defaultWindowLevel
    
    /**
     The actions that user can invoke for this WindowAlert.
     */
    public private(set) var actions: [WindowAlertAction]
    
    private var textFieldConfigurationHandlers: [((UITextField) -> Void)?]
    
    private var storedTitle: String?
    
    /**
     The title of the alert.
     */
    public var title: String? {
        get {
            return storedTitle
        }
        
        set(newTitle) {
            storedTitle = newTitle
            alertController?.title = newTitle
        }
    }
    
    private var storedMessage: String?
    
    /**
     The message of the alert.
     */
    public var message: String? {
        get {
            return storedMessage
        }
        
        set(newMessage) {
            storedMessage = newMessage
            alertController?.message = newMessage
        }
    }
    
    private var storedPreferredStyle: UIAlertControllerStyle
    
    /**
     Preferred style of the alert.
     */
    public var preferredStyle: UIAlertControllerStyle {
        get {
            return storedPreferredStyle
        }
    }
    
    /**
     The array of text fields displayed by the alert.
     */
    public var textFields: [UITextField]? {
        get {
            return alertController?.textFields
        }
    }
    
    /**
     Holds true if UIWindow that holds UIAlertController, and UIAlertController itself is added to window hierarchy and is visible,
     otherwise false.
     */
    public var visible: Bool {
        get {
            if let window = self.internalWindow {
                return !window.hidden
            }
            
            //if internalWindow is nil, then it can't be visible, returning false
            return false
        }
    }
    
    private var internalWindow: UIWindow?
    private var alertController: UIAlertController?
    private let rootViewController = UIViewController()
    private weak var referenceWindow: UIWindow?
    
    /**
     Creates and returns new alert with specified title, message, style and reference window.
     - parameter title: Title for the alert.
     - parameter message: Message for the alert.
     - parameter preferredStyle: Preferred style for the alert.
     - parameter referenceWindow: Window to inherit size and tint color from.
     - returns: New WindowAlert object.
     */
    public init(title: String, message: String, preferredStyle: UIAlertControllerStyle, referenceWindow: UIWindow) {
        self.referenceWindow = referenceWindow
        actions = []
        textFieldConfigurationHandlers = []
        
        storedPreferredStyle = preferredStyle
        storedTitle = title
        storedMessage = message
    }
    
    /**
     Tries to create and returns new alert with specified title, message, style and main application window
     taken from app delegate as reference window. May fail if main application window or app delegate is missing.
     - parameter title: Title for the alert.
     - parameter message: Message for the alert.
     - parameter preferredStyle: Preferred style for the alert.
     - returns: New WindowAlert object or nil if app delegate or main window is missing.
     */
    public convenience init?(title: String, message: String, preferredStyle: UIAlertControllerStyle) {
        guard let delegate = UIApplication.sharedApplication().delegate else {
            return nil
        }
        
        guard let windowPresent = delegate.window else {
            return nil
        }
        
        guard let window = windowPresent else {
            return nil
        }
        
        self.init(title: title, message: message, preferredStyle: preferredStyle, referenceWindow: window)
    }
    
    private func createNewWindowFromReferenceWindow() {
        //if reference window is present, we create window with same dimensions and tint color
        if let window = referenceWindow {
            internalWindow = UIWindow(frame: window.bounds)
            internalWindow?.tintColor = window.tintColor
            internalWindow?.windowLevel = windowLevel
            internalWindow?.rootViewController = rootViewController
        }
    }
    
    private func createAlertController() {
        alertController = UIAlertController(title: storedTitle, message: storedMessage, preferredStyle: storedPreferredStyle)
        
        //safe to unwrap since we just created it
        for action in actions {
            alertController!.addAction(convertWindowAlertViewActionToAlertControllerAction(windowAlertViewAction: action))
        }
        
        for textFieldConfigurationHandler in textFieldConfigurationHandlers {
            alertController!.addTextFieldWithConfigurationHandler(textFieldConfigurationHandler)
        }
    }
    
    /**
     Add new window to window hieararchy at set window level, and present UIAlertController
     on top of invisible root view controller attached to this new window.
     - returns: True if UIAlertController was presented, false otherwise(was already presented, or reference window is missing)
     */
    public func show() -> Bool {
        if(visible) {
            return false
        }
        
        createNewWindowFromReferenceWindow()
        
        guard let window = internalWindow else {
            //this will only fail if reference window is missing
            return false
        }
        
        createAlertController()
        
        //at this point alertController is not nil thanks to ensureAlertController(), so it's safe to unwrap alertController
        //it's also safe to unwrap rootViewController, thanks to ensureWindowIfPossible()
        window.makeKeyAndVisible()
        window.rootViewController!.presentViewController(alertController!, animated: true, completion: nil)
        
        return true
    }
    
    
    /**
     Removes window from window hierarchy and dismisses UIAlertController.
     - returns: True if was hidden successfully, false if tried to hide already hidden alert.
     */
    public func hide() -> Bool {
        //if WindowAlert is already hidden, no need to proceed
        if(!visible) {
            return false
        }
        
        guard let window = internalWindow else {
            return false
        }
        
        window.rootViewController!.dismissViewControllerAnimated(true, completion: {
            //removing window from window hierarchy, and getting rid of unnecessary resources
            window.hidden = true
            window.removeFromSuperview()
            self.internalWindow = nil
            self.alertController = nil
        })
        
        return true
    }
    
    /**
     Attaches an action to this WindowAlert.
     Please remember not to call hide() inside of action handler, as WindowAlert will
     hide automatically when action is invoked.
     - parameter action: Action to add to the alert.
     */
    public func addAction(action: WindowAlertAction) {
        let alertAction = convertWindowAlertViewActionToAlertControllerAction(windowAlertViewAction: action)
        actions.append(action)
        alertController?.addAction(alertAction)
    }
    
    private func convertWindowAlertViewActionToAlertControllerAction(windowAlertViewAction action: WindowAlertAction) -> UIAlertAction {
        var selfReference: WindowAlert? = self
        let actualAction = action.action
        let alertAction = UIAlertAction(title: action.title, style: action.style) { _ in
            actualAction?(action)
            
            
            //no need to dismiss UIAlertController, as it's automatically dismissed
            //removing window from window hierarchy, and getting rid of unnecessary resources
            selfReference?.internalWindow?.hidden = true
            selfReference?.internalWindow?.removeFromSuperview()
            selfReference?.internalWindow = nil
            selfReference?.alertController = nil
            
            //now onto preventing retain cycle
            selfReference = nil
        }
        return alertAction
    }
    
    /**
     Adds a text field to an alert.
     - parameter configurationHandler: Action to be invoked with UITextField as argument before
     showing alert to the user. Use this action to configure UITextField parameters.
     */
    public func addTextFieldWithConfigurationHandler(configurationHandler: ((UITextField) -> Void)?) {
        textFieldConfigurationHandlers.append(configurationHandler)
        alertController?.addTextFieldWithConfigurationHandler(configurationHandler)
    }
}