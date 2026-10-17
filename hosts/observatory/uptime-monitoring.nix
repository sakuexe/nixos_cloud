{ userSettings, ... }:

let
  domain = "status.taurudesign.com";
in
{
  # listens on 127.0.0.1:3001 by default, only reachable through traefik
  services.uptime-kuma.enable = true;

  services.traefik = {
    enable = true;

    staticConfigOptions = {
      entryPoints.web = {
        address = ":80";
        http.redirections.entryPoint = {
          to = "websecure";
          scheme = "https";
        };
      };

      entryPoints.websecure.address = ":443";

      certificatesResolvers.letsencrypt.acme = {
        email = userSettings.email;
        storage = "/var/lib/traefik/acme.json";
        httpChallenge.entryPoint = "web";
      };
    };

    dynamicConfigOptions.http = {
      routers.uptime-kuma = {
        rule = "Host(`${domain}`)";
        entryPoints = [ "websecure" ];
        service = "uptime-kuma";
        tls.certResolver = "letsencrypt";
      };

      services.uptime-kuma.loadBalancer.servers = [
        { url = "http://127.0.0.1:3001"; }
      ];
    };
  };
}
