{ python3Packages }:

python3Packages.buildPythonApplication {
  pname = "lsy";
  version = "0.1.0";
  pyproject = true;
  src = ./.;

  build-system = [ python3Packages.setuptools ];

  checkPhase = ''
    runHook preCheck
    python -m unittest discover -s tests -v
    runHook postCheck
  '';

  pythonImportsCheck = [ "lsy.cli" ];
  meta.mainProgram = "lsy";
}
