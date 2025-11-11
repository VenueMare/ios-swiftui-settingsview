import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsState
    @EnvironmentObject var keychain: KeychainService
    @EnvironmentObject var providerSelector: ProviderSelector
    @EnvironmentObject var subscription: SubscriptionManager
    @EnvironmentObject var gating: GatingService

    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    @State private var tempKey: String = ""
    @State private var showPaywall = false

    @FocusState private var focusedField: Field?
    private enum Field { case proxy, apiKey, keyURL }

    @State private var proxyHidden = true
    @State private var showDebugInfo = false
    @State private var debugInfoText = ""

    private static let fallbackProxyURL = "https://www.venueflux.com/proxy-openai.php?t=2d3787b67bdbe360fc3c398cb5dc8de9c843580f1631b376e9db38e135985ead"

    private var isEffectivePremium: Bool {
        #if DEBUG
        return subscription.isPremium || settings.devForcePremium
        #else
        return subscription.isPremium
        #endif
    }

    private var premiumSummaryMaxWords: Int { 1500 }

    private var effectiveSummaryWords: Int {
        let target = settings.summaryTargetTokens
        return isEffectivePremium ? min(target, premiumSummaryMaxWords)
                                  : min(target, gating.config.summaryTokensFree)
    }
    private var effectiveCards: Int {
        isEffectivePremium ? min(settings.targetCards, 60)
                           : min(settings.targetCards, gating.config.maxCardsFree)
    }

    private var reminderLocaleOverride: Locale? {
        switch settings.reminderTimeFormat {
        case "24h":
            // Locale that uses 24-hour time
            return Locale(identifier: "en_GB")
        case "12h":
            // Locale that uses 12-hour time with AM/PM
            return Locale(identifier: "en_US_POSIX")
        default:
            return nil // system
        }
    }

    private var nextReminderString: String {
        let comps = settings.reminderDateComponents
        let cal = Calendar.current
        let now = Date()
        guard let next = cal.date(from: comps) else { return "--:--" }
        let fmt = DateFormatter()
        switch settings.reminderTimeFormat {
        case "24h":
            fmt.locale = Locale(identifier: "en_GB")
            fmt.dateFormat = "HH:mm"
        case "12h":
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.dateFormat = "h:mm a"
        default:
            fmt.locale = .current
            fmt.timeStyle = .short
        }
        // Wenn die Zeit heute bereits vorbei ist, gilt morgen
        let today = cal.startOfDay(for: now)
        var nextDate = cal.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: today) ?? next
        if nextDate <= now { nextDate = cal.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate }
        return fmt.string(from: nextDate)
    }

    var body: some View {
        Form {
            // Abo
            Section {
                HStack(spacing: 12) {
                    Image(systemName: isEffectivePremium ? "star.circle.fill" : "star.circle")
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isEffectivePremium ? "lbl_status_premium" : "lbl_status_free")
                            .font(.headline)
                        Text(isEffectivePremium ? "paywall_already_premium" : "info_generation_limits")
                            .font(.footnote)
                            .foregroundStyle(Color("VFLabelSecondary"))
                        #if DEBUG
                        if settings.devForcePremium && !subscription.isPremium {
                            Text("debug_badge")
                                .font(.caption2)
                                .foregroundStyle(Color("VFLabelSecondary"))
                                .accessibilityHidden(true)
                        }
                        #endif
                    }

                    Spacer()
                    if isEffectivePremium { PremiumBadge() }
                }

                if !isEffectivePremium {
                    Button {
                        Haptics.selection()
                        showPaywall = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.circle")
                            Text("btn_upgrade")
                        }
                        .foregroundStyle(Color("VFLabelPrimary"))
                        .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .tint(Color("VFButtonPrimary"))
                }

                Button {
                    Haptics.selection()
                    Task { try? await AppStore.sync() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise.circle")
                        Text("restore_purchases")
                    }
                    .foregroundStyle(Color("VFLabelPrimary"))
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(Color("VFButtonPrimary"))

                Button {
                    Haptics.selection()
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        openURL(url)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                        Text("manage_subscriptions")
                    }
                    .foregroundStyle(Color("VFLabelPrimary"))
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(Color("VFButtonPrimary"))
            } header: {
                Text("title_subscription")
            }

            // Trial-/Abo-Info-Banner (nur Texte geändert)
            if !isEffectivePremium {
                Section("trial_info_title") {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("trial_info_point_free_trial", systemImage: "info.circle")
                        Label("trial_info_point_monthly_price", systemImage: "info.circle")
                        Label("trial_info_point_yearly_price", systemImage: "info.circle")
                        Label("trial_info_point_cancel_anytime", systemImage: "info.circle")
                        Label("trial_info_point_after_trial_requires_sub", systemImage: "info.circle")
                    }
                    .font(.footnote)
                    .foregroundStyle(Color("VFLabelSecondary"))
                }
            }

            // Personalisierung
            Section {
                TextField("settings_name_placeholder", text: $settings.userDisplayName)
                    .textContentType(.name)
                    .submitLabel(.done)
            } header: {
                Text("settings_personalization")
            }

            // Erinnerungen
            Section {
                Toggle("reminder_enable", isOn: $settings.reminderEnabled)

                if settings.reminderEnabled {
                    if let loc = reminderLocaleOverride {
                        DatePicker("reminder_time",
                                   selection: Binding(
                                       get: { settings.reminderDate },
                                       set: { settings.updateReminder(from: $0) }
                                   ),
                                   displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .environment(\.locale, loc)
                    } else {
                        DatePicker("reminder_time",
                                   selection: Binding(
                                       get: { settings.reminderDate },
                                       set: { settings.updateReminder(from: $0) }
                                   ),
                                   displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                    }

                    // Next reminder info
                    if settings.reminderEnabled {
                        HStack {
                            Image(systemName: "clock.badge.checkmark")
                                .foregroundStyle(Color("VFLabelSecondary"))
                            Text(LocalizedStringKey("next_reminder"))
                            Spacer()
                            Text(nextReminderString)
                                .foregroundStyle(Color("VFLabelSecondary"))
                        }
                        .font(.footnote)

                        Button {
                            Task {
                                let _ = await NotificationService.requestAuthorization()
                                let now = Calendar.current.dateComponents([.hour, .minute], from: Date().addingTimeInterval(10))
                                await NotificationService.applyReminderSettings(
                                    enabled: true,
                                    dateComponents: now,
                                    displayName: settings.userDisplayName
                                )
                            }
                        } label: {
                            Label(LocalizedStringKey("send_test_notification"), systemImage: "paperplane")
                        }
                        .buttonStyle(.bordered)
                    }

                    Picker("reminder_format", selection: $settings.reminderTimeFormat) {
                        Text("reminder_format_system").tag("system")
                        Text("reminder_format_24h").tag("24h")
                        Text("reminder_format_12h").tag("12h")
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("settings_reminders")
            } footer: {
                Text("settings_reminders_footer")
            }

            // Zwischenablage-Schnellaufnahme
            Section {
                Toggle("clipboard_quickadd_title", isOn: $settings.clipboardQuickAddEnabled)
                Text("clipboard_quickadd_footer")
                    .font(.footnote)
                    .foregroundStyle(Color("VFLabelSecondary"))
            } header: {
                Text("clipboard_quickadd_header")
            }

            // KI-Modus
            Section {
                Picker("title_ai_mode", selection: $settings.aiMode) {
                    Text("mode_proxy").tag("proxy")
                    Text("mode_openai").tag("openai")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("title_ai_mode")
            }

            // Proxy / OpenAI
            if settings.aiMode == "proxy" {
                proxySettingsSection
            } else {
                openAISettingsSection
            }

            // Generierung
            Section {
                Toggle("lbl_summary_enabled", isOn: $settings.summaryEnabled)

                Stepper(
                    value: $settings.summaryTargetTokens,
                    in: isEffectivePremium ? 200...premiumSummaryMaxWords : 200...gating.config.summaryTokensFree,
                    step: 100
                ) {
                    HStack {
                        Text("lbl_summary_tokens")
                        Spacer()
                        Text("\(settings.summaryTargetTokens)").foregroundStyle(Color("VFLabelSecondary"))
                    }
                }

                HStack {
                    Text(String(format: NSLocalizedString("effective_words", comment: ""),
                                effectiveSummaryWords))
                    Spacer()
                    if !isEffectivePremium {
                        Text(String(format: NSLocalizedString("free_limit_value_words", comment: ""),
                                    gating.config.summaryTokensFree))
                            .foregroundStyle(Color("VFLabelSecondary"))
                    }
                }
                .font(.caption)

                Stepper(value: $settings.targetCards, in: 4...60, step: 2) {
                    HStack {
                        Text("txt_target_cards")
                        Spacer()
                        Text("\(settings.targetCards)").foregroundStyle(Color("VFLabelSecondary"))
                    }
                }

                HStack {
                    Text(String(format: NSLocalizedString("effective_cards", comment: ""),
                                effectiveCards))
                    Spacer()
                    if !isEffectivePremium {
                        Text(String(format: NSLocalizedString("free_limit_value_cards", comment: ""),
                                    gating.config.maxCardsFree))
                            .foregroundStyle(Color("VFLabelSecondary"))
                    }
                }
                .font(.caption)
            } header: {
                Text("title_generation")
            }

            // Darstellung
            Section {
                Picker("title_appearance", selection: $settings.appearance) {
                    Text("appearance_system").tag("system")
                    Text("appearance_light").tag("light")
                    Text("appearance_dark").tag("dark")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("title_appearance")
            }

            // Rechtliches
            Section {
                NavigationLink("title_impressum") {
                    LegalMarkdownView(
                        title: NSLocalizedString("title_impressum", comment: ""),
                        resourceName: "Impressum.md"
                    )
                }
                NavigationLink("title_agb") {
                    LegalMarkdownView(
                        title: NSLocalizedString("title_agb", comment: ""),
                        resourceName: "AGB.md"
                    )
                }
            } header: {
                Text("title_legal")
            }

            #if DEBUG
            // Entwickler
            Section(LocalizedStringKey("dev_section_title")) {
                Toggle("dev_force_premium", isOn: $settings.devForcePremium)
                    .onChange(of: settings.devForcePremium) { _ in
                        gating.sync(settings: settings, subscription: subscription)
                    }

                Button {
                    Haptics.selection()
                    awaitMain {
                        ReviewService.forceRequestReviewForDebug()
                        debugInfoText = NSLocalizedString("dev.info.review_suppressed", comment: "")
                        showDebugInfo = true
                    }
                } label: {
                    Text("dev_request_review")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color("VFLabelPrimary"))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("VFButtonPrimary"))

                Button {
                    Haptics.selection()
                    if AppReview.appStoreID != "6751287615",
                       let url = URL(string: AppReview.writeReviewURLString) {
                        openURL(url)
                    } else {
                        debugInfoText = NSLocalizedString("dev.info.store_id_missing", comment: "")
                        showDebugInfo = true
                    }
                } label: {
                    Text("dev_open_ratings")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color("VFLabelPrimary"))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("VFButtonPrimary"))

                Button {
                    Haptics.selection()
                    #if DEBUG
                    debugInfoText = DebugLocalizationChecker.report()
                    showDebugInfo = true
                    #endif
                } label: {
                    Text("dev_check_localizations")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color("VFLabelPrimary"))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("VFButtonPrimary"))
            }
            #endif
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("tab_settings"))
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("VFTint"))
        .scrollContentBackground(.hidden)
        .background(Color("VFGroupedBackground"))
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("btn_ok") { focusedField = nil }
            }
        }
        .task(id: settings.aiMode) { providerSelector.refresh(settings: settings, keychain: keychain, subscription: subscription) }
        .task(id: settings.proxyURL) { providerSelector.refresh(settings: settings, keychain: keychain, subscription: subscription) }
        .task(id: keychain.apiKey) { providerSelector.refresh(settings: settings, keychain: keychain, subscription: subscription) }
        .task(id: settings.keyURL) { providerSelector.refresh(settings: settings, keychain: keychain, subscription: subscription) }
        .task(id: subscription.isPremium) { providerSelector.refresh(settings: settings, keychain: keychain, subscription: subscription) }
        .task(id: settings.reminderEnabled) {
            await NotificationService.applyReminderSettings(
                enabled: settings.reminderEnabled,
                dateComponents: settings.reminderDateComponents,
                displayName: settings.userDisplayName
            )
        }
        .task(id: settings.reminderHour) {
            await NotificationService.applyReminderSettings(
                enabled: settings.reminderEnabled,
                dateComponents: settings.reminderDateComponents,
                displayName: settings.userDisplayName
            )
        }
        .task(id: settings.reminderMinute) {
            await NotificationService.applyReminderSettings(
                enabled: settings.reminderEnabled,
                dateComponents: settings.reminderDateComponents,
                displayName: settings.userDisplayName
            )
        }
        .alert(Text("dev_debug_title"), isPresented: $showDebugInfo) {
            Button("btn_ok", role: .cancel) { showDebugInfo = false }
        } message: { Text(debugInfoText) }
        .sheet(isPresented: $showPaywall) {
            NavigationStack { PaywallView() }
        }
    }

    // MARK: - Abschnitte (unverändert)

    @ViewBuilder
    private var proxySettingsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    proxyURLInput
                    Button {
                        proxyHidden.toggle()
                        Haptics.selection()
                    } label: {
                        Image(systemName: proxyHidden ? "eye.slash" : "eye")
                            .foregroundStyle(Color("VFLabelPrimary"))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("VFButtonPrimary"))
                    .accessibilityLabel(LocalizedStringKey(proxyHidden ? "hide" : "show"))
                }

                HStack(spacing: 12) {
                    Button {
                        Haptics.selection()
                        settings.proxyURL = SettingsView.fallbackProxyURL
                        providerSelector.refresh(settings: settings, keychain: keychain, subscription: subscription)
                        focusedField = nil
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.uturn.left")
                            Text("reset_proxy")
                        }
                        .foregroundStyle(Color("VFLabelPrimary"))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("VFButtonPrimary"))

                    Spacer()

                    Button {
                        Haptics.selection()
                        providerSelector.refresh(settings: settings, keychain: keychain, subscription: subscription)
                        focusedField = nil
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle")
                            Text("btn_ok")
                        }
                        .foregroundStyle(Color("VFLabelPrimary"))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("VFButtonPrimary"))
                }
            }
        } header: {
            Text("title_proxy_settings")
        }
    }

    @ViewBuilder
    private var openAISettingsSection: some View {
        Section {
            SecureField("ph_api_key", text: Binding(
                get: { tempKey.isEmpty ? (keychain.apiKey ?? "") : tempKey },
                set: { tempKey = $0 }
            ))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.password)
            .focused($focusedField, equals: .apiKey)

            HStack {
                Button {
                    Task {
                        var value = (tempKey.isEmpty ? (keychain.apiKey ?? "") : tempKey)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !value.isEmpty else {
                            Haptics.warning()
                            debugInfoText = NSLocalizedString("settings.api_key.paste_or_url", comment: "")
                            showDebugInfo = true
                            return
                        }

                        if looksLikeURL(value) {
                            if let fetched = try? await KeyFetchService.fetchKey(from: value) {
                                let k = fetched.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard isPlausibleOpenAIKey(k) else {
                                    Haptics.warning()
                                    debugInfoText = NSLocalizedString("settings.api_key.fetched_not_looking_like_key", comment: "")
                                    showDebugInfo = true
                                    return
                                }
                                value = k
                            } else {
                                Haptics.warning()
                                debugInfoText = NSLocalizedString("settings.api_key.could_not_fetch", comment: "")
                                showDebugInfo = true
                                return
                            }
                        } else if !isPlausibleOpenAIKey(value) {
                            Haptics.warning()
                            debugInfoText = NSLocalizedString("settings.api_key.invalid_input", comment: "")
                            showDebugInfo = true
                            return
                        }

                        keychain.apiKey = value
                        tempKey = ""
                        Haptics.success()
                        focusedField = nil
                        providerSelector.refresh(settings: settings, keychain: keychain, subscription: subscription)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal")
                        Text("btn_save_key")
                    }
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 12)

                Button {
                    Task {
                        let url = settings.keyURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard looksLikeURL(url) else {
                            Haptics.warning()
                            debugInfoText = NSLocalizedString("settings.api_key.enter_valid_url", comment: "")
                            showDebugInfo = true
                            return
                        }
                        if let newKey = try? await KeyFetchService.fetchKey(from: url) {
                            let k = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard isPlausibleOpenAIKey(k) else {
                                Haptics.warning()
                                debugInfoText = NSLocalizedString("settings.api_key.fetched_not_openai_key", comment: "")
                                showDebugInfo = true
                                return
                            }
                            keychain.apiKey = k
                            debugInfoText = NSLocalizedString("settings.api_key.saved_success", comment: "")
                            Haptics.success()
                            showDebugInfo = true
                            providerSelector.refresh(settings: settings, keychain: keychain, subscription: subscription)
                        } else {
                            Haptics.warning()
                            debugInfoText = NSLocalizedString("settings.api_key.could_not_fetch", comment: "")
                            showDebugInfo = true
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle")
                        Text("btn_fetch_key")
                    }
                }
                .buttonStyle(.bordered)
            }

            TextField("ph_key_url", text: $settings.keyURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.URL)
                .submitLabel(.done)
                .focused($focusedField, equals: .keyURL)
        } header: {
            Text("title_api")
        }
    }

    @ViewBuilder
    private var proxyURLInput: some View {
        if proxyHidden {
            SecureField("ph_proxy_url", text: $settings.proxyURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.URL)
                .submitLabel(.done)
                .focused($focusedField, equals: .proxy)
        } else {
            TextField("ph_proxy_url", text: $settings.proxyURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.URL)
                .submitLabel(.done)
                .focused($focusedField, equals: .proxy)
        }
    }
}

// Helper
private func awaitMain(_ work: @escaping @MainActor () -> Void) {
    Task { @MainActor in work() }
}

// MARK: - Key/URL Plausibilität

private func looksLikeURL(_ s: String) -> Bool {
    let l = s.lowercased()
    return l.hasPrefix("http://") || l.hasPrefix("https://")
}

private func isPlausibleOpenAIKey(_ s: String) -> Bool {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    return t.hasPrefix("sk-") && t.count > 40 && !t.contains(" ")
}

