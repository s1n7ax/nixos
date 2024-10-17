{ ... }:
{
  programs.firefox.profiles.work.bookmarks = [
    {
      toolbar = true;
      bookmarks = [
        {
          name = "outlook";
          tags = [ "email" ];
          url = "https://outlook.office.com";
        }
        {
          name = "orlitech-be-auth";
          tags = [ "github" ];
          url = "https://github.com/Orli-Tech/orlitech-be-auth/pulls";
        }
        {
          name = "orlitech-fe";
          tags = [ "github" ];
          url = "https://github.com/Orli-Tech/orlitech-fe/pulls";
        }
        {
          name = "orlitech-be";
          tags = [ "github" ];
          url = "https://github.com/Orli-Tech/orlitech-be/pulls";
        }
        {
          name = "Sprint";
          tags = [ "spring" ];
          url = "https://app.clickup.com/9016146704/v/l/6-901604061184-1";
        }
        {
          name = "ChatGPT";
          tags = [ "AI" ];
          url = "https://chatgpt.com/";
        }
        {
          name = "Router";
          tags = [ "router" ];
          url = "http://192.168.1.1/";
        }
        {
          name = "SMTP2GO | Activity";
          tags = [ "email" ];
          url = "https://app-us.smtp2go.com/reports/activity/";
        }
        {
          name = "DigitalOcean";
          tags = [ "cloud" ];
          url = "https://cloud.digitalocean.com/projects/3873560c-6bac-4bd4-a1ce-c3d010c4b2da/resources?i=71ad79";
        }
        {
          name = "Scoring system";
          tags = [ "prod" ];
          url = "https://dev.platform.orli.tech/";
        }
        {
          name = "HTTP Status Codes Decision Diagram - Infographic | Loggly";
          tags = [ "prod" ];
          url = "https://www.loggly.com/blog/http-status-code-diagram/";
        }
        {
          name = "Drawing";
          tags = [ "notes" ];
          url = "https://excalidraw.com/";
        }
      ];
    }
  ];
}
