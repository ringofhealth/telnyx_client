defmodule Telnyx.Provisioning.CallRouting do
  @moduledoc """
  High-level idempotent provisioning for Telnyx Call Routing.

  This module provides convenient functions for setting up call routing
  infrastructure in Telnyx. Operations are designed to be idempotent -
  running them multiple times with the same parameters will result in
  the same end state.

  ## Usage

      # Provision a complete call routing setup
      {:ok, result} = Telnyx.Provisioning.CallRouting.provision(
        %{
          application_name: "my-call-router",
          webhook_event_url: "https://example.com/webhooks/telnyx",
          phone_number: "+18005551234"
        },
        api_key
      )

      # Or step by step:
      {:ok, app} = Telnyx.Provisioning.CallRouting.ensure_application_exists(
        "my-call-router",
        %{webhook_event_url: "https://example.com/webhooks/telnyx"},
        api_key
      )

      :ok = Telnyx.Provisioning.CallRouting.assign_phone_number(
        "+18005551234",
        app["id"],
        api_key
      )

  """

  alias Telnyx.{CallControlApplication, PhoneNumbers, Error}

  @type provision_params :: %{
          required(:application_name) => String.t(),
          required(:webhook_event_url) => String.t(),
          optional(:webhook_api_version) => String.t(),
          optional(:phone_number) => String.t()
        }

  @type provision_result :: %{
          application: map(),
          phone_number: map() | nil
        }

  @doc """
  Provisions a complete call routing setup.

  Creates or finds the Call Control Application and optionally assigns
  a phone number to it. This operation is idempotent.

  ## Parameters

  - `params` - Map containing:
    - `:application_name` - Name for the Call Control Application (required)
    - `:webhook_event_url` - URL for receiving webhook events (required)
    - `:webhook_api_version` - API version for webhooks (default: "2")
    - `:phone_number` - Phone number to assign (optional, E.164 format)
  - `api_key` - Telnyx API key

  ## Returns

  - `{:ok, %{application: app, phone_number: phone}}` on success
  - `{:error, Telnyx.Error.t()}` on failure

  ## Examples

      iex> params = %{
      ...>   application_name: "violet-call-router-prod",
      ...>   webhook_event_url: "https://api.example.com/webhooks/telnyx/inbound",
      ...>   phone_number: "+18555345529"
      ...> }
      iex> Telnyx.Provisioning.CallRouting.provision(params, api_key)
      {:ok, %{application: %{"id" => "...", ...}, phone_number: %{"id" => "...", ...}}}

  """
  @spec provision(provision_params(), String.t()) ::
          {:ok, provision_result()} | {:error, Error.t()}
  def provision(params, api_key) do
    with {:ok, application_name} <- get_required(params, :application_name),
         {:ok, webhook_event_url} <- get_required(params, :webhook_event_url),
         app_params <- build_app_params(webhook_event_url, params),
         {:ok, application} <- ensure_application_exists(application_name, app_params, api_key),
         {:ok, phone_number} <- maybe_assign_phone_number(params, application["id"], api_key) do
      {:ok, %{application: application, phone_number: phone_number}}
    end
  end

  @doc """
  Ensures a Call Control Application exists with the given name.

  If an application with the name already exists, it returns that application.
  Otherwise, it creates a new one with the provided parameters.

  ## Parameters

  - `application_name` - The unique name for the application
  - `params` - Application parameters (used only when creating):
    - `:webhook_event_url` - URL for receiving webhook events (required)
    - `:webhook_api_version` - API version for webhooks (default: "2")
  - `api_key` - Telnyx API key

  ## Returns

  - `{:ok, application}` - The existing or newly created application
  - `{:error, Telnyx.Error.t()}` - On failure

  ## Examples

      iex> params = %{webhook_event_url: "https://example.com/webhooks"}
      iex> Telnyx.Provisioning.CallRouting.ensure_application_exists("my-app", params, api_key)
      {:ok, %{"id" => "app-123", "application_name" => "my-app", ...}}

  """
  @spec ensure_application_exists(String.t(), map(), String.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def ensure_application_exists(application_name, params, api_key) do
    case CallControlApplication.find_by_application_name(application_name, api_key) do
      {:ok, application} ->
        {:ok, application}

      {:error, %Error{code: "call_control_application_not_found"}} ->
        create_params =
          params
          |> Map.put(:application_name, application_name)
          |> Map.put_new(:webhook_api_version, "2")

        CallControlApplication.create(create_params, api_key)

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Assigns a phone number to a Call Control Application.

  Looks up the phone number by its E.164 format and assigns it to the
  specified application.

  ## Parameters

  - `phone_number` - The phone number in E.164 format (e.g., "+18005551234")
  - `application_id` - The Call Control Application ID
  - `api_key` - Telnyx API key

  ## Returns

  - `:ok` on success
  - `{:error, Telnyx.Error.t()}` on failure

  ## Examples

      iex> Telnyx.Provisioning.CallRouting.assign_phone_number("+18005551234", "app-123", api_key)
      :ok

  """
  @spec assign_phone_number(String.t(), String.t(), String.t()) ::
          :ok | {:error, Error.t()}
  def assign_phone_number(phone_number, application_id, api_key) do
    with {:ok, phone_record} <- PhoneNumbers.find_by_number(phone_number, api_key),
         {:ok, _updated} <-
           PhoneNumbers.assign_to_call_control_application(
             phone_record["id"],
             application_id,
             api_key
           ) do
      :ok
    end
  end

  @doc """
  Returns the application ID for a named Call Control Application.

  This is useful when you need to get the `connection_id` for assigning
  phone numbers or configuring other resources.

  ## Examples

      iex> Telnyx.Provisioning.CallRouting.get_application_id("my-app", api_key)
      {:ok, "1234567890-abcd-efgh-ijkl-mnopqrstuvwx"}

  """
  @spec get_application_id(String.t(), String.t()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def get_application_id(application_name, api_key) do
    case CallControlApplication.find_by_application_name(application_name, api_key) do
      {:ok, application} -> {:ok, application["id"]}
      {:error, error} -> {:error, error}
    end
  end

  # Private helpers

  defp get_required(params, key) do
    case Map.get(params, key) do
      nil ->
        {:error, Error.validation("Missing required parameter: #{key}")}

      "" ->
        {:error, Error.validation("Parameter cannot be empty: #{key}")}

      value ->
        {:ok, value}
    end
  end

  defp build_app_params(webhook_event_url, params) do
    %{webhook_event_url: webhook_event_url}
    |> maybe_put(:webhook_api_version, Map.get(params, :webhook_api_version, "2"))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_assign_phone_number(%{phone_number: phone_number}, application_id, api_key)
       when is_binary(phone_number) and phone_number != "" do
    case assign_phone_number(phone_number, application_id, api_key) do
      :ok ->
        # Re-fetch the phone number to return its details
        PhoneNumbers.find_by_number(phone_number, api_key)

      {:error, error} ->
        {:error, error}
    end
  end

  defp maybe_assign_phone_number(_params, _application_id, _api_key) do
    {:ok, nil}
  end
end
