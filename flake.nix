{
  description = "gliver flake flake";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
    gliver = {
      url = "git+https://codeberg.org/ebeem/gliver.git?ref=master";
      flake = false;
    };
  };

  outputs =
    inputs:
    let
      buildInputs = (pkgs: with pkgs; [
        guile
        river
        wayland
        wayland-protocols
        libxkbcommon
        librsvg
        gnumake
        guile-cairo
        pango
        pkgconf
        pkg-config
      ]);
    in
    {
      devShells = builtins.mapAttrs
        (system: pkgs: {
          default = pkgs.mkShell {
            buildInputs = (buildInputs pkgs);
          };
        })
        inputs.nixpkgs.legacyPackages;
      packages = builtins.mapAttrs
        (system: pkgs: {
          gliver-unwrapped = pkgs.stdenv.mkDerivation (finalAttrs: {
            pname = "gliver";
            version = "master";
            src = inputs.gliver;
            propagatedBuildInputs = with pkgs; [
              guile-cairo
              river
            ];
            nativeBuildInputs = [ pkgs.makeWrapper ] ++ buildInputs pkgs;
            buildInputs = buildInputs pkgs;
            makeFlags = [ "PREFIX=${placeholder "out"}" "GUILE_AUTO_COMPILE=0" ];
            preInstall = /*bash*/''
              patchShebangs bin/gliver
              patchShebangs bin/gliver-repl
            '';
            fixupPhase =
              let
                libs = [ "$out" ];
                wrap = (program:
                  /*bash*/
                  ''
                    wrapProgram $out/${program} \
                      --set GUILE_AUTO_COMPILE 0 \
                      --prefix GUILE_LOAD_PATH : ${(pkgs.lib.makeSearchPath pkgs.guile.siteDir libs) + ":${pkgs.guile-cairo}/share/guile/site"} \
                      --prefix GUILE_LOAD_COMPILED_PATH : ${pkgs.lib.makeSearchPath pkgs.guile.siteCcacheDir libs}'');
              in
              ''
                ${wrap "bin/gliver"}
                ${wrap "bin/gliver-repl"}'';
            doCheck = false;
            meta = with pkgs.lib; {
              mainProgram = "gliver";
              description = "guile scheme window manager for wayland";
              homepage = "https://codeberg.org/ebeem/gliver";
              license = licenses.gpl3Plus;
              maintainers = [ ];
              platforms = platforms.unix;
            };
          });
          gliver-wrapped = pkgs.writeShellScriptBin "gliver" ''
            ${pkgs.lib.getExe pkgs.river} -c ${pkgs.lib.getExe inputs.self.packages.${system}.gliver-unwrapped}
          '';
          gliver-session = pkgs.runCommand "gliver-session"
            {
              passthru.providedSessions = [ "gliver" ];
              nativeBuildInputs = [ pkgs.makeWrapper ];
            } ''
            mkdir -p $out/share/wayland-sessions
            cat > $out/share/wayland-sessions/gliver.desktop <<EOF
            [Desktop Entry]
            Name=gliver
            Comment=A River Based Emacs-inspired Wayland window manager
            Exec=${pkgs.lib.getExe' inputs.self.packages.${system}.gliver-unwrapped "gliver"}
            Type=Application
            Keywords=wayland;compositor;window manager;river;stumpwm;emacs;
            EOF
          '';
          gliver = with inputs.self.packages.${system}; pkgs.symlinkJoin {
            name = "gliver";
            paths = [
              gliver-session
              gliver-wrapped
            ];
            postBuild = ''
              cp "${gliver-unwrapped}/bin/gliver-repl" $out/bin/
            '';
          };
          default = inputs.self.packages.${system}.gliver;
        })
        inputs.nixpkgs.legacyPackages;
    };
}
