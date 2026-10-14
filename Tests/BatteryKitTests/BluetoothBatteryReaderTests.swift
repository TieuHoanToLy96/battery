import XCTest
@testable import BatteryKit

final class BluetoothBatteryReaderTests: XCTestCase {

    private func loadFixture(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(
            forResource: name, withExtension: "json", subdirectory: "Fixtures"
        ) else {
            throw XCTSkip("Fixture \(name).json not found")
        }
        return try Data(contentsOf: url)
    }

    func testParsesConnectedDevices() throws {
        let data = try loadFixture("connected")
        let devices = BluetoothBatteryReader.parse(data)

        // 3 thiết bị kết nối; "Some Speaker" ở device_not_connected bị bỏ.
        XCTAssertEqual(devices.count, 3)

        let keyboard = try XCTUnwrap(devices.first { $0.name == "Magic Keyboard" })
        XCTAssertEqual(keyboard.address, "aabbccddee01")
        XCTAssertEqual(keyboard.percent, 85)
        XCTAssertTrue(keyboard.hasBattery)
    }

    func testAirPodsComponentsAndRepresentative() throws {
        let data = try loadFixture("connected")
        let devices = BluetoothBatteryReader.parse(data)

        let airpods = try XCTUnwrap(devices.first { $0.name == "AirPods Pro" })
        XCTAssertEqual(airpods.left, 70)
        XCTAssertEqual(airpods.right, 65)
        XCTAssertEqual(airpods.caseLevel, 90)
        // Không có Main -> đại diện = min(left, right).
        XCTAssertEqual(airpods.percent, 65)
    }

    func testDeviceWithoutBattery() throws {
        let data = try loadFixture("connected")
        let devices = BluetoothBatteryReader.parse(data)

        let mouse = try XCTUnwrap(devices.first { $0.name == "Old Mouse" })
        XCTAssertNil(mouse.percent)
        XCTAssertFalse(mouse.hasBattery)
    }

    func testEmptyAndInvalidData() {
        XCTAssertTrue(BluetoothBatteryReader.parse(Data()).isEmpty)
        XCTAssertTrue(BluetoothBatteryReader.parse(Data("not json".utf8)).isEmpty)
        XCTAssertTrue(BluetoothBatteryReader.parse(Data("{}".utf8)).isEmpty)
    }

    func testPercentValueParsing() {
        XCTAssertEqual(BluetoothBatteryReader.percentValue("80%"), 80)
        XCTAssertEqual(BluetoothBatteryReader.percentValue("80"), 80)
        XCTAssertEqual(BluetoothBatteryReader.percentValue(80), 80)
        XCTAssertEqual(BluetoothBatteryReader.percentValue("150%"), 100)
        XCTAssertEqual(BluetoothBatteryReader.percentValue("-5%"), 0)
        XCTAssertNil(BluetoothBatteryReader.percentValue("abc"))
        XCTAssertNil(BluetoothBatteryReader.percentValue(nil))
    }
}
