import { defineRailway, project, service, volume } from "railway/iac";

// Railway does not run docker-compose.yml. This file is the same three
// processes: the site, the Go API, and the DuckDB server.
// Connect the GitHub repository that contains this code, then
// `npm install railway` and `railway config apply`.
// Do not put secrets in this file. Set them in the Railway dashboard.
export default defineRailway(() => {
  const data = volume("ohbaby-data", {
    sizeMB: 1024,
  });

  const duckdb = service("duckdb", {
    env: {
      RAILWAY_DOCKERFILE_PATH: "deploy/railway/Dockerfile.duckdb",
      HOME: "/workspace",
      DUCKDB_PATH: "/workspace/ohbaby.duckdb",
    },
    volumeMounts: {
      "/workspace": data,
    },
  });

  const web = service("web", {
    healthcheck: "/healthz",
    healthcheckTimeout: 300,
    env: {
      RAILWAY_DOCKERFILE_PATH: "deploy/railway/Dockerfile.web",
      API_UPSTREAM: "api.railway.internal:47220",
    },
  });

  const api = service("api", {
    healthcheck: "/healthz",
    healthcheckTimeout: 300,
    env: {
      RAILWAY_DOCKERFILE_PATH: "Dockerfile",
      OHBABY_ADDR: ":47220",
      OHBABY_DB: "quack:duckdb.railway.internal:9494",
    },
  });

  return project("oh-baby-baby", {
    resources: [data, duckdb, api, web],
  });
});
