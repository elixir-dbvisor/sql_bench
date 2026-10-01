# SQLBench

Compile a release and start it in one terminal:

```bash
MIX_ENV=prod mix release
_build/prod/rel/sql_bench/bin/sql_bench start
```

In another terminal run the benchmark suite:

```bash
_build/prod/rel/sql_bench/bin/sql_bench rpc "SQLBench.run_all()
```
