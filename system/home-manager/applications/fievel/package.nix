{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "fievel";
  version = "2.0.0";

  src = fetchFromGitHub {
    owner = "MontyTheSoftwareEngineer";
    repo = "fievel";
    tag = finalAttrs.version;
    hash = "sha256-paQprw6/v3IK+1xHRkgoRQ+QBNAmG5fVtHsOVJzMSCw=";
  };

  cargoHash = "sha256-maNbT9tKiDEem1OF/PORCmKW3jkPclgvlYpzaWak1KE=";

  meta = {
    description = "Replace mouse movements with the keyboard";
    homepage = "https://github.com/MontyTheSoftwareEngineer/fievel";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "fievel";
  };
})
