use Amnesia

defdatabase TodoDatabase do

  deftable TodoList, [:name, :list], type: :set do

    @type date :: {number, number, number}
    @type t :: %TodoList{name: {String.t, date}, list: [{date, String.t}]}

  end
end
