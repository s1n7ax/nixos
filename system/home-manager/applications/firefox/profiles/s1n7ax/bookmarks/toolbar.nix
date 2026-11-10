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
            name = "riya-mandiya";
            tags = [ "project" ];
            url = "https://github.com/Syntxio/riya-mandiya";
          }
          {
            name = "openrep";
            tags = [ "project" ];
            url = "https://github.com/s1n7ax/openrep";
          }
        ];
      }
    ];
  };
}
