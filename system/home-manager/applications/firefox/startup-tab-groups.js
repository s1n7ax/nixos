/**
 * Opens one tab group per project, each with its pull requests, issues and
 * Claude Code, in the first browser window after Firefox starts.
 */
(() => {
  const groups = [
    { label: "NixOS", color: "blue", repo: "s1n7ax/nixos" },
    { label: "riya-mandiya", color: "orange", repo: "Syntxio/riya-mandiya" },
    { label: "openrep", color: "green", repo: "s1n7ax/openrep" },
  ];
  const labels = new Set(groups.map(({ label }) => label));

  const blankURLs = new Set([
    "about:blank",
    "chrome://browser/content/blanktab.html",
  ]);

  const lazy = {};
  ChromeUtils.defineESModuleGetters(lazy, {
    SessionStore:
      "moz-src:///browser/components/sessionstore/SessionStore.sys.mjs",
  });

  /**
   * Forgets the saved copies of the project groups. Firefox saves the groups
   * that were open when it last quit, so without this the saved groups list
   * gains a copy of every project group on each restart.
   */
  const forgetSavedGroups = () =>
    lazy.SessionStore.getSavedTabGroups()
      .filter(({ name }) => labels.has(name))
      .forEach(({ id }) => lazy.SessionStore.forgetSavedTabGroup(id));

  const openGroups = (window) => {
    const { gBrowser } = window;
    const triggeringPrincipal =
      Services.scriptSecurityManager.getSystemPrincipal();
    const blankTabs = gBrowser.tabs.filter(({ linkedBrowser }) =>
      [
        linkedBrowser.currentURI.spec,
        linkedBrowser.userTypedValue ?? "about:blank",
      ].every((url) => blankURLs.has(url)),
    );
    const existingLabels = new Set(
      [...Services.wm.getEnumerator("navigator:browser")].flatMap((win) =>
        win.gBrowser.tabGroups.map((group) => group.label),
      ),
    );

    forgetSavedGroups();

    const groupTabs = groups
      .filter(({ label }) => !existingLabels.has(label))
      .map(({ label, color, repo }) => {
        const tabs = [
          `https://github.com/${repo}/pulls`,
          `https://github.com/${repo}/issues`,
          "https://claude.ai/code",
        ].map((url) => gBrowser.addTab(url, { triggeringPrincipal }));
        gBrowser.addTabGroup(tabs, { label, color });
        return tabs;
      });

    if (!groupTabs.length) {
      return;
    }
    gBrowser.selectedTab = groupTabs[0][0];
    blankTabs.forEach((tab) => gBrowser.removeTab(tab));
  };

  const startupTopic = "browser-delayed-startup-finished";

  /**
   * Opens the groups once the first window has started up, Firefox has
   * restored whatever session state it brings into that window, and the
   * window has gone idle. Firefox restores state even after a clean quit (the
   * previous session's groups, pinned and closed tabs), and tabs added before
   * that restore and idle are never attached to the tab strip, so their
   * groups are dropped.
   */
  const onStartup = (window) => {
    Services.obs.removeObserver(onStartup, startupTopic);
    lazy.SessionStore.promiseAllWindowsRestored.then(() =>
      window.requestIdleCallback(() => openGroups(window)),
    );
  };
  Services.obs.addObserver(onStartup, startupTopic);
})();
