ExUnit.start()

# Configure logger to suppress noise during tests
Logger.configure(level: :warning)

# Ensure clean environment for each test
Application.ensure_all_started(:telnyx)
