import XCTest
@testable import AeroSpace_Debug

final class ConfigTest: XCTestCase {
    func testParseI3Config() {
        let toml = try! String(contentsOf: projectRoot.appending(component: "config-examples/i3-like-config-example.toml"))
        let (i3Config, errors) = parseConfig(toml).toTuple()
        XCTAssertEqual(errors.descriptions, [])
        XCTAssertEqual(i3Config.autoFlattenContainers, false)
    }

    func testParseMode() {
        let (config, errors) = parseConfig(
            """
            [mode.main.binding]
            alt-h = 'focus left'
            """
        ).toTuple()
        XCTAssertEqual(errors.descriptions, [])
        XCTAssertEqual(
            config.modes[mainModeId],
            Mode(name: nil, bindings: [HotkeyBinding(.option, .h, FocusCommand(direction: .left))])
        )
    }

    func testModesMustContainDefaultModeError() {
        let (config, errors) = parseConfig(
            """
            [mode.foo.binding]
            alt-h = 'focus left'
            """
        ).toTuple()
        XCTAssertEqual(
            errors.descriptions,
            ["mode: Please specify \'main\' mode"]
        )
        XCTAssertEqual(config.modes[mainModeId], nil)
    }

    func testHotkeyParseError() {
        let (config, errors) = parseConfig(
            """
            [mode.main.binding]
            alt-hh = 'focus left'
            aalt-j = 'focus down'
            alt-k = 'focus up'
            """
        ).toTuple()
        XCTAssertEqual(
            errors.descriptions,
            ["mode.main.binding.aalt-j: Can\'t parse modifiers in \'aalt-j\' binding",
             "mode.main.binding.alt-hh: Can\'t parse the key in \'alt-hh\' binding"]
        )
        XCTAssertEqual(
            config.modes[mainModeId],
            Mode(name: nil, bindings: [HotkeyBinding(.option, .k, FocusCommand(direction: .up))])
        )
    }

    func testUnknownKeyParseError() {
        let (config, errors) = parseConfig(
            """
            unknownKey = true
            auto-flatten-containers = false
            """
        ).toTuple()
        XCTAssertEqual(
            errors.descriptions,
            ["unknownKey: Unknown key"]
        )
        XCTAssertEqual(config.autoFlattenContainers, false)
    }

    func testTypeMismatch() {
        let (_, errors) = parseConfig(
            """
            auto-flatten-containers = 'true'
            """
        ).toTuple()
        XCTAssertEqual(
            errors.descriptions,
            ["auto-flatten-containers: Expected type is \'bool\'. But actual type is \'string\'"]
        )
    }
}

private extension [TomlParseError] {
    var descriptions: [String] { map { $0.description } }
}

extension Mode: Equatable {
    public static func ==(lhs: AeroSpace_Debug.Mode, rhs: AeroSpace_Debug.Mode) -> Bool {
        lhs.name == rhs.name && lhs.bindings == rhs.bindings
    }
}

extension HotkeyBinding: Equatable {
    public static func ==(lhs: AeroSpace_Debug.HotkeyBinding, rhs: AeroSpace_Debug.HotkeyBinding) -> Bool {
        lhs.modifiers == rhs.modifiers && lhs.key == rhs.key && lhs.command.describe == rhs.command.describe
    }
}

extension Command {
    var describe: CommandDescription {
        if let focus = self as? FocusCommand {
            return .focusCommand(focus.direction)
        }
        error("Unsupported command: \(self)")
    }
}

enum CommandDescription: Equatable {
    case focusCommand(FocusCommand.Direction)
}