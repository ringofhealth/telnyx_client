defmodule Telnyx.SMS.Message do
  @moduledoc """
  SMS message structure and validation.

  Represents an SMS message with minimal validation - letting Telnyx handle format validation.
  """

  @enforce_keys [:to, :text]
  defstruct [
    :to,
    :text,
    :from,
    :messaging_profile_id,
    :webhook_url,
    :webhook_failover_url,
    :use_profile_webhooks,
    type: "SMS"
  ]

  @type t :: %__MODULE__{
          to: String.t(),
          text: String.t(),
          from: String.t() | nil,
          messaging_profile_id: String.t() | nil,
          webhook_url: String.t() | nil,
          webhook_failover_url: String.t() | nil,
          use_profile_webhooks: boolean() | nil,
          type: String.t()
        }

  @doc """
  Creates a new SMS message.

  Performs minimal validation - only ensures required fields are present and non-empty.
  Telnyx API handles format validation (phone number format, character limits, etc.).

  ## Examples

      iex> Telnyx.SMS.Message.new(%{to: "+19876543210", text: "Hello!"})
      {:ok, %Telnyx.SMS.Message{to: "+19876543210", text: "Hello!"}}

      iex> Telnyx.SMS.Message.new(%{to: "", text: "Hello!"})
      {:error, %Telnyx.Error{type: :validation, message: "Field 'to' cannot be empty"}}

  """
  @spec new(map()) :: {:ok, t()} | {:error, Telnyx.Error.t()}
  def new(params) when is_map(params) do
    with {:ok, to} <- validate_required_string(params, :to),
         {:ok, text} <- validate_required_string(params, :text) do
      message = %__MODULE__{
        to: to,
        text: text,
        from: get_param(params, :from),
        messaging_profile_id: get_param(params, :messaging_profile_id),
        webhook_url: get_param(params, :webhook_url),
        webhook_failover_url: get_param(params, :webhook_failover_url),
        use_profile_webhooks: get_param(params, :use_profile_webhooks),
        type: get_param(params, :type) || "SMS"
      }

      {:ok, message}
    end
  end

  def new(_params) do
    {:error, Telnyx.Error.validation("Message must be a map")}
  end

  @doc """
  Converts message to map for API request.
  """
  @spec to_api_params(t()) :: map()
  def to_api_params(%__MODULE__{} = message) do
    message
    |> Map.from_struct()
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  @doc """
  Merges message with config defaults.
  """
  @spec merge_with_config(t(), Telnyx.Config.t()) :: t()
  def merge_with_config(%__MODULE__{} = message, %Telnyx.Config{} = config) do
    %{message |
      from: message.from || config.default_from,
      messaging_profile_id: message.messaging_profile_id || config.messaging_profile_id,
      webhook_url: message.webhook_url || config.webhook_url,
      webhook_failover_url: message.webhook_failover_url || config.webhook_failover_url
    }
  end

  # Private helper functions

  defp get_param(params, field) do
    Map.get(params, field) || Map.get(params, to_string(field))
  end

  defp validate_required_string(params, field) do
    value = get_param(params, field)
    
    case value do
      nil ->
        {:error, Telnyx.Error.validation("Field '#{field}' is required")}

      "" ->
        {:error, Telnyx.Error.validation("Field '#{field}' cannot be empty")}

      value when is_binary(value) ->
        {:ok, value}

      _other ->
        {:error, Telnyx.Error.validation("Field '#{field}' must be a string")}
    end
  end
end