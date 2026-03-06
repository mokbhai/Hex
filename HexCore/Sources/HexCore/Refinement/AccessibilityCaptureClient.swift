import ApplicationServices
import Dependencies
import DependenciesMacros
import Foundation

public enum AccessibilityCaptureError: Error, LocalizedError, Sendable {
  case focusedElementUnavailable
  case setValueFailed

  public var errorDescription: String? {
    switch self {
    case .focusedElementUnavailable:
      return "Unable to find a focused UI element."
    case .setValueFailed:
      return "Unable to replace the selected text in the focused app."
    }
  }
}

@DependencyClient
public struct AccessibilityCaptureClient: Sendable {
  public var captureSelectedText: @Sendable () async throws -> String?
  public var replaceSelectedText: @Sendable (_ newValue: String) async throws -> Void
}

extension AccessibilityCaptureClient: DependencyKey {
  public static var liveValue: AccessibilityCaptureClient {
    let live = AccessibilityCaptureClientLive()
    return AccessibilityCaptureClient(
      captureSelectedText: {
        try await live.captureSelectedText()
      },
      replaceSelectedText: { text in
        try await live.replaceSelectedText(text)
      }
    )
  }
}

public extension DependencyValues {
  var accessibilityCapture: AccessibilityCaptureClient {
    get { self[AccessibilityCaptureClient.self] }
    set { self[AccessibilityCaptureClient.self] = newValue }
  }
}

actor AccessibilityCaptureClientLive {
  private let logger = HexLog.refinement

  func captureSelectedText() async throws -> String? {
    let element = try focusedElement()
    var value: CFTypeRef?

    // Preferred: selected text attribute
    if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value) == .success,
       let selected = value as? String,
       !selected.isEmpty {
      logger.notice("Captured selected text length=\(selected.count)")
      return selected
    }

    // Fallback: value attribute (common for plain text fields)
    if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
       let currentValue = value as? String,
       !currentValue.isEmpty {
      logger.notice("Captured value text length=\(currentValue.count)")
      return currentValue
    }

    logger.error("No selected text available from focused element")
    return nil
  }

  func replaceSelectedText(_ newValue: String) async throws {
    let element = try focusedElement()
    logger.notice("Replacing selected text length=\(newValue.count)")

    // First attempt to replace the selected range only
    var setResult = AXUIElementSetAttributeValue(
      element,
      kAXSelectedTextAttribute as CFString,
      newValue as CFTypeRef
    )

    if setResult != .success {
      // Fallback: replace the full value
      setResult = AXUIElementSetAttributeValue(
        element,
        kAXValueAttribute as CFString,
        newValue as CFTypeRef
      )
    }

    guard setResult == .success else {
      logger.error("Failed to set value via accessibility: \(setResult.rawValue)")
      throw AccessibilityCaptureError.setValueFailed
    }
  }

  private func focusedElement() throws -> AXUIElement {
    let systemWideElement = AXUIElementCreateSystemWide()
    var focusedElement: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(
      systemWideElement,
      kAXFocusedUIElementAttribute as CFString,
      &focusedElement
    )

    guard result == .success, let rawElement = focusedElement else {
      logger.error("No focused accessibility element available")
      throw AccessibilityCaptureError.focusedElementUnavailable
    }

    return rawElement as! AXUIElement
  }
}
