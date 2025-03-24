{ ... }:
{
  programs.firefox.profiles.s1n7ax.bookmarks = {
    force = true;
    settings = [
      {
        name = "To Read";
        bookmarks = [
          {
            name = "My Git & GitHub workflow - an efficient yet messy setup | Dolev Hadar";
            tags = [
              "github"
              "git"
              "workflow"
            ];
            url = "https://dlvhdr.me/posts/how-i-use-github";
          }
          {
            name = "Help! Linux ate my RAM!";
            tags = [ "linux" ];
            url = "https://www.linuxatemyram.com/";
          }
          {
            name = "OAuth 2.1 explained | Connect2id";
            tags = [
              "oauth"
              "security"
            ];
            url = "https://connect2id.com/learn/oauth-2-1";
          }
          {
            name = "I built a garbage collector for a language that doesn’t need one | clayt";
            tags = [ "programming" ];
            url = "https://claytonwramsey.github.io/2023/08/14/dumpster.html";
          }
          {
            name = "OAuth 2.0 for Browser-Based Apps";
            tags = [
              "oauth"
              "security"
            ];
            url = "https://www.ietf.org/archive/id/draft-ietf-oauth-browser-based-apps-10.html";
          }
          {
            name = "What Color is Your Function? – journal.stuffwithstuff.com";
            url = "https://journal.stuffwithstuff.com/2015/02/01/what-color-is-your-function/";
          }
          {
            name = "Lua: async/await/await_all abstraction, structured concurrency · Issue #19624 · neovim/neovim";
            url = "https://github.com/neovim/neovim/issues/19624";
          }
          {
            name = "tfp2020-postsymposium.pdf";
            url = "http://logic.cs.tsukuba.ac.jp/~sat/pdf/tfp2020-postsymposium.pdf";
          }
          {
            name = "RFC 7231: Hypertext Transfer Protocol (HTTP/1.1): Semantics and Content";
            url = "https://www.rfc-editor.org/rfc/rfc7231#section-4.3.4";
          }
          {
            name = "api-guidelines/azure/Guidelines.md at vNext · microsoft/api-guidelines";
            url = "https://github.com/microsoft/api-guidelines/blob/vNext/azure/Guidelines.md";
          }
          {
            name = "Scale, Standardize, or Normalize with Scikit-Learn | by Jeff Hale | Towards Data Science";
            url = "https://towardsdatascience.com/scale-standardize-or-normalize-with-scikit-learn-6ccc7d176a02";
          }
          {
            name = "zakirullin/cognitive-load: 🧠 Cognitive Load is what matters";
            url = "https://github.com/zakirullin/cognitive-load";
          }
          {
            name = "The Copenhagen Book";
            url = "https://thecopenhagenbook.com/";
          }
        ];
      }
    ];
  };
}
