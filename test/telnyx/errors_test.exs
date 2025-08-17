defmodule Telnyx.ErrorTest do
  use ExUnit.Case, async: true

  alias Telnyx.Error

  describe "validation/2" do
    test "creates validation error with message" do
      error = Error.validation("Invalid field")

      assert error.type == :validation
      assert error.message == "Invalid field"
      assert error.code == nil
      assert error.details == nil
    end

    test "creates validation error with code and details" do
      error =
        Error.validation("Invalid field",
          code: "invalid_phone",
          details: %{field: :to, value: "invalid"}
        )

      assert error.type == :validation
      assert error.message == "Invalid field"
      assert error.code == "invalid_phone"
      assert error.details == %{field: :to, value: "invalid"}
    end
  end

  describe "authentication/2" do
    test "creates authentication error" do
      error = Error.authentication("Invalid API key", code: "unauthorized", status_code: 401)

      assert error.type == :authentication
      assert error.message == "Invalid API key"
      assert error.code == "unauthorized"
      assert error.status_code == 401
    end
  end

  describe "rate_limit/2" do
    test "creates rate limit error" do
      error =
        Error.rate_limit("Rate limit exceeded",
          code: "rate_limit",
          retry_after: 60,
          status_code: 429
        )

      assert error.type == :rate_limit
      assert error.message == "Rate limit exceeded"
      assert error.code == "rate_limit"
      assert error.retry_after == 60
      assert error.status_code == 429
    end
  end

  describe "network/2" do
    test "creates network error" do
      error = Error.network("Connection timeout", code: "timeout", details: %{timeout: 5000})

      assert error.type == :network
      assert error.message == "Connection timeout"
      assert error.code == "timeout"
      assert error.details == %{timeout: 5000}
    end
  end

  describe "api/2" do
    test "creates API error" do
      error =
        Error.api("Server error",
          code: "internal_error",
          details: %{trace_id: "abc123"},
          status_code: 500
        )

      assert error.type == :api
      assert error.message == "Server error"
      assert error.code == "internal_error"
      assert error.details == %{trace_id: "abc123"}
      assert error.status_code == 500
    end
  end

  describe "unknown/2" do
    test "creates unknown error" do
      error = Error.unknown("Unexpected error", code: "unknown")

      assert error.type == :unknown
      assert error.message == "Unexpected error"
      assert error.code == "unknown"
    end
  end

  describe "from_response/2" do
    test "creates validation error for 400 status" do
      error_data = %{
        "code" => "invalid_phone_number",
        "detail" => "The phone number is invalid",
        "meta" => %{"field" => "to"}
      }

      error = Error.from_response(error_data, 400)

      assert error.type == :validation
      assert error.message == "The phone number is invalid"
      assert error.code == "invalid_phone_number"
      assert error.details == %{"field" => "to"}
      assert error.status_code == 400
    end

    test "creates authentication error for 401 status" do
      error_data = %{
        "code" => "unauthorized",
        "detail" => "Invalid API key"
      }

      error = Error.from_response(error_data, 401)

      assert error.type == :authentication
      assert error.message == "Invalid API key"
      assert error.code == "unauthorized"
      assert error.status_code == 401
    end

    test "creates rate limit error for 429 status" do
      error_data = %{
        "code" => "rate_limit_exceeded",
        "detail" => "Too many requests",
        "meta" => %{"retry_after" => 60}
      }

      error = Error.from_response(error_data, 429)

      assert error.type == :rate_limit
      assert error.message == "Too many requests"
      assert error.code == "rate_limit_exceeded"
      assert error.retry_after == 60
      assert error.status_code == 429
    end

    test "creates API error for 500 status" do
      error_data = %{
        "code" => "internal_error",
        "detail" => "Server error",
        "meta" => %{"trace_id" => "abc123"}
      }

      error = Error.from_response(error_data, 500)

      assert error.type == :api
      assert error.message == "Server error"
      assert error.code == "internal_error"
      assert error.details == %{"trace_id" => "abc123"}
      assert error.status_code == 500
    end

    test "creates API error for other status codes" do
      error_data = %{
        "code" => "not_found",
        "detail" => "Message not found"
      }

      error = Error.from_response(error_data, 404)

      assert error.type == :api
      assert error.message == "Message not found"
      assert error.code == "not_found"
      assert error.status_code == 404
    end

    test "handles missing detail field" do
      error_data = %{"code" => "unknown_error"}

      error = Error.from_response(error_data, 400)

      assert error.type == :validation
      assert error.message == "Invalid request"
      assert error.code == "unknown_error"
    end

    test "handles retry_after not being an integer" do
      error_data = %{
        "code" => "rate_limit",
        "detail" => "Rate limited",
        "meta" => %{"retry_after" => "60"}
      }

      error = Error.from_response(error_data, 429)

      assert error.type == :rate_limit
      assert error.retry_after == nil
    end
  end

  describe "String.Chars implementation" do
    test "converts error to string without code" do
      error = Error.validation("Invalid field")

      assert to_string(error) == "[validation] Invalid field"
    end

    test "converts error to string with code" do
      error = Error.validation("Invalid field", code: "invalid_phone")

      assert to_string(error) == "[validation:invalid_phone] Invalid field"
    end
  end
end