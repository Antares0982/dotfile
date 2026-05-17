input: {
  # device description
  mac = input.mac or false;
  pc = input.pc or false;
  rpi = input.rpi or false;
  server = input.server or { };
  wsl = input.wsl or false;
  # settings
  system = input.system;
  useProxy = input.useProxy or false;
  withHm = input.withHm or false;
}
