defmodule Telnyx.Telemetry do
  @moduledoc """
  Telemetry events and utilities for Telnyx operations.

  Provides standardized telemetry events for monitoring SMS operations.
  """

  @doc """
  All telemetry events emitted by the Telnyx library.

  ## Events

  ### `[:telnyx, :sms, :send, :start]`
  Emitted when an SMS send operation begins.

  #### Measurements
  - `:system_time` - System time when the event was emitted

  #### Metadata
  - `:to` - Destination phone number
  - `:messaging_profile_id` - Telnyx messaging profile ID

  ### `[:telnyx, :sms, :send, :stop]`
  Emitted when an SMS send operation completes (success or failure).

  #### Measurements
  - `:duration` - Duration of the operation in native time units
  - `:monotonic_time` - Monotonic time when the event was emitted

  #### Metadata (Success)
  - `:status` - `:success`
  - `:message_id` - Telnyx message ID
  - `:parts` - Number of SMS parts
  - `:cost` - Cost information `%{amount: string, currency: string}`
  - `:to` - Destination phone number
  - `:messaging_profile_id` - Telnyx messaging profile ID

  #### Metadata (Failure)
  - `:status` - `:error`
  - `:error_type` - Type of error (`:validation`, `:network`, `:rate_limit`, etc.)
  - `:error_code` - Specific error code from Telnyx API
  - `:to` - Destination phone number
  - `:messaging_profile_id` - Telnyx messaging profile ID

  ### `[:telnyx, :sms, :send, :exception]`
  Emitted when an SMS send operation raises an exception.

  #### Measurements
  - `:duration` - Duration until the exception in native time units
  - `:monotonic_time` - Monotonic time when the event was emitted

  #### Metadata
  - `:kind` - Exception kind (`:error`, `:exit`, `:throw`)
  - `:reason` - Exception reason
  - `:stacktrace` - Exception stacktrace
  - `:to` - Destination phone number
  - `:messaging_profile_id` - Telnyx messaging profile ID

  ## Usage Examples

      # Attach to all SMS events
      :telemetry.attach_many(
        "my-app-telnyx-handler",
        [
          [:telnyx, :sms, :send, :start],
          [:telnyx, :sms, :send, :stop],
          [:telnyx, :sms, :send, :exception]
        ],
        &MyApp.Telemetry.handle_telnyx_event/4,
        nil
      )

      # Example handler
      def handle_telnyx_event([:telnyx, :sms, :send, :stop], measurements, metadata, _config) do
        case metadata.status do
          :success ->
            Logger.info("SMS sent successfully",
              message_id: metadata.message_id,
              duration_ms: System.convert_time_unit(measurements.duration, :native, :millisecond)
            )

          :error ->
            Logger.error("SMS failed",
              error_type: metadata.error_type,
              error_code: metadata.error_code,
              duration_ms: System.convert_time_unit(measurements.duration, :native, :millisecond)
            )
        end
      end

  """

  @spec events() :: [[atom()]]
  def events do
    [
      [:telnyx, :sms, :send, :start],
      [:telnyx, :sms, :send, :stop],
      [:telnyx, :sms, :send, :exception]
    ]
  end
end