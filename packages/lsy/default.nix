{ lib, python3Packages, tmux }:

python3Packages.buildPythonApplication {
  pname = "lsy";
  version = "0.1.0";
  pyproject = true;
  src = ./.;

  build-system = [ python3Packages.setuptools ];

  # A private tmux server owns VM consoles, including detached sessions.
  makeWrapperArgs = [ "--prefix PATH : ${lib.makeBinPath [ tmux ]}" ];

  checkPhase = ''
    runHook preCheck
    python -m unittest discover -s tests -v
    runHook postCheck
  '';

  pythonImportsCheck = [ "lsy.cli" ];
  meta = {
    mainProgram = "lsy";
    platforms = lib.platforms.linux;
  };
}
