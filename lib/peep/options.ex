defmodule Peep.Options do
  @statsd_opts_schema [
    flush_interval_ms: [
      type: :non_neg_integer,
      default: 5000,
      doc: "Time interval between StatsD metric emissions."
    ],
    host: [
      type: {:custom, __MODULE__, :host, []},
      default: {127, 0, 0, 1},
      doc: "Hostname or IP address of the StatsD server."
    ],
    port: [
      type: :non_neg_integer,
      default: 8125,
      doc: "Port of the StatsD server."
    ],
    socket_path: [
      type: {:custom, __MODULE__, :socket_path, []},
      doc: "Path to the Unix Domain Socket used for publishing instead of the hostname and port."
    ],
    formatter: [
      type: {:custom, __MODULE__, :formatter, []},
      default: :standard,
      doc:
        "Determines the format of the published metrics. Can be either `:standard` or `:datadog`."
    ],
    mtu: [
      type: :non_neg_integer,
      default: 1472,
      doc:
        "Determine max size of statsd packets. For UDP, 1472 is a good choice. For UDS, 8192 is probably better."
    ]
  ]

  @schema [
    name: [
      type: :atom,
      required: true,
      doc: "A name for the Peep worker process"
    ],
    metrics: [
      type: {:list, :any},
      required: true,
      doc: "A list of `Telemetry.Metrics` metric definitions to be collected and exposed."
    ],
    statsd: [
      type: {:or, [nil, {:keyword_list, @statsd_opts_schema}]}
    ],
    global_tags: [
      type: :keyword_list,
      default: [],
      doc:
        "Additional tags published with every metric. " <>
          "Global tags are overriden by the tags specified in the metric definition."
    ]
  ]

  defstruct Keyword.keys(@schema)

  @spec docs() :: String.t()
  def docs do
    NimbleOptions.docs(@schema)
  end

  @spec validate(Keyword.t()) :: {:ok, %__MODULE__{}} | {:error, String.t()}
  def validate(options) do
    case NimbleOptions.validate(options, @schema) do
      {:ok, options} ->
        new_statsd_options = rename_socket_path(options[:statsd])
        new_options = Keyword.put(options, :statsd, new_statsd_options)
        {:ok, struct(__MODULE__, new_options)}

      {:error, err} ->
        {:error, Exception.message(err)}
    end
  end

  @spec host(term()) ::
          {:ok, :inet.ip_address() | :inet.hostname()} | {:error, String.t()}
  def host(address) when is_tuple(address) do
    case :inet.ntoa(address) do
      {:error, _} ->
        {:error, "expected :host to be a valid IP address, got #{inspect(address)}"}

      _ ->
        {:ok, address}
    end
  end

  def host(address) when is_binary(address) do
    {:ok, to_charlist(address)}
  end

  def host(term) do
    {:error, "expected :host to be an IP address or a hostname, got #{inspect(term)}"}
  end

  @spec socket_path(term()) :: {:ok, :inet.local_address()} | {:error, String.t()}
  def socket_path(path) when is_binary(path) do
    {:ok, {:local, to_charlist(path)}}
  end

  def socket_path(term) do
    {:error, "expected :socket_path to be a string, got #{inspect(term)}"}
  end

  @spec formatter(term()) :: {:ok, :standard | :datadog} | {:error, String.t()}
  def formatter(:standard) do
    {:ok, :standard}
  end

  def formatter(:datadog) do
    {:ok, :datadog}
  end

  def formatter(term) do
    {:error, "expected :formatter be either :standard or :datadog, got #{inspect(term)}"}
  end

  defp rename_socket_path(nil) do
    nil
  end

  defp rename_socket_path(opts) do
    statsd_opts = opts[:statsd]

    if socket_path = Keyword.get(statsd_opts, :socket_path) do
      new_statsd_opts =
        statsd_opts
        |> Keyword.put(:host, socket_path)
        |> Keyword.delete(:socket_path)

      Keyword.put(opts, :statsd, new_statsd_opts)
    else
      opts
    end
  end
end
