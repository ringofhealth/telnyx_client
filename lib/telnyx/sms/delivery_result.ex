defmodule Telnyx.SMS.DeliveryResult do
  @moduledoc """
  Represents the result of an SMS delivery attempt.

  Contains information about the message status, cost, and delivery details returned by Telnyx.
  """

  @enforce_keys [:id, :status, :to]
  defstruct [
    :id,
    :status,
    :to,
    :from,
    :text,
    :direction,
    :parts,
    :cost,
    :carrier,
    :line_type,
    :created_at,
    :updated_at,
    :valid_until,
    :errors
  ]

  @type status :: :queued | :sending | :sent | :delivered | :delivery_failed | :failed

  @type cost :: %{
          amount: String.t(),
          currency: String.t()
        }

  @type recipient :: %{
          address: String.t(),
          status: String.t(),
          updated_at: String.t()
        }

  @type t :: %__MODULE__{
          id: String.t(),
          status: status(),
          to: [recipient()],
          from: String.t() | nil,
          text: String.t() | nil,
          direction: String.t() | nil,
          parts: pos_integer() | nil,
          cost: cost() | nil,
          carrier: String.t() | nil,
          line_type: String.t() | nil,
          created_at: String.t() | nil,
          updated_at: String.t() | nil,
          valid_until: String.t() | nil,
          errors: [String.t()] | nil
        }

  @doc """
  Creates a delivery result from Telnyx API response.

  ## Examples

      iex> response = %{
      ...>   "id" => "msg_123",
      ...>   "to" => [%{"address" => "+19876543210", "status" => "queued"}],
      ...>   "from" => "+14165551234",
      ...>   "text" => "Hello!"
      ...> }
      iex> Telnyx.SMS.DeliveryResult.from_response(response)
      %Telnyx.SMS.DeliveryResult{id: "msg_123", status: :queued, ...}

  """
  @spec from_response(map()) :: t()
  def from_response(response) when is_map(response) do
    %__MODULE__{
      id: response["id"],
      status: parse_status(response),
      to: response["to"] || [],
      from: response["from"],
      text: response["text"],
      direction: response["direction"],
      parts: response["parts"],
      cost: parse_cost(response["cost"]),
      carrier: response["carrier"],
      line_type: response["line_type"],
      created_at: response["created_at"],
      updated_at: response["updated_at"],
      valid_until: response["valid_until"],
      errors: response["errors"] || []
    }
  end

  @doc """
  Returns true if the message was successfully queued/sent.
  """
  @spec success?(t()) :: boolean()
  def success?(%__MODULE__{status: status}) do
    status in [:queued, :sending, :sent, :delivered]
  end

  @doc """
  Returns true if the message failed.
  """
  @spec failed?(t()) :: boolean()
  def failed?(%__MODULE__{status: status}) do
    status in [:delivery_failed, :failed]
  end

  @doc """
  Gets the primary recipient phone number.
  """
  @spec primary_recipient(t()) :: String.t() | nil
  def primary_recipient(%__MODULE__{to: [%{"address" => address} | _]}) do
    address
  end

  def primary_recipient(%__MODULE__{to: []}) do
    nil
  end

  # Private helper functions

  defp parse_status(%{"to" => [%{"status" => status} | _]}) do
    case status do
      "queued" -> :queued
      "sending" -> :sending
      "sent" -> :sent
      "delivered" -> :delivered
      "delivery_failed" -> :delivery_failed
      "failed" -> :failed
      _other -> :queued
    end
  end

  defp parse_status(_response) do
    :queued
  end

  defp parse_cost(%{"amount" => amount, "currency" => currency}) do
    %{amount: amount, currency: currency}
  end

  defp parse_cost(_cost) do
    nil
  end
end