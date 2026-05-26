defmodule WatchClub.Shared.Fs do
  @moduledoc """
  Timeout-bounded wrappers around `File.*` calls.

  Any filesystem syscall can block uninterruptibly when the underlying mount
  goes unresponsive (stale NFS handle, sleeping external drive, cloud-sync
  placeholder waiting on the network, FUSE daemon stalled, etc.). The BEAM
  cannot interrupt a process parked in such a syscall: `Process.exit/2` marks
  it for death but the dirty-I/O scheduler thread it is riding stays parked
  until the kernel returns — which for a stale handle is "never".

  Each call here runs inside an isolated task spawned via
  `Task.Supervisor.async_nolink/2` under `__MODULE__.TaskSupervisor` (started
  by `WatchClub.Application`). If the call doesn't return within the timeout,
  `Task.shutdown/2` reaps the task pid and we surface `{:error, :timeout}`.
  The underlying dirty thread remains parked — that's a BEAM-level
  constraint we can't work around in code. Callers should treat `:timeout`
  as a per-path failure and decide whether to skip or bail.
  """

  @default_timeout :timer.seconds(3)

  @type error :: :timeout | {:crash, term()} | File.posix() | atom()

  @doc """
  Like `File.lstat/2`, but returns `{:error, :timeout}` if the syscall does
  not complete within the configured timeout.

  Accepts the same options as `File.lstat/2` plus a `:timeout` (milliseconds,
  default #{@default_timeout}).
  """
  @spec lstat(Path.t(), keyword()) :: {:ok, File.Stat.t()} | {:error, error()}
  def lstat(path, opts \\ []) do
    {timeout, file_opts} = Keyword.pop(opts, :timeout, @default_timeout)
    with_timeout(timeout, fn -> File.lstat(path, file_opts) end)
  end

  @doc """
  Like `File.ls/1`, but returns `{:error, :timeout}` if the syscall does
  not complete within the configured timeout.

  Accepts a `:timeout` option (milliseconds, default #{@default_timeout}).
  """
  @spec ls(Path.t(), keyword()) :: {:ok, [binary()]} | {:error, error()}
  def ls(path, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    with_timeout(timeout, fn -> File.ls(path) end)
  end

  defp with_timeout(timeout, fun) do
    task = Task.Supervisor.async_nolink(__MODULE__.TaskSupervisor, fun)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      nil -> {:error, :timeout}
      {:exit, reason} -> {:error, {:crash, reason}}
    end
  end
end
