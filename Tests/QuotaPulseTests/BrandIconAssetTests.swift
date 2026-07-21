import AppKit
import XCTest

final class BrandIconAssetTests: XCTestCase {
    func testAppIconMasterIsStandardSizeWithTransparentCorners() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repositoryRoot = testsDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let iconURL = repositoryRoot
            .appendingPathComponent("script/assets/QuotaPulse-AppIcon-Master.png")

        let data = try Data(contentsOf: iconURL)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))

        XCTAssertEqual(bitmap.pixelsWide, 1024)
        XCTAssertEqual(bitmap.pixelsHigh, 1024)

        let corners = [
            NSPoint(x: 0, y: 0),
            NSPoint(x: bitmap.pixelsWide - 1, y: 0),
            NSPoint(x: 0, y: bitmap.pixelsHigh - 1),
            NSPoint(x: bitmap.pixelsWide - 1, y: bitmap.pixelsHigh - 1),
        ]
        for corner in corners {
            XCTAssertLessThan(try XCTUnwrap(bitmap.colorAt(x: Int(corner.x), y: Int(corner.y))).alphaComponent, 0.01)
        }
    }
}
