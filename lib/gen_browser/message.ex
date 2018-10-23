defmodule GenBrowser.Message do
  @moduledoc false
  @enforce_keys [:id, :data]
  defstruct @enforce_keys

  def new(id, data) do
    %__MODULE__{
      id: id,
      data: data
    }
  end
end
