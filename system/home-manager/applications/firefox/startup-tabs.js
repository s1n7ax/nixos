/**
 * Opens each project's pull requests and Claude Code as plain tabs in the
 * first browser window after Firefox starts.
 */
(() => {
  const urls = [
    "https://github.com/s1n7ax/nixos/pulls",
    "https://github.com/Syntxio/riya-mandiya/pulls",
    "https://github.com/s1n7ax/openrep/pulls",
    "https://claude.ai/code",
  ];
  const oldGroupLabels = new Set(["NixOS", "riya-mandiya", "openrep"]);

  const blankURLs = new Set([
    "about:blank",
    "chrome://browser/content/blanktab.html",
  ]);
  const restorePromptURLs = new Set([
    "about:sessionrestore",
    "about:welcomeback",
  ]);

  const lazy = {};
  ChromeUtils.defineESModuleGetters(lazy, {
    SessionStore:
      "moz-src:///browser/components/sessionstore/SessionStore.sys.mjs",
  });

  /**
   * Removes the project tab groups that earlier versions of this script
   * opened: forgets their saved copies and ungroups any a restored session
   * brought back, keeping their tabs.
   */
  const removeOldGroups = (windows) => {
    lazy.SessionStore.getSavedTabGroups()
      .filter(({ name }) => oldGroupLabels.has(name))
      .forEach(({ id }) => lazy.SessionStore.forgetSavedTabGroup(id));
    windows
      .flatMap((win) => win.gBrowser.tabGroups)
      .filter(({ label }) => oldGroupLabels.has(label))
      .forEach((group) => group.ungroupTabs());
  };

  /**
   * The URLs a tab shows or is about to show. A restored tab that has not
   * loaded yet still reports about:blank, so its session entry is read too.
   */
  const tabURLs = (tab) => {
    const { entries = [], index = entries.length } = JSON.parse(
      lazy.SessionStore.getTabState(tab),
    );
    return [tab.linkedBrowser.currentURI.spec, entries[index - 1]?.url];
  };

  const openTabs = (window) => {
    const { gBrowser } = window;
    const triggeringPrincipal =
      Services.scriptSecurityManager.getSystemPrincipal();
    const blankTabs = gBrowser.tabs.filter(
      (tab) =>
        !tab.hasAttribute("busy") &&
        [
          tab.linkedBrowser.currentURI.spec,
          tab.linkedBrowser.userTypedValue ?? "about:blank",
        ].every((url) => blankURLs.has(url)),
    );
    const windows = [...Services.wm.getEnumerator("navigator:browser")];
    const openURLs = new Set(
      windows.flatMap((win) => win.gBrowser.tabs.flatMap(tabURLs)),
    );

    removeOldGroups(windows);

    const tabs = urls
      .filter((url) => !openURLs.has(url))
      .map((url) => gBrowser.addTab(url, { triggeringPrincipal }));

    if (!tabs.length) {
      return;
    }
    if (blankTabs.includes(gBrowser.selectedTab)) {
      gBrowser.selectedTab = tabs[0];
    }
    blankTabs.forEach((tab) => gBrowser.removeTab(tab));
  };

  const whenIdle = (window) =>
    new Promise((resolve) => window.requestIdleCallback(resolve));

  /**
   * Resolves once the window no longer shows Firefox's restore prompt, which
   * replaces the automatic restore after repeated crashes. The crashed session
   * already holds the tabs, so opening them next to the prompt would
   * duplicate them when the user restores it.
   */
  const leftRestorePrompt = ({ gBrowser }) =>
    new Promise((resolve) => {
      const showsPrompt = () =>
        gBrowser.tabs.some(({ linkedBrowser }) =>
          restorePromptURLs.has(linkedBrowser.currentURI.spec),
        );
      if (!showsPrompt()) {
        resolve();
        return;
      }
      const listener = {
        onLocationChange() {
          if (!showsPrompt()) {
            gBrowser.removeTabsProgressListener(listener);
            resolve();
          }
        },
      };
      gBrowser.addTabsProgressListener(listener);
    });

  const startupTopic = "browser-delayed-startup-finished";

  /**
   * Opens the tabs once the first window has started up, Firefox has
   * restored whatever session state it brings into that window, the user has
   * answered the restore prompt if Firefox showed one, and the window has gone
   * idle. Firefox restores state even after a clean quit (the previous
   * session's pinned and closed tabs), and tabs added before that restore
   * and idle are never attached to the tab strip.
   */
  const onStartup = (window) => {
    Services.obs.removeObserver(onStartup, startupTopic);
    lazy.SessionStore.promiseAllWindowsRestored
      .then(() => whenIdle(window))
      .then(() => leftRestorePrompt(window))
      .then(() => whenIdle(window))
      .then(() => openTabs(window));
  };
  Services.obs.addObserver(onStartup, startupTopic);
})();
