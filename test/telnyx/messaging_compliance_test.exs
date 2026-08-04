defmodule Telnyx.MessagingComplianceTest do
  use ExUnit.Case, async: false

  alias Telnyx.MessagingCompliance

  defmodule HttpClient do
    @behaviour Telnyx.Client.HttpClient

    def get(path, headers, timeout), do: respond(:get, path, headers, "", timeout)
    def post(path, headers, body, timeout), do: respond(:post, path, headers, body, timeout)
    def patch(path, headers, body, timeout), do: respond(:patch, path, headers, body, timeout)
    def put(path, headers, body, timeout), do: respond(:put, path, headers, body, timeout)

    defp respond(method, path, headers, body, timeout) do
      send(self(), {:http_request, method, path, headers, body, timeout})
      {:ok, %{status: 200, body: Jason.encode!(%{"data" => %{"ok" => true}})}}
    end
  end

  test "exposes registration endpoints through an injected HTTP client" do
    opts = [api_key: "test-only", http_client: HttpClient]

    assert {:ok, %{"ok" => true}} =
             MessagingCompliance.create_brand(%{"displayName" => "Acme"}, opts)

    assert_receive {:http_request, :post, "/10dlc/brand", headers, body, 15_000}
    assert {"Authorization", "Bearer test-only"} in headers
    assert Jason.decode!(body) == %{"displayName" => "Acme"}

    assert {:ok, _response} = MessagingCompliance.get_campaign("campaign/unsafe", opts)

    assert_receive {:http_request, :get, "/10dlc/campaign/campaign%2Funsafe", _headers, "",
                    15_000}

    assert {:ok, _response} = MessagingCompliance.verify_brand_otp("brand-1", "123456", opts)

    assert_receive {:http_request, :put, "/10dlc/brand/brand-1/smsOtp", _headers, otp_body,
                    15_000}

    assert Jason.decode!(otp_body) == %{"otpPin" => "123456"}
  end

  test "refuses to make a request without an explicit or configured credential" do
    previous = Application.get_env(:telnyx, :api_key)
    Application.delete_env(:telnyx, :api_key)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:telnyx, :api_key, previous),
        else: Application.delete_env(:telnyx, :api_key)
    end)

    assert {:error, %Telnyx.Error{type: :authentication}} =
             MessagingCompliance.get_brand("brand-1", http_client: HttpClient)

    refute_received {:http_request, _, _, _, _, _}
  end
end
