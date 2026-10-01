# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 DBVisor

defmodule SQLBench.InformationSchema.Column do
  use Ecto.Schema

  @primary_key false
  schema "columns" do
    field :table_catalog, :string
    field :table_schema, :string
    field :table_name, :string
    field :column_name, :string
    field :ordinal_position, :integer
    field :column_default, :string
    field :is_nullable, :string
    field :data_type, :string
    field :udt_name, :string
    field :udt_schema, :string
    field :udt_catalog, :string
    field :character_maximum_length, :integer
    field :character_octet_length, :integer
    field :character_set_catalog, :string
    field :character_set_schema, :string
    field :character_set_name, :string
    field :collation_catalog, :string
    field :collation_schema, :string
    field :collation_name, :string
    field :scope_catalog, :string
    field :scope_schema, :string
    field :scope_name, :string
    field :maximum_cardinality, :integer
    field :numeric_precision, :integer
    field :numeric_precision_radix, :integer
    field :numeric_scale, :integer
    field :datetime_precision, :integer
    field :interval_type, :string
    field :interval_precision, :integer
    field :dtd_identifier, :integer
    field :is_self_referencing, :string
    field :is_identity, :string
    field :identity_generation, :string
    field :identity_start, :string
    field :identity_increment, :string
    field :identity_maximum, :string
    field :identity_minimum, :string
    field :identity_cycle, :string
    field :is_generated, :string
    field :generation_expression, :string
    field :domain_catalog, :string
    field :domain_schema, :string
    field :domain_name, :string
    field :is_updatable, :string
  end

  @doc false
  def query do
    __MODULE__
    |> Ecto.Queryable.to_query()
    |> Map.put(:prefix, "information_schema")
  end
end

defmodule SQLBench do
  @moduledoc """
  Documentation for `SQLBench`.
  """
  use Ecto.Repo, otp_app: :sql, adapter: Ecto.Adapters.Postgres
  use SQL
  import Ecto.Query


  @all_targets [:statement, :empty, :transaction, :savepoint, :cursor]
  # @all_targets [:empty]
  @sql_queries %{
      statement: "SELECT * FROM information_schema.columns",
      empty: "BEGIN; COMMIT; -- Empty transaction",
      transaction: "BEGIN; SELECT 1; COMMIT;",
      savepoint: "BEGIN; SAVEPOINT sp1; SELECT 1; RELEASE SAVEPOINT sp1; COMMIT;",
      cursor: "DECLARE cursor... FETCH 100 FROM generate_series(1, 10000)"
    }

  def sql(type \\ :transaction)
  # def sql(:sum) do
  #   Enum.to_list(~SQL"SELECT sum(x)::int8 FROM generate_series(1, 1000000) AS x")
  # end
  # def sql(:mix) do
  #   Enum.to_list(~SQL[SELECT {{1337}}::int as int, {{"wat"}}::varchar as string, {{DateTime.utc_now()}}::timestamp as timestamp, {{nil}}::int as null, {{false}}::boolean as boolean, {{<<"awesome">>}}::bytea as bytea, {{%{"some" => "json"}}}::json as json])
  # end
  def sql(:statement) do
    try do
      # Enum.to_list(~SQL"SELECT 1")
      # Enum.to_list(SQL.map(~SQL"SELECT * FROM information_schema.columns", &struct!(SQLBench.InformationSchema.Column, &1)))
      Enum.to_list(~SQL"SELECT * FROM information_schema.columns")
      :ok
    rescue RuntimeError ->
      :error
    end
  end
  def sql(:empty) do
    try do
    SQL.transaction do
      :ok
    end
    |> elem(0)
    rescue RuntimeError ->
      :error
    end
  end
  def sql(:transaction) do
    try do
    SQL.transaction do
      Enum.to_list(~SQL"SELECT 1")
    end
    |> elem(0)
    rescue RuntimeError ->
      :error
    end
  end
  def sql(:savepoint) do
    try do
    SQL.transaction do
      SQL.transaction do
        Enum.to_list(~SQL"SELECT 1")
      end
    end
    |> elem(0)
    rescue RuntimeError ->
      :error
    end
  end
  def sql(:cursor) do
    try do
    SQL.transaction do
      ~SQL"SELECT g::int, repeat(md5(g::text), 4) FROM generate_series(1, 10000) AS g"
      |> SQL.stream(max_rows: 100)
      |> Stream.run()
    end
    |> elem(0)
    rescue RuntimeError ->
      :error
    end
  end

  def ecto(type \\ :transaction)
  def ecto(:sum) do
      SQLBench.query("SELECT sum(x)::int8 FROM generate_series(1, 1000000) AS x", [])
  end

  def ecto(:mix) do
    SQLBench.query("select $1::int as int, $2::varchar as string, $3:timestamp as timestamp, $4::int as null, $5::boolean as boolean, $6::bytea as bytea, $7::json as json", [1337, "wat", DateTime.utc_now(), nil, false, "awesome", %{"some" => "json"}])
  end

  def ecto(:statement) do
    try do
      # SQLBench.all(SQLBench.InformationSchema.Column.query())
      # case SQLBench.query("SELECT 1", []) do
      # case SQLBench.query("SELECT * FROM information_schema.sql_sizing", []) do
      case SQLBench.query("SELECT * FROM information_schema.columns", []) do
        {:ok, %{rows: rows, columns: columns}} ->
          Enum.map(rows, &Enum.zip(columns, &1))
          :ok
        _result ->
          :error
      end
    rescue _ ->
      :error
    end
  end
  def ecto(:empty) do
    try do
      elem(SQLBench.transaction(fn -> :ok end), 0)
    rescue _ ->
      :error
    end
  end
  def ecto(:transaction) do
    try do
      elem(SQLBench.transaction(fn ->
        case SQLBench.query("SELECT 1", []) do
        # case SQLBench.query("SELECT * FROM information_schema.columns", []) do
          {:ok, %{rows: rows, columns: columns}} -> Enum.map(rows, &Enum.zip(columns, &1))
          result ->
            result
        end
      end), 0)
    rescue _ ->
      :error
    end
  end
  def ecto(:savepoint) do
    try do
    elem(SQLBench.transaction(fn ->
      SQLBench.transaction(fn ->
        SQLBench.query("SELECT 1", [])
      end)
    end), 0)
    rescue _ ->
      :error
    end
  end
  def ecto(:cursor) do
    try do
      elem(SQLBench.transaction(fn ->
        from(row in fragment("SELECT g, repeat(md5(g::text), 4) FROM generate_series(1, ?) AS g", 10000), select: [fragment("?::int", row.g), fragment("?::text", row.repeat)])
        |> SQLBench.stream(max_rows: 100)
        |> Stream.run()
      end), 0)
    rescue _ ->
      :error
    end
  end

  defp collect(_ref, 0, ok, err), do: {ok, err}
  defp collect(ref, n, acc1, acc3) do
    receive do
      {^ref, :res, ok, erorrs} -> collect(ref, n-1, ok++acc1, erorrs++acc3)
    end
  end

  defp __run__(fun, args, n, duration) do
    ref = make_ref()
    parent = self()
    pings = for _ <- :lists.seq(1, n), do: start(ref, parent, fun, args)
    :erlang.yield()
    for pid <- pings, do: send(pid, {ref, :go})
    receive do
    after duration ->
      for pid <- pings, do: send(pid, {ref, :stop})
      {ok, err} = collect(ref, n, [], [])
      stats(ok, err)
    end
  end

  defp start(ref, parent, fun, args) do
    peer = spawn(fn -> each_loop(ref, fun, args) end)
    spawn(fn -> ping_loop(ref, parent, peer, [], []) end)
  end

  defp ping_loop(ref, parent, peer,  oks, errors) do
    receive do
      {^ref, :go} -> ping_cycle(ref, parent, peer, oks, errors)
      {^ref, :stop} ->
        send peer, {ref, :stop}
        send parent, {ref, :res, :lists.reverse(oks), :lists.reverse(errors)}
    end
  end

  defp ping_cycle(ref, parent, peer, oks, errors) do
    t0 = :erlang.monotonic_time(:microsecond)
    send peer, {ref, :ping, self()}
    receive do
      {^ref, :ok} -> ping_cycle(ref, parent, peer, [:erlang.monotonic_time(:microsecond) - t0|oks], errors)
      {^ref, :error} -> ping_cycle(ref, parent, peer, oks, [:erlang.monotonic_time(:microsecond) - t0|errors])
      {^ref, :stop} ->
        send peer, {ref, :stop}
        send parent, {ref, :res, :lists.reverse(oks), :lists.reverse(errors)}
    end
  end

  defp each_loop(ref, type, fun) do
    receive do
      {^ref, :ping, from} ->
        case {type, fun} do
          {:sql, fun} -> send from, {ref, sql(fun)}
          {:ecto, fun} -> send from, {ref, ecto(fun)}
        end
        each_loop(ref, type, fun)
      {^ref, :stop} -> :ok
    end
  end

 defp stats(oks, errors) do
   ok_c = length(oks)
   er_c = length(errors)
    %{
        n: ok_c + er_c,
        ok: calculate(oks, ok_c),
        error: calculate(errors, er_c),
    }
  end

  defp calculate([], n), do: %{n: n, p50: 0, p95: 0, p99: 0, max: 0}
  defp calculate(samples, n) do
    sorted = :lists.sort(samples)
    at = fn p -> :lists.nth(max(1, div((n * p), 100)), sorted) end
    %{
      n: n,
      p50: at.(50),
      p95: at.(95),
      p99: at.(99),
      max: :lists.last(sorted),
    }
  end

  defp u(us) when us >= 1000, do: :io_lib.format(~c"~.1fms", [us / 1000]) |> IO.iodata_to_binary()
  defp u(us), do: "#{us}us"

  defp build_comprehensive_comparison(name1, r1, name2, r2) do
    p50_1 = r1.ok.p50
    p50_2 = r2.ok.p50
    err1 = r1.error.n
    err2 = r2.error.n
    ok1 = r1.ok.n
    ok2 = r2.ok.n

    {faster_name, _slower_name, latency_win?, ratio} =
      cond do
        p50_1 == 0 or p50_2 == 0 -> {nil, nil, false, 1.0}
        p50_1 == p50_2 -> {nil, nil, false, 1.0}
        p50_1 < p50_2 -> {name1, name2, true, Float.round(p50_2 / max(1, p50_1), 1)}
        p50_1 > p50_2 -> {name2, name1, true, Float.round(p50_1 / max(1, p50_2), 1)}
      end

    {more_ok_name, ok_diff_str, yield_win?} =
      cond do
        ok1 == ok2 -> {nil, "", false}
        true ->
          diff = abs(ok1 - ok2)
          formatted_diff = if diff >= 1000, do: "#{Float.round(diff / 1000, 1)}k", else: to_string(diff)
          winner = if ok1 > ok2, do: name1, else: name2
          {winner, "+#{formatted_diff} OK", true}
      end

    cond do
      latency_win? and yield_win? and faster_name == more_ok_name ->
        has_errors? = if faster_name == name1, do: err1 > 0, else: err2 > 0
        if has_errors? do
          "#{faster_name} #{ratio}x faster, #{ok_diff_str} (fast-failing works)"
        else
          "#{faster_name} #{ratio}x faster, #{ok_diff_str}"
        end

      latency_win? and yield_win? and faster_name != more_ok_name ->
        "#{faster_name} #{ratio}x faster | #{more_ok_name} #{ok_diff_str}"

      latency_win? ->
        "#{faster_name} #{ratio}x faster"

      true ->
        "Tie"
    end
  end


  def run_all(sched \\ :erlang.system_info(:schedulers)) do
    IO.puts("==========================================================================")
    IO.puts(" Starting SQLBench Suites (Schedulers: #{sched})")
    IO.puts("==========================================================================")
    concurrencies = [1, sched, 2 * sched, 5 * sched, 10 * sched, 50 * sched]
    sql = for target <- @all_targets, do: {target, (for n <- concurrencies, do: {n, __run__(:sql, target, n, 2000)})}
    SQLBench.start_link()
    ecto = for target <- @all_targets, do: {target, (for n <- concurrencies, do: {n, __run__(:ecto, target, n, 2000)})}
    print(sql, ecto)
    IO.puts("\n==========================================================================")
    IO.puts(" All Benchmark Suites Completed.")
    IO.puts("==========================================================================")
  end

  defp print([], []), do: :ok
  defp print([{target, right}|r], [{target, left}|l]) do
    IO.puts("\n### Performance Comparison: sql vs ecto")
    IO.puts("\n🔍 Target SQL: `#{Map.get(@sql_queries, target)}`")
    IO.puts("| Concurrency | Impl | Total Req | OK Req | p50 | p95 | p99 | Max | Errors (p50 / p99) | Comparison |")
    IO.puts("|---|---|---|---|---|---|---|---|---|---|")
    print(target, right, left)
    print(r, l)
  end
  def print(target, [], []), do: target
  def print(target, [{c, r}|right], [{c, l}|left]) do
    comparison_str = build_comprehensive_comparison("sql", r, "ecto", l)
    %{n: n, ok: ok, error: err} = r
    err_str = if err.n > 0 do
      "#{err.n} (#{u(err.p50)} / #{u(err.p99)})"
    else
      "0"
    end
    IO.puts("| #{String.pad_trailing("C = #{c}", 11)} | #{String.pad_trailing("sql", 4)} | #{String.pad_trailing(to_string(n), 9)} | #{String.pad_trailing(to_string(ok.n), 6)} | #{String.pad_trailing(u(ok.p50), 7)} | #{String.pad_trailing(u(ok.p95), 7)} | #{String.pad_trailing(u(ok.p99), 7)} | #{String.pad_trailing(u(ok.max), 7)} | #{String.pad_trailing(err_str, 18)} | #{String.pad_trailing(comparison_str, 38)} |")
    %{n: n, ok: ok, error: err} = l
    err_str = if err.n > 0 do
      "#{err.n} (#{u(err.p50)} / #{u(err.p99)})"
    else
      "0"
    end
    IO.puts("| #{String.pad_trailing("C = #{c}", 11)} | #{String.pad_trailing("ecto", 4)} | #{String.pad_trailing(to_string(n), 9)} | #{String.pad_trailing(to_string(ok.n), 6)} | #{String.pad_trailing(u(ok.p50), 7)} | #{String.pad_trailing(u(ok.p95), 7)} | #{String.pad_trailing(u(ok.p99), 7)} | #{String.pad_trailing(u(ok.max), 7)} | #{String.pad_trailing(err_str, 18)} | #{String.pad_trailing("", 38)} |")
    IO.puts("|---|---|---|---|---|---|---|---|---|---|")
    print(target, right, left)
  end
end
