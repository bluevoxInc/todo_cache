defmodule HttpServerTest do
  use ExUnit.Case, async: false

  setup do
    # This is an integration test of the entire app. Remove the old
    # persisted data, then start the app.
    #File.rm_rf("./persist/test")
    {:ok, apps} = Application.ensure_all_started(:todo)

    # Start HTTPoison
    HTTPoison.start

    on_exit fn ->
      # stop all applications started above
      Enum.each(apps, &Application.stop/1)
    end

    :ok
  end

  test "http server" do
    case HTTPoison.get("http://127.0.0.1:5454/entries?list=test&date=20170123") do
      {:ok, %HTTPoison.Response{status_code: status_code, headers: _headers, body: body}} ->
        assert status_code == 200
        assert body == ""
      _ -> assert false
    end

    case HTTPoison.post("http://127.0.0.1:5454/add_entry?list=test&date=20170123&title=Dentist", "") do
      {:ok, %HTTPoison.Response{status_code: status_code, headers: _headers, body: body}} ->
        assert status_code == 200
        assert body == "OK"
      _ -> assert false
    end

    case HTTPoison.get("http://127.0.0.1:5454/entries?list=test&date=20170123") do
      {:ok, %HTTPoison.Response{status_code: status_code, headers: _headers, body: body}} ->
        assert status_code == 200
        assert body == "2017-1-23 Dentist"
      _ -> assert false
    end

    case HTTPoison.post("http://127.0.0.1:5454/add_entry?list=test&date=20170125&title=Business%20meeting", "") do
      {:ok, %HTTPoison.Response{status_code: status_code, headers: _headers, body: body}} ->
        assert status_code == 200
        assert body == "OK"
      _ -> assert false
    end

    case HTTPoison.get("http://127.0.0.1:5454/all_entries?list=test") do
      {:ok, %HTTPoison.Response{status_code: status_code, headers: _headers, body: body}} ->
        assert status_code == 200
        assert body == "2017-1-23 Dentist\n2017-1-25 Business meeting"
      _ -> assert false
    end

  end

end
