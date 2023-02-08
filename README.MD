# A flake to create an environment-local postgreSQL database

This flake provides a set of commands to set up and work with a postgres
database inside a specific folder, without any need to install/configure
any containers.

## How to use

When launching the dev-shell

    nix develop github:hermann-p/nix-postgres-dev-db

there will be three commands available. All commands need an environment
variable `$PG_ROOT` set, else they will fail saying so.

- `start-database` launches a postgres server keeping all data in `$PG_ROOT`. If
  there is no postgreSQL-folder at that location, everything will be set up and
  three databases will be created, named `dev`, `test` and whatever `$USER` is
  set to. Note it will try to bind to port 5432 and fail if that port is not
  available.
- `stop-database` stops the postgres server at `$PG_ROOT`. If it fails it tries
  to remove stale lock files from there.
- `psql-wrapped` is just `psql` set up with the correct port and host parameters
  to access the local postgres server.

## Use it in your dev shell

To use the convenience setup for your own dev env, you will need to import the
three commands seperately. Don't forget to provide your desired postgres version in `buildInputs`!  
Something like the following flake.nix will work:

```nix
{
  inputs = {
    utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs.inputs.nixpkgs.follows = "nixpkgs";
    devDB.url = "github:hermann-p/nix-postgres-dev-db";
    devDB.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, nixpkgs, utils, devDB }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        db = devDB.outputs.packages.${system};
      in {
        devShell = with pkgs;
          mkShell {
            buildInputs = [
              postgresql_15
              db.start-database
              db.stop-database
              db.psql-wrapped
            ];
            shellHook = ''
              export PG_ROOT=$(git rev-parse --show-toplevel)
            '';
          };

      });
}
```
