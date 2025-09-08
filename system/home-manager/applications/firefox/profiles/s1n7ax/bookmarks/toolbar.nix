{ ... }:
{

  programs.firefox.profiles.s1n7ax.bookmarks = {
    force = true;
    settings = [
      {
        toolbar = true;
        bookmarks = [
          {
            name = "Facebook";
            tags = [ "social" ];
            url = "https://web.facebook.com/";
          }
          {
            name = "WhatsApp";
            tags = [
              "social"
              "chat"
            ];
            url = "https://web.whatsapp.com/";
          }
          {
            name = "YouTube";
            tags = [ "video" ];
            url = "https://www.youtube.com/";
          }
          {
            name = "YouTube Studio";
            tags = [ "video" ];
            url = "https://studio.youtube.com/";
          }
          {
            name = "Router";
            tags = [ "router" ];
            url = "http://192.168.1.1/";
          }
          {
            name = "Music";
            tags = [ "music" ];
            url = "https://music.youtube.com/";
          }
          {
            name = "Home Assistant";
            tags = [ "self-hosted" ];
            url = "http://192.168.1.110:8124/";
          }
          {
            name = "DeepSeek";
            tags = [ "AI" ];
            url = "https://chat.deepseek.com/";
          }
          {
            name = "LeetCode";
            tags = [ "programming" ];
            url = "https://leetcode.com/problemset/?difficulty=EASY&page=1";
          }
          {
            name = "HNB";
            tags = [ "bank" ];
            url = "https://onlinebanking.hnb.lk/";
          }
          {
            name = "AliExpress";
            tags = [ "shopping" ];
            url = "https://www.aliexpress.com/";
          }
          {
            name = "OpenUnicodeConverter";
            tags = [ "unicode" ];
            url = "https://www.sinhalaunicode.org/";
          }
          {
            name = "Monkeytype";
            tags = [ "typing" ];
            url = "https://monkeytype.com/";
          }
          {
            name = "Gmail";
            tags = [ "email" ];
            url = "https://mail.google.com/";
          }
          {
            name = "Adebe Express";
            tags = [ "editor" ];
            url = "https://express.adobe.com/";
          }
          {
            name = "Drawing";
            tags = [ "notes" ];
            url = "https://excalidraw.com/";
          }
        ];
      }
    ];
  };
}
