defmodule Telnyx.CallControl do
  @moduledoc """
  Telnyx Call Control API for routing and managing inbound calls.

  Provides commands to transfer, answer, and hang up calls using Telnyx's
  Call Control API. Designed for use with inbound call routing webhooks.

  ## Authentication

  API key can be provided in three ways (in order of precedence):
  1. Passed directly via `api_key` option
  2. Application config: `config :telnyx, :api_key, "KEY..."`
  3. Environment variable via config: `config :telnyx, :api_key, {:system, "TELNYX_API_KEY"}`

  ## Examples

      # Transfer to LiveKit SIP trunk
      Telnyx.CallControl.transfer(call_control_id, "sip:+14155551234@trunk.livekit.cloud")

      # Transfer to PSTN call center
      Telnyx.CallControl.transfer(call_control_id, "+18005551234")

      # With explicit API key
      Telnyx.CallControl.transfer(call_control_id, destination, api_key: "KEY...")

  ## Telemetry

  The following telemetry events are emitted:

      [:telnyx, :call_control, :transfer, :start]
      [:telnyx, :call_control, :transfer, :stop]
      [:telnyx, :call_control, :transfer, :exception]

      [:telnyx, :call_control, :hangup, :start]
      [:telnyx, :call_control, :hangup, :stop]
      [:telnyx, :call_control, :hangup, :exception]

      [:telnyx, :call_control, :answer, :start]
      [:telnyx, :call_control, :answer, :stop]
      [:telnyx, :call_control, :answer, :exception]

      [:telnyx, :call_control, :refer, :start]
      [:telnyx, :call_control, :refer, :stop]
      [:telnyx, :call_control, :refer, :exception]

  """

  alias Telnyx.CallControl.Result
  alias Telnyx.Client.FinchClient

  require Logger

  @default_timeout 10_000

  @doc """
  Transfer a call using SIP REFER (blind/cold transfer).

  This instructs Telnyx to perform a SIP REFER on the active call, handing
  the call off to the destination and removing Telnyx from the media path
  after the transfer completes.

  **Cost:** $0.10 flat fee (vs per-minute for regular transfer).
  **Trade-off:** Telnyx exits the call - no recording, monitoring, or further commands.

  The destination must be a valid SIP URI or PSTN number in E.164 format.

  ## Options

  - `:api_key` - Telnyx API key (falls back to application config/env)
  - `:timeout` - Request timeout in milliseconds (default: #{@default_timeout})
  - `:custom_headers` - List of custom SIP headers to pass to destination

  ## Examples

      # REFER to external PSTN call center
      Telnyx.CallControl.refer("v2:abc123", "+18005551234")

      # REFER with custom headers (pass context to destination)
      Telnyx.CallControl.refer("v2:abc123", "+18005551234",
        custom_headers: [
          {"X-Caller-ID", caller_id},
          {"X-Reason", "after-hours-routing"}
        ]
      )

      # REFER with explicit API key
      Telnyx.CallControl.refer("v2:abc123", destination, api_key: "KEY...")

  ## Webhook Events

  - `call.refer.started` - REFER initiated
  - `call.refer.completed` - REFER successful, Telnyx exited
  - `call.refer.failed` - REFER failed (call may drop)

  ## Returns

      {:ok, %Telnyx.CallControl.Result{}} - Command executed successfully
      {:error, %Telnyx.Error{}} - Command failed

  """
  @spec refer(String.t(), String.t(), keyword()) ::
          {:ok, Result.t()} | {:error, Telnyx.Error.t()}
  def refer(call_control_id, destination, opts \\ []) do
    params = build_refer_params(destination, opts)
    execute_command(:refer, call_control_id, params, opts)
  end

  defp build_refer_params(destination, opts) do
    base = %{to: destination}

    case Keyword.get(opts, :custom_headers) do
      nil ->
        base

      headers when is_list(headers) ->
        # Convert list of tuples to list of maps with name/value keys
        formatted_headers =
          Enum.map(headers, fn
            {name, value} -> %{name: name, value: value}
            %{name: _, value: _} = header -> header
          end)

        Map.put(base, :custom_headers, formatted_headers)
    end
  end

  @doc """
  Transfer a call to a destination.

  The destination can be either:
  - A SIP URI: `"sip:+14155551234@trunk.livekit.cloud"`
  - A PSTN number in E.164 format: `"+18005551234"`

  ## Options

  - `:api_key` - Telnyx API key (falls back to application config/env)
  - `:timeout` - Request timeout in milliseconds (default: #{@default_timeout})

  ## Examples

      # Transfer to LiveKit SIP trunk
      Telnyx.CallControl.transfer("v2:abc123", "sip:+14155551234@trunk.livekit.cloud")
      # => {:ok, %Telnyx.CallControl.Result{action: :transfer, status: :ok, ...}}

      # Transfer to PSTN call center
      Telnyx.CallControl.transfer("v2:abc123", "+18005551234")
      # => {:ok, %Telnyx.CallControl.Result{action: :transfer, status: :ok, ...}}

      # With explicit API key
      Telnyx.CallControl.transfer("v2:abc123", destination, api_key: "KEY...")

  ## Returns

      {:ok, %Telnyx.CallControl.Result{}} - Command executed successfully
      {:error, %Telnyx.Error{}} - Command failed

  """
  @spec transfer(String.t(), String.t(), keyword()) ::
          {:ok, Result.t()} | {:error, Telnyx.Error.t()}
  def transfer(call_control_id, destination, opts \\ []) do
    execute_command(:transfer, call_control_id, %{to: destination}, opts)
  end

  @doc """
  Hang up an active call.

  Use this to gracefully terminate a call, typically in error scenarios
  where transfer is not possible.

  ## Options

  - `:api_key` - Telnyx API key (falls back to application config/env)
  - `:timeout` - Request timeout in milliseconds (default: #{@default_timeout})

  ## Examples

      Telnyx.CallControl.hangup("v2:abc123")
      # => {:ok, %Telnyx.CallControl.Result{action: :hangup, status: :ok, ...}}

  """
  @spec hangup(String.t(), keyword()) ::
          {:ok, Result.t()} | {:error, Telnyx.Error.t()}
  def hangup(call_control_id, opts \\ []) do
    execute_command(:hangup, call_control_id, %{}, opts)
  end

  @doc """
  Answer an incoming call.

  This is needed before playing audio or performing operations that require
  the call to be answered. For blind transfers, answering is NOT required.

  ## Options

  - `:api_key` - Telnyx API key (falls back to application config/env)
  - `:timeout` - Request timeout in milliseconds (default: #{@default_timeout})

  ## Examples

      Telnyx.CallControl.answer("v2:abc123")
      # => {:ok, %Telnyx.CallControl.Result{action: :answer, status: :ok, ...}}

  """
  @spec answer(String.t(), keyword()) ::
          {:ok, Result.t()} | {:error, Telnyx.Error.t()}
  def answer(call_control_id, opts \\ []) do
    execute_command(:answer, call_control_id, %{}, opts)
  end

  # Private implementation

  defp execute_command(action, call_control_id, params, opts) do
    metadata = %{
      action: action,
      call_control_id: call_control_id
    }

    :telemetry.span([:telnyx, :call_control, action], metadata, fn ->
      case do_execute_command(action, call_control_id, params, opts) do
        {:ok, result} = success ->
          telemetry_metadata = Map.merge(metadata, %{
            status: :success,
            command_id: result.command_id
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

  defp do_execute_command(action, call_control_id, params, opts) do
    with {:ok, api_key} <- get_api_key(opts),
         {:ok, body} <- encode_body(params),
         {:ok, response} <- make_request(action, call_control_id, api_key, body, opts),
         {:ok, result} <- parse_response(response, action, call_control_id) do
      {:ok, result}
    end
  end

  defp get_api_key(opts) do
    api_key =
      Keyword.get(opts, :api_key) ||
        get_api_key_from_config()

    case api_key do
      nil ->
        {:error,
         Telnyx.Error.authentication(
           "API key not found. Pass via :api_key option or set TELNYX_API_KEY environment variable"
         )}

      "" ->
        {:error, Telnyx.Error.authentication("API key cannot be empty")}

      key when is_binary(key) ->
        {:ok, key}
    end
  end

  defp get_api_key_from_config do
    case Application.get_env(:telnyx, :api_key) do
      {:system, env_var} -> System.get_env(env_var)
      value -> value
    end
  end

  defp encode_body(params) do
    case Jason.encode(params) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, Telnyx.Error.unknown("JSON encoding failed: #{inspect(reason)}")}
    end
  end

  defp make_request(action, call_control_id, api_key, body, opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    path = "/calls/#{URI.encode(call_control_id)}/actions/#{action}"

    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case FinchClient.post(path, headers, body, timeout) do
      {:ok, response} ->
        {:ok, response}

      {:error, :timeout} ->
        {:error, Telnyx.Error.network("Request timeout after #{timeout}ms")}

      {:error, reason} ->
        {:error, Telnyx.Error.network("HTTP request failed: #{inspect(reason)}")}
    end
  end

  defp parse_response(%{status: status, body: body}, action, call_control_id)
       when status in 200..299 do
    case Jason.decode(body) do
      {:ok, response} ->
        result = Result.from_response(response, action, call_control_id)
        {:ok, result}

      {:error, reason} ->
        Logger.error("Failed to parse Telnyx Call Control response",
          body: body,
          reason: reason
        )

        {:error, Telnyx.Error.api("Invalid JSON response")}
    end
  end

  defp parse_response(%{status: status, body: body}, _action, _call_control_id) do
    case Jason.decode(body) do
      {:ok, %{"errors" => [error | _]}} ->
        {:error, Telnyx.Error.from_response(error, status)}

      {:ok, %{"error" => error}} ->
        {:error, Telnyx.Error.from_response(error, status)}

      {:ok, response} ->
        Logger.warning("Unexpected Telnyx Call Control error response",
          response: response,
          status: status
        )

        {:error, Telnyx.Error.api("Unexpected error response", status_code: status)}

      {:error, _reason} ->
        Logger.error("Failed to parse Telnyx Call Control error response",
          body: body,
          status: status
        )

        {:error, Telnyx.Error.api("Invalid error response", status_code: status)}
    end
  end
end
