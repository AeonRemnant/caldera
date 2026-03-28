_:

{
  perSystem =
    { ... }:
    {
      pre-commit.settings.hooks = {
        treefmt.enable = true;
        nil.enable = true;
        typos.enable = true;
        check-merge-conflicts.enable = true;
      };
    };
}
