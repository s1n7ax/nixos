
/**
 * Opens one tab group per project, each with its pull requests and Claude
 * Code, in the first browser window after Firefox starts.
 */
(() => {
  const groups = [
    {
      label: "NixOS",
      color: "blue",
      urls: ["https://github.com/s1n7ax/nixos/pulls", "https://claude.ai/code"],
    },
    {
      label: "riya-mandiya",
      color: "orange",
      urls: [
        "https://github.com/Syntxio/riya-mandiya/pulls",
        "https://claude.ai/code",
      ],
    },
    {
      label: "openrep",
      color: "green",
      urls: ["https://github.com/s1n7ax/openrep/pulls", "https://claude.ai/code"],
    },
  ];

  const openGroups = (window) => {
    const { gBrowser } = window;
    const triggeringPrincipal =
      Services.scriptSecurityManager.getSystemPrincipal();
    const blankTabs = gBrowser.tabs.filter((tab) =>
      window.isBlankPageURL(tab.linkedBrowser.currentURI.spec),
    );
    const existingLabels = new Set(
      gBrowser.tabGroups.map((group) => group.label),
    );

    const groupTabs = groups
      .filter(({ label }) => !existingLabels.has(label))
      .map(({ label, color, urls }) => {
        const tabs = urls.map((url) =>
          gBrowser.addTab(url, { triggeringPrincipal }),
        );
        gBrowser.addTabGroup(tabs, { label, color });
        return tabs;
      });

    if (groupTabs.length) {
      gBrowser.selectedTab = groupTabs[0][0];
    }
    blankTabs.forEach((tab) => gBrowser.removeTab(tab));
  };

  /**
   * Waits for the first window to finish starting up and for startup session
   * restore to finish, so neither can replace or close the new tabs.
   */
  const pending = new Set([
    "browser-delayed-startup-finished",
    "sessionstore-windows-restored",
  ]);
  const observer = (subject, topic) => {
    Services.obs.removeObserver(observer, topic);
    pending.delete(topic);
    if (pending.size) {
      return;
    }
    const window = Services.wm.getMostRecentWindow("navigator:browser");
    if (window) {
      Services.tm.dispatchToMainThread(() => openGroups(window));
    }
  };
  pending.forEach((topic) => Services.obs.addObserver(observer, topic));
})();
