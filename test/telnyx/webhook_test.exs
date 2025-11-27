defmodule Telnyx.WebhookTest do
  use ExUnit.Case, async: true

  alias Telnyx.Webhook

  # Test keypair - generated once for tests
  # In production, use the public key from Telnyx Portal
  @test_private_key :crypto.generate_key(:eddsa, :ed25519) |> elem(1)
  @test_public_key :crypto.generate_key(:eddsa, :ed25519, @test_private_key) |> elem(0)
  @test_public_key_base64 Base.encode64(@test_public_key)

  describe "verify/4" do
    setup do
      # Clean up any app config
      on_exit(fn ->
        Application.delete_env(:telnyx, :webhook_public_key)
      end)

      :ok
    end

    test "returns :ok for valid signature" do
      payload = ~s({"event_type":"call.initiated","data":{"call_control_id":"v2:abc123"}})
      timestamp = to_string(System.system_time(:second))

      signature = sign_payload(payload, timestamp)

      assert :ok =
               Webhook.verify(payload, signature, timestamp, public_key: @test_public_key_base64)
    end

    test "returns error for invalid signature" do
      payload = ~s({"event_type":"call.initiated"})
      timestamp = to_string(System.system_time(:second))

      # Use a different payload to create an invalid signature
      wrong_signature = sign_payload("different payload", timestamp)

      assert {:error, :invalid_signature} =
               Webhook.verify(payload, wrong_signature, timestamp,
                 public_key: @test_public_key_base64
               )
    end

    test "returns error for expired timestamp" do
      payload = ~s({"event_type":"call.initiated"})
      # Timestamp from 10 minutes ago (outside 5 minute tolerance)
      old_timestamp = to_string(System.system_time(:second) - 600)

      signature = sign_payload(payload, old_timestamp)

      assert {:error, :timestamp_expired} =
               Webhook.verify(payload, signature, old_timestamp,
                 public_key: @test_public_key_base64
               )
    end

    test "returns error for missing public key" do
      payload = ~s({"event_type":"call.initiated"})
      timestamp = to_string(System.system_time(:second))
      signature = sign_payload(payload, timestamp)

      # Don't pass public_key option and ensure app config is clear
      Application.delete_env(:telnyx, :webhook_public_key)

      assert {:error, :missing_public_key} =
               Webhook.verify(payload, signature, timestamp)
    end

    test "returns error for invalid public key format" do
      payload = ~s({"event_type":"call.initiated"})
      timestamp = to_string(System.system_time(:second))
      signature = sign_payload(payload, timestamp)

      assert {:error, :invalid_public_key} =
               Webhook.verify(payload, signature, timestamp, public_key: "not-valid-base64!")
    end

    test "returns error for wrong size public key" do
      payload = ~s({"event_type":"call.initiated"})
      timestamp = to_string(System.system_time(:second))
      signature = sign_payload(payload, timestamp)

      # Valid base64 but wrong size for ED25519
      assert {:error, :invalid_public_key} =
               Webhook.verify(payload, signature, timestamp, public_key: Base.encode64("short"))
    end

    test "returns error for malformed signature" do
      payload = ~s({"event_type":"call.initiated"})
      timestamp = to_string(System.system_time(:second))

      assert {:error, :invalid_signature} =
               Webhook.verify(payload, "not-valid-base64!", timestamp,
                 public_key: @test_public_key_base64
               )
    end

    test "returns error for invalid timestamp format" do
      payload = ~s({"event_type":"call.initiated"})
      signature = sign_payload(payload, "12345")

      assert {:error, :invalid_timestamp} =
               Webhook.verify(payload, signature, "not-a-number",
                 public_key: @test_public_key_base64
               )
    end

    test "uses public key from application config" do
      Application.put_env(:telnyx, :webhook_public_key, @test_public_key_base64)

      payload = ~s({"event_type":"call.initiated"})
      timestamp = to_string(System.system_time(:second))
      signature = sign_payload(payload, timestamp)

      # No public_key option - should use app config
      assert :ok = Webhook.verify(payload, signature, timestamp)
    end

    test "option public_key overrides application config" do
      # Set wrong key in app config
      wrong_key = :crypto.generate_key(:eddsa, :ed25519) |> elem(0) |> Base.encode64()
      Application.put_env(:telnyx, :webhook_public_key, wrong_key)

      payload = ~s({"event_type":"call.initiated"})
      timestamp = to_string(System.system_time(:second))
      signature = sign_payload(payload, timestamp)

      # Pass correct key in options - should succeed
      assert :ok =
               Webhook.verify(payload, signature, timestamp, public_key: @test_public_key_base64)
    end

    test "respects custom tolerance option" do
      payload = ~s({"event_type":"call.initiated"})
      # Timestamp from 4 minutes ago
      old_timestamp = to_string(System.system_time(:second) - 240)

      signature = sign_payload(payload, old_timestamp)

      # With default tolerance (300s / 5 min), this should pass
      assert :ok =
               Webhook.verify(payload, signature, old_timestamp,
                 public_key: @test_public_key_base64
               )

      # With tight tolerance (60s), this should fail
      assert {:error, :timestamp_expired} =
               Webhook.verify(payload, signature, old_timestamp,
                 public_key: @test_public_key_base64,
                 tolerance: 60
               )
    end
  end

  describe "valid?/4" do
    test "returns true for valid signature" do
      payload = ~s({"event_type":"call.initiated"})
      timestamp = to_string(System.system_time(:second))
      signature = sign_payload(payload, timestamp)

      assert Webhook.valid?(payload, signature, timestamp, public_key: @test_public_key_base64)
    end

    test "returns false for invalid signature" do
      payload = ~s({"event_type":"call.initiated"})
      timestamp = to_string(System.system_time(:second))

      refute Webhook.valid?(payload, "invalid", timestamp, public_key: @test_public_key_base64)
    end
  end

  describe "verify_conn/2" do
    test "returns error when signature header is missing" do
      conn = build_test_conn(%{}, %{raw_body: ~s({"event_type":"call.initiated"})})

      assert {:error, :missing_header} = Webhook.verify_conn(conn)
    end

    test "returns error when timestamp header is missing" do
      conn =
        build_test_conn(
          %{"telnyx-signature-ed25519" => "signature"},
          %{raw_body: ~s({"event_type":"call.initiated"})}
        )

      assert {:error, :missing_header} = Webhook.verify_conn(conn)
    end

    test "returns error when raw_body is not in assigns" do
      conn =
        build_test_conn(
          %{
            "telnyx-signature-ed25519" => "signature",
            "telnyx-timestamp" => "12345"
          },
          %{}
        )

      assert {:error, :missing_raw_body} = Webhook.verify_conn(conn)
    end

    test "verifies valid request from conn" do
      payload = ~s({"event_type":"call.initiated"})
      timestamp = to_string(System.system_time(:second))
      signature = sign_payload(payload, timestamp)

      conn =
        build_test_conn(
          %{
            "telnyx-signature-ed25519" => signature,
            "telnyx-timestamp" => timestamp
          },
          %{raw_body: payload}
        )

      assert :ok = Webhook.verify_conn(conn, public_key: @test_public_key_base64)
    end
  end

  # Helper functions

  defp sign_payload(payload, timestamp) do
    signed_payload = "#{timestamp}.#{payload}"
    signature = :crypto.sign(:eddsa, :none, signed_payload, [@test_private_key, :ed25519])
    Base.encode64(signature)
  end

  defp build_test_conn(headers, assigns) do
    # Build a minimal conn-like struct for testing
    %Plug.Conn{
      req_headers: Enum.map(headers, fn {k, v} -> {k, v} end),
      assigns: assigns
    }
  end
end
