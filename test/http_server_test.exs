defmodule HttpServerTest do
  use ExUnit.Case, async: false

  setup do
    File.rm_rf("Mnesia.nonode@nohost")

    # Initializes the mnesia database.
    :mnesia.stop    # First we stop mnesia, so we can create the schema.
    :mnesia.create_schema([node()])
    :mnesia.start
    :mnesia.create_table(:todo_lists, [attributes: [:name, :list], disc_only_copies: [node()]])
    :ok = :mnesia.wait_for_tables([:todo_lists], 5000)
    
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

    case HTTPoison.post("http://127.0.0.1:5454/add_entry?list=test&date=20170123&title=Business%20meeting", "") do
      {:ok, %HTTPoison.Response{status_code: status_code, headers: _headers, body: body}} ->
        assert status_code == 200
        assert body == "OK"
      _ -> assert false
    end

    case HTTPoison.post("http://127.0.0.1:5454/add_entry?list=test&date=20170203&title=Batting%20practice", "") do
      {:ok, %HTTPoison.Response{status_code: status_code, headers: _headers, body: body}} ->
        assert status_code == 200
        assert body == "OK"
      _ -> assert false
    end

    case HTTPoison.get("http://127.0.0.1:5454/entries?list=test&date=20170123") do
      {:ok, %HTTPoison.Response{status_code: status_code, headers: _headers, body: body}} ->
        assert status_code == 200
        assert body == "2017-1-23 Business meeting\n2017-1-23 Dentist"
      _ -> assert false
    end

    case HTTPoison.get("http://127.0.0.1:5454/all_entries?list=test") do
      {:ok, %HTTPoison.Response{status_code: status_code, headers: _headers, body: body}} ->
        assert status_code == 200
        assert body == "2017-1-23 Business meeting\n2017-1-23 Dentist\n2017-2-3 Batting practice"
      _ -> assert false
    end

    case HTTPoison.delete("http://127.0.0.1:5454/delete_entry_by_date?list=test&date=20170123") do
      {:ok, %HTTPoison.Response{status_code: status_code, headers: _headers, body: body}} ->
        assert status_code == 200
        assert body == "OK"
      _ -> assert false
    end

    case HTTPoison.get("http://127.0.0.1:5454/entries?list=test&date=20170123") do
      {:ok, %HTTPoison.Response{status_code: status_code, headers: _headers, body: body}} ->
        assert status_code == 200
        assert body == ""
      _ -> assert false
    end

  end

end
