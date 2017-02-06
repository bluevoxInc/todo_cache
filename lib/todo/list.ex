defmodule Todo.List do
  # The data structure has changed so that entries are keyed by date.
  # This allows quick fetch of data by date and reduces the amount 
  # of data written back to the database on each change.
  # %todo_list{days: %{entry.date: [entries]}}
  defstruct days: Map.new, size: 0

  def new(entries \\ []) do
    Enum.reduce(
      entries,
      %Todo.List{},
      &add_entry(&2, &1)
    )
  end

  def add_entry(todo_list, entry) do
    %Todo.List{todo_list | 
      days: Map.update(todo_list.days, entry.date, [entry], &[entry | &1]),
      size: todo_list.size + 1
    }
  end

  def entries(%Todo.List{days: days}, date) do
    Map.get(days, date)
  end

  # This function called to restore entries from the database.
  def set_entries(todo_list, date, entries) do
    %Todo.List{todo_list | days: Map.put(todo_list.days, date, entries)}
  end
end
