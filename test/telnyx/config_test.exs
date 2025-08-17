defmodule Telnyx.ConfigTest do
  use ExUnit.Case, async: true

  alias Telnyx.Config

  describe "new/1" do
    test "creates config with required messaging_profile_id" do
      config = Config.new(messaging_profile_id: "test-profile")

      assert config.messaging_profile_id == "test-profile"
      assert config.api_key == nil
      assert config.timeout == 10_000
    end

    test "creates config with all optional fields" do
      config =
        Config.new(
          messaging_profile_id: "test-profile",
          default_from: "+14165551234",
          webhook_url: "https://example.com/webhook",
          webhook_failover_url: "https://example.com/failover",
          api_key: "test-key",
          timeout: 5_000
        )

      assert config.messaging_profile_id == "test-profile"
      assert config.default_from == "+14165551234"
      assert config.webhook_url == "https://example.com/webhook"
      assert config.webhook_failover_url == "https://example.com/failover"
      assert config.api_key == "test-key"
      assert config.timeout == 5_000
    end

    test "raises error when messaging_profile_id is missing" do
      assert_raise ArgumentError, fn ->
        Config.new([])
      end
    end
  end

  describe "get_api_key/1" do
    test "returns explicit api_key when present" do
      config = Config.new(messaging_profile_id: "test", api_key: "explicit-key")

      assert Config.get_api_key(config) == "explicit-key"
    end

    test "returns application config when api_key is nil" do
      config = Config.new(messaging_profile_id: "test")

      # Mock application config
      Application.put_env(:telnyx, :api_key, "app-config-key")

      assert Config.get_api_key(config) == "app-config-key"

      # Cleanup
      Application.delete_env(:telnyx, :api_key)
    end

    test "handles system environment variable config" do
      config = Config.new(messaging_profile_id: "test")

      # Mock application config pointing to env var
      Application.put_env(:telnyx, :api_key, {:system, "TELNYX_TEST_KEY"})
      System.put_env("TELNYX_TEST_KEY", "env-var-key")

      assert Config.get_api_key(config) == "env-var-key"

      # Cleanup
      Application.delete_env(:telnyx, :api_key)
      System.delete_env("TELNYX_TEST_KEY")
    end

    test "returns nil when no api_key is configured" do
      config = Config.new(messaging_profile_id: "test")

      # Ensure no application config
      Application.delete_env(:telnyx, :api_key)

      assert Config.get_api_key(config) == nil
    end
  end

  describe "default/0" do
    test "returns nil when no default_messaging_profile_id is configured" do
      Application.delete_env(:telnyx, :default_messaging_profile_id)

      assert Config.default() == nil
    end

    test "creates default config from application environment" do
      Application.put_env(:telnyx, :default_messaging_profile_id, "default-profile")
      Application.put_env(:telnyx, :default_from, "+14165551234")
      Application.put_env(:telnyx, :webhook_url, "https://example.com/webhook")
      Application.put_env(:telnyx, :timeout, 15_000)

      config = Config.default()

      assert config.messaging_profile_id == "default-profile"
      assert config.default_from == "+14165551234"
      assert config.webhook_url == "https://example.com/webhook"
      assert config.timeout == 15_000

      # Cleanup
      Application.delete_env(:telnyx, :default_messaging_profile_id)
      Application.delete_env(:telnyx, :default_from)
      Application.delete_env(:telnyx, :webhook_url)
      Application.delete_env(:telnyx, :timeout)
    end

    test "filters out nil values from application config" do
      Application.put_env(:telnyx, :default_messaging_profile_id, "default-profile")
      # Don't set optional configs

      config = Config.default()

      assert config.messaging_profile_id == "default-profile"
      assert config.default_from == nil
      assert config.webhook_url == nil
      assert config.timeout == 10_000

      # Cleanup
      Application.delete_env(:telnyx, :default_messaging_profile_id)
    end
  end
end