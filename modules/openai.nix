{ lib, ... }:
{
  options.antares.openai.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Allow this host's OpenAI services and their dedicated integrations.";
  };
}
