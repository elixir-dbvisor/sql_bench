# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 DBVisor

import Config

size = 10

config :sql,
env: config_env(),
pools: [
  default: [
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "sql_dev",
    adapter: SQL.Adapters.Postgres,
    size: size,
    ssl: false
  ]
]

config :sql, ecto_repos: [SQLBench]
config :sql, SQLBench, log: false, username: "postgres", password: "postgres", hostname: "localhost", database: "sql_dev", pool_size: size, ssl: false
