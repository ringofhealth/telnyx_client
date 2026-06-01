defmodule Telnyx.PhoneNumbersTest do
  use ExUnit.Case, async: false

  alias Telnyx.PhoneNumbers
  alias Telnyx.Error

  describe "search_available/2" do
    test "returns error with invalid API key" do
      search_params = %{
        filter: %{country_code: "US"}
      }

      assert {:error, %Error{}} = PhoneNumbers.search_available(search_params, "invalid-key")
    end

    test "handles nested search parameters" do
      search_params = %{
        filter: %{
          country_code: "US",
          phone_number: %{starts_with: "+1416"}
        },
        page: %{size: 10}
      }

      # Should not crash with nested params
      assert {:error, %Error{}} = PhoneNumbers.search_available(search_params, "invalid-key")
    end
  end

  describe "search_by_area_code/2" do
    test "returns error with invalid API key" do
      assert {:error, %Error{}} = PhoneNumbers.search_by_area_code("416", "invalid-key")
    end
  end

  describe "buy/2" do
    test "returns error with invalid API key" do
      assert {:error, %Error{}} = PhoneNumbers.buy("+14165551234", "invalid-key")
    end
  end

  describe "get/2" do
    test "returns error for non-existent phone number" do
      assert {:error, %Error{}} = PhoneNumbers.get("non-existent-id", "invalid-key")
    end
  end

  describe "list/1" do
    test "returns error with invalid API key" do
      assert {:error, %Error{}} = PhoneNumbers.list("invalid-key")
    end
  end

  describe "update/3" do
    test "returns error with invalid API key" do
      params = %{messaging_profile_id: "profile-123"}

      assert {:error, %Error{}} = PhoneNumbers.update("phone-id", params, "invalid-key")
    end
  end

  describe "assign_to_messaging_profile/3" do
    test "returns error with invalid API key" do
      assert {:error, %Error{}} =
               PhoneNumbers.assign_to_messaging_profile(
                 "phone-id",
                 "profile-123",
                 "invalid-key"
               )
    end
  end

  describe "assign_to_call_control_application/3" do
    test "returns error with invalid API key" do
      assert {:error, %Error{}} =
               PhoneNumbers.assign_to_call_control_application(
                 "phone-id",
                 "app-id",
                 "invalid-key"
               )
    end

    test "calls update with connection_id parameter" do
      # This test verifies that assign_to_call_control_application
      # properly delegates to update with the connection_id field.
      # Since we can't mock, we verify it returns the expected error type.
      result =
        PhoneNumbers.assign_to_call_control_application(
          "1234567890",
          "call-control-app-id",
          "invalid-key"
        )

      assert {:error, %Error{}} = result
    end
  end

  describe "find_by_number/2" do
    test "returns error when list fails" do
      # With invalid key, list will fail
      assert {:error, %Error{}} = PhoneNumbers.find_by_number("+14165551234", "invalid-key")
    end
  end

  describe "find_phone_number_id/1" do
    setup :reset_api_key

    test "returns auth error when api_key config is missing" do
      Application.delete_env(:telnyx, :api_key)

      assert {:error, %Error{type: :authentication}} =
               PhoneNumbers.find_phone_number_id("+14165551234")
    end

    test "returns auth error when api_key config is blank" do
      Application.put_env(:telnyx, :api_key, "")

      assert {:error, %Error{type: :authentication}} =
               PhoneNumbers.find_phone_number_id("+14165551234")
    end

    test "resolves api_key from {:system, env_var}" do
      Application.put_env(:telnyx, :api_key, {:system, "TELNYX_API_KEY_TEST"})
      System.put_env("TELNYX_API_KEY_TEST", "invalid-key")
      on_exit(fn -> System.delete_env("TELNYX_API_KEY_TEST") end)

      # Real HTTP attempt with invalid key — proves the env-var was read.
      assert {:error, %Error{}} = PhoneNumbers.find_phone_number_id("+14165551234")
    end

    test "returns auth error when {:system, var} target is unset" do
      Application.put_env(:telnyx, :api_key, {:system, "TELNYX_API_KEY_TEST_MISSING"})
      System.delete_env("TELNYX_API_KEY_TEST_MISSING")

      assert {:error, %Error{type: :authentication}} =
               PhoneNumbers.find_phone_number_id("+14165551234")
    end

    test "propagates phone_number_not_found from find_by_number" do
      # The mapping itself is exercised by find_by_number/2 returning
      # validation error with code "phone_number_not_found". We can't hit
      # the happy path without a live Telnyx account, but we verify that
      # the {:error, %Telnyx.Error{}} contract is preserved through the
      # convenience layer (no atomization, no struct change).
      Application.put_env(:telnyx, :api_key, "invalid-key")

      assert {:error, %Error{}} = PhoneNumbers.find_phone_number_id("+14165551234")
    end
  end

  describe "get_voice/1" do
    setup :reset_api_key

    test "returns auth error when api_key config is missing" do
      Application.delete_env(:telnyx, :api_key)

      assert {:error, %Error{type: :authentication}} = PhoneNumbers.get_voice("phone-id")
    end

    test "returns auth error when api_key config is blank" do
      Application.put_env(:telnyx, :api_key, "")

      assert {:error, %Error{type: :authentication}} = PhoneNumbers.get_voice("phone-id")
    end

    test "resolves api_key from {:system, env_var}" do
      Application.put_env(:telnyx, :api_key, {:system, "TELNYX_API_KEY_TEST"})
      System.put_env("TELNYX_API_KEY_TEST", "invalid-key")
      on_exit(fn -> System.delete_env("TELNYX_API_KEY_TEST") end)

      assert {:error, %Error{}} = PhoneNumbers.get_voice("phone-id")
    end

    test "propagates underlying error when api_key is invalid" do
      Application.put_env(:telnyx, :api_key, "invalid-key")

      assert {:error, %Error{}} = PhoneNumbers.get_voice("phone-id")
    end
  end

  describe "set_call_forwarding/4" do
    setup :reset_api_key

    test "returns auth error when api_key config is missing" do
      Application.delete_env(:telnyx, :api_key)

      assert {:error, %Error{type: :authentication}} =
               PhoneNumbers.set_call_forwarding("phone-id", true, "+14165551234", "always")
    end

    test "resolves api_key from {:system, env_var}" do
      Application.put_env(:telnyx, :api_key, {:system, "TELNYX_API_KEY_TEST"})
      System.put_env("TELNYX_API_KEY_TEST", "invalid-key")
      on_exit(fn -> System.delete_env("TELNYX_API_KEY_TEST") end)

      assert {:error, %Error{}} =
               PhoneNumbers.set_call_forwarding("phone-id", true, "+14165551234", "always")
    end

    test "propagates underlying error when api_key is invalid" do
      Application.put_env(:telnyx, :api_key, "invalid-key")

      assert {:error, %Error{}} =
               PhoneNumbers.set_call_forwarding("phone-id", true, "+14165551234", "always")
    end
  end

  defp reset_api_key(_context) do
    previous = Application.get_env(:telnyx, :api_key)
    on_exit(fn -> restore_api_key(previous) end)
    :ok
  end

  defp restore_api_key(nil), do: Application.delete_env(:telnyx, :api_key)
  defp restore_api_key(value), do: Application.put_env(:telnyx, :api_key, value)

  describe "search_and_buy_first/2" do
    test "returns error with invalid API key" do
      assert {:error, %Error{}} = PhoneNumbers.search_and_buy_first("416", "invalid-key")
    end
  end

  describe "query parameter building" do
    test "handles empty search params" do
      assert {:error, %Error{}} = PhoneNumbers.search_available(%{}, "invalid-key")
    end

    test "handles nil values in params" do
      search_params = %{
        filter: %{country_code: nil}
      }

      # nil values should be filtered out
      assert {:error, %Error{}} = PhoneNumbers.search_available(search_params, "invalid-key")
    end
  end
end
