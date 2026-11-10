
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

  const topic = "browser-delayed-startup-finished";

  const openGroups = (window) => {
    Services.obs.removeObserver(openGroups, topic);

    const { gBrowser } = window;
    const triggeringPrincipal =
      Services.scriptSecurityManager.getSystemPrincipal();
    const blankTabs = gBrowser.tabs.filter((tab) =>
      window.isBlankPageURL(tab.linkedBrowser.currentURI.spec),
    );

    const groupTabs = groups.map(({ label, color, urls }) => {
      const tabs = urls.map((url) =>
        gBrowser.addTab(url, { triggeringPrincipal }),
      );
      gBrowser.addTabGroup(tabs, { label, color });
      return tabs;
    });

    gBrowser.selectedTab = groupTabs[0][0];
    blankTabs.forEach((tab) => gBrowser.removeTab(tab));
  };

  Services.obs.addObserver(openGroups, topic);
})();
