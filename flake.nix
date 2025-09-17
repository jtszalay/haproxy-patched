{
  description = "Patched haproxy for OCI layer";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        final = pkgs;
        haproxy_patched = final.runCommand "haproxy-patched-dir"
          {
            closureInfo = final.closureInfo {
              rootPaths = [
                (final.haproxy.overrideAttrs (attrs: {
                  patches = (if (attrs ? "patches") then attrs.patches else [ ]) ++ [
                    ./haproxy_race.patch
                  ];
                }))
              ];
            };
          }
          ''
            mkdir -p layer

            # Copy entire closure preserving nix store paths
            haproxy_path=""
            while read path; do
              mkdir -p "layer/$(dirname "$path")"
              cp -rL "$path" "layer/$path"
              if [[ -f "$path/bin/haproxy" ]]; then
                haproxy_path="$path/bin/haproxy"
              fi
            done < $closureInfo/store-paths

            # Create standard /bin/haproxy symlink
            mkdir -p layer/bin
            ln -s "$haproxy_path" layer/bin/haproxy

            mkdir -p $out
            tar -czf $out/haproxy-layer.tar.gz -C layer .
          '';
      in
      {
        packages = {
          default = haproxy_patched;
          haproxy-layer = haproxy_patched;
        };

        apps = {
          default = {
            type = "app";
            program = "${haproxy_patched}/haproxy-layer.tar.gz";
          };
        };
      });
}
