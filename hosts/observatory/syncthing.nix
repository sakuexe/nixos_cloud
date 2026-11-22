{ ... }:

# gui: ssh -p 2001 -N -L 8384:127.0.0.1:8384 <user>@<host>, then http://localhost:8384
{
  services.syncthing = {
    enable = true;
    guiAddress = "127.0.0.1:8384";
    overrideDevices = true;
    overrideFolders = true;

    settings = {
      # no lan on a vps, so skip local discovery (and port 21027)
      options.localAnnounceEnabled = false;

      devices = {
        pc.id = "VYXRJVJ-XHQMAIY-TKNGDEZ-35VAEDS-RKITW25-Z4B4PDW-LGQ3TB4-GYJEVQ4";
        deck.id = "DECK-DEVICE-ID";
      };

      folders."unleashed-saves" = {
        path = "/var/lib/syncthing/unleashed-saves";
        devices = [
          "pc"
          "deck"
        ];
        versioning = {
          type = "simple";
          params.keep = "10";
        };
      };
    };
  };

  # openDefaultPorts would also open udp 21027 (lan discovery)
  networking.firewall = {
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 22000 ];
  };
}
