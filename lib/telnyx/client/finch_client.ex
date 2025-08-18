defmodule Telnyx.Client.FinchClient do
  @moduledoc """
  Finch-based HTTP client for Telnyx API.

  Provides reliable HTTP communication with connection pooling and HTTP/2 support.
  """

  @behaviour Telnyx.Client.HttpClient

  require Logger

  @base_url "https://api.telnyx.com/v2"

  @impl true
  def post(path, headers, body, timeout) do
    url = build_url(path)

    request = Finch.build(:post, url, headers, body)

    case Finch.request(request, Telnyx.Finch, receive_timeout: timeout) do
      {:ok, %Finch.Response{status: status, body: response_body}} ->
        {:ok, %{status: status, body: response_body}}

      {:error, %Finch.Error{reason: :timeout}} ->
        {:error, :timeout}

      {:error, %Finch.Error{reason: reason}} ->
        Logger.warning("Telnyx HTTP request failed", reason: reason, url: url)
        {:error, reason}

      {:error, reason} ->
        Logger.warning("Telnyx HTTP request failed", reason: reason, url: url)
        {:error, reason}
    end
  end

  @impl true
  def get(path, headers, timeout) do
    url = build_url(path)

    request = Finch.build(:get, url, headers)

    case Finch.request(request, Telnyx.Finch, receive_timeout: timeout) do
      {:ok, %Finch.Response{status: status, body: response_body}} ->
        {:ok, %{status: status, body: response_body}}

      {:error, %Finch.Error{reason: :timeout}} ->
        {:error, :timeout}

      {:error, %Finch.Error{reason: reason}} ->
        Logger.warning("Telnyx HTTP request failed", reason: reason, url: url)
        {:error, reason}

      {:error, reason} ->
        Logger.warning("Telnyx HTTP request failed", reason: reason, url: url)
        {:error, reason}
    end
  end

  @impl true
  def patch(path, headers, body, timeout) do
    url = build_url(path)

    request = Finch.build(:patch, url, headers, body)

    case Finch.request(request, Telnyx.Finch, receive_timeout: timeout) do
      {:ok, %Finch.Response{status: status, body: response_body}} ->
        {:ok, %{status: status, body: response_body}}

      {:error, %Finch.Error{reason: :timeout}} ->
        {:error, :timeout}

      {:error, %Finch.Error{reason: reason}} ->
        Logger.warning("Telnyx HTTP request failed", reason: reason, url: url)
        {:error, reason}

      {:error, reason} ->
        Logger.warning("Telnyx HTTP request failed", reason: reason, url: url)
        {:error, reason}
    end
  end

  defp build_url(path) do
    @base_url <> path
  end
end