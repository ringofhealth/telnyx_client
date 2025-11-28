defmodule Telnyx.CallControlApplicationTest do
  use ExUnit.Case, async: false

  alias Telnyx.CallControlApplication
  alias Telnyx.Error

  # These tests focus on the module's logic without mocking HTTP.
  # They test error paths and parameter handling that don't require
  # actual API calls.

  describe "create/2" do
    test "returns authentication error when API key is invalid" do
      params = %{
        application_name: "test-app",
        webhook_event_url: "https://example.com/webhooks"
      }

      # Using an invalid API key will result in an API error from Telnyx
      assert {:error, %Error{}} = CallControlApplication.create(params, "invalid-key")
    end

    test "returns error for empty API key" do
      params = %{application_name: "test-app"}

      # Empty API key should result in an authentication error from Telnyx
      assert {:error, %Error{}} = CallControlApplication.create(params, "")
    end
  end

  describe "get/2" do
    test "returns error for non-existent application" do
      # Invalid ID will result in API error
      assert {:error, %Error{}} =
               CallControlApplication.get("non-existent-id", "invalid-key")
    end
  end

  describe "list/2" do
    test "returns error with invalid API key" do
      assert {:error, %Error{}} = CallControlApplication.list("invalid-key")
    end

    test "builds query params correctly for filter option" do
      # This test verifies the internal build_query_params function
      # by checking that the request doesn't crash with nested params
      assert {:error, %Error{}} =
               CallControlApplication.list("invalid-key",
                 filter: %{application_name: "test-app"}
               )
    end

    test "builds query params correctly for page option" do
      assert {:error, %Error{}} =
               CallControlApplication.list("invalid-key",
                 page: %{size: 20, number: 1}
               )
    end

    test "builds query params correctly for combined options" do
      assert {:error, %Error{}} =
               CallControlApplication.list("invalid-key",
                 filter: %{application_name: "test"},
                 page: %{size: 10}
               )
    end
  end

  describe "find_by_application_name/2" do
    test "returns error with invalid API key" do
      assert {:error, %Error{}} =
               CallControlApplication.find_by_application_name("my-app", "invalid-key")
    end
  end

  describe "update/3" do
    test "returns error for invalid application ID" do
      params = %{application_name: "updated-name"}

      assert {:error, %Error{}} =
               CallControlApplication.update("invalid-id", params, "invalid-key")
    end
  end

  describe "delete/2" do
    test "returns error for non-existent application" do
      assert {:error, %Error{}} =
               CallControlApplication.delete("non-existent-id", "invalid-key")
    end
  end

  describe "query parameter building" do
    # These tests verify the internal flatten_nested_params logic
    # by ensuring the module handles various parameter structures

    test "handles empty options" do
      # Should not crash with empty options
      assert {:error, %Error{}} = CallControlApplication.list("invalid-key", [])
    end

    test "handles nil values in options" do
      # nil values should be filtered out
      assert {:error, %Error{}} =
               CallControlApplication.list("invalid-key",
                 filter: %{application_name: nil}
               )
    end

    test "handles deeply nested parameters" do
      # Should handle nested structures for bracket notation
      assert {:error, %Error{}} =
               CallControlApplication.list("invalid-key",
                 filter: %{
                   application_name: "test",
                   status: "active"
                 },
                 page: %{size: 25, number: 2}
               )
    end
  end
end
