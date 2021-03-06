import XCTest
@testable import ServiceWorker
import JavaScriptCore

class GlobalScopeTests: XCTestCase {

    func testCanAccessGlobalVariables() {

        let sw = ServiceWorker.createTestWorker(id: name)

        sw.evaluateScript("location.host")
            .then { (val: String?) in
                XCTAssertEqual(val, "www.example.com")
            }
            .assertResolves()
    }

    func testEventListenersWork() {

        let sw = ServiceWorker.createTestWorker(id: name)
        sw.withJSContext { context in

            // should be accessible globally and in self.
            context.evaluateScript("""
                var fired = 0;
                self.addEventListener("test", function() {
                    fired++
                })

                addEventListener("test", function() {
                    fired++
                })
            """)
        }
        .then {
            let ev = ExtendableEvent(type: "test")
            return sw.dispatchEvent(ev)
        }
        .then {
            return sw.withJSContext { context in
                XCTAssertEqual(context.objectForKeyedSubscript("fired").toInt32(), 2)
            }
        }
        .assertResolves()
    }

    func testEventListenersHandleErrors() {

        let sw = ServiceWorker.createTestWorker(id: name)
        sw.withJSContext { context in

            // should be accessible globally and in self.
            context.evaluateScript("""
                self.addEventListener("activate", function () {
                    throw new Error("oh no")
                });
            """)
        }
        .then {
            let ev = ExtendableEvent(type: "activate")
            return sw.dispatchEvent(ev)
        }
        .then { () -> Int in
            return 1
        }
        .recover { error -> Int in
            XCTAssertEqual((error as! ErrorMessage).message, "Error: oh no")
            return 0
        }
        .then { val in
            XCTAssertEqual(val, 0)
        }

        .assertResolves()
    }

    func testAllEventFunctionsAreAdded() {
        let sw = ServiceWorker.createTestWorker(id: name)

        let keys = [
            "addEventListener", "removeEventListener", "dispatchEvent",
            "self.addEventListener", "self.removeEventListener", "self.dispatchEvent"
        ]

        sw.evaluateScript("[\(keys.joined(separator: ","))]")
            .then { (val: [Any]?) -> Void in
                if let valArray = val {
                    valArray.enumerated().forEach { arg in
                        let asJsVal = arg.element as? JSValue
                        XCTAssert(asJsVal == nil || asJsVal!.isUndefined == true, "Not found: " + keys[arg.offset])
                    }

                } else {
                    XCTFail("Could not get array, val: \(val)")
                }
            }
            .assertResolves()
    }

    func testHasLocation() {

        let sw = TestWorker(id: name, state: .activated, url: URL(string: "http://www.example.com/sw.js")!, content: "")

        sw.evaluateScript("[self.location, location]")
            .then { (arr: [WorkerLocation]?) -> Void in
                XCTAssertNotNil(arr?[0])
                XCTAssertNotNil(arr?[1])
                XCTAssertEqual(arr?[0], arr?[1])
                XCTAssertEqual(arr?[0].href, "http://www.example.com/sw.js")
            }
            .assertResolves()
    }
}
