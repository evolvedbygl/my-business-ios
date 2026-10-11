//  AboutScreen.swift — the APP's page: identity (icon + version), legal + support links, and the
//  Gold Life apps showcase.
//
//  Powered turnkey by GoldLifeUI.GLAboutScreen (canonical fleet About standard). The app supplies
//  only its unique identity, localized strings, and in-app legal sheets.

import SwiftUI
import GoldLifeUI

struct AboutScreen: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GLAboutScreen(
            appName: "My Business",
            tagline: mbLoc("Invoices, estimates, payroll, and customer accounting."),
            supportEmail: "software@evolvedbygl.com",
            supportSubject: "My Business Support",
            title: mbLoc("About"),
            localizedTagline: { MBLocalization.shared.dynamic($0) },
            icon: {
                Image("appMark")
                    .resizable()
                    .scaledToFit()
            },
            privacyDestination: {
                PrivacyPolicySheet(showsBanners: true).glAppearance(colorScheme)
            },
            termsDestination: {
                TermsOfUseSheet(showsBanners: true).glAppearance(colorScheme)
            }
        )
        .mbSystemBanners()
    }
}

// MARK: - In-app legal

/// The app's PUBLISHED Privacy Policy in the fleet's one embed web sheet (GoldLifeUI
/// `GLEmbedWebSheet`): one source of truth (the website), tagged with the app's language. The
/// address is read fresh each time the sheet is built, so a language change takes.
struct PrivacyPolicySheet: View {
    /// The standing notices ride under the bar only where the sheet opens from a signed-in screen
    /// (About); the sign-in gate and the paywall keep the absence.
    var showsBanners = false

    var body: some View {
        if showsBanners {
            GLEmbedWebSheet(url: MBLocalization.webURL("https://software.evolvedbygl.com/embed/my-business/privacy"),
                            title: mbLoc("Privacy Policy"),
                            failureTitle: "Couldn’t load the Privacy Policy") { MBSystemBannerInset() }
        } else {
            GLEmbedWebSheet(url: MBLocalization.webURL("https://software.evolvedbygl.com/embed/my-business/privacy"),
                            title: mbLoc("Privacy Policy"),
                            failureTitle: "Couldn’t load the Privacy Policy")
        }
    }
}

/// The twin of `PrivacyPolicySheet` for the Terms of Use.
struct TermsOfUseSheet: View {
    /// See `PrivacyPolicySheet.showsBanners`.
    var showsBanners = false

    var body: some View {
        if showsBanners {
            GLEmbedWebSheet(url: MBLocalization.webURL("https://software.evolvedbygl.com/embed/my-business/terms"),
                            title: mbLoc("Terms of Use"),
                            failureTitle: "Couldn’t load the Terms of Use") { MBSystemBannerInset() }
        } else {
            GLEmbedWebSheet(url: MBLocalization.webURL("https://software.evolvedbygl.com/embed/my-business/terms"),
                            title: mbLoc("Terms of Use"),
                            failureTitle: "Couldn’t load the Terms of Use")
        }
    }
}
