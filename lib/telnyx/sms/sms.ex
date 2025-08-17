defmodule Telnyx.SMS do
  @moduledoc """
  Main SMS interface with telemetry integration.

  Provides the primary API for sending SMS messages with observability support.
  """

  import Kernel, except: [send: 2]
  alias Telnyx.SMS.{Message, Sender}

  @doc """
  Sends an SMS message.

  ## Examples

      # With explicit config
      config = Telnyx.Config.new(messaging_profile_id: "abc-123", default_from: "+14165551234")
      Telnyx.SMS.send(%{to: "+19876543210", text: "Hello!"}, config)

      # With default config from application environment
      Telnyx.SMS.send(%{to: "+19876543210", text: "Hello!"})

      # With per-message overrides
      Telnyx.SMS.send(%{
        to: "+19876543210",
        text: "Emergency alert!",
        from: "+14165550911"  # Override config default
      }, config)

  ## Returns

      {:ok, %Telnyx.SMS.DeliveryResult{}} - Message successfully queued/sent
      {:error, %Telnyx.Error{}} - Message failed with categorized error

  """
  @spec send(map(), Telnyx.Config.t() | nil) ::
          {:ok, Telnyx.SMS.DeliveryResult.t()} | {:error, Telnyx.Error.t()}
  def send(message_params, config \\ nil)

  def send(message_params, nil) do
    case Telnyx.Config.default() do
      nil ->
        {:error,
         Telnyx.Error.validation(
           "No configuration provided. Either pass a config or set default_messaging_profile_id in application config"
         )}

      default_config ->
        send(message_params, default_config)
    end
  end

  def send(message_params, %Telnyx.Config{} = config) when is_map(message_params) do
    metadata = %{
      to: message_params[:to] || message_params["to"],
      messaging_profile_id: config.messaging_profile_id
    }

    :telemetry.span([:telnyx, :sms, :send], metadata, fn ->
      case do_send(message_params, config) do
        {:ok, result} = success ->
          telemetry_metadata = Map.merge(metadata, %{
            status: :success,
            message_id: result.id,
            parts: result.parts,
            cost: result.cost
          })

          {success, telemetry_metadata}

        {:error, error} = failure ->
          telemetry_metadata = Map.merge(metadata, %{
            status: :error,
            error_type: error.type,
            error_code: error.code
          })

          {failure, telemetry_metadata}
      end
    end)
  end

  def send(_message_params, _config) do
    {:error, Telnyx.Error.validation("Message must be a map")}
  end

  @doc """
  Sends an SMS message without telemetry (for internal use).
  """
  @spec send_without_telemetry(map(), Telnyx.Config.t()) ::
          {:ok, Telnyx.SMS.DeliveryResult.t()} | {:error, Telnyx.Error.t()}
  def send_without_telemetry(message_params, %Telnyx.Config{} = config) do
    do_send(message_params, config)
  end

  # Private implementation

  defp do_send(message_params, config) do
    with {:ok, message} <- Message.new(message_params),
         {:ok, result} <- Sender.send(message, config) do
      {:ok, result}
    end
  end
end