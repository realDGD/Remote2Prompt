import SwiftUI

// SDK 27 also declares a State macro whose plugin is absent from standalone CLT.
// A distinct name selects the existing public property wrapper on both old and new SDKs.
typealias ViewState<Value> = SwiftUI.State<Value>
