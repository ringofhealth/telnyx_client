defmodule Telnyx.CallControl.Result do
  @moduledoc """
  Represents the result of a Call Control command.

  Contains information about the command execution returned by Telnyx.
  """

  @enforce_keys [:command_id, :status, :action]
  defstruct [
    :command_id,
    :status,
    :action,
    :call_control_id
  ]

  @type action :: :transfer | :hangup | :answer

  @type t :: %__MODULE__{
          command_id: String.t(),
          status: :ok,
          action: action(),
          call_control_id: String.t() | nil
        }

  @doc """
  Creates a result from Telnyx API response.

  ## Examples

      iex> response = %{"result" => "ok"}
      iex> Telnyx.CallControl.Result.from_response(response, :transfer, "v2:abc123")
      %Telnyx.CallControl.Result{
        command_id: "cmd_...",
        status: :ok,
        action: :transfer,
        call_control_id: "v2:abc123"
      }

  """
  @spec from_response(map(), action(), String.t()) :: t()
  def from_response(response, action, call_control_id) when is_map(response) do
    %__MODULE__{
      command_id: extract_command_id(response),
      status: :ok,
      action: action,
      call_control_id: call_control_id
    }
  end

  defp extract_command_id(%{"data" => %{"command_id" => command_id}}), do: command_id
  defp extract_command_id(%{"command_id" => command_id}), do: command_id
  defp extract_command_id(_), do: nil
end
