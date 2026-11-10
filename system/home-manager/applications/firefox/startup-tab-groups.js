
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

  const blankURLs = new Set([
    "about:blank",
    "chrome://browser/content/blanktab.html",
  ]);

  const openGroups = (window) => {
    const { gBrowser } = window;
    const triggeringPrincipal =
      Services.scriptSecurityManager.getSystemPrincipal();
    const blankTabs = gBrowser.tabs.filter(({ linkedBrowser }) =>
      [linkedBrowser.currentURI.spec, linkedBrowser.userTypedValue ?? "about:blank"]
        .every((url) => blankURLs.has(url)),
    );
    const existingLabels = new Set(
      [...Services.wm.getEnumerator("navigator:browser")].flatMap((win) =>
        win.gBrowser.tabGroups.map((group) => group.label),
      ),
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

    if (!groupTabs.length) {
      return;
    }
    gBrowser.selectedTab = groupTabs[0][0];
    blankTabs.forEach((tab) => gBrowser.removeTab(tab));
  };

  /**
   * Opens the groups once the first window has started up. When Firefox is
   * about to restore a session into that window, waits for the restore to
   * finish first, so the restored session cannot replace the new tabs.
   */
  const restoredTopic = "sessionstore-windows-restored";
  const startupTopic = "browser-delayed-startup-finished";
  const onStartup = (window) => {
    Services.obs.removeObserver(onStartup, startupTopic);

    const { SessionStartup } = ChromeUtils.importESModule(
      "moz-src:///browser/components/sessionstore/SessionStartup.sys.mjs",
    );
    SessionStartup.onceInitialized.then(() => {
      if (!SessionStartup.willRestore()) {
        openGroups(window);
        return;
      }
      const onRestored = () => {
        Services.obs.removeObserver(onRestored, restoredTopic);
        Services.tm.dispatchToMainThread(() => openGroups(window));
      };
      Services.obs.addObserver(onRestored, restoredTopic);
    });
  };
  Services.obs.addObserver(onStartup, startupTopic);
})();
