defmodule Telnyx.Config do
  @moduledoc """
  Configuration management for Telnyx SMS operations.

  Supports both global application configuration and explicit per-operation configuration.
  """

  @enforce_keys [:messaging_profile_id]
  defstruct [
    :messaging_profile_id,
    :default_from,
    :webhook_url,
    :webhook_failover_url,
    api_key: nil,
    timeout: 10_000
  ]

  @type t :: %__MODULE__{
          messaging_profile_id: String.t(),
          default_from: String.t() | nil,
          webhook_url: String.t() | nil,
          webhook_failover_url: String.t() | nil,
          api_key: String.t() | nil,
          timeout: pos_integer()
        }

  @doc """
  Creates a new configuration.

  ## Examples

      iex> config = Telnyx.Config.new(messaging_profile_id: "abc-123", default_from: "+14165551234")
      %Telnyx.Config{messaging_profile_id: "abc-123", default_from: "+14165551234"}

  """
  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    struct!(__MODULE__, opts)
  end

  @doc """
  Gets the API key from config or application environment.

  ## Examples

      iex> Telnyx.Config.get_api_key(%Telnyx.Config{api_key: "explicit-key"})
      "explicit-key"

      iex> Telnyx.Config.get_api_key(%Telnyx.Config{api_key: nil})
      # Returns value from Application.get_env(:telnyx, :api_key)

  """
  @spec get_api_key(t()) :: String.t() | nil
  def get_api_key(%__MODULE__{api_key: api_key}) when is_binary(api_key) do
    api_key
  end

  def get_api_key(%__MODULE__{api_key: nil}) do
    case Application.get_env(:telnyx, :api_key) do
      {:system, env_var} -> System.get_env(env_var)
      value -> value
    end
  end

  @doc """
  Gets the default configuration from application environment.

  ## Examples

      # In config.exs:
      config :telnyx,
        api_key: {:system, "TELNYX_API_KEY"},
        default_messaging_profile_id: "default-profile-id"

      iex> Telnyx.Config.default()
      %Telnyx.Config{messaging_profile_id: "default-profile-id", ...}

  """
  @spec default() :: t() | nil
  def default do
    case Application.get_env(:telnyx, :default_messaging_profile_id) do
      nil ->
        nil

      profile_id ->
        opts = [
          messaging_profile_id: profile_id,
          default_from: Application.get_env(:telnyx, :default_from),
          webhook_url: Application.get_env(:telnyx, :webhook_url),
          webhook_failover_url: Application.get_env(:telnyx, :webhook_failover_url),
          timeout: Application.get_env(:telnyx, :timeout, 10_000)
        ]

        new(Enum.filter(opts, fn {_k, v} -> v != nil end))
    end
  end
end