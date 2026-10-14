import XCTest
@testable import BatteryKit

final class IORegistryBatteryReaderTests: XCTestCase {

    private func loadFixture(_ name: String, ext: String) throws -> Data {
        guard let url = Bundle.module.url(
            forResource: name, withExtension: ext, subdirectory: "Fixtures"
        ) else {
            throw XCTSkip("Fixture \(name).\(ext) not found")
        }
        return try Data(contentsOf: url)
    }

    func testParsesIORegistryPlist() throws {
        let data = try loadFixture("ioreg_battery", ext: "plist")
        let devices = IORegistryBatteryReader.parse(data)

        XCTAssertEqual(devices.count, 2)

        let trackpad = try XCTUnwrap(devices.first { $0.name == "Magic Trackpad" })
        XCTAssertEqual(trackpad.address, "a07817e2b9b4")
        XCTAssertEqual(trackpad.percent, 53)

        let airpods = try XCTUnwrap(devices.first { $0.name == "AirPods Pro" })
        XCTAssertEqual(airpods.left, 80)
        XCTAssertEqual(airpods.right, 72)
        XCTAssertEqual(airpods.caseLevel, 95)
        // Không có Main/Combined -> đại diện = min(left, right).
        XCTAssertEqual(airpods.percent, 72)
    }

    func testEmptyAndInvalid() {
        XCTAssertTrue(IORegistryBatteryReader.parse(Data()).isEmpty)
        XCTAssertTrue(IORegistryBatteryReader.parse(Data("not a plist".utf8)).isEmpty)
    }

    func testCompositeMergePrefersFirstFillsGaps() {
        // Nguồn 1 (IORegistry-style): có main, thiếu case.
        let primary = StubReader([
            BluetoothDevice(address: "x", name: "AirPods", percent: 70, left: 70, right: 65, caseLevel: nil)
        ])
        // Nguồn 2 (system_profiler-style): có case, main khác (bị bỏ qua).
        let secondary = StubReader([
            BluetoothDevice(address: "x", name: "AirPods", percent: 99, left: nil, right: nil, caseLevel: 90),
            BluetoothDevice(address: "y", name: "Keyboard", percent: 40),
        ])

        let composite = CompositeBatteryReader([primary, secondary])
        let devices = try! composite.fetch()

        XCTAssertEqual(devices.count, 2)
        let airpods = devices.first { $0.address == "x" }!
        XCTAssertEqual(airpods.percent, 70)   // giữ của nguồn 1
        XCTAssertEqual(airpods.caseLevel, 90) // bù từ nguồn 2
        XCTAssertEqual(devices.first { $0.address == "y" }?.percent, 40)
    }
}

/// Reader giả cho test.
private struct StubReader: BatteryDeviceReading {
    let devices: [BluetoothDevice]
    init(_ devices: [BluetoothDevice]) { self.devices = devices }
    func fetch() throws -> [BluetoothDevice] { devices }
}
