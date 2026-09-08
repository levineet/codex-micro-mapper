import XCTest
import CodexMicroCore

final class HIDFrameDecoderTests: XCTestCase {
    func testDecodesFragmentedMessageWithReportIDOutsideBuffer() {
        var decoder = HIDFrameDecoder()
        let line = Array(#"{"m":"v.oai.hid","p":{"k":"ACT06","act":1,"ag":"one"}}"#.utf8)
        let split = 19

        let first = decoder.receive(
            reportID: 6,
            bytes: packet(channel: 1, payload: Array(line[..<split]))
        )
        let second = decoder.receive(
            reportID: 6,
            bytes: packet(channel: 1, payload: Array(line[split...]) + [0x0A])
        )

        XCTAssertTrue(first.isEmpty)
        XCTAssertEqual(
            second,
            [HIDKeyEvent(key: .act06, phase: .down, agent: "one")]
        )
    }

    func testDecodesCRLFWhenReportIDIsInsideBuffer() {
        var decoder = HIDFrameDecoder()
        let payload = Array(
            (#"{"method":"v.oai.hid","params":{"k":"ACT11","act":false}}"# + "\r\n").utf8
        )

        let events = decoder.receive(
            reportID: 6,
            bytes: packet(channel: 2, payload: payload, includesReportID: true)
        )

        XCTAssertEqual(events, [HIDKeyEvent(key: .act11, phase: .up)])
        XCTAssertEqual(decoder.bufferedByteCount(for: 2), 0)
    }

    func testKeepsChannelsIndependentWhileFragmentsInterleave() {
        var decoder = HIDFrameDecoder()
        let channelOneLine = Array(
            (#"{"m":"v.oai.hid","p":{"k":"ACT06","act":1}}"# + "\n").utf8
        )
        let channelTwoLine = Array(
            (#"{"m":"v.oai.hid","p":{"k":"ACT09","act":0}}"# + "\n").utf8
        )
        let split = 12

        XCTAssertTrue(decoder.receive(
            reportID: 6,
            bytes: packet(channel: 1, payload: Array(channelOneLine[..<split]))
        ).isEmpty)

        XCTAssertEqual(
            decoder.receive(reportID: 6, bytes: packet(channel: 2, payload: channelTwoLine)),
            [HIDKeyEvent(key: .act09, phase: .up)]
        )

        XCTAssertEqual(
            decoder.receive(
                reportID: 6,
                bytes: packet(channel: 1, payload: Array(channelOneLine[split...]))
            ),
            [HIDKeyEvent(key: .act06, phase: .down)]
        )
    }

    func testIgnoresBadJSONWrongMethodInvalidActionAndWrongReport() {
        var decoder = HIDFrameDecoder()
        let lines = [
            "not-json\n",
            #"{"m":"something.else","p":{"k":"ACT06","act":1}}"# + "\n",
            #"{"m":"v.oai.hid","p":{"k":"ACT06","act":"down"}}"# + "\n",
        ]

        for line in lines {
            XCTAssertTrue(decoder.receive(
                reportID: 6,
                bytes: packet(channel: 1, payload: Array(line.utf8))
            ).isEmpty)
        }

        let valid = Array((#"{"m":"v.oai.hid","p":{"k":"ACT07","act":1}}"# + "\n").utf8)
        XCTAssertTrue(decoder.receive(
            reportID: 5,
            bytes: packet(channel: 1, payload: valid)
        ).isEmpty)
        XCTAssertEqual(decoder.totalBufferedByteCount, 0)
    }

    func testNeverBuffersMoreThan64KiBAndRecoversAtNextLine() {
        var decoder = HIDFrameDecoder()
        let fragment = Array(repeating: UInt8(ascii: "x"), count: 255)

        for _ in 0..<258 {
            XCTAssertTrue(decoder.receive(
                reportID: 6,
                bytes: packet(channel: 4, payload: fragment)
            ).isEmpty)
            XCTAssertLessThanOrEqual(
                decoder.bufferedByteCount(for: 4),
                HIDFrameDecoder.maximumBufferedBytesPerChannel
            )
        }

        XCTAssertEqual(decoder.discardedOversizedLineCount, 1)

        XCTAssertTrue(decoder.receive(
            reportID: 6,
            bytes: packet(channel: 4, payload: [0x0A])
        ).isEmpty)

        let valid = Array((#"{"m":"v.oai.hid","p":{"k":"ACT12","act":1}}"# + "\n").utf8)
        XCTAssertEqual(
            decoder.receive(reportID: 6, bytes: packet(channel: 4, payload: valid)),
            [HIDKeyEvent(key: .act12, phase: .down)]
        )
    }

    func testResetDropsPartialFrames() {
        var decoder = HIDFrameDecoder()
        let partial = Array(#"{"m":"v.oai.hid""#.utf8)
        _ = decoder.receive(reportID: 6, bytes: packet(channel: 1, payload: partial))
        XCTAssertFalse(decoder.totalBufferedByteCount == 0)

        decoder.reset()

        XCTAssertEqual(decoder.totalBufferedByteCount, 0)
    }

    private func packet(
        channel: UInt8,
        payload: [UInt8],
        includesReportID: Bool = false
    ) -> [UInt8] {
        precondition(payload.count <= 255)
        let frame = [channel, UInt8(payload.count)] + payload
        return includesReportID ? [6] + frame : frame
    }
}
