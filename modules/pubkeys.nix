{ lib, ... }:

{
  # readPubKeys :: path -> [ string ]
  readAll = dir:
    builtins.map
      (name: builtins.readFile (dir + "/${name}"))
      (builtins.filter
        (name: lib.hasSuffix ".pub" name)
        (builtins.attrNames (builtins.readDir dir)));
}
