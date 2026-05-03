defmodule ThesisPhoenixLiveviewWeb.PageController do
  use ThesisPhoenixLiveviewWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
