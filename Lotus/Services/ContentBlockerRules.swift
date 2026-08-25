//
//  ContentBlockerRules.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/23/26.
//

import Foundation

/// Generates WebKit content blocker JSON rule definitions inspired by uBlock Origin,
/// EasyList, and EasyPrivacy for blocking ads, popups, push ads, trackers, telemetry, and cosmetic placeholders.
enum ContentBlockerRules {

    static let ruleListIdentifier = "LotusAdBlockRules"
    static let allowlistRuleListIdentifier = "LotusAllowlistRules"
    static let rulesVersion = "4.0.0"

    // MARK: - Ad Networks, Ad Exchanges, & Video Ad Domains

    private static let adDomains: [String] = [
        // Google & DoubleClick
        "doubleclick.net",
        "googlesyndication.com",
        "googleadservices.com",
        "adservice.google.com",
        "pagead2.googlesyndication.com",
        "adwords.google.com",
        "googleads.g.doubleclick.net",
        "securepubads.g.doubleclick.net",
        "partner.googleadservices.com",
        "tpc.googlesyndication.com",
        "static.doubleclick.net",
        "adx.g.doubleclick.net",
        "2mdn.net",
        "invitemedia.com",
        "admeld.com",
        "admob.com",

        // Video Ad Networks & Video DSPs
        "aniview.com",
        "aniview.tv",
        "telaria.com",
        "freewheel.tv",
        "fwmrm.net",
        "tremorhub.com",
        "tremormedia.com",
        "spotx.tv",
        "spotxchange.com",
        "springserve.com",
        "vidoomy.com",
        "videologygroup.com",
        "unruly.co",
        "teads.tv",
        "teads.com",
        "jwpsrv.com",
        "streamrail.com",
        "playwire.com",
        "brid.tv",
        "vungle.com",
        "unityads.unity3d.com",
        "applovin.com",
        "chartboost.com",
        "mintegral.com",
        "inmobi.com",
        "adcolony.com",
        "tapjoy.com",
        "fyber.com",
        "smaato.net",
        "innovid.com",
        "dynadmic.com",
        "vidazoo.com",
        "undertone.com",
        "showheroes.com",
        "primis.tech",
        "ex.co",
        "anyclip.com",
        "connatix.com",

        // Popups, Popunders, Redirects & Interstitials
        "adsterra.com",
        "clickadu.com",
        "hilltopads.com",
        "exoclick.com",
        "trafficstars.com",
        "trafficjunky.com",
        "juicyads.com",
        "plugrush.com",
        "adcash.com",
        "admaven.com",
        "ad-maven.com",
        "monetag.com",
        "rollerads.com",
        "richpush.co",
        "evadav.com",
        "onclickalgo.com",
        "onclickpredictv.com",
        "popads.net",
        "popcash.net",
        "propellerads.com",
        "popunder.net",
        "poponclick.com",
        "yllix.com",
        "bidvertiser.com",
        "adclickmedia.com",
        "spopup.com",
        "wigetmedia.com",
        "yepads.com",
        "galaksion.com",
        "clickaine.com",
        "ezmob.com",
        "adxad.com",
        "ero-advertising.com",
        "tubecorporate.com",
        "trafficfactory.biz",
        "runative-syndicate.com",

        // Web Push Ad Networks & Notification Spam
        "pushengage.com",
        "subscribers.com",
        "pushassist.com",
        "pushowl.com",
        "aimtell.com",
        "onesignal.com",
        "cleverpush.com",
        "notix.io",
        "pushwoosh.com",
        "push-sdk.com",
        "in-page-push.com",
        "pushprompts.com",
        "push-notification.org",
        "p-n.io",
        "gravitec.net",
        "izooto.com",

        // Major DSPs, Exchanges & SSPs
        "adnxs.com",
        "adnxs.net",
        "adsymptotic.com",
        "adroll.com",
        "adsrvr.org",
        "adsystem.com",
        "amazon-adsystem.com",
        "a-ads.com",
        "bidswitch.net",
        "buysellads.com",
        "buysellads.net",
        "casalemedia.com",
        "criteo.com",
        "criteo.net",
        "infolinks.com",
        "media.net",
        "moatads.com",
        "openx.net",
        "openx.com",
        "outbrain.com",
        "outbrainimg.com",
        "pubmatic.com",
        "revcontent.com",
        "rubiconproject.com",
        "serving-sys.com",
        "sharethrough.com",
        "smartadserver.com",
        "sovrn.com",
        "taboola.com",
        "trafficjunior.com",
        "yieldmo.com",
        "zedo.com",
        "adform.net",
        "adpushup.com",
        "adblade.com",
        "adcell.com",
        "adition.com",
        "adman.gr",
        "admanmedia.com",
        "adreactor.com",
        "adtegrity.com",
        "adzerk.net",
        "adkernel.com",
        "adbutler.com",
        "adspirit.de",
        "adtrue.com",
        "advanse.com",
        "adzerk.com",
        "affinity.com",
        "alexametrics.com",
        "audience2media.com",
        "clickfuse.com",
        "conversantmedia.com",
        "distroscale.com",
        "emxdgt.com",
        "ezoic.com",
        "ezoic.net",
        "gumgum.com",
        "indexexchange.com",
        "intentiq.com",
        "kargo.com",
        "kevel.com",
        "komoona.com",
        "liveintent.com",
        "mgid.com",
        "nativo.com",
        "onetag.com",
        "powerlinks.com",
        "pulsepoint.com",
        "richaudience.com",
        "seedtag.com",
        "simpli.fi",
        "sonobi.com",
        "stackadapt.com",
        "themonetizer.com",
        "triplelift.com",
        "widespace.com",
        "yieldlab.net",
        "yieldone.com",
        "yieldoptimizer.com",
        "yieldpartner.com",
        "yieldbird.com",
        "ad-delivery.net",
        "adlightning.com",
        "adlooxtracking.com",
        "admarvel.com",
        "admedo.com",
        "admicro.vn",
        "adoperator.com",
        "adprotect.net",
        "adrecover.com",
        "adriver.ru",
        "adskeeper.com",
        "adskeeper.co.uk",
        "adtarget.me",
        "adthrive.com",
        "adverline.com",
        "adwhirl.com",
        "adxpose.com",
        "bidtheatre.com",
        "carbonads.net",
        "connextra.com",
        "content-ad.net",
        "dianomi.com",
        "engageya.com",
        "exponential.com",
        "eyewonder.com",
        "fastclick.net",
        "flashtalking.com",
        "imrworldwide.com",
        "interclick.com",
        "leadboltads.net",
        "lijit.com",
        "mediaplex.com",
        "tribalfusion.com",
        "valueclick.com",
        "zergnet.com",
        "mediavine.com",
        "raptive.com",
        "monumetric.com",
        "shemedia.com",
        "gwallet.com",
        "contextweb.com",
        "directrev.com"
    ]

    // MARK: - Trackers, Telemetry, Fingerprinting & Behavioral Analytics

    private static let trackerDomains: [String] = [
        "google-analytics.com",
        "analytics.google.com",
        "googletagmanager.com",
        "googletagservices.com",
        "stats.g.doubleclick.net",
        "hotjar.com",
        "hotjar.io",
        "script.hotjar.com",
        "scorecardresearch.com",
        "quantserve.com",
        "quantcount.com",
        "mixpanel.com",
        "api.mixpanel.com",
        "segment.io",
        "segment.com",
        "cdn.segment.com",
        "optimizely.com",
        "logx.optimizely.com",
        "crazyegg.com",
        "chartbeat.com",
        "chartbeat.net",
        "mouseflow.com",
        "fullstory.com",
        "heapanalytics.com",
        "newrelic.com",
        "nr-data.net",
        "branch.io",
        "adjust.com",
        "appsflyer.com",
        "datadoghq-browser-agent.com",
        "browser-http-intake.logs.datadoghq.com",
        "browser-intake-datadoghq.com",
        "clarity.ms",
        "c.clarity.ms",
        "c.bing.com",
        "bat.bing.com",
        "yandex.ru/metrika",
        "mc.yandex.ru",
        "cxense.com",
        "parsely.com",
        "permutive.com",
        "bluekai.com",
        "krxd.net",
        "liveramp.com",
        "rlcdn.com",
        "agkn.com",
        "demdex.net",
        "omtrdc.net",
        "2o7.net",
        "everesttech.net",
        "exelator.com",
        "liadm.com",
        "mathtag.com",
        "turn.com",
        "tapad.com",
        "eyeota.net",
        "lotame.com",
        "crwdcntrl.net",
        "bkrtx.com",
        "tidaltv.com",
        "visualdna.com",
        "webtrekk.net",
        "woopra.com",
        "clicky.com",
        "statcounter.com",
        "histats.com",
        "gemius.pl",
        "sensic.net",
        "amplitude.com",
        "api.amplitude.com",
        "braze.com",
        "appboy.com",
        "kissmetrics.com",
        "userzoom.com",
        "inspectlet.com",
        "luckyorange.com",
        "freshmarketer.com",
        "sessioncam.com",
        "vgo.io",
        "vwo.com",
        "smartlook.com",
        "logrocket.io",
        "lr-ingest.io",
        "sentry.io",
        "browser.sentry-cdn.com",
        "sdk.split.io",
        "launchdarkly.com",
        "events.launchdarkly.com",
        "posthog.com",
        "eu.posthog.com",
        "app.posthog.com",

        // Fingerprinting Endpoints & Anti-Adblock Scripts
        "fingerprint.com",
        "fpjs.io",
        "api.fpjs.io",
        "api.fingerprint.com",
        "fpjs.pro",
        "fingerprintjs.com",
        "openfpcdn.io",
        "fundingchoicesmessages.google.com",
        "adblock-analytics.com",
        "antiadblocksystems.com",
        "admiral.com",
        "getadmiral.com"
    ]

    // MARK: - Cryptominers & Malicious Hosts

    private static let minerDomains: [String] = [
        "coinhive.com",
        "crypto-loot.com",
        "jsecoin.com",
        "webminepool.com",
        "minr.pw",
        "monerominer.rocks",
        "coin-have.com",
        "authedmine.com"
    ]

    // MARK: - Pattern Based Ad, Pixel & Video Telemetry Endpoints

    private static let adURLRegexPatterns: [String] = [
        // YouTube Ad & Tracking Endpoints (leaves video playback streams intact)
        "^https?://.*youtube\\.com/api/stats/ads",
        "^https?://.*youtube\\.com/pagead/",
        "^https?://.*youtube\\.com/get_midroll_info",
        "^https?://.*youtube\\.com/ptracking",
        "^https?://.*youtube\\.com/api/stats/qoe",
        "^https?://.*youtube\\.com/youtubei/v1/player/ad_break",
        "^https?://.*youtube\\.com/api/stats/playback",
        "^https?://.*youtube\\.com/api/stats/atr",

        // Google & DoubleClick Ad Endpoints
        "^https?://.*googleads\\.g\\.doubleclick\\.net/pagead/",
        "^https?://.*googleads\\.g\\.doubleclick\\.net/pcs/view",
        "^https?://.*pagead2\\.googlesyndication\\.com/pagead/",
        "^https?://.*pagead2\\.google\\.",
        "^https?://.*adservice\\.google\\.",

        // Social Media Tracking & Pixel Endpoints
        "^https?://.*facebook\\.com/tr\\?",
        "^https?://.*connect\\.facebook\\.net/.*/fbevents\\.js",
        "^https?://.*tiktok\\.com/api/.*/pixel",
        "^https?://.*analytics\\.tiktok\\.com/",
        "^https?://.*analytics\\.twitter\\.com/i/adsct",
        "^https?://.*ads-twitter\\.com/",
        "^https?://.*t\\.co/i/adsct",
        "^https?://.*linkedin\\.com/li/track",
        "^https?://.*px\\.ads\\.linkedin\\.com/",
        "^https?://.*snap\\.licdn\\.com/",
        "^https?://.*ct\\.pinterest\\.com/v3/",
        "^https?://.*redditstatic\\.com/ads/",
        "^https?://.*ads\\.reddit\\.com/",
        "^https?://.*events\\.reddit\\.com/",
        "^https?://.*tr\\.snapchat\\.com/",
        "^https?://.*sc-static\\.net/scevent\\.min\\.js",
        "^https?://.*q\\.quora\\.com/_/ad/",
        "^https?://.*bat\\.bing\\.com/action/",
        "^https?://.*c\\.clarity\\.ms/c\\.gif"
    ]

    // MARK: - Cosmetic CSS Element Hiding Selectors

    private static let cosmeticSelectors: [String] = [
        // Google Ads & DFP
        ".adsbygoogle",
        "ins.adsbygoogle",
        "[id^='google_ads_']",
        "[id^='div-gpt-ad']",
        "[id*='google_ad']",
        "[data-google-query-id]",
        "[data-ad-client]",
        "[data-ad-slot]",
        "[data-ad-unit]",
        "[data-dfp-id]",
        ".dfp-ad-slot",

        // Generic Ad Containers, Banners & Sponsored Units
        "[class*='ad-container']",
        "[class*='ad-banner']",
        "[class*='ad-wrapper']",
        "[class*='ad-slot']",
        "[class*='ad-unit']",
        "[class*='ad_wrapper']",
        "[class*='ad_slot']",
        "[class*='ad_unit']",
        "[class*='ad_banner']",
        "[class*='ad_block']",
        "[class*='advertisement']",
        "[class*='advert-block']",
        "[class*='ad-leaderboard']",
        "[class*='ad-sidebar']",
        "[class*='ad-footer']",
        "[class*='top-ad-banner']",
        "[class*='sticky-ad-bar']",
        "[class*='banner-ad']",
        "[class*='banner_ad']",
        "[class*='native-ad']",
        "[class*='native_ad']",
        "[class*='sponsored-post']",
        "[class*='sponsored-content']",
        "[class*='sponsored-article']",
        "[class*='sponsor-container']",
        "[class*='commercial-unit']",
        "[class*='promoted-tweet']",
        "[class*='feed-shared-update-v2__sponsored-content']",
        "[aria-label='advertisement' i]",
        "[aria-label='sponsored' i]",
        "[data-ad]",
        "[data-ad-name]",
        "[data-adclient]",
        "[data-native-ad]",
        "[data-ad-preview]",
        "[data-ad-placeholder]",
        "[data-ad-wrapper]",
        "[data-ad-container]",
        "[data-ad-layout]",
        ".trc_rbox_header",
        ".mediavine-video-wrapper",
        ".ad-placement",
        ".ad-placeholder",

        // Push Notification Prompts & In-Page Dialogs
        "[class*='onesignal']",
        "[id*='onesignal']",
        "[class*='push-prompt']",
        "[id*='push-prompt']",
        ".sp-prompt",
        ".webpush-prompt",
        ".pushcrew-chrome-prompt",
        ".push-prompt-box",
        ".notification-prompt",
        "[class*='inpage-push']",
        ".in-page-push-wrapper",
        ".push-optin-container",

        // Interstitials, Overlays & Popups
        "[class*='interstitial']",
        "[id*='interstitial']",
        "[class*='fullscreen-ad']",
        "[class*='floating-banner']",
        ".floating-ad",
        "[class*='overlay-ad']",
        "[id*='overlay-ad']",
        "[class*='sticky-banner']",
        "[id*='sticky-banner']",
        "[class*='bottom-sticky']",
        "[class*='top-sticky-ad']",
        ".ad-interstitial",
        ".interstitial-wrapper",
        "div[class*='ad-sticky']",
        "div[id*='ad-sticky']",

        // Taboola, Outbrain & Content Recommendation Networks
        "[class*='taboola-']",
        "[class*='outbrain-']",
        "[id*='taboola-']",
        "[id*='outbrain-']",
        ".trc_related_container",
        ".trc_rbox_div",
        ".ob-smartfeed-wrapper",
        ".ob-widget",
        ".mgbox",
        ".mgid-container",

        // Carbon Ads
        "#carbonads",
        ".carbon-img",
        ".carbon-text",
        ".carbon-poweredby",

        // Video Ads & YouTube Overlays
        ".video-ad-overlay",
        ".ytp-ad-overlay-container",
        ".ytp-ad-message-container",
        ".ytp-ad-player-overlay",
        ".ytp-ad-action-interstitial",
        ".ytp-ad-module",
        ".ytp-ad-text-overlay",
        "ytd-promoted-video-renderer",
        "ytd-banner-promo-renderer",
        "ytd-statement-banner-renderer",
        "ytd-in-feed-ad-layout-renderer",
        "ytd-ad-slot-renderer",
        "ytd-display-ad-renderer",
        "ytd-primetime-promo-renderer",
        "ytd-compact-promoted-video-renderer",
        "ytd-video-masthead-ad-v3-renderer",
        "#masthead-ad",
        "#player-ads",
        ".ytd-mealbar-promo-renderer",
        "ytd-rich-item-renderer:has(ytd-ad-slot-renderer)",
        "ytd-rich-item-renderer:has(ytd-in-feed-ad-layout-renderer)",
        "ytd-rich-section-renderer:has(ytd-ad-slot-renderer)",
        "ytd-rich-section-renderer:has(ytd-statement-banner-renderer)",
        "ytd-engagement-panel-section-list-renderer[target-id='engagement-panel-ads']",
        "tp-yt-paper-dialog:has(ytd-enforcement-message-view-model)",
        "ytd-enforcement-message-view-model",

        // Ad Iframes
        "iframe[src*='doubleclick']",
        "iframe[src*='adservice']",
        "iframe[src*='adnxs']",
        "iframe[src*='outbrain']",
        "iframe[src*='taboola']",
        "iframe[src*='criteo']",
        "iframe[src*='amazon-adsystem']",
        "iframe[id^='google_ads_frame']",
        "iframe[id^='aswift_']"
    ]

    // MARK: - Rule Generation

    /// Builds the base JSON string containing ad blocking, tracking prevention,
    /// and cosmetic element hiding rules.
    static func generateDefaultRuleListJSON() -> String {
        var rules: [[String: Any]] = []

        // Format a domain for WebKit rule trigger
        func formatDomain(_ domain: String) -> String {
            domain.hasPrefix("*") ? domain : "*\(domain)"
        }

        // 1. Grouped Domain Blocking (Ad Networks, Trackers, Miners)
        let allBlockedDomains = (adDomains + trackerDomains + minerDomains)
            .map { formatDomain($0) }

        // Auth domains that must never have essential login resources blocked
        let authUnlessDomains = [
            "*accounts.google.com",
            "*myaccount.google.com",
            "*appleid.apple.com",
            "*idmsa.apple.com",
            "*login.microsoftonline.com",
            "*login.live.com"
        ]

        // Allow essential authentication domains to bypass any domain-level blocks
        rules.append([
            "trigger": [
                "url-filter": ".*",
                "if-domain": authUnlessDomains
            ],
            "action": [
                "type": "ignore-previous-rules"
            ]
        ])

        // Chunk domain lists into batches of 150 for WebKit rule list performance
        let chunkSize = 150
        for i in stride(from: 0, to: allBlockedDomains.count, by: chunkSize) {
            let chunk = Array(allBlockedDomains[i..<min(i + chunkSize, allBlockedDomains.count)])
            rules.append([
                "trigger": [
                    "url-filter": ".*",
                    "if-domain": chunk
                ],
                "action": [
                    "type": "block"
                ]
            ])
        }

        // 2. Pattern-based URL & Endpoint blocking (using simple prefix/substring filters without alternations)
        for pattern in adURLRegexPatterns {
            rules.append([
                "trigger": [
                    "url-filter": pattern,
                    "load-type": ["third-party"]
                ],
                "action": [
                    "type": "block"
                ]
            ])
        }

        // 3. Popups & Third-Party Popunders
        rules.append([
            "trigger": [
                "url-filter": ".*",
                "resource-type": ["popup"],
                "load-type": ["third-party"]
            ],
            "action": [
                "type": "block"
            ]
        ])

        // 4. Universal Cosmetic Element Hiding
        let combinedSelector = cosmeticSelectors.joined(separator: ", ")
        rules.append([
            "trigger": [
                "url-filter": ".*"
            ],
            "action": [
                "type": "css-display-none",
                "selector": combinedSelector
            ]
        ])

        guard let data = try? JSONSerialization.data(withJSONObject: rules, options: []),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return jsonString
    }

    /// Builds the allowlist JSON string to ignore blocking rules on user-whitelisted domains.
    static func generateAllowlistJSON(domains: Set<String>) -> String {
        guard !domains.isEmpty else {
            return "[]"
        }

        let formattedDomains = domains.map { domain -> String in
            domain.hasPrefix("*") ? domain : "*\(domain)"
        }

        let rules: [[String: Any]] = [
            [
                "trigger": [
                    "url-filter": ".*",
                    "if-domain": formattedDomains
                ],
                "action": [
                    "type": "ignore-previous-rules"
                ]
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: rules, options: []),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return jsonString
    }
}
