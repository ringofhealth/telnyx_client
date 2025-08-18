defmodule Telnyx.Client.HttpClient do
  @moduledoc """
  HTTP client behavior for Telnyx API communication.

  Defines the contract for HTTP operations with the Telnyx API.
  """

  @type headers :: [{String.t(), String.t()}]
  @type body :: String.t()
  @type response :: %{status: pos_integer(), body: String.t()}

  @doc """
  Performs a POST request to the Telnyx API.
  """
  @callback post(url :: String.t(), headers :: headers(), body :: body(), timeout :: pos_integer()) ::
              {:ok, response()} | {:error, term()}

  @doc """
  Performs a GET request to the Telnyx API.
  """
  @callback get(url :: String.t(), headers :: headers(), timeout :: pos_integer()) ::
              {:ok, response()} | {:error, term()}

  @doc """
  Performs a PATCH request to the Telnyx API.
  """
  @callback patch(url :: String.t(), headers :: headers(), body :: body(), timeout :: pos_integer()) ::
              {:ok, response()} | {:error, term()}
end