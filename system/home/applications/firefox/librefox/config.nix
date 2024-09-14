{ ... }:
let
  lock-val = val: {
    Value = val;
    Status = "locked";
  };
in
{
  programs.firefox.policies = {
    Preferences = {
      "accessibility.force_disabled" = lock-val 1;
      "accessibility.support.url" = lock-val "";
      "accessibility.typeaheadfind" = lock-val true;
      "app.feedback.baseURL" = lock-val "";
      "app.normandy.api_url" = lock-val "";
      "app.normandy.enabled" = lock-val false;
      "app.normandy.first_run" = lock-val false;
      "app.normandy.shieldLearnMoreUrl" = lock-val "";
      "app.normandy.user_id" = lock-val "";
      "app.productInfo.baseURL" = lock-val "";
      "app.releaseNotesURL" = lock-val "";
      "app.shield.optoutstudies.enabled" = lock-val false;
      "app.support.baseURL" = lock-val "";
      "app.update.auto" = lock-val false;
      "app.update.enabled" = lock-val false;
      "app.update.lastUpdateTime.telemetry_modules_ping" = lock-val 0;
      "app.update.service.enabled" = lock-val false;
      "app.update.silent" = lock-val false;
      "app.update.staging.enabled" = lock-val false;
      "app.update.url" = lock-val "";
      "app.update.url.details" = lock-val "";
      "app.update.url.manual" = lock-val "";
      "app.vendorURL" = lock-val "";
      "beacon.enabled" = lock-val false;
      "breakpad.reportURL" = lock-val "";
      "browser.aboutHomeSnippets.updateUrl" = lock-val "";
      "browser.bookmarks.max_backups" = lock-val 2;
      "browser.bookmarks.restore_default_bookmarks" = lock-val false;
      "browser.cache.offline.enable" = lock-val false;
      "browser.casting.enabled" = lock-val false;
      "browser.chrome.errorReporter.enabled" = lock-val false;
      "browser.chrome.errorReporter.infoURL" = lock-val "";
      "browser.chrome.errorReporter.publicKey" = lock-val "";
      "browser.chrome.errorReporter.submitUrl" = lock-val "";
      "browser.contentblocking.rejecttrackers.reportBreakage.enabled" = lock-val false;
      "browser.contentblocking.reportBreakage.enabled" = lock-val false;
      "browser.contentblocking.reportBreakage.url" = lock-val "";
      "browser.contentblocking.trackingprotection.control-center.ui.enabled" = lock-val false;
      "browser.contentblocking.trackingprotection.ui.enabled" = lock-val false;
      "browser.crashReports.unsubmittedCheck.autoSubmit2" = lock-val false;
      "browser.crashReports.unsubmittedCheck.enabled" = lock-val false;
      "browser.dictionaries.download.url" = lock-val "";
      "browser.download.autohideButton" = lock-val false;
      "browser.fixup.alternate.enabled" = lock-val false;
      "browser.fixup.hide_user_pass" = lock-val true;
      "browser.formfill.enable" = lock-val false;
      "browser.geolocation.warning.infoURL" = lock-val "";
      "browser.helperApps.deleteTempFileOnExit" = lock-val true;
      "browser.link.open_newwindow" = lock-val 3;
      "browser.link.open_newwindow.restriction" = lock-val 0;
      "browser.newtab.preload" = lock-val false;
      "browser.newtabpage.activity-stream.aboutHome.enabled" = lock-val false;
      "browser.newtabpage.activity-stream.asrouter.messageProviders" = lock-val "";
      "browser.newtabpage.activity-stream.asrouter.providers.cfr" = lock-val "";
      "browser.newtabpage.activity-stream.asrouter.providers.onboarding" = lock-val "";
      "browser.newtabpage.activity-stream.asrouter.providers.snippets" = lock-val "";
      "browser.newtabpage.activity-stream.disableSnippets" = lock-val true;
      "browser.newtabpage.activity-stream.enabled" = lock-val false;
      "browser.newtabpage.activity-stream.feeds.section.highlights" = lock-val false;
      "browser.newtabpage.activity-stream.feeds.section.topstories" = lock-val false;
      "browser.newtabpage.activity-stream.feeds.section.topstories.options" = lock-val "";
      "browser.newtabpage.activity-stream.feeds.snippets" = lock-val false;
      "browser.newtabpage.activity-stream.feeds.telemetry" = lock-val false;
      "browser.newtabpage.activity-stream.fxaccounts.endpoint" = lock-val "";
      "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts.searchEngines" = lock-val "";
      "browser.newtabpage.activity-stream.prerender" = lock-val false;
      "browser.newtabpage.activity-stream.section.highlights.includeBookmarks" = lock-val false;
      "browser.newtabpage.activity-stream.section.highlights.includeDownloads" = lock-val false;
      "browser.newtabpage.activity-stream.section.highlights.includePocket" = lock-val false;
      "browser.newtabpage.activity-stream.section.highlights.includeVisited" = lock-val false;
      "browser.newtabpage.activity-stream.showSponsored" = lock-val false;
      "browser.newtabpage.activity-stream.telemetry" = lock-val false;
      "browser.newtabpage.activity-stream.telemetry.ping.endpoint" = lock-val "";
      "browser.newtabpage.directory.ping" = lock-val "data:text/plain,";
      "browser.newtabpage.directory.source" = lock-val "data:text/plain,";
      "browser.newtabpage.enhanced" = lock-val false;
      "browser.onboarding.notification.finished" = lock-val true;
      "browser.onboarding.notification.tour-ids-queue" = lock-val "";
      "browser.onboarding.tour.onboarding-tour-customize.completed" = lock-val true;
      "browser.onboarding.tour.onboarding-tour-performance.completed" = lock-val true;
      "browser.pagethumbnails.capturing_disabled" = lock-val true;
      "browser.ping-centre.production.endpoint" = lock-val "";
      "browser.ping-centre.staging.endpoint" = lock-val "";
      "browser.ping-centre.telemetry" = lock-val false;
      "browser.pocket.enabled" = lock-val false;
      "browser.safebrowsing.allowOverride" = lock-val false;
      "browser.safebrowsing.blockedURIs.enabled" = lock-val false;
      "browser.safebrowsing.downloads.enabled" = lock-val false;
      "browser.safebrowsing.downloads.remote.block_dangerous" = lock-val false;
      "browser.safebrowsing.downloads.remote.block_dangerous_host" = lock-val false;
      "browser.safebrowsing.downloads.remote.block_potentially_unwanted" = lock-val false;
      "browser.safebrowsing.downloads.remote.block_uncommon" = lock-val false;
      "browser.safebrowsing.downloads.remote.enabled" = lock-val false;
      "browser.safebrowsing.downloads.remote.url" = lock-val "";
      "browser.safebrowsing.id" = lock-val "";
      "browser.safebrowsing.malware.enabled" = lock-val false;
      "browser.safebrowsing.passwords.enabled" = lock-val false;
      "browser.safebrowsing.phishing.enabled" = lock-val false;
      "browser.safebrowsing.provider.google.advisoryName" = lock-val "";
      "browser.safebrowsing.provider.google.advisoryURL" = lock-val "";
      "browser.safebrowsing.provider.google.gethashURL" = lock-val "";
      "browser.safebrowsing.provider.google.lastupdatetime" = lock-val "";
      "browser.safebrowsing.provider.google.lists" = lock-val "";
      "browser.safebrowsing.provider.google.nextupdatetime" = lock-val "";
      "browser.safebrowsing.provider.google.pver" = lock-val "";
      "browser.safebrowsing.provider.google.reportMalwareMistakeURL" = lock-val "";
      "browser.safebrowsing.provider.google.reportPhishMistakeURL" = lock-val "";
      "browser.safebrowsing.provider.google.reportURL" = lock-val "";
      "browser.safebrowsing.provider.google.updateURL" = lock-val "";
      "browser.safebrowsing.provider.google4.advisoryName" = lock-val "";
      "browser.safebrowsing.provider.google4.advisoryURL" = lock-val "";
      "browser.safebrowsing.provider.google4.dataSharing.enabled" = lock-val false;
      "browser.safebrowsing.provider.google4.dataSharingURL" = lock-val "";
      "browser.safebrowsing.provider.google4.gethashURL" = lock-val "";
      "browser.safebrowsing.provider.google4.lastupdatetime" = lock-val "";
      "browser.safebrowsing.provider.google4.lists" = lock-val "";
      "browser.safebrowsing.provider.google4.nextupdatetime" = lock-val "";
      "browser.safebrowsing.provider.google4.pver" = lock-val "";
      "browser.safebrowsing.provider.google4.reportMalwareMistakeURL" = lock-val "";
      "browser.safebrowsing.provider.google4.reportPhishMistakeURL" = lock-val "";
      "browser.safebrowsing.provider.google4.reportURL" = lock-val "";
      "browser.safebrowsing.provider.google4.updateURL" = lock-val "";
      "browser.safebrowsing.provider.mozilla.gethashURL" = lock-val "";
      "browser.safebrowsing.provider.mozilla.lastupdatetime" = lock-val "";
      "browser.safebrowsing.provider.mozilla.lists" = lock-val "";
      "browser.safebrowsing.provider.mozilla.lists.base" = lock-val "";
      "browser.safebrowsing.provider.mozilla.lists.content" = lock-val "";
      "browser.safebrowsing.provider.mozilla.nextupdatetime" = lock-val "";
      "browser.safebrowsing.provider.mozilla.pver" = lock-val "";
      "browser.safebrowsing.provider.mozilla.updateURL" = lock-val "";
      "browser.safebrowsing.reportPhishURL" = lock-val "";
      "browser.search.countryCode" = "US";
      "browser.search.geoSpecificDefaults" = lock-val false;
      "browser.search.geoSpecificDefaults.url" = lock-val "";
      "browser.search.geoip.url" = lock-val "";
      "browser.search.region" = "US";
      "browser.search.searchEnginesURL" = lock-val "";
      "browser.search.suggest.enabled" = lock-val false;
      "browser.search.update" = lock-val false;
      "browser.selfsupport.url" = lock-val "";
      "browser.send_pings" = lock-val false;
      "browser.send_pings.require_same_host" = lock-val true;
      "browser.sessionhistory.max_entries" = 20;
      "browser.sessionstore.interval" = 60000;
      "browser.sessionstore.privacy_level" = lock-val 2;
      "browser.shell.checkDefaultBrowser" = lock-val false;
      "browser.shell.didSkipDefaultBrowserCheckOnFirstRun" = lock-val true;
      "browser.shell.shortcutFavicons" = lock-val false;
      "browser.ssl_override_behavior" = lock-val 1;
      "browser.startup.blankWindow" = lock-val false;
      "browser.startup.homepage_override.buildID" = "20100101";
      "browser.startup.homepage_override.mstone" = "ignore";
      "browser.tabs.animate" = lock-val false;
      "browser.tabs.closeTabByDblclick" = lock-val true;
      "browser.tabs.closeWindowWithLastTab" = lock-val false;
      "browser.tabs.crashReporting.sendReport" = lock-val false;
      "browser.tabs.loadBookmarksInTabs" = lock-val true;
      "browser.taskbar.lists.enabled" = lock-val false;
      "browser.taskbar.lists.frequent.enabled" = lock-val false;
      "browser.taskbar.lists.recent.enabled" = lock-val false;
      "browser.taskbar.lists.tasks.enabled" = lock-val false;
      "browser.taskbar.previews.enable" = lock-val false;
      "browser.translation.engine" = lock-val "";
      "browser.uidensity" = lock-val 1;
      "browser.uitour.enabled" = lock-val false;
      "browser.uitour.themeOrigin" = lock-val "";
      "browser.uitour.url" = lock-val "";
      "browser.urlbar.daysBeforeHidingSuggestionsPrompt" = lock-val 0;
      "browser.urlbar.filter.javascript" = lock-val true;
      "browser.urlbar.oneOffSearches" = lock-val false;
      "browser.urlbar.searchSuggestionsChoice" = lock-val false;
      "browser.urlbar.speculativeConnect.enabled" = lock-val false;
      "browser.urlbar.suggest.searches" = lock-val false;
      "browser.urlbar.timesBeforeHidingSuggestionsHint" = lock-val 0;
      "browser.urlbar.trimURLs" = lock-val false;
      "browser.urlbar.usepreloadedtopurls.enabled" = lock-val false;
      "browser.urlbar.userMadeSearchSuggestionsChoice" = lock-val true;
      "browser.xul.error_pages.expert_bad_cert" = lock-val true;
      "camera.control.face_detection.enabled" = lock-val false;
      "canvas.capturestream.enabled" = lock-val false;
      "captivedetect.canonicalURL" = lock-val "";
      "clipboard.autocopy" = lock-val false;
      "datareporting.healthreport.about.reportUrl" = "data:,";
      "datareporting.healthreport.infoURL" = lock-val "";
      "datareporting.healthreport.service.enabled" = lock-val false;
      "datareporting.healthreport.uploadEnabled" = lock-val false;
      "datareporting.policy.dataSubmissionEnabled" = lock-val false;
      "datareporting.policy.firstRunURL" = lock-val "";
      "device.sensors.enabled" = lock-val false;
      "devtools.chrome.enabled" = lock-val false;
      "devtools.debugger.force-local" = lock-val true;
      "devtools.debugger.remote-enabled" = lock-val false;
      "devtools.devedition.promo.url" = lock-val "";
      "devtools.devices.url" = lock-val "";
      "devtools.gcli.imgurUploadURL" = lock-val "";
      "devtools.gcli.jquerySrc" = lock-val "";
      "devtools.gcli.lodashSrc" = lock-val "";
      "devtools.gcli.underscoreSrc" = lock-val "";
      "devtools.onboarding.telemetry.logged" = lock-val false;
      "devtools.performance.recording.ui-base-url" = lock-val "";
      "devtools.telemetry.supported_performance_marks" = lock-val "";
      "devtools.webide.adaptersAddonURL" = lock-val "";
      "devtools.webide.adbAddonURL" = lock-val "";
      "devtools.webide.autoinstallADBHelper" = lock-val false;
      "devtools.webide.autoinstallFxdtAdapters" = lock-val false;
      "devtools.webide.enabled" = lock-val false;
      "devtools.webide.templatesURL" = lock-val "";
      "dom.IntersectionObserver.enabled" = lock-val false;
      "dom.battery.enabled" = lock-val false;
      "dom.disable_open_during_load" = lock-val true;
      "dom.disable_window_move_resize" = lock-val true;
      "dom.disable_window_open_feature.close" = lock-val true;
      "dom.disable_window_open_feature.menubar" = lock-val true;
      "dom.disable_window_open_feature.minimizable" = lock-val true;
      "dom.disable_window_open_feature.titlebar" = lock-val true;
      "dom.disable_window_open_feature.toolbar" = lock-val true;
      "dom.enable_performance_navigation_timing" = lock-val false;
      "dom.enable_resource_timing" = lock-val false;
      "dom.enable_user_timing" = lock-val false;
      "dom.event.clipboardevents.enabled" = lock-val false;
      "dom.event.contextmenu.enabled" = lock-val false;
      "dom.flyweb.enabled" = lock-val false;
      "dom.forms.datetime" = lock-val false;
      "dom.gamepad.enabled" = lock-val false;
      "dom.ipc.plugins.flash.subprocess.crashreporter.enabled" = lock-val false;
      "dom.ipc.plugins.reportCrashURL" = lock-val false;
      "dom.mozTCPSocket.enabled" = lock-val false;
      "dom.netinfo.enabled" = lock-val false;
      "dom.permissions.enabled" = lock-val false;
      "dom.popup_maximum" = lock-val 4;
      "dom.push.connection.enabled" = lock-val false;
      "dom.push.enabled" = lock-val false;
      "dom.push.userAgentID" = lock-val "";
      "dom.registerProtocolHandler.insecure.enabled" = lock-val true;
      "dom.serviceWorkers.enabled" = lock-val false;
      "dom.telephony.enabled" = lock-val false;
      "dom.vibrator.enabled" = lock-val false;
      "dom.vr.enabled" = lock-val false;
      "dom.w3c_pointer_events.enabled" = lock-val false;
      "dom.webaudio.enabled" = lock-val false;
      "experiments.activeExperiment" = lock-val false;
      "experiments.enabled" = lock-val false;
      "experiments.manifest.uri" = lock-val "";
      "experiments.supported" = lock-val false;
      "extensions.blocklist.detailsURL" = lock-val "";
      "extensions.blocklist.enabled" = lock-val false;
      "extensions.blocklist.itemURL" = lock-val "";
      "extensions.blocklist.url" = lock-val "";
      "extensions.formautofill.addresses.enabled" = lock-val false;
      "extensions.formautofill.available" = "off";
      "extensions.formautofill.creditCards.enabled" = lock-val false;
      "extensions.formautofill.heuristics.enabled" = lock-val false;
      "extensions.getAddons.cache.enabled" = lock-val false;
      "extensions.getAddons.compatOverides.url" = lock-val "";
      "extensions.getAddons.get.url" = lock-val "";
      "extensions.getAddons.langpacks.url" = lock-val "";
      "extensions.getAddons.link.url" = lock-val "";
      "extensions.getAddons.search.browseURL" = lock-val "";
      "extensions.getAddons.showPane" = lock-val false;
      "extensions.getAddons.themes.browseURL" = lock-val "";
      "extensions.pocket.api" = lock-val "";
      "extensions.pocket.enabled" = lock-val false;
      "extensions.pocket.oAuthConsumerKey" = lock-val "";
      "extensions.pocket.site" = lock-val "";
      "extensions.screenshots.upload-disabled" = lock-val true;
      "extensions.shield-recipe-client.enabled" = lock-val false;
      "extensions.systemAddon.update.enabled" = lock-val false;
      "extensions.systemAddon.update.url" = lock-val "";
      "extensions.ui.experiment.hidden" = lock-val false;
      "extensions.update.autoUpdateDefault" = lock-val false;
      "extensions.update.background.url" = lock-val "";
      "extensions.update.enabled" = lock-val false;
      "extensions.update.url" = lock-val "";
      "extensions.webcompat-reporter.newIssueEndpoint" = lock-val "";
      "extensions.webextensions.base-content-security-policy" = "default-src 'self' moz-extension: blob: filesystem: 'unsafe-eval' 'unsafe-inline'; script-src 'self' moz-extension: blob: filesystem: 'unsafe-eval' 'unsafe-inline'; object-src 'self' moz-extension: blob: filesystem:;";
      "extensions.webextensions.identity.redirectDomain" = lock-val "";
      "extensions.webextensions.restrictedDomains" = lock-val "";
      "extensions.webservice.discoverURL" = lock-val "";
      "font.blacklist.underline_offset" = lock-val "";
      "gecko.handlerService.schemes.irc.0.name" = lock-val "";
      "gecko.handlerService.schemes.irc.0.uriTemplate" = lock-val "";
      "gecko.handlerService.schemes.ircs.0.name" = lock-val "";
      "gecko.handlerService.schemes.mailto.0.name" = lock-val "";
      "gecko.handlerService.schemes.mailto.0.uriTemplate" = lock-val "";
      "gecko.handlerService.schemes.mailto.1.name" = lock-val "";
      "gecko.handlerService.schemes.mailto.1.uriTemplate" = lock-val "";
      "gecko.handlerService.schemes.webcal.0.uriTemplate" = lock-val "";
      "general.appname.override" = "Netscape";
      "general.appversion.override" = "5.0 (Windows)";
      "general.autoScroll" = lock-val false;
      "general.buildID.override" = "20100101";
      "general.config.filename" = "mozilla.cfg";
      "general.oscpu.override" = "Windows NT 6.1";
      "general.platform.override" = "Win32";
      "general.useragent.site_specific_overrides" = lock-val false;
      "geo.enabled" = lock-val false;
      "geo.wifi.logging.enabled" = lock-val true;
      "geo.wifi.uri" = lock-val "";
      "gfx.font_rendering.graphite.enabled" = lock-val false;
      "gfx.font_rendering.opentype_svg.enabled" = lock-val false;
      "identity.fxaccounts.auth.uri" = lock-val "";
      "identity.fxaccounts.remote.oauth.uri" = lock-val "";
      "identity.fxaccounts.remote.profile.uri" = lock-val "";
      "identity.fxaccounts.remote.root" = lock-val "";
      "identity.mobilepromo.android" = lock-val "";
      "identity.mobilepromo.ios" = lock-val "";
      "identity.sync.tokenserver.uri" = lock-val "";
      "intl.locale.requested" = "en-US";
      "intl.regional_prefs.use_os_locales" = lock-val false;
      "javascript.options.shared_memory" = lock-val false;
      "javascript.use_us_english_locale" = lock-val true;
      "layers.acceleration.disabled" = lock-val false;
      "layers.acceleration.force-enabled" = lock-val true;
      "layers.async-video.enabled" = lock-val true;
      "layers.offmainthreadcomposition.async-animations" = lock-val true;
      "layers.offmainthreadcomposition.enabled" = lock-val true;
      "layout.css.visited_links_enabled" = lock-val false;
      "layout.frame_rate.precise" = lock-val true;
      "layout.spellcheckDefault" = lock-val 2;
      "lightweightThemes.getMoreURL" = lock-val "";
      "lightweightThemes.persisted.footerURL" = lock-val false;
      "lightweightThemes.persisted.headerURL" = lock-val false;
      "lightweightThemes.recommendedThemes" = lock-val "";
      "lightweightThemes.update.enabled" = lock-val false;
      "loop.logDomains" = lock-val false;
      "lpbmode.enabled" = lock-val true;
      "mailnews.messageid_browser.url" = lock-val "";
      "mailnews.mx_service_url" = lock-val "";
      "media.autoplay.default" = lock-val 2;
      "media.decoder-doctor.new-issue-endpoint" = lock-val "";
      "media.eme.enabled" = lock-val false;
      "media.getusermedia.audiocapture.enabled" = lock-val false;
      "media.getusermedia.browser.enabled" = lock-val false;
      "media.getusermedia.screensharing.enabled" = lock-val false;
      "media.gmp-eme-adobe.enabled" = lock-val false;
      "media.gmp-gmpopenh264.autoupdate" = lock-val false;
      "media.gmp-gmpopenh264.enabled" = lock-val false;
      "media.gmp-manager.certs.1.commonName" = lock-val "";
      "media.gmp-manager.certs.2.commonName" = lock-val "";
      "media.gmp-manager.updateEnabled" = lock-val false;
      "media.gmp-manager.url" = "data:text/plain,";
      "media.gmp-manager.url.override" = "data:text/plain,";
      "media.gmp-provider.enabled" = lock-val false;
      "media.gmp-widevinecdm.autoupdate" = lock-val false;
      "media.gmp-widevinecdm.enabled" = lock-val false;
      "media.gmp-widevinecdm.visible" = lock-val false;
      "media.gmp.trial-create.enabled" = lock-val false;
      "media.navigator.enabled" = lock-val false;
      "media.peerconnection.enabled" = lock-val false;
      "media.video_stats.enabled" = lock-val false;
      "media.webspeech.recognition.enable" = lock-val false;
      "middlemouse.contentLoadURL" = lock-val false;
      "network.IDN_show_punycode" = lock-val true;
      "network.allow-experiments" = lock-val false;
      "network.captive-portal-service.enabled" = lock-val false;
      "network.cookie.cookieBehavior" = lock-val 1;
      "network.cookie.lifetimePolicy" = lock-val 2;
      "network.dns.blockDotOnion" = lock-val true;
      "network.dns.disableIPv6" = lock-val true;
      "network.dns.disablePrefetch" = lock-val true;
      "network.dns.disablePrefetchFromHTTPS" = lock-val true;
      "network.dns.localDomains" = "librefox.com";
      "network.http.altsvc.enabled" = lock-val false;
      "network.http.altsvc.oe" = lock-val false;
      "network.http.redirection-limit" = 10;
      "network.http.referer.XOriginPolicy" = lock-val 1;
      "network.http.referer.XOriginTrimmingPolicy" = lock-val 0;
      "network.http.referer.hideOnionSource" = lock-val true;
      "network.http.referer.spoofSource" = lock-val false;
      "network.http.referer.trimmingPolicy" = lock-val 0;
      "network.http.speculative-parallel-limit" = lock-val 0;
      "network.jar.block-remote-files" = lock-val true;
      "network.jar.open-unsafe-types" = lock-val false;
      "network.manage-offline-status" = lock-val false;
      "network.negotiate-auth.allow-insecure-ntlm-v1" = lock-val false;
      "network.negotiate-auth.allow-insecure-ntlm-v1-https" = lock-val false;
      "network.predictor.cleaned-up" = lock-val true;
      "network.predictor.enable-prefetch" = lock-val false;
      "network.predictor.enabled" = lock-val false;
      "network.prefetch-next" = lock-val false;
      "network.protocol-handler.expose-all" = lock-val false;
      "network.protocol-handler.expose.about" = lock-val true;
      "network.protocol-handler.expose.blob" = lock-val true;
      "network.protocol-handler.expose.chrome" = lock-val true;
      "network.protocol-handler.expose.data" = lock-val true;
      "network.protocol-handler.expose.file" = lock-val true;
      "network.protocol-handler.expose.ftp" = lock-val true;
      "network.protocol-handler.expose.http" = lock-val true;
      "network.protocol-handler.expose.https" = lock-val true;
      "network.protocol-handler.expose.javascript" = lock-val true;
      "network.protocol-handler.expose.moz-extension" = lock-val true;
      "network.protocol-handler.external.about" = lock-val false;
      "network.protocol-handler.external.blob" = lock-val false;
      "network.protocol-handler.external.chrome" = lock-val false;
      "network.protocol-handler.external.data" = lock-val false;
      "network.protocol-handler.external.file" = lock-val false;
      "network.protocol-handler.external.ftp" = lock-val false;
      "network.protocol-handler.external.http" = lock-val false;
      "network.protocol-handler.external.https" = lock-val false;
      "network.protocol-handler.external.javascript" = lock-val false;
      "network.protocol-handler.external.moz-extension" = lock-val false;
      "network.protocol-handler.external.ms-windows-store" = lock-val false;
      "network.protocol-handler.warn-external-default" = lock-val true;
      "network.proxy.autoconfig_url" = lock-val "";
      "network.proxy.autoconfig_url.include_path" = lock-val false;
      "network.proxy.socks_remote_dns" = lock-val true;
      "network.proxy.socks_version" = lock-val 5;
      "network.stricttransportsecurity.preloadlist" = lock-val false;
      "network.trr.bootstrapAddress" = lock-val "";
      "network.trr.confirmationNS" = lock-val "";
      "network.trr.mode" = lock-val 5;
      "network.trr.uri" = lock-val "";
      "network.websocket.enabled" = lock-val false;
      "offline-apps.allow_by_default" = lock-val false;
      "pdfjs.disabled" = lock-val false;
      "pdfjs.enableWebGL" = lock-val false;
      "pdfjs.enabledCache.state" = lock-val false;
      "pdfjs.previousHandler.alwaysAskBeforeHandling" = lock-val true;
      "permissions.default.geo" = lock-val 2;
      "permissions.manager.defaultsUrl" = lock-val "";
      "places.history.enabled" = lock-val false;
      "plugin.default.state" = lock-val 1;
      "plugin.defaultXpi.state" = lock-val 1;
      "plugin.scan.plid.all" = lock-val false;
      "plugin.sessionPermissionNow.intervalInMinutes" = lock-val 0;
      "plugin.state.flash" = lock-val 0;
      "plugin.state.java" = lock-val 0;
      "plugin.state.libgnome-shell-browser-plugin" = lock-val 0;
      "plugins.click_to_play" = lock-val true;
      "plugins.crash.supportUrl" = lock-val "";
      "pref.general.disable_button.default_browser" = lock-val false;
      "pref.privacy.disable_button.change_blocklist" = lock-val true;
      "pref.privacy.disable_button.view_passwords" = lock-val false;
      "prio.publicKeyA" = lock-val "";
      "prio.publicKeyB" = lock-val "";
      "privacy.clearOnShutdown.offlineApps" = lock-val true;
      "privacy.donottrackheader.enabled" = lock-val true;
      "privacy.donottrackheader.value" = lock-val 1;
      "privacy.history.custom" = lock-val true;
      "privacy.resistFingerprinting" = lock-val true;
      "privacy.resistFingerprinting.block_mozAddonManager" = lock-val true;
      "privacy.sanitize.sanitizeOnShutdown" = lock-val true;
      "privacy.sanitize.timeSpan" = lock-val 0;
      "privacy.spoof_english" = lock-val 2;
      "privacy.trackingprotection.annotate_channels" = lock-val false;
      "privacy.trackingprotection.enabled" = lock-val false;
      "privacy.trackingprotection.introURL" = lock-val "";
      "privacy.trackingprotection.lower_network_priority" = lock-val false;
      "privacy.trackingprotection.pbmode.enabled" = lock-val false;
      "privacy.userContext.enabled" = lock-val true;
      "privacy.userContext.longPressBehavior" = lock-val 2;
      "privacy.userContext.ui.enabled" = lock-val true;
      "reader.parse-on-load.enabled" = lock-val false;
      "security.OCSP.enabled" = lock-val 0;
      "security.OCSP.require" = lock-val false;
      "security.cert_pinning.enforcement_level" = lock-val 2;
      "security.csp.enable" = lock-val true;
      "security.csp.experimentalEnabled" = lock-val true;
      "security.dialog_enable_delay" = lock-val 700;
      "security.family_safety.mode" = lock-val 0;
      "security.fileuri.strict_origin_policy" = lock-val true;
      "security.insecure_connection_icon.enabled" = lock-val true;
      "security.insecure_connection_icon.pbmode.enabled" = lock-val true;
      "security.insecure_connection_text.enabled" = lock-val true;
      "security.insecure_field_warning.contextual.enabled" = lock-val true;
      "security.insecure_password.ui.enabled" = lock-val true;
      "security.mixed_content.block_active_content" = lock-val true;
      "security.mixed_content.block_display_content" = lock-val true;
      "security.mixed_content.block_object_subrequest" = lock-val true;
      "security.mixed_content.upgrade_display_content" = lock-val true;
      "security.pki.sha1_enforcement_level" = lock-val 1;
      "security.ssl.disable_session_identifiers" = lock-val true;
      "security.ssl.enable_ocsp_stapling" = lock-val true;
      "security.ssl.errorReporting.automatic" = lock-val false;
      "security.ssl.errorReporting.enabled" = lock-val false;
      "security.ssl.errorReporting.url" = lock-val "";
      "security.ssl.require_safe_negotiation" = lock-val true;
      "security.ssl.treat_unsafe_negotiation_as_broken" = lock-val true;
      "security.ssl3.ecdh_ecdsa_rc4_128_sha" = lock-val false;
      "security.ssl3.ecdh_rsa_rc4_128_sha" = lock-val false;
      "security.ssl3.ecdhe_ecdsa_rc4_128_sha" = lock-val false;
      "security.ssl3.ecdhe_rsa_rc4_128_sha" = lock-val false;
      "security.ssl3.rsa_aes_128_sha" = lock-val false;
      "security.ssl3.rsa_aes_256_sha" = lock-val false;
      "security.ssl3.rsa_des_ede3_sha" = lock-val false;
      "security.ssl3.rsa_rc4_128_md5" = lock-val false;
      "security.ssl3.rsa_rc4_128_sha" = lock-val false;
      "security.ssl3.rsa_seed_sha" = lock-val false;
      "security.tls.unrestricted_rc4_fallback" = lock-val false;
      "security.tls.version.fallback-limit" = lock-val 3;
      "security.tls.version.min" = lock-val 2;
      "security.xpconnect.plugin.unrestricted" = lock-val false;
      "services.blocklist.addons.collection" = lock-val "";
      "services.blocklist.addons.signer" = lock-val "";
      "services.blocklist.gfx.collection" = lock-val "";
      "services.blocklist.gfx.signer" = lock-val "";
      "services.blocklist.onecrl.signer" = lock-val "";
      "services.blocklist.pinning.signer" = lock-val "";
      "services.blocklist.plugins.collection" = lock-val "";
      "services.blocklist.plugins.signer" = lock-val "";
      "services.blocklist.update_enabled" = lock-val false;
      "services.settings.default_signer" = lock-val "";
      "services.settings.server" = lock-val "";
      "services.sync.addons.trustedSourceHostnames" = lock-val "";
      "services.sync.clients.lastSync" = lock-val "0";
      "services.sync.clients.lastSyncLocal" = lock-val "0";
      "services.sync.declinedEngines" = lock-val "";
      "services.sync.enabled" = lock-val false;
      "services.sync.engine.addresses.available" = lock-val false;
      "services.sync.fxa.privacyURL" = lock-val "";
      "services.sync.fxa.termsURL" = lock-val "";
      "services.sync.globalScore" = lock-val 0;
      "services.sync.jpake.serverURL" = lock-val "";
      "services.sync.lastversion" = lock-val "";
      "services.sync.migrated" = lock-val true;
      "services.sync.nextSync" = lock-val 0;
      "services.sync.prefs.sync.browser.safebrowsing.downloads.enabled" = lock-val false;
      "services.sync.prefs.sync.browser.safebrowsing.malware.enabled" = lock-val false;
      "services.sync.prefs.sync.browser.safebrowsing.passwords.enabled" = lock-val false;
      "services.sync.prefs.sync.browser.safebrowsing.phishing.enabled" = lock-val false;
      "services.sync.prefs.sync.signon.rememberSignons" = lock-val false;
      "services.sync.serverURL" = lock-val "";
      "services.sync.tabs.lastSync" = lock-val "0";
      "services.sync.tabs.lastSyncLocal" = lock-val "0";
      "shield.savant.enabled" = lock-val false;
      "shumway.disabled" = lock-val true;
      "signon.autofillForms" = lock-val false;
      "signon.autofillForms.http" = lock-val false;
      "signon.formlessCapture.enabled" = lock-val false;
      "social.directories" = lock-val "";
      "social.remote-install.enabled" = lock-val false;
      "social.whitelist" = lock-val "";
      "sync.enabled" = lock-val false;
      "sync.jpake.serverURL" = lock-val "";
      "sync.serverURL" = lock-val "";
      "toolkit.coverage.endpoint.base" = lock-val "";
      "toolkit.crashreporter.infoURL" = lock-val "";
      "toolkit.datacollection.infoURL" = lock-val "";
      "toolkit.telemetry.archive.enabled" = lock-val false;
      "toolkit.telemetry.bhrPing.enabled" = lock-val false;
      "toolkit.telemetry.cachedClientID" = lock-val "";
      "toolkit.telemetry.coverage.opt-out" = lock-val true;
      "toolkit.telemetry.enabled" = lock-val false;
      "toolkit.telemetry.firstShutdownPing.enabled" = lock-val false;
      "toolkit.telemetry.hybridContent.enabled" = lock-val false;
      "toolkit.telemetry.infoURL" = lock-val "";
      "toolkit.telemetry.newProfilePing.enabled" = lock-val false;
      "toolkit.telemetry.previousBuildID" = lock-val "";
      "toolkit.telemetry.rejected" = lock-val true;
      "toolkit.telemetry.reportingpolicy.firstRun" = lock-val false;
      "toolkit.telemetry.server" = "data:,";
      "toolkit.telemetry.server_owner" = lock-val "";
      "toolkit.telemetry.shutdownPingSender.enabled" = lock-val false;
      "toolkit.telemetry.unified" = lock-val false;
      "toolkit.telemetry.updatePing.enabled" = lock-val false;
      "toolkit.winRegisterApplicationRestart" = lock-val false;
      "urlclassifier.trackingTable" = lock-val "";
      "webchannel.allowObject.urlWhitelist" = lock-val "";
      "webextensions.storage.sync.serverURL" = lock-val "";
      "webgl.disable-extensions" = lock-val true;
      "webgl.disable-fail-if-major-performance-caveat" = lock-val true;
      "webgl.dxgl.enabled" = lock-val false;
      "webgl.enable-webgl2" = lock-val false;
      "webgl.force-enabled" = lock-val true;
      "webgl.min_capability_mode" = lock-val true;
      "xpinstall.signatures.devInfoURL" = lock-val "";
    };
  };

}
