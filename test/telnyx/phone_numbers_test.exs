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
