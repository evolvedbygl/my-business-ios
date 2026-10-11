//  MBFeatureFlags.swift
//  GLSmallBusiness
//
//  Switches for features that are built but not shown yet.

import Foundation

enum MBFeatureFlags {
    /// The assistant (Beta) and its Pro + AI subscription. Existing Pro + AI subscribers still open
    /// the app as Pro. Flip to true to bring all of it back.
    nonisolated static let assistantEnabled = false
}
