defmodule Todo.Web do
  use Plug.Router
  require Logger

  plug :match
  plug :dispatch

  def start_server do
    case Application.get_env(:todo, :port) do
      nil -> raise("Todo port not specified")
      port ->
        Logger.info "Starting #{Application.get_application(__MODULE__)} application web router on port #{port}"
        Plug.Adapters.Cowboy.http(__MODULE__, nil, port: port)
    end
  end

  get "/hello" do
    Plug.Conn.send_resp(conn, 200, "world")
  end

  # curl -d '' 'http://localhost:5454/all_entries?list=bill's list'
  get "/all_entries" do
    conn
    |> Plug.Conn.fetch_query_params
    |> fetch_all_entries
    |> respond
  end

  # curl -d '' 'http://localhost:5454/entries?list=bill's list&date=20170123&title=Dentist'
  get "/entries" do
    conn
    |> Plug.Conn.fetch_query_params
    |> fetch_entries
    |> respond
  end

  # curl -d '' 'http://localhost:5454/add_entry?list=bill's list&date=20170123&title=Dentist'
  post "/add_entry" do
    conn
    |> Plug.Conn.fetch_query_params
    |> add_entry
    |> respond
  end

  defp fetch_all_entries(conn) do
    Plug.Conn.assign(
      conn,
      :response,
      all_entries(conn.params["list"])
    )
  end

  defp fetch_entries(conn) do
    Plug.Conn.assign(
      conn, 
      :response, 
      entries(conn.params["list"], parse_date(conn.params["date"]))
    )
  end

  defp all_entries(list_name) do
    list_name
    |> Todo.Cache.server_process
    |> Todo.Server.all_entries
    |> format_entries
  end

  defp entries(list_name, date) do
    list_name
    |> Todo.Cache.server_process
    |> Todo.Server.entries(date)
    |> format_entries
  end

  defp format_entries(entries) do
    for entry <- entries do
      {y,m,d} = entry.date
      "#{y}-#{m}-#{d} #{entry.title}"
    end
    |> Enum.join("\n")
  end

  defp add_entry(conn) do
    conn.params["list"]
    |> Todo.Cache.server_process
    |> Todo.Server.add_entry(
        %{
          date: parse_date(conn.params["date"]),
          title: conn.params["title"]
        }
    )

    Plug.Conn.assign(conn, :response, "OK")
  end

  defp respond(conn) do
    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(200, conn.assigns[:response])
  end

  defp parse_date(<<year::binary-size(4), month::binary-size(2), day::binary-size(2)>>) do
    {String.to_integer(year), String.to_integer(month), String.to_integer(day)}
  end

  match _ do
    Plug.Conn.send_resp(conn, 404, "oops, not found")
  end

end
