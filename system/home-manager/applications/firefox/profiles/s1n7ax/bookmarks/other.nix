{ ... }:
{
  programs.firefox.profiles.s1n7ax.bookmarks = {
    force = true;
    settings = [
      {
        name = "Other";
        bookmarks = [
          {
            name = "DigitalOcean";
            tags = [ "digitalocean" ];
            url = "https://cloud.digitalocean.com/projects/b289809c-5802-4b1a-984a-48e352fb87ac";
          }
          {
            name = "Tailwind";
            tags = [ "css" ];
            url = "https://tailwindcss.com/";
          }
          {
            name = "IRD";
            tags = [ "IRD" ];
            url = "https://eservices.ird.gov.lk/Dashboard/ShowDashboard";
          }
        ];
      }
    ];
  };
}
