defmodule Telnyx.Error do
  @moduledoc """
  Structured error types for Telnyx operations.

  Provides clear error categorization to help upstream services handle failures appropriately.
  """

  @type error_type :: :validation | :authentication | :rate_limit | :network | :api | :unknown

  @enforce_keys [:type, :message]
  defstruct [
    :type,
    :message,
    :code,
    :details,
    :retry_after,
    :status_code
  ]

  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t(),
          code: String.t() | nil,
          details: map() | nil,
          retry_after: pos_integer() | nil,
          status_code: pos_integer() | nil
        }

  @doc """
  Creates a validation error.

  ## Examples

      iex> Telnyx.Error.validation("Missing required field", code: "missing_field")
      %Telnyx.Error{type: :validation, message: "Missing required field", code: "missing_field"}

  """
  @spec validation(String.t(), keyword()) :: t()
  def validation(message, opts \\ []) do
    %__MODULE__{
      type: :validation,
      message: message,
      code: opts[:code],
      details: opts[:details],
      status_code: opts[:status_code]
    }
  end

  @doc """
  Creates an authentication error.
  """
  @spec authentication(String.t(), keyword()) :: t()
  def authentication(message, opts \\ []) do
    %__MODULE__{
      type: :authentication,
      message: message,
      code: opts[:code],
      status_code: opts[:status_code]
    }
  end

  @doc """
  Creates a rate limit error.
  """
  @spec rate_limit(String.t(), keyword()) :: t()
  def rate_limit(message, opts \\ []) do
    %__MODULE__{
      type: :rate_limit,
      message: message,
      code: opts[:code],
      retry_after: opts[:retry_after],
      status_code: opts[:status_code]
    }
  end

  @doc """
  Creates a network error.
  """
  @spec network(String.t(), keyword()) :: t()
  def network(message, opts \\ []) do
    %__MODULE__{
      type: :network,
      message: message,
      code: opts[:code],
      details: opts[:details]
    }
  end

  @doc """
  Creates an API error from Telnyx response.
  """
  @spec api(String.t(), keyword()) :: t()
  def api(message, opts \\ []) do
    %__MODULE__{
      type: :api,
      message: message,
      code: opts[:code],
      details: opts[:details],
      status_code: opts[:status_code]
    }
  end

  @doc """
  Creates an unknown error.
  """
  @spec unknown(String.t(), keyword()) :: t()
  def unknown(message, opts \\ []) do
    %__MODULE__{
      type: :unknown,
      message: message,
      code: opts[:code],
      details: opts[:details],
      status_code: opts[:status_code]
    }
  end

  @doc """
  Converts a Telnyx API error response to a structured error.
  """
  @spec from_response(map(), pos_integer()) :: t()
  def from_response(error_data, status_code) do
    case status_code do
      400 ->
        validation(
          error_data["detail"] || "Invalid request",
          code: error_data["code"],
          details: error_data["meta"],
          status_code: status_code
        )

      401 ->
        authentication(
          error_data["detail"] || "Authentication failed",
          code: error_data["code"],
          status_code: status_code
        )

      429 ->
        rate_limit(
          error_data["detail"] || "Rate limit exceeded",
          code: error_data["code"],
          retry_after: parse_retry_after(error_data),
          status_code: status_code
        )

      status when status >= 500 ->
        api(
          error_data["detail"] || "Server error",
          code: error_data["code"],
          details: error_data["meta"],
          status_code: status_code
        )

      _ ->
        api(
          error_data["detail"] || "API error",
          code: error_data["code"],
          details: error_data["meta"],
          status_code: status_code
        )
    end
  end

  defp parse_retry_after(error_data) do
    case error_data do
      %{"meta" => %{"retry_after" => retry_after}} when is_integer(retry_after) ->
        retry_after

      _ ->
        nil
    end
  end
end

defimpl String.Chars, for: Telnyx.Error do
  def to_string(%Telnyx.Error{type: type, message: message, code: code}) do
    case code do
      nil -> "[#{type}] #{message}"
      code -> "[#{type}:#{code}] #{message}"
    end
  end
end