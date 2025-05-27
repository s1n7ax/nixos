{ ... }:
{
  programs.pet = {
    enable = true;
    snippets = [
      {
        description = "Stop all docker containers";
        command = "docker container stop $(docker container ls -aq)";
        tag = [ "docker" ];
      }
      {
        description = "Remove all docker containers and volumes";
        command = "docker rm -vf $(docker ps -aq)";
        tag = [ "docker" ];
      }
      {
        description = "Remove all docker images";
        command = "docker rmi -f $(docker images -aq)";
        tag = [ "docker" ];
      }
      {
        description = "Copy file with rsync";
        command = "rsync --verbose --archive --append  <source> <destination>";
        tag = [ "docker" ];
      }
      {
        description = "Move file with rsync";
        command = "rsync --verbose --archive --append --remove-source-files  <source> <destination>";
        tag = [ "docker" ];
      }
    ];
  };
}
