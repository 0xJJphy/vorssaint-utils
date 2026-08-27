// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum MenuBarHiderTests {
    static func run(_ suite: TestSuite) {
        // MARK: Menu Bar Hider calculations and localization
        suite.expect(MenuBarHiderSupport.sanitizeAutoCollapseDelay(5) == 5, "auto-collapse delay 5 is valid")
        suite.expect(MenuBarHiderSupport.sanitizeAutoCollapseDelay(30) == 30, "auto-collapse delay 30 is valid")
        suite.expect(MenuBarHiderSupport.sanitizeAutoCollapseDelay(99) == MenuBarHiderSupport.defaultAutoCollapseDelay, "invalid auto-collapse delay resets to default")
        suite.expect(MenuBarHiderSupport.sanitizeAutoCollapseDelay(-5) == MenuBarHiderSupport.defaultAutoCollapseDelay, "negative auto-collapse delay resets to default")

        // The expansion covers the strip the items live in and no more. A 14"
        // MacBook Pro has 790 pt left of the notch on an 1800 pt display, so
        // sizing off the full screen asks for an item far wider than its bar.
        suite.expect(MenuBarHiderSupport.expansionLength(for: 790) > 790,
               "expansion clears the usable width it was given")
        suite.expect(MenuBarHiderSupport.expansionLength(for: 790) < 1800,
               "expansion off a notched strip stays under the full screen width")
        suite.expect(MenuBarHiderSupport.expansionLength(for: 1920) == 1920 + MenuBarHiderSupport.expansionMargin,
               "expansion is the usable width plus the margin")
        suite.expect(MenuBarHiderSupport.expansionLength(for: nil)
                == MenuBarHiderSupport.fallbackUsableWidth + MenuBarHiderSupport.expansionMargin,
               "expansion falls back when no width can be measured")
        suite.expect(MenuBarHiderSupport.expansionLength(for: -50) == MenuBarHiderSupport.expansionMargin,
               "a nonsensical negative width cannot produce a negative length")

        suite.expect(MenuBarHiderSupport.separatorLength(state: .collapsed, usableWidth: 790)
                == MenuBarHiderSupport.expansionLength(for: 790), "collapsed separator is expanded")
        suite.expect(MenuBarHiderSupport.separatorLength(state: .expanded, usableWidth: 1920) == MenuBarHiderSupport.normalSeparatorWidth, "expanded separator has normal width")
        suite.expect(MenuBarHiderSupport.separatorLength(state: .showAll, usableWidth: 1920) == MenuBarHiderSupport.normalSeparatorWidth, "showAll separator has normal width")

        suite.expect(MenuBarHiderSupport.alwaysHiddenLength(state: .showAll, usableWidth: 1920, isEnabled: false) == 0.0, "disabled always-hidden item has zero length")
        suite.expect(MenuBarHiderSupport.alwaysHiddenLength(state: .expanded, usableWidth: 790, isEnabled: true)
                == MenuBarHiderSupport.expansionLength(for: 790), "always-hidden stays collapsed during normal expansion")
        suite.expect(MenuBarHiderSupport.alwaysHiddenLength(state: .showAll, usableWidth: 1920, isEnabled: true) == MenuBarHiderSupport.normalAlwaysHiddenWidth, "always-hidden shows normal width on showAll")

        suite.expect(MenuBarHiderSupport.toggleSymbolName(isCollapsed: true, style: .chevron) == "chevron.left", "collapsed chevron toggle shows chevron.left")
        suite.expect(MenuBarHiderSupport.toggleSymbolName(isCollapsed: false, style: .chevron) == "chevron.right", "expanded chevron toggle shows chevron.right")
        suite.expect(MenuBarHiderSupport.toggleSymbolName(isCollapsed: true, style: .dots) == "ellipsis.circle", "collapsed dots toggle shows ellipsis.circle")
        suite.expect(MenuBarHiderSupport.toggleSymbolName(isCollapsed: false, style: .dots) == "ellipsis.circle.fill", "expanded dots toggle shows ellipsis.circle.fill")
        suite.expect(MenuBarHiderSupport.toggleSymbolName(isCollapsed: true, style: .eye) == "eye.slash", "collapsed eye toggle shows eye.slash")
        suite.expect(MenuBarHiderSupport.toggleSymbolName(isCollapsed: false, style: .eye) == "eye", "expanded eye toggle shows eye")
        // The tooltip picks a localized string rather than building English, so
        // the check is which field each state selects, in every language.
        for lang in AppLanguage.allCases {
            let t = FeatureStrings.menuBarHider(lang)
            suite.expect(MenuBarHiderSupport.toggleTooltip(isCollapsed: true, isShowingAll: false, alwaysHiddenEnabled: false, strings: t) == t.tooltipExpand,
                   "collapsed toggle uses the expand tooltip for \(lang)")
            suite.expect(MenuBarHiderSupport.toggleTooltip(isCollapsed: true, isShowingAll: false, alwaysHiddenEnabled: true, strings: t) == t.tooltipExpand,
                   "collapsed toggle uses the expand tooltip with always-hidden on for \(lang)")
            suite.expect(MenuBarHiderSupport.toggleTooltip(isCollapsed: false, isShowingAll: false, alwaysHiddenEnabled: false, strings: t) == t.tooltipCollapse,
                   "expanded toggle uses the plain collapse tooltip for \(lang)")
            suite.expect(MenuBarHiderSupport.toggleTooltip(isCollapsed: false, isShowingAll: false, alwaysHiddenEnabled: true, strings: t) == t.tooltipCollapseShowAll,
                   "expanded toggle offers show-all when always-hidden is on for \(lang)")
            suite.expect(MenuBarHiderSupport.toggleTooltip(isCollapsed: false, isShowingAll: true, alwaysHiddenEnabled: true, strings: t) == t.tooltipCollapseHideAlways,
                   "showing-all toggle offers hiding the always-hidden section for \(lang)")
        }

        // The reveal gesture must be tighter than the system double-click
        // interval, which is a comfort setting that can sit far above the speed
        // of an actual double click.
        suite.expect(MenuBarHiderSupport.revealGestureInterval(systemDoubleClickInterval: 0.5)
                == MenuBarHiderSupport.revealGestureCeiling,
               "a roomy system interval is capped at the reveal ceiling")
        suite.expect(MenuBarHiderSupport.revealGestureInterval(systemDoubleClickInterval: 1.2)
                == MenuBarHiderSupport.revealGestureCeiling,
               "the slowest system interval is still capped")
        suite.expect(MenuBarHiderSupport.revealGestureInterval(systemDoubleClickInterval: 0.18) == 0.18,
               "a system interval below the ceiling wins, since AppKit will not report past it")
        suite.expect(MenuBarHiderSupport.revealGestureInterval(systemDoubleClickInterval: -1) == 0,
               "a nonsensical system interval cannot produce a negative window")
        suite.expect(MenuBarHiderSupport.revealGestureCeiling < 0.5,
               "the ceiling is meaningfully tighter than the macOS default interval")

        // Every style's symbols must resolve on the running system: a nil image
        // leaves the variable-length toggle with no image and no title, which
        // collapses it to zero width and makes the button disappear.
        for style in MenuBarHiderIconStyle.allCases {
            for collapsed in [true, false] {
                let name = MenuBarHiderSupport.toggleSymbolName(isCollapsed: collapsed, style: style)
                suite.expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil,
                       "toggle symbol \(name) exists for style \(style.rawValue) collapsed=\(collapsed)")
            }
        }

        let testOrder = MenuBarHiderSupport.sortedRoles(positions: [("toggle", 1200.0), ("alwaysHidden", 800.0), ("separator", 1000.0)])
        suite.expect(testOrder == ["alwaysHidden", "separator", "toggle"], "items are sorted left-to-right by horizontal position")


        for lang in AppLanguage.allCases {
            let hiderStrings = FeatureStrings.menuBarHider(lang)
            suite.expect(!hiderStrings.pageTitle.isEmpty, "menu bar hider page title is localized for \(lang)")
            suite.expect(!hiderStrings.hubDescription.isEmpty, "menu bar hider hub description is localized for \(lang)")
            suite.expect(!hiderStrings.enable.isEmpty, "menu bar hider enable toggle is localized for \(lang)")
            suite.expect(!hiderStrings.howToUseTitle.isEmpty, "menu bar hider guide title is localized for \(lang)")
            suite.expect(!hiderStrings.alwaysHiddenSection.isEmpty, "menu bar hider always-hidden section is localized for \(lang)")
            suite.expect(!hiderStrings.autoCollapseSection.isEmpty, "menu bar hider auto-collapse section is localized for \(lang)")
            suite.expect(!hiderStrings.interactionSection.isEmpty, "menu bar hider interaction section is localized for \(lang)")
            suite.expect(!hiderStrings.scrollToToggle.isEmpty, "menu bar hider scrollToToggle is localized for \(lang)")
            suite.expect(!hiderStrings.scrollToToggleCaption.isEmpty, "menu bar hider scrollToToggleCaption is localized for \(lang)")
            suite.expect(!hiderStrings.hapticFeedback.isEmpty, "menu bar hider hapticFeedback is localized for \(lang)")
            suite.expect(!hiderStrings.hapticFeedbackCaption.isEmpty, "menu bar hider hapticFeedbackCaption is localized for \(lang)")
            suite.expect(!hiderStrings.iconStyleTitle.isEmpty, "menu bar hider iconStyleTitle is localized for \(lang)")
            suite.expect(!hiderStrings.styleChevron.isEmpty, "menu bar hider styleChevron is localized for \(lang)")
            suite.expect(!hiderStrings.styleDots.isEmpty, "menu bar hider styleDots is localized for \(lang)")
            suite.expect(!hiderStrings.styleEye.isEmpty, "menu bar hider styleEye is localized for \(lang)")
            suite.expect(!hiderStrings.styleSlash.isEmpty, "menu bar hider styleSlash is localized for \(lang)")
            suite.expect(!hiderStrings.resetPositionsButton.isEmpty, "menu bar hider resetPositionsButton is localized for \(lang)")
            suite.expect(!hiderStrings.resetPositionsSuccess.isEmpty, "menu bar hider resetPositionsSuccess is localized for \(lang)")
            suite.expect(!hiderStrings.resetPositionsCaption.isEmpty, "menu bar hider resetPositionsCaption is localized for \(lang)")
            suite.expect(!hiderStrings.shortcutSection.isEmpty, "menu bar hider shortcut section is localized for \(lang)")
            suite.expect(!hiderStrings.contextMenuExpand.isEmpty, "menu bar hider contextMenuExpand is localized for \(lang)")
            suite.expect(!hiderStrings.contextMenuCollapse.isEmpty, "menu bar hider contextMenuCollapse is localized for \(lang)")
            suite.expect(!hiderStrings.contextMenuShowAll.isEmpty, "menu bar hider contextMenuShowAll is localized for \(lang)")
            suite.expect(!hiderStrings.contextMenuHideAlways.isEmpty, "menu bar hider contextMenuHideAlways is localized for \(lang)")
            suite.expect(!hiderStrings.contextMenuSettings.isEmpty, "menu bar hider contextMenuSettings is localized for \(lang)")
            suite.expect(!hiderStrings.tooltipExpand.isEmpty, "menu bar hider tooltipExpand is localized for \(lang)")
            suite.expect(!hiderStrings.tooltipCollapse.isEmpty, "menu bar hider tooltipCollapse is localized for \(lang)")
            suite.expect(!hiderStrings.tooltipCollapseShowAll.isEmpty, "menu bar hider tooltipCollapseShowAll is localized for \(lang)")
            suite.expect(!hiderStrings.tooltipCollapseHideAlways.isEmpty, "menu bar hider tooltipCollapseHideAlways is localized for \(lang)")
            suite.expect(!hiderStrings.tooltipSeparator.isEmpty, "menu bar hider tooltipSeparator is localized for \(lang)")
            suite.expect(!hiderStrings.tooltipAlwaysHidden.isEmpty, "menu bar hider tooltipAlwaysHidden is localized for \(lang)")
            suite.expect(!hiderStrings.diagramAlwaysHidden.isEmpty, "menu bar hider diagramAlwaysHidden is localized for \(lang)")
            suite.expect(!hiderStrings.diagramHidden.isEmpty, "menu bar hider diagramHidden is localized for \(lang)")
            suite.expect(!hiderStrings.diagramVisible.isEmpty, "menu bar hider diagramVisible is localized for \(lang)")
            suite.expect(hiderStrings.secondsFormat.contains("%d"), "menu bar hider secondsFormat contains %d for \(lang)")
        }

        // MARK: Detached command reruns (counted last, so a late rerun still fails)
        // The `||` form reran the whole installer — as root — on every non-zero
        // payload exit. Counting here rather than after a fixed wait leaves the
        // check no window a second run can arrive behind.
        let detachedRuns = detachedRunCount()
        suite.expect(detachedRuns == 1,
               "a detached command runs its payload once whatever the payload exits with "
               + "(ran \(detachedRuns) time(s))")
        try? FileManager.default.removeItem(at: detachRoot)

        // MARK: Command-Q / Command-W protection
        suite.expect(QuitProtectionSupport.sanitizedHoldDuration(100) == 250,
               "quit protection clamps a too-short hold duration")
        suite.expect(QuitProtectionSupport.sanitizedHoldDuration(3_000) == 2_000,
               "quit protection clamps an overly long hold duration")
        suite.expect(QuitProtectionSupport.sanitizedHoldDuration(.nan)
                == QuitProtectionSupport.defaultHoldDurationMilliseconds
                && QuitProtectionSupport.sanitizedHoldDuration(.infinity)
                    == QuitProtectionSupport.defaultHoldDurationMilliseconds,
               "quit protection replaces non-finite hold durations with its default")
        suite.expect(QuitProtectionSupport.sanitizedDoublePressInterval(100) == 200,
               "quit protection clamps a too-short double-press interval")
        suite.expect(QuitProtectionSupport.sanitizedDoublePressInterval(3_000) == 1_500,
               "quit protection clamps an overly long double-press interval")
        suite.expect(QuitProtectionSupport.sanitizedDoublePressInterval(.nan)
                == QuitProtectionSupport.defaultDoublePressIntervalMilliseconds
                && QuitProtectionSupport.sanitizedDoublePressInterval(-.infinity)
                    == QuitProtectionSupport.defaultDoublePressIntervalMilliseconds,
               "quit protection replaces non-finite double-press intervals with its default")
        suite.expect(!SettingsBackupSupport.valueLooksRight(
                    DefaultsKey.quitProtectionQuitDoubleIntervalMs, Double.nan)
                && !SettingsBackupSupport.valueLooksRight(
                    DefaultsKey.quitProtectionQuitDoubleIntervalMs, Double.infinity),
               "settings backups reject non-finite numeric preferences")
        suite.expect(QuitProtectionSupport.isWithinDoublePressInterval(
            firstTimestamp: 1_000_000_000,
            secondTimestamp: 2_500_000_000,
            intervalMilliseconds: 1_500
        ), "a second press on the interval edge confirms")
        suite.expect(!QuitProtectionSupport.isWithinDoublePressInterval(
            firstTimestamp: 1_000_000_000,
            secondTimestamp: 2_500_000_001,
            intervalMilliseconds: 1_500
        ), "a second press after the interval starts a new confirmation")
        suite.expect(QuitProtectionSupport.usesNativeQuitRequest(for: .quit)
                && !QuitProtectionSupport.usesNativeQuitRequest(for: .close),
               "quit confirmation asks the target app to terminate while close stays a window shortcut")

        suite.expect(QuitProtectionSupport.scopeAllows(.all, bundleIdentifier: nil, exceptions: []),
               "all-app scope protects even an app without a bundle identifier")
        suite.expect(QuitProtectionSupport.scopeAllows(.selectedOnly,
                                                 bundleIdentifier: "com.example.editor",
                                                 exceptions: ["com.example.editor"]),
               "selected-only scope protects a selected bundle")
        suite.expect(!QuitProtectionSupport.scopeAllows(.selectedOnly,
                                                  bundleIdentifier: "com.example.other",
                                                  exceptions: ["com.example.editor"]),
               "selected-only scope leaves an unselected bundle alone")
        suite.expect(!QuitProtectionSupport.scopeAllows(.allExceptSelected,
                                                  bundleIdentifier: "com.example.editor",
                                                  exceptions: ["com.example.editor"]),
               "all-except scope leaves a selected bundle alone")
        suite.expect(QuitProtectionSupport.scopeAllows(.allExceptSelected,
                                                 bundleIdentifier: "com.example.other",
                                                 exceptions: ["com.example.editor"]),
               "all-except scope protects an unselected bundle")

        suite.expect(QuitProtectionSupport.matchesKey(keyCharacter: "q", keyCode: 0,
                                                shortcut: .quit),
               "quit protection prefers the layout-resolved q character")
        suite.expect(QuitProtectionSupport.matchesKey(keyCharacter: nil, keyCode: 13,
                                                shortcut: .close),
               "quit protection falls back to the W key code without a character")
        suite.expect(QuitProtectionSupport.isBaseShortcut(keyCharacter: "q", keyCode: 12,
                                                    command: true, control: false,
                                                    option: false, shift: false, shortcut: .quit),
               "plain Command-Q is recognized")
        suite.expect(!QuitProtectionSupport.isBaseShortcut(keyCharacter: "q", keyCode: 12,
                                                     command: true, control: false,
                                                     option: false, shift: true, shortcut: .quit),
               "Shift-Command-Q is not mistaken for plain Command-Q")
        suite.expect(QuitProtectionSupport.isExtraShortcut(keyCharacter: "q", keyCode: 12,
                                                     command: true, control: false,
                                                     option: false, shift: true,
                                                     shortcut: .quit, extraModifier: .shift),
               "Shift-Command-Q is recognized as an extra-modifier confirmation")
        suite.expect(QuitProtectionSupport.isExtraShortcut(keyCharacter: "w", keyCode: 13,
                                                     command: true, control: true,
                                                     option: false, shift: false,
                                                     shortcut: .close, extraModifier: .control),
               "Control-Command-W is recognized as an extra-modifier confirmation")
        suite.expect(!QuitProtectionSupport.isExtraShortcut(keyCharacter: "q", keyCode: 12,
                                                      command: true, control: false,
                                                      option: true, shift: false,
                                                      shortcut: .quit, extraModifier: .shift),
               "an unrelated modifier combination is not protected")

        let quitProtectionKeys = [
            DefaultsKey.quitProtectionQuitEnabled,
            DefaultsKey.quitProtectionQuitMode,
            DefaultsKey.quitProtectionQuitHoldDurationMs,
            DefaultsKey.quitProtectionQuitDoubleIntervalMs,
            DefaultsKey.quitProtectionQuitExtraModifier,
            DefaultsKey.quitProtectionQuitScope,
            DefaultsKey.quitProtectionQuitExceptions,
            DefaultsKey.quitProtectionQuitShowFeedback,
            DefaultsKey.quitProtectionCloseEnabled,
            DefaultsKey.quitProtectionCloseMode,
            DefaultsKey.quitProtectionCloseHoldDurationMs,
            DefaultsKey.quitProtectionCloseDoubleIntervalMs,
            DefaultsKey.quitProtectionCloseExtraModifier,
            DefaultsKey.quitProtectionCloseScope,
            DefaultsKey.quitProtectionCloseExceptions,
            DefaultsKey.quitProtectionCloseShowFeedback,
        ]
        suite.expect(quitProtectionKeys.allSatisfy { Defaults.registeredDefaults[$0] != nil },
               "quit and close protection settings have registered defaults")
        suite.expect(SettingsBackupSupport.exportKeys().isSuperset(of: Set<String>(quitProtectionKeys)),
               "quit and close protection settings are included in portable backup")

        for language in AppLanguage.allCases {
            let quitProtection = FeatureStrings.quitProtection(language)
            let quitProtectionValues = Mirror(reflecting: quitProtection).children
                .compactMap { $0.value as? String }
            suite.expect(quitProtectionValues.count == 29 && quitProtectionValues.allSatisfy { !$0.isEmpty },
                   "every quit protection string is set for \(language.rawValue)")
            suite.expect(quitProtectionValues.allSatisfy { !$0.contains("—") },
                   "no em-dash in quit protection strings (\(language.rawValue))")
            expectFormat(quitProtection.holdHUDFormat, ["@"],
                         "\(language.rawValue) quit protection hold HUD format")
            expectFormat(quitProtection.doubleHUDFormat, ["@"],
                         "\(language.rawValue) quit protection double HUD format")
            expectFormat(quitProtection.extraHUDFormat, ["@"],
                         "\(language.rawValue) quit protection modifier HUD format")
        }

    }
}
