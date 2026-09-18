{ lib
, stdenv
, fetchurl
, makeWrapper
, gnutar
, gzip
, openssl
, libcap
, libz
, bubblewrap
, binName ? "codex"
}:

let
  version = "0.155.1";

  platformMap = {
    "aarch64-darwin" = "aarch64-apple-darwin";
    "x86_64-darwin" = "x86_64-apple-darwin";
    "x86_64-linux" = "x86_64-unknown-linux-musl";
    "aarch64-linux" = "aarch64-unknown-linux-musl";
  };

  platform = platformMap.${stdenv.hostPlatform.system} or
    (throw "Codex is not supported on ${stdenv.hostPlatform.system}. Supported: aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux");

  nativeHashes = {
    "aarch64-apple-darwin" = "0s1pgah4gbwf2zskv0x690l0xk64pg893lbbv7wj696f1m3m2njy";
    "x86_64-apple-darwin" = "14bpq8jcp9jcfszii48gz9q53zji8jk0xvr8zgdni1cby85ss8pz";
    "x86_64-unknown-linux-musl" = "05cibl5lg0d2id4pc8nc1nn004z39lskk85i0xz79gy3xcnqpvx0";
    "aarch64-unknown-linux-musl" = "1mx2ykqylrp376hvfbd442lk4pbh2c39v4pk0kp553b8plpydiyn";
  };

  # codex >= 0.143 spawns a separate `codex-code-mode-host` binary (found
  # next to the running executable) when "code mode" is enabled. Shipped as its
  # own release asset, so the native build must fetch and install it too.
  codeModeHostHashes = {
    "aarch64-apple-darwin" = "12jh3c3x89f685q199vj35ylfavsgzmpr18614xrcw5xxq4735g8";
    "x86_64-apple-darwin" = "0sh6d1apzw0dx4ng6v44qknz8bsrs7fy4w3wl0zw2hlqldvj67ad";
    "x86_64-unknown-linux-musl" = "0bbv0qkksdw7f0b8z4x3d9dny4xm3wvisdgbmhcfhnzm79s87l4z";
    "aarch64-unknown-linux-musl" = "10qnhsvfi79isws6gqlp79fdq6zdfr2qzh6kfhh6rsaadpbjwvsi";
  };

  nativeBinary = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-${platform}.tar.gz";
    sha256 = nativeHashes.${platform};
  };

  codeModeHost = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-code-mode-host-${platform}.tar.gz";
    sha256 = codeModeHostHashes.${platform};
  };

  linuxRuntimePath = lib.makeBinPath (lib.optionals stdenv.isLinux [ bubblewrap ]);
in
stdenv.mkDerivation {
  pname = "codex";
  inherit version;

  dontUnpack = true;
  dontPatchELF = true;
  dontStrip = true;

  nativeBuildInputs = [ gnutar gzip makeWrapper ];
  buildInputs = lib.optionals stdenv.isLinux [ openssl libcap libz ];

  buildPhase = ''
    runHook preBuild
    mkdir -p build
    tar -xzf ${nativeBinary} -C build
    mv build/codex-${platform} build/codex
    chmod u+w,+x build/codex

    tar -xzf ${codeModeHost} -C build
    mv build/codex-code-mode-host-${platform} build/codex-code-mode-host
    chmod u+w,+x build/codex-code-mode-host

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin

    cp build/codex $out/bin/codex-raw
    chmod +x $out/bin/codex-raw
    cp build/codex-code-mode-host $out/bin/codex-code-mode-host
    chmod +x $out/bin/codex-code-mode-host
    makeWrapper "$out/bin/codex-raw" "$out/bin/${binName}" \
      --run 'export CODEX_EXECUTABLE_PATH="$HOME/.local/bin/${binName}"' \
      --set DISABLE_AUTOUPDATER 1 \
      ${lib.optionalString stdenv.isLinux ''--prefix PATH : "${linuxRuntimePath}"''}
    runHook postInstall
  '';

  meta = with lib; {
    description = "OpenAI Codex CLI (Native Binary) - AI coding assistant in your terminal";
    homepage = "https://github.com/openai/codex";
    license = licenses.asl20;
    platforms = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
    mainProgram = binName;
  };
}
