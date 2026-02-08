{ hostname, ... }:
{
  programs.bash.enable = true;
  programs.bash.shellAliases = {
    la = "ls -laFh --color=auto";  # show all
    ll = "ls -lhpg --color=auto";  # long format, hide hidden
    l = "ls -F --color=auto";      # list short form

    c = "clear";
    vi = "nvim";
    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";


    rebuild = ''
      sudo nixos-rebuild switch \
      --flake 'github:sakuexe/nixos_cloud#${hostname}' --refresh
    '';
    dockerref = "docker compose down && docker compose up -d";
  };
}
