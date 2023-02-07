{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs.inputs.nixpkgs.follows = "nixpkgs";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        root-env-var = "$PG_ROOT";
        dev-db = "dev";
        test-db = "test";
        db-path = "${root-env-var}/PG15_DATA";
        db-port = "5432";
      in {
        devShell = with pkgs;
          mkShell {
            buildInputs = [
              postgresql_15
              (writeShellScriptBin "check-env" ''
                if [ -z "${root-env-var}" ]; then
                  echo '${root-env-var}' is not set, can not init database;
                  exit 1;
                else
                  echo PGHOST=${db-path}
                  echo PGPORT=${db-port}
                fi
              '')

              (writeShellScriptBin "start-database" ''
                set -e
                check-env
                if [[ ! -d "${db-path}" ]]; then
                  set -e
                  initdb -D "${db-path}"
                  pg_ctl -D ${db-path} -o "-k ${db-path}" -o "-p ${db-port}" -l ${db-path}/database.log start
                  for DBNAME in {${dev-db},${test-db},$USER}; do
                    createdb -h ${db-path} -p ${db-port}  $DBNAME && echo Created db $DBNAME
                  done
                  psql --host ${db-path} --port ${db-port} \
                    -tc "ALTER USER $USER WITH SUPERUSER" \
                    && echo Changed user $USER to superuser
                elif [[ ! -f "${db-path}/.s.PGSQL.${db-port}.lock" ]]; then
                  pg_ctl -D ${db-path} -o "-k ${db-path}" -o "-p ${db-port}" -l ${db-path}/database.log start
                else
                  echo Postgres is already running for this project
                fi
              '')
              (writeShellScriptBin "stop-database" ''
                set -e
                check-env
                pg_ctl -D ${db-path} stop || rm "${db-path}/.s.PGSQL.${db-port}.lock"
              '')
              (writeShellScriptBin "psql-wrapped" ''
                set -e
                check-env
                if [[ -z $PGDATABASE ]]; then export PGDATABASE="${dev-db}"; fi
                PGHOST="${db-path}" PGPORT="${db-port}" psql "$@"
              '')
            ];
          };
        PGHOST = "${db-path}";
        PGPORT = "${db-port}";
      });
}
